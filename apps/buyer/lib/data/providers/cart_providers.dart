import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cart/cart_logic.dart';
import '../models/cart_item.dart';
import 'package:shopscroll_shared/models/product.dart';
import '../repositories/cart_repository.dart';
import '../repositories/repository_providers.dart';

/// The buyer's current cart contents, as if fetched from `GET /cart`. The
/// notifier also holds the writes (spec 0007): each one changes the state
/// first, then saves through the repository, and puts the state back if the
/// save fails, rethrowing so the caller can say so.
///
/// No automatic retry: a failed load must reach the screen as an error with
/// its own "Try again" button (spec 0007, AC-8), not spin through retries.
final cartItemsProvider = AsyncNotifierProvider<CartNotifier, List<CartItem>>(
  CartNotifier.new,
  retry: (retryCount, error) => null,
);

class CartNotifier extends AsyncNotifier<List<CartItem>> {
  // Writes run one after another, in the order they were made, so quick
  // taps never overwrite each other. Quantities are sent as absolute
  // values, so the last one wins.
  Future<void> _tail = Future.value();
  int _pending = 0;
  bool _dirty = false;
  int _localIds = 0;

  // Lines added here carry a `local-N` id until the save returns the real
  // one; later writes to such a line look its real id up in here.
  final _realIds = <String, String>{};

  CartRepository get _repo => ref.read(cartRepositoryProvider);

  @override
  Future<List<CartItem>> build() =>
      ref.watch(cartRepositoryProvider).getCartItems();

  /// As if sent to `POST /cart/items`. The same product, size and colour
  /// raises the existing line instead of adding a second one.
  Future<void> add(
    Product product, {
    int quantity = 1,
    String? size,
    int? color,
    DateTime? addedAt,
  }) {
    String? targetId;
    return _run(
      (lines) {
        final match = findLine(lines, product.id, size, color);
        if (match != null) {
          targetId = match.id;
          return [
            for (final line in lines)
              line.id == match.id
                  ? line.copyWith(
                      quantity: clampQuantity(line.quantity + quantity),
                    )
                  : line,
          ];
        }
        targetId = 'local-${_localIds++}';
        return [
          ...lines,
          CartItem(
            id: targetId!,
            product: product,
            quantity: clampQuantity(quantity),
            selectedSize: size,
            selectedColor: color,
            addedAt: addedAt ?? DateTime.now(),
          ),
        ];
      },
      () async {
        final saved = await _repo.addItem(
          product,
          quantity,
          size: size,
          color: color,
        );
        _adoptId(targetId!, saved.id);
      },
    );
  }

  /// As if sent to `PATCH /cart/items/:id`.
  Future<void> setQuantity(String itemId, int quantity) {
    final clamped = clampQuantity(quantity);
    return _run(
      (lines) => [
        for (final line in lines)
          line.id == itemId ? line.copyWith(quantity: clamped) : line,
      ],
      () => _repo.setQuantity(_realId(itemId), clamped),
    );
  }

  /// Steps a line's quantity by [delta] from what it is when the call runs,
  /// so quick taps never work from a stale number.
  Future<void> changeQuantity(String itemId, int delta) {
    int? target;
    return _run(
      (lines) => [
        for (final line in lines)
          if (line.id == itemId)
            line.copyWith(
              quantity: target = clampQuantity(line.quantity + delta),
            )
          else
            line,
      ],
      () async {
        if (target != null) await _repo.setQuantity(_realId(itemId), target!);
      },
    );
  }

  /// As if sent to `DELETE /cart/items/:id`.
  Future<void> remove(String itemId) => _run(
    (lines) => [
      for (final line in lines)
        if (line.id != itemId) line,
    ],
    () => _repo.removeItem(_realId(itemId)),
  );

  /// Puts a removed line back with the same product, size, colour and
  /// quantity. It is a new row on the server, so it gets a new id.
  Future<void> undoRemove(CartItem line) => add(
    line.product,
    quantity: line.quantity,
    size: line.selectedSize,
    color: line.selectedColor,
    addedAt: line.addedAt,
  );

  String _realId(String id) => _realIds[id] ?? id;

  void _adoptId(String from, String to) {
    if (from == to) return;
    _realIds[from] = to;
    state = AsyncData([
      for (final line in state.requireValue)
        line.id == from ? line.copyWith(id: to) : line,
    ]);
  }

  Future<void> _run(
    List<CartItem> Function(List<CartItem> lines) apply,
    Future<void> Function() write,
  ) async {
    if (!state.hasValue) await future;
    final before = state.requireValue;
    state = AsyncData(apply(before));

    _pending++;
    final turn = _tail.then((_) => write());
    _tail = turn.then((_) {}, onError: (_) {});
    try {
      await turn;
    } catch (_) {
      // Alone in flight, the state before this call is exactly the last
      // saved one. With other writes in flight it is not, so reload once
      // they are all done instead.
      if (_pending == 1) {
        state = AsyncData(before);
      } else {
        _dirty = true;
      }
      rethrow;
    } finally {
      _pending--;
      if (_pending == 0 && _dirty) {
        _dirty = false;
        try {
          state = AsyncData(await _repo.getCartItems());
        } catch (_) {
          // Keep what is shown; the next read of the cart tries again.
        }
      }
    }
  }
}
