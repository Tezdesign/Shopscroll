import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopscroll_shared/models/conversation.dart';
import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/reel.dart';
import '../models/saved_product.dart';
import '../models/saved_reel.dart';
import '../repositories/repository_providers.dart';

/// The buyer's saved products, as if fetched from `GET /saved-products`,
/// newest saved first (spec 0008). The notifier also holds the writes: each
/// one changes the state first, then saves through the repository, and puts
/// the state back if the save fails, rethrowing so the caller can say so.
///
/// No automatic retry: a failed load must reach the screen as an error with
/// its own "Try again" button (AC-12), not spin through retries.
final savedProductsProvider =
    AsyncNotifierProvider<SavedProductsNotifier, List<SavedProduct>>(
      SavedProductsNotifier.new,
      retry: (retryCount, error) => null,
    );

/// The buyer's saved reels, as if fetched from `GET /saved-reels`, newest
/// saved first, unavailable reels included. Same rules as
/// [savedProductsProvider].
final savedReelsProvider =
    AsyncNotifierProvider<SavedReelsNotifier, List<SavedReel>>(
      SavedReelsNotifier.new,
      retry: (retryCount, error) => null,
    );

/// The buyer's store conversations, as if fetched from
/// `GET /conversations`, newest first. No automatic retry, so a failed load
/// reaches the Messages tab as an error with its own "Try again" (AC-12).
final conversationsProvider = FutureProvider<List<Conversation>>(
  (ref) => ref.watch(conversationRepositoryProvider).getConversations(),
  retry: (retryCount, error) => null,
);

class SavedProductsNotifier extends _SavedNotifier<SavedProduct> {
  @override
  Future<List<SavedProduct>> build() =>
      ref.watch(savedProductRepositoryProvider).getSavedProducts();

  @override
  Future<List<SavedProduct>> _reload() =>
      ref.read(savedProductRepositoryProvider).getSavedProducts();

  @override
  String _id(SavedProduct item) => item.product.id;

  @override
  DateTime _savedAt(SavedProduct item) => item.savedAt;

  /// As if sent to `PUT /saved-products/:productId`. [savedAt] is only for
  /// Undo, which keeps the old place in the list.
  Future<void> save(Product product, {DateTime? savedAt}) {
    final at = savedAt ?? DateTime.now();
    return _run(
      (items) => _with(items, SavedProduct(product, at)),
      () => ref
          .read(savedProductRepositoryProvider)
          .saveProduct(product, savedAt: at),
    );
  }

  /// As if sent to `DELETE /saved-products/:productId`.
  Future<void> unsave(String productId) => _run(
    (items) => _without(items, productId),
    () => ref.read(savedProductRepositoryProvider).unsaveProduct(productId),
  );

  /// Saves the product, or unsaves it when it is already saved, going by
  /// what is saved when the call runs.
  Future<void> toggle(Product product) async {
    if (!state.hasValue) await future;
    return isSaved(product.id) ? unsave(product.id) : save(product);
  }
}

class SavedReelsNotifier extends _SavedNotifier<SavedReel> {
  @override
  Future<List<SavedReel>> build() =>
      ref.watch(reelRepositoryProvider).getSavedReels();

  @override
  Future<List<SavedReel>> _reload() =>
      ref.read(reelRepositoryProvider).getSavedReels();

  @override
  String _id(SavedReel item) => item.reel.id;

  @override
  DateTime _savedAt(SavedReel item) => item.savedAt;

  /// As if sent to `PUT /saved-reels/:reelId`. [savedAt] is only for Undo.
  Future<void> save(Reel reel, {DateTime? savedAt}) {
    final at = savedAt ?? DateTime.now();
    return _run(
      (items) => _with(items, SavedReel(reel.copyWith(isSaved: true), at)),
      () => ref.read(reelRepositoryProvider).saveReel(reel, savedAt: at),
    );
  }

  /// As if sent to `DELETE /saved-reels/:reelId`.
  Future<void> unsave(String reelId) => _run(
    (items) => _without(items, reelId),
    () => ref.read(reelRepositoryProvider).unsaveReel(reelId),
  );

  /// Saves the reel, or unsaves it when it is already saved, going by what
  /// is saved when the call runs.
  Future<void> toggle(Reel reel) async {
    if (!state.hasValue) await future;
    return isSaved(reel.id) ? unsave(reel.id) : save(reel);
  }
}

/// The shared write logic of the two saved lists. The list is always kept
/// newest saved first, so it reads straight from the state.
abstract class _SavedNotifier<T> extends AsyncNotifier<List<T>> {
  Future<List<T>> _reload();
  String _id(T item);
  DateTime _savedAt(T item);

  // Writes run one after another, in the order they were made, so quick
  // taps never overwrite each other.
  Future<void> _tail = Future.value();
  int _pending = 0;
  bool _dirty = false;

  /// Whether [id] is saved right now. False while the list is loading.
  bool isSaved(String id) =>
      state.value?.any((item) => _id(item) == id) ?? false;

  List<T> _with(List<T> items, T added) =>
      [...items.where((item) => _id(item) != _id(added)), added]
        ..sort((a, b) => _savedAt(b).compareTo(_savedAt(a)));

  List<T> _without(List<T> items, String id) => [
    for (final item in items)
      if (_id(item) != id) item,
  ];

  Future<void> _run(
    List<T> Function(List<T> items) apply,
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
          state = AsyncData(await _reload());
        } catch (_) {
          // Keep what is shown; the next read of the list tries again.
        }
      }
    }
  }
}
