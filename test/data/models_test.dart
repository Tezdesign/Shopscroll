import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/models/cart_item.dart';
import 'package:marketplace_app/data/models/order.dart';
import 'package:marketplace_app/data/models/product.dart';
import 'package:marketplace_app/data/models/reel.dart';
import 'package:marketplace_app/data/models/user_profile.dart';

void main() {
  group('Product', () {
    final product = Product(
      id: 'p1',
      title: 'Title',
      description: 'Description',
      price: 42,
      originalPrice: 60,
      category: 'Fashion',
      storeId: 's1',
      storeName: 'Store',
      colorOptions: const [0xFF000000],
      sizes: const ['S', 'M'],
      isDeal: true,
      rating: 4.5,
      reviewCount: 10,
      createdAt: DateTime(2026, 1, 1),
    );

    test('round-trips through toJson/fromJson', () {
      final restored = Product.fromJson(product.toJson());

      expect(restored.id, product.id);
      expect(restored.price, product.price);
      expect(restored.colorOptions, product.colorOptions);
      expect(restored.sizes, product.sizes);
      expect(restored.isDeal, isTrue);
      expect(restored.createdAt, product.createdAt);
    });

    test('priceLabel formats as a whole dollar amount', () {
      expect(product.priceLabel, r'$42');
    });

    test('copyWith overrides only the given fields', () {
      final updated = product.copyWith(price: 99);
      expect(updated.price, 99);
      expect(updated.title, product.title);
    });
  });

  group('Reel', () {
    test('round-trips through toJson/fromJson', () {
      final reel = Reel(
        id: 'r1',
        videoUrl: 'https://example.com/v.mp4',
        thumbnailUrl: 'https://example.com/t.jpg',
        storeId: 's1',
        storeName: 'Store',
        caption: 'Caption',
        productIds: const ['p1', 'p2'],
        isAvailable: false,
        createdAt: DateTime(2026, 1, 1),
      );

      final restored = Reel.fromJson(reel.toJson());

      expect(restored.id, reel.id);
      expect(restored.productIds, reel.productIds);
      expect(restored.isAvailable, isFalse);
    });
  });

  group('UserProfile', () {
    test('round-trips through toJson/fromJson', () {
      const profile = UserProfile(
        id: 'u1',
        name: 'Name',
        username: '@name',
        role: UserRole.seller,
        isVerified: true,
      );

      final restored = UserProfile.fromJson(profile.toJson());

      expect(restored.id, profile.id);
      expect(restored.role, UserRole.seller);
      expect(restored.isVerified, isTrue);
    });
  });

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
