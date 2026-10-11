import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/providers/store_activity_providers.dart';
import 'package:marketplace_app/features/seller_activity/orders_tab.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: OrdersTab()),
      ),
    ),
  );
  await tester.pump(mockNetworkDelay);
  await tester.pump();
  return container;
}

void main() {
  testWidgets(
    'shows the first rows with number, name, place, total and status',
    (tester) async {
      await _pump(tester);
      expect(find.text('Order#002545'), findsOneWidget);
      expect(find.text('Sousse, sahloul'), findsWidgets);
      expect(find.text('Total : 450.000 TND'), findsWidgets);
      expect(find.text('Delivered'), findsWidgets);
    },
  );

  testWidgets('a chip filters, and tapping it again clears the filter', (
    tester,
  ) async {
    final container = await _pump(tester);
    // The third chip sits past the right edge of a phone, like in the frame.
    await tester.ensureVisible(find.text('Canceled').first);
    await tester.tap(find.text('Canceled').first);
    await tester.pump();
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(container.read(storeOrderStatusFilterProvider)?.name, 'canceled');
    expect(find.text('Delivered'), findsOneWidget); // only the chip is left
    await tester.tap(find.text('Canceled').first);
    await tester.pump();
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(container.read(storeOrderStatusFilterProvider), isNull);
  });

  testWidgets('a search with no match says so', (tester) async {
    final container = await _pump(tester);
    container.read(storeActivitySearchProvider.notifier).state = 'zzz';
    await tester.pump();
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(find.text('No results found for “zzz”'), findsOneWidget);
  });

  testWidgets('reaching the end loads the next page', (tester) async {
    final container = await _pump(tester);
    expect(
      container.read(storeOrdersProvider).requireValue.orders,
      hasLength(20),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -6000));
    await tester.pump();
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(
      container.read(storeOrdersProvider).requireValue.orders,
      hasLength(30),
    );
  });

  testWidgets('tapping a row opens its detail', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: OrdersTab()),
        ),
        GoRoute(
          path: '/store/activity/orders/:id',
          builder: (context, state) =>
              Scaffold(body: Text('DETAIL ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    await tester.tap(find.text('Order#002545'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL mock-order-002545'), findsOneWidget);
  });
}
