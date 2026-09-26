import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/mock/mock_cart_items.dart';
import 'package:marketplace_app/data/mock/mock_products.dart';
import 'package:marketplace_app/data/models/cart_item.dart';
import 'package:marketplace_app/data/models/product.dart';
import 'package:marketplace_app/data/providers/cart_providers.dart';
import 'package:marketplace_app/data/repositories/cart_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';

/// In memory repository with no delay, and switches to make a write fail.
class _FakeRepo implements CartRepository {
  final items = List<CartItem>.of(mockCartItems);
  bool failSetQuantity = false;
  int _n = 0;

  @override
  Future<List<CartItem>> getCartItems() async => List.of(items);

  @override
  Future<CartItem> addItem(
    Product product,
    int quantity, {
    String? size,
    int? color,
  }) async {
    final i = items.indexWhere(
      (l) =>
          l.product.id == product.id &&
          l.selectedSize == size &&
          l.selectedColor == color,
    );
    if (i != -1) {
      return items[i] = items[i].copyWith(
        quantity: items[i].quantity + quantity,
      );
    }
    final item = CartItem(
      id: 'real-${_n++}',
      product: product,
      quantity: quantity,
      selectedSize: size,
      selectedColor: color,
      addedAt: DateTime.now(),
    );
    items.add(item);
    return item;
  }

  @override
  Future<CartItem> setQuantity(String itemId, int quantity) async {
    if (failSetQuantity) throw Exception('boom');
    final i = items.indexWhere((l) => l.id == itemId);
    return items[i] = items[i].copyWith(quantity: quantity);
  }

  @override
  Future<void> removeItem(String itemId) async =>
      items.removeWhere((l) => l.id == itemId);
}

void main() {
  late _FakeRepo repo;
  late ProviderContainer container;
  final blazer = mockProducts[0];

  Future<CartNotifier> open() async {
    await container.read(cartItemsProvider.future);
    return container.read(cartItemsProvider.notifier);
  }

  List<CartItem> lines() => container.read(cartItemsProvider).requireValue;

  setUp(() {
    repo = _FakeRepo();
    container = ProviderContainer(
      overrides: [cartRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  test('five quick plus taps raise the quantity by exactly 5 (AC-4)', () async {
    final cart = await open();
    final start = lines().first.quantity;
    final id = lines().first.id;
    final taps = [
      for (var i = 1; i <= 5; i++)
        cart.setQuantity(id, lines().first.quantity + 1),
    ];
    expect(lines().first.quantity, start + 5); // shown at once
    await Future.wait(taps);
    expect(repo.items.first.quantity, start + 5); // and saved
  });

  test('quantity is clamped to 1 to 99', () async {
    final cart = await open();
    await cart.setQuantity(lines().first.id, 500);
    expect(lines().first.quantity, 99);
    await cart.setQuantity(lines().first.id, 0);
    expect(lines().first.quantity, 1);
  });

  test('adding the same variant twice makes one line of 2 (AC-13)', () async {
    final cart = await open();
    final before = lines().length;
    await cart.add(blazer, size: 'XL', color: 1);
    await cart.add(blazer, size: 'XL', color: 1);
    expect(lines().length, before + 1);
    expect(lines().last.quantity, 2);
    await cart.add(blazer, size: 'XS', color: 1);
    expect(lines().length, before + 2);
  });

  test('quick taps on add before the save returns make one line', () async {
    final cart = await open();
    final before = lines().length;
    await Future.wait([
      cart.add(blazer, size: 'L'),
      cart.add(blazer, size: 'L'),
      cart.add(blazer, size: 'L'),
    ]);
    expect(lines().length, before + 1);
    expect(lines().last.quantity, 3);
    expect(lines().last.id, startsWith('real-'));
    expect(repo.items.last.quantity, 3);
  });

  test(
    'a stepper tap on a line still being added writes to its real id',
    () async {
      final cart = await open();
      final add = cart.add(blazer, size: 'L');
      final localId = lines().last.id;
      final set = cart.setQuantity(localId, 5);
      await Future.wait([add, set]);
      expect(repo.items.last.quantity, 5);
    },
  );

  test('remove then undo puts the same line back (AC-6)', () async {
    final cart = await open();
    final gone = lines().first;
    await cart.remove(gone.id);
    expect(lines().any((l) => l.id == gone.id), isFalse);
    await cart.undoRemove(gone);
    final back = lines().firstWhere((l) => l.product.id == gone.product.id);
    expect(back.quantity, gone.quantity);
    expect(back.selectedSize, gone.selectedSize);
    expect(back.selectedColor, gone.selectedColor);
    expect(lines().length, mockCartItems.length);
  });

  test('a failed write reverts the state and rethrows (AC-15)', () async {
    final cart = await open();
    final id = lines().first.id;
    final start = lines().first.quantity;
    repo.failSetQuantity = true;
    await expectLater(cart.setQuantity(id, start + 1), throwsException);
    expect(lines().first.quantity, start);
  });
}
