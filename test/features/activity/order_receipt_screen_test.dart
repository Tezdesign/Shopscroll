import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/data/mock/mock_orders.dart';
import 'package:marketplace_app/data/models/contact_info.dart';
import 'package:marketplace_app/data/models/order.dart';
import 'package:marketplace_app/data/models/shipping_address.dart';
import 'package:marketplace_app/data/repositories/mock/mock_order_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/features/activity/order_receipt_screen.dart';

/// Serves one order (or fails, or finds nothing) for any id.
class _Orders extends MockOrderRepository {
  _Orders({this.order, this.fail = false});

  final Order? order;
  final bool fail;
  int reads = 0;

  @override
  Future<Order?> getOrderById(String id) async {
    reads++;
    if (fail) throw Exception('no network');
    return order;
  }
}

void main() {
  final placed = Order(
    id: 'order-x',
    items: mockOrders.first.items,
    status: OrderStatus.inProgress,
    totalAmount: 55,
    orderNumber: 589,
    subtotal: 45,
    deliveryFee: 10,
    deliveryMethod: 'standard',
    contact: const ContactInfo(
      name: 'Moetez ben attia',
      email: 'moetez@example.com',
      phone: '+21650460604',
    ),
    shippingAddress: const ShippingAddress(
      city: 'menzah V',
      address: '18 rue des bonbons',
      zip: '0000',
      note: 'Next to the bank',
    ),
    paymentMethod: 'card',
    createdAt: DateTime.utc(2026, 9, 25, 9),
    estimatedDelivery: DateTime.utc(2026, 10, 5, 12),
  );

  Future<GoRouter> open(WidgetTester tester, _Orders orders) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/activity/orders/order-x',
      routes: [
        GoRoute(
          path: '/activity',
          builder: (context, state) =>
              const Scaffold(body: Text('Activity page')),
          routes: [
            GoRoute(
              path: 'orders/:id',
              builder: (context, state) =>
                  OrderReceiptScreen(orderId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(orders)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    return router;
  }

  Future<void> load(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the order number, date and status', (tester) async {
    await open(tester, _Orders(order: placed));
    await load(tester);

    expect(find.text('Order Receipt'), findsOneWidget);
    expect(find.text('Order#000589'), findsOneWidget);
    expect(find.textContaining('Purchase date : 25 Sep'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
  });

  testWidgets('lists every item with its store, quantity and price', (
    tester,
  ) async {
    await open(tester, _Orders(order: placed));
    await load(tester);

    for (final item in placed.items) {
      expect(find.text(item.product.storeName), findsWidgets);
      expect(find.text(item.product.title), findsOneWidget);
      expect(find.text('x${item.quantity}'), findsWidgets);
    }
  });

  testWidgets('shows the totals and the payment, shipping, delivery and '
      'contact blocks', (tester) async {
    await open(tester, _Orders(order: placed));
    await load(tester);

    expect(find.text('Order subtotal'), findsOneWidget);
    expect(find.text(r'$45'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text(r'$10'), findsOneWidget);
    expect(find.text('Total price'), findsOneWidget);
    expect(find.text(r'$55'), findsOneWidget);

    expect(find.text('Payment Method'), findsOneWidget);
    expect(find.text('Paid with a credit card'), findsOneWidget);

    expect(find.text('Shipping Address'), findsOneWidget);
    expect(find.text('Tunisia'), findsOneWidget);
    expect(find.text('18 rue des bonbons, menzah V, 0000'), findsOneWidget);
    expect(find.text('Next to the bank'), findsOneWidget);

    expect(find.text('Delivery Method'), findsOneWidget);
    expect(find.text('Standard shipping'), findsOneWidget);
    expect(find.text('Estimated arrival : 5 Oct'), findsOneWidget);

    expect(find.text('Contact Information'), findsOneWidget);
    expect(find.text('Moetez ben attia'), findsOneWidget);
    expect(find.text('moetez@example.com'), findsOneWidget);
    expect(find.text('+21650460604'), findsOneWidget);
  });

  testWidgets('the back button and the system back both leave the screen', (
    tester,
  ) async {
    Future<void> expectLeft(Future<void> Function() leave) async {
      await open(tester, _Orders(order: placed));
      await load(tester);
      await leave();
      await tester.pumpAndSettle();
      expect(find.text('Activity page'), findsOneWidget);
      expect(find.text('Order Receipt'), findsNothing);
    }

    await expectLeft(() => tester.tap(find.byIcon(Icons.chevron_left)));
    await expectLeft(() async {
      await tester.binding.handlePopRoute();
    });
  });

  testWidgets('shows a loading indicator while the order loads', (
    tester,
  ) async {
    await open(tester, _Orders(order: placed));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await load(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a failed load shows the message, and Try again reloads it', (
    tester,
  ) async {
    final orders = _Orders(fail: true);
    await open(tester, orders);
    await load(tester);

    expect(find.text("Couldn't load this order."), findsOneWidget);
    expect(orders.reads, 1);

    await tester.tap(find.text('Try again'));
    await load(tester);
    expect(orders.reads, 2);
  });

  testWidgets('an order that does not exist shows a not found message', (
    tester,
  ) async {
    await open(tester, _Orders());
    await load(tester);

    expect(find.text('Order not found'), findsOneWidget);
  });

  testWidgets('an older order with no contact renders without that block', (
    tester,
  ) async {
    await open(tester, _Orders(order: mockOrders[1]));
    await load(tester);

    expect(find.text('Order'), findsOneWidget);
    expect(find.text('Contact Information'), findsNothing);
    expect(find.text('Shipping Address'), findsOneWidget);
  });
}
