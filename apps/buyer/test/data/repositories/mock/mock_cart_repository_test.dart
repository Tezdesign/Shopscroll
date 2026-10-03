import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/mock/mock_cart_items.dart';
import 'package:marketplace_app/data/mock/mock_products.dart';
import 'package:marketplace_app/data/repositories/mock/mock_cart_repository.dart';

void main() {
  late MockCartRepository repository;
  final blazer = mockProducts[0];

  setUp(() => repository = MockCartRepository());

  test('starts from the seed and never changes the shared seed list', () async {
    await repository.addItem(blazer, 1, size: 'XL');
    expect(mockCartItems.length, 3);
    expect((await repository.getCartItems()).length, 4);
  });

  test('addItem raises the same product, size and colour (AC-13)', () async {
    final seeded = mockCartItems[0];
    final saved = await repository.addItem(
      seeded.product,
      2,
      size: seeded.selectedSize,
      color: seeded.selectedColor,
    );
    expect(saved.id, seeded.id);
    expect(saved.quantity, seeded.quantity + 2);
    expect((await repository.getCartItems()).length, 3);
  });

  test('a different size makes a separate line', () async {
    await repository.addItem(blazer, 1, size: 'XL', color: 0xFF0066FF);
    expect((await repository.getCartItems()).length, 4);
  });

  test('quantity is held to 99', () async {
    final seeded = mockCartItems[0];
    final saved = await repository.addItem(
      seeded.product,
      500,
      size: seeded.selectedSize,
      color: seeded.selectedColor,
    );
    expect(saved.quantity, 99);
  });

  test('setQuantity updates a line and throws for a missing one', () async {
    final updated = await repository.setQuantity('cart-item-001', 7);
    expect(updated.quantity, 7);
    expect(repository.setQuantity('nope', 2), throwsStateError);
  });

  test('removeItem drops the line', () async {
    await repository.removeItem('cart-item-001');
    final ids = (await repository.getCartItems()).map((i) => i.id);
    expect(ids, isNot(contains('cart-item-001')));
  });
}
