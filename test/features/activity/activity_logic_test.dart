import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/mock/mock_conversations.dart';
import 'package:marketplace_app/data/mock/mock_orders.dart';
import 'package:marketplace_app/data/mock/mock_reels.dart';
import 'package:marketplace_app/data/mock/mock_saved_products.dart';
import 'package:marketplace_app/data/models/saved_reel.dart';
import 'package:marketplace_app/features/activity/activity_logic.dart';

void main() {
  final now = DateTime(2026, 9, 26, 12);

  test(
    'order dates read like 27 Feb, with the year when not this one (AC-3)',
    () {
      expect(orderDateLabel(DateTime(2026, 2, 27), now), '27 Feb');
      expect(orderDateLabel(DateTime(2025, 12, 1), now), '1 Dec 2025');
    },
  );

  test('message times read 4:25am today and 27 Feb otherwise (AC-11)', () {
    expect(messageTimeLabel(DateTime(2026, 9, 26, 4, 25), now), '4:25am');
    expect(messageTimeLabel(DateTime(2026, 9, 26, 16, 5), now), '4:05pm');
    expect(messageTimeLabel(DateTime(2026, 9, 26, 0, 0), now), '12:00am');
    expect(messageTimeLabel(DateTime(2026, 2, 27, 9, 40), now), '27 Feb');
  });

  test('"+ N products" counts the items past the two shown (AC-3)', () {
    final order = mockOrders.first;
    expect(extraProductsLabel(order), isNull);
    final three = order.copyWith(items: [...order.items, ...order.items]);
    expect(extraProductsLabel(three), '+ 2 products');
    expect(
      extraProductsLabel(
        order.copyWith(items: [...order.items, order.items[0]]),
      ),
      '+ 1 products',
    );
  });

  test('totals read like \$320 (AC-3)', () {
    expect(
      orderTotalLabel(mockOrders.first.copyWith(totalAmount: 320)),
      '\$320',
    );
  });

  test('orders sort newest first without touching the input (AC-3)', () {
    final sorted = newestOrdersFirst(mockOrders);
    for (var i = 1; i < sorted.length; i++) {
      expect(sorted[i - 1].createdAt.isAfter(sorted[i].createdAt), isTrue);
    }
  });

  test('search ignores case and spaces, and matches the fields in AC-2', () {
    // Orders: any item's title or store name.
    final firstItem = mockOrders.first.items.first.product;
    expect(
      filterOrders(mockOrders, '  ${firstItem.title.toUpperCase()} '),
      contains(mockOrders.first),
    );
    expect(
      filterOrders(mockOrders, firstItem.storeName.toLowerCase()),
      contains(mockOrders.first),
    );
    expect(filterOrders(mockOrders, 'zzzz'), isEmpty);
    expect(filterOrders(mockOrders, '   '), mockOrders);

    // Saved products: title or store name.
    final saved = mockSavedProducts.first.product;
    expect(filterSavedProducts(mockSavedProducts, saved.title), isNotEmpty);
    expect(filterSavedProducts(mockSavedProducts, 'zzzz'), isEmpty);

    // Saved reels: caption or store name.
    final reels = [for (final r in mockReels) SavedReel(r, now)];
    expect(filterSavedReels(reels, mockReels.first.caption), isNotEmpty);
    expect(filterSavedReels(reels, mockReels.first.storeName), isNotEmpty);
    expect(filterSavedReels(reels, 'zzzz'), isEmpty);

    // Conversations: store name or last message.
    final c = mockConversations.first;
    expect(filterConversations(mockConversations, c.storeName), isNotEmpty);
    expect(filterConversations(mockConversations, c.lastMessage), isNotEmpty);
    expect(filterConversations(mockConversations, 'zzzz'), isEmpty);
  });
}
