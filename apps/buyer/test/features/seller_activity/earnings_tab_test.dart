import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/models/store_order.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/repositories/mock/mock_store_activity_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/store_activity_repository.dart';
import 'package:marketplace_app/features/seller_activity/activity_message.dart';
import 'package:marketplace_app/features/seller_activity/earnings_tab.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

class _Fixed extends MockStoreActivityRepository {
  _Fixed(this._earnings);

  final Future<StoreEarnings> Function() _earnings;

  @override
  Future<StoreEarnings> earnings() => _earnings();
}

StoreEarnings _empty() => const StoreEarnings(
  totalSales: 0,
  todaySales: 0,
  todayOrders: 0,
  weekSales: 0,
  prevWeekSameSpanSales: 0,
  customers: 0,
  newCustomersToday: 0,
  currency: 'TND',
  recent: [],
);

Future<void> _pump(
  WidgetTester tester, {
  StoreActivityRepository? repository,
  VoidCallback? onSeeOrders,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repository != null)
          storeActivityRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: EarningsTab(onSeeOrders: onSeeOrders ?? () {})),
      ),
    ),
  );
  await tester.pump(mockNetworkDelay);
  await tester.pump();
}

StoreEarnings _with({
  double total = 0,
  double today = 0,
  int todayOrders = 0,
  double week = 0,
  double prevWeek = 0,
  int customers = 0,
  int newCustomers = 0,
}) => StoreEarnings(
  totalSales: total,
  todaySales: today,
  todayOrders: todayOrders,
  weekSales: week,
  prevWeekSameSpanSales: prevWeek,
  customers: customers,
  newCustomersToday: newCustomers,
  currency: 'TND',
  recent: const [],
);

Future<void> _tapPeriod(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  // The tab shows one period at a time (UI audit, Oct 2026): spec 0018 AC-6
  // numbers are all still there, one tab of the selector at a time.
  group('the period selector and the hero card (AC-6)', () {
    testWidgets('opens on Today with its sales, orders and new customers', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('All time'), findsOneWidget);
      expect(find.text("Today's Sales"), findsOneWidget);
      expect(find.text('12,426.000 TND'), findsOneWidget);
      expect(find.text('6 orders today'), findsOneWidget);
      expect(find.text('Orders today'), findsOneWidget);
      expect(find.text('New customers'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets(
      'This Week shows the week sales and the percent against last week',
      (tester) async {
        await _pump(tester);
        await _tapPeriod(tester, 'This Week');
        expect(find.text('90,458.000 TND'), findsOneWidget);
        expect(find.text('32% more than last week'), findsOneWidget);
        // The figure the percent compares with, not an invented order count.
        expect(find.text('Same span last week'), findsOneWidget);
        expect(find.text('68,529.000 TND'), findsOneWidget);
        expect(find.text('Customers'), findsOneWidget);
        expect(find.text('125'), findsOneWidget);
      },
    );

    testWidgets('All time shows the total sales and the customers', (
      tester,
    ) async {
      await _pump(tester);
      await _tapPeriod(tester, 'All time');
      expect(find.text('Total Sales'), findsOneWidget);
      expect(find.text('478,458.000 TND'), findsOneWidget);
      expect(find.text('125 customers total'), findsOneWidget);
      expect(find.text('New today'), findsOneWidget);
    });

    testWidgets('a fall shows "less than last week"', (tester) async {
      await _pump(
        tester,
        repository: _Fixed(
          () async => _with(total: 100, week: 50, prevWeek: 100, customers: 1),
        ),
      );
      await _tapPeriod(tester, 'This Week');
      expect(find.text('50% less than last week'), findsOneWidget);
    });

    testWidgets('no sales last week hides the percent', (tester) async {
      await _pump(
        tester,
        repository: _Fixed(() async => _with(week: 50, prevWeek: 0)),
      );
      await _tapPeriod(tester, 'This Week');
      expect(find.textContaining('than last week'), findsNothing);
    });

    testWidgets(
      'each period tab has a spoken name and a 44 high tap area (AC-16)',
      (tester) async {
        await _pump(tester);
        for (final label in ['Today', 'This Week', 'All time']) {
          final tab = find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == label,
          );
          expect(tab, findsOneWidget, reason: label);
          expect(
            tester.getSize(tab).height,
            greaterThanOrEqualTo(44),
            reason: '$label tap area',
          );
        }
      },
    );
  });

  group('recent sales (AC-7)', () {
    testWidgets(
      'lists the 4 latest sales with number, name, place and amount',
      (tester) async {
        await _pump(tester);
        expect(find.text('Recent sales'), findsOneWidget);
        expect(find.text('Order#002545'), findsOneWidget);
        expect(find.text('450.000 TND'), findsOneWidget);
        expect(find.text('Sousse, sahloul'), findsNWidgets(4));
      },
    );

    testWidgets('the arrow beside Recent sales opens the Orders tab', (
      tester,
    ) async {
      var tapped = false;
      await _pump(tester, onSeeOrders: () => tapped = true);
      final arrow = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'See all orders',
      );
      // AC-16: at least 44 by 44.
      expect(tester.getSize(arrow).shortestSide, greaterThanOrEqualTo(44));
      await tester.tap(arrow);
      expect(tapped, isTrue);
    });
  });

  group('states (AC-14)', () {
    testWidgets('a store with no orders shows zeros and "No sales yet"', (
      tester,
    ) async {
      await _pump(tester, repository: _Fixed(() async => _empty()));
      expect(find.text('0.000 TND'), findsOneWidget);
      expect(find.text('0 orders today'), findsOneWidget);
      expect(find.text('No sales yet'), findsOneWidget);
      await _tapPeriod(tester, 'All time');
      expect(find.text('0.000 TND'), findsOneWidget);
      expect(find.text('0 customers total'), findsOneWidget);
    });

    testWidgets('a failed load shows a message and "Try again" reloads', (
      tester,
    ) async {
      var calls = 0;
      await _pump(
        tester,
        repository: _Fixed(() async {
          calls++;
          if (calls == 1) throw const StoreActivityException('boom');
          return _empty();
        }),
      );
      expect(find.text("Couldn't load your earnings."), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(mockNetworkDelay);
      await tester.pump();
      expect(find.text("Today's Sales"), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets('the Try again button is at least 44 high (AC-16)', (
      tester,
    ) async {
      await _pump(
        tester,
        repository: _Fixed(() async => throw const StoreActivityException('x')),
      );
      expect(
        tester.getSize(find.byType(RetryButton)).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('the week orders card', () {
    // `StoreEarnings` carries no order count for the week, so the card has no
    // honest number to show. Dividing the week's money by today's average
    // order, or by 1 when there were no sales today, shows money as a count.
    testWidgets("never shows the week's money as an order count", (
      tester,
    ) async {
      await _pump(
        tester,
        repository: _Fixed(
          () async => _with(total: 50000, week: 50000, customers: 3),
        ),
      );
      await _tapPeriod(tester, 'This Week');
      expect(find.text('50000'), findsNothing);
    });
  });

  test('weekChangePercent rounds, and is null without a week before', () {
    expect(_with(week: 90458, prevWeek: 68529).weekChangePercent, 32);
    expect(_with(week: 50, prevWeek: 100).weekChangePercent, -50);
    expect(_with(week: 10, prevWeek: 0).weekChangePercent, isNull);
  });
}
