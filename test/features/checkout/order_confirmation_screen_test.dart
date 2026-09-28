import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/data/mock/mock_orders.dart';
import 'package:marketplace_app/data/models/contact_info.dart';
import 'package:marketplace_app/data/models/order.dart';
import 'package:marketplace_app/data/models/shipping_address.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/repositories/mock/mock_order_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/features/checkout/order_confirmation_screen.dart';

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
    orderNumber: 7,
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
    paymentMethod: 'cashOnDelivery',
    createdAt: DateTime.utc(2026, 9, 25, 9),
    estimatedDelivery: DateTime.utc(2026, 10, 5, 12),
  );

  Future<GoRouter> open(
    WidgetTester tester,
    _Orders orders, {
    bool isSignedIn = false,
  }) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/order-confirmation/order-x',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home page')),
        ),
        GoRoute(
          path: '/sign-in',
          builder: (context, state) =>
              const Scaffold(body: Text('Sign in page')),
        ),
        GoRoute(
          path: '/order-confirmation/:id',
          builder: (context, state) => OrderConfirmationScreen(
            orderId: state.pathParameters['id']!,
            isSignedIn: isSignedIn,
          ),
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

  testWidgets('shows the number, the greeting and the ready line (AC-17)', (
    tester,
  ) async {
    await open(tester, _Orders(order: placed));
    await load(tester);

    expect(find.text('Order Confirmation'), findsOneWidget);
    expect(find.text('Order#000007 is confirmed'), findsOneWidget);
    expect(find.text('Thank you for your order, Moetez!'), findsOneWidget);
    expect(
      find.text("We'll send you an email and an sms when it's ready"),
      findsOneWidget,
    );
    expect(find.text('Go back to home page'), findsOneWidget);
  });

  testWidgets('the summary card shows totals, contact, address, delivery and '
      'payment (AC-18)', (tester) async {
    await open(tester, _Orders(order: placed));
    await load(tester);

    expect(find.text('Order Summary'), findsOneWidget);
    expect(find.text(r'$45'), findsOneWidget);
    expect(find.text(r'$10'), findsOneWidget);
    expect(find.text('Total price'), findsOneWidget);
    expect(find.text(r'$55'), findsOneWidget);

    expect(find.text('Contact Information'), findsOneWidget);
    expect(find.text('Moetez ben attia'), findsOneWidget);
    expect(find.text('moetez@example.com'), findsOneWidget);
    expect(find.text('+21650460604'), findsOneWidget);

    expect(find.text('Shipping Address'), findsOneWidget);
    expect(find.text('Tunisia'), findsOneWidget);
    expect(find.text('18 rue des bonbons, menzah V, 0000'), findsOneWidget);
    expect(find.text('Next to the bank'), findsOneWidget);

    expect(find.text('Delivery Method'), findsOneWidget);
    expect(find.text('Standard shipping'), findsOneWidget);
    expect(find.text(r'Shipping price: $10'), findsOneWidget);
    expect(find.text('Estimated arrival: 5 Oct'), findsOneWidget);

    expect(find.text('Payment Method'), findsOneWidget);
    expect(find.text('Pay on delivery'), findsOneWidget);
  });

  testWidgets('a signed out buyer sees the Sign in block, which opens '
      '/sign-in (AC-17)', (tester) async {
    await open(tester, _Orders(order: placed));
    await load(tester);

    expect(find.text('Be the first in line for exclusive offers.'), findsOne);
    expect(find.textContaining('Sign in to get early alerts'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in page'), findsOneWidget);
  });

  testWidgets('a signed in buyer does not see the Sign in block (AC-17)', (
    tester,
  ) async {
    await open(tester, _Orders(order: placed), isSignedIn: true);
    await load(tester);

    expect(
      find.text('Be the first in line for exclusive offers.'),
      findsNothing,
    );
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('the button, the X and the system back all go Home (AC-19)', (
    tester,
  ) async {
    Future<void> expectHome(Future<void> Function() leave) async {
      await open(tester, _Orders(order: placed));
      await load(tester);
      await leave();
      await tester.pumpAndSettle();
      expect(find.text('Home page'), findsOneWidget);
      expect(find.text('Order Confirmation'), findsNothing);
    }

    await expectHome(() => tester.tap(find.text('Go back to home page')));
    await expectHome(() => tester.tap(find.byIcon(Icons.close)));
    await expectHome(() async {
      await tester.binding.handlePopRoute();
    });
  });

  testWidgets('shows a loading indicator while the order loads (AC-22)', (
    tester,
  ) async {
    await open(tester, _Orders(order: placed));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await load(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a failed load shows the message, and Try again reloads it '
      '(AC-22)', (tester) async {
    final orders = _Orders(fail: true);
    await open(tester, orders);
    await load(tester);

    expect(find.text("Couldn't load your order."), findsOneWidget);
    expect(find.text('Go back to home page'), findsOneWidget);
    expect(orders.reads, 1);

    await tester.tap(find.text('Try again'));
    await load(tester);
    expect(orders.reads, 2);
  });

  testWidgets('an order that does not exist shows the same message (AC-22)', (
    tester,
  ) async {
    await open(tester, _Orders());
    await load(tester);

    expect(find.text("Couldn't load your order."), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('an older order with no contact or address still renders', (
    tester,
  ) async {
    await open(tester, _Orders(order: mockOrders[1]));
    await load(tester);

    expect(find.text('Order is confirmed'), findsOneWidget);
    expect(find.text('Thank you for your order!'), findsOneWidget);
    expect(find.text('Contact Information'), findsNothing);
    expect(find.text('Order Summary'), findsOneWidget);
    // Its subtotal is worked out: total minus the fee.
    expect(find.text(r'$145'), findsOneWidget);
  });

  testWidgets('the header and the greeting are announced as headers (AC-23)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await open(tester, _Orders(order: placed));
    await load(tester);

    expect(
      tester.getSemantics(find.text('Order Confirmation')),
      matchesSemantics(label: 'Order Confirmation', isHeader: true),
    );
    handle.dispose();
    await tester.pump(mockNetworkDelay);
  });
}
