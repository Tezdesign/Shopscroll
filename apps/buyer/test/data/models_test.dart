import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/models/cart_item.dart';
import 'package:marketplace_app/data/models/order.dart';
import 'package:shopscroll_shared/models/product.dart';

void main() {
  group('CartItem', () {
    test('round-trips through toJson/fromJson and computes subtotal', () {
      final product = Product(
        id: 'p1',
        title: 'Title',
        description: 'Description',
        price: 20,
        category: 'Fashion',
        storeId: 's1',
        storeName: 'Store',
        createdAt: DateTime(2026, 1, 1),
      );
      final item = CartItem(
        id: 'c1',
        product: product,
        quantity: 3,
        addedAt: DateTime(2026, 1, 2),
      );

      expect(item.subtotal, 60);

      final restored = CartItem.fromJson(item.toJson());
      expect(restored.product.id, product.id);
      expect(restored.quantity, 3);
    });
  });

  group('Order', () {
    test('round-trips through toJson/fromJson', () {
      final product = Product(
        id: 'p1',
        title: 'Title',
        description: 'Description',
        price: 20,
        category: 'Fashion',
        storeId: 's1',
        storeName: 'Store',
        createdAt: DateTime(2026, 1, 1),
      );
      final order = Order(
        id: 'o1',
        items: [
          CartItem(id: 'c1', product: product, addedAt: DateTime(2026, 1, 2)),
        ],
        status: OrderStatus.inProgress,
        totalAmount: 20,
        createdAt: DateTime(2026, 1, 2),
      );

      final restored = Order.fromJson(order.toJson());

      expect(restored.id, order.id);
      expect(restored.status, OrderStatus.inProgress);
      expect(restored.items.single.product.id, product.id);
    });
  });
}
