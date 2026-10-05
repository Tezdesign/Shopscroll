import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/models/cart_item.dart';
import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/product_variant.dart';

void main() {
  final product = Product(
    id: 'p1',
    title: 'Dress',
    description: 'd',
    price: 40,
    category: 'Fashion',
    storeId: 's',
    storeName: 'S',
    createdAt: DateTime(2026),
    currency: 'TND',
    variants: const [
      ProductVariant(id: 'v1', colorValue: 1, size: 'S', price: 40, stock: 3),
      ProductVariant(id: 'v2', colorValue: 1, size: 'L', price: 55.5, stock: 3),
    ],
  );

  // Spec 0015, AC-19: a cart line pays the price of the picked variant.
  test('a line is priced from the picked color and size', () {
    final item = CartItem(
      id: 'c1',
      product: product,
      quantity: 2,
      selectedColor: 1,
      selectedSize: 'L',
      addedAt: DateTime(2026),
    );

    expect(item.unitPrice, 55.5);
    expect(item.subtotal, 111);
  });

  test('a line with no matching variant falls back to the product price', () {
    final item = CartItem(
      id: 'c1',
      product: product,
      selectedColor: 9,
      selectedSize: 'XL',
      addedAt: DateTime(2026),
    );

    expect(item.unitPrice, 40);
  });
}
