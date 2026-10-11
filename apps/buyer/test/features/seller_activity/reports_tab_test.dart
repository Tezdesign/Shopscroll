import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/providers/store_activity_providers.dart';
import 'package:marketplace_app/data/repositories/mock/mock_store_activity_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/store_activity_repository.dart';
import 'package:marketplace_app/features/seller_activity/reports_tab.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

class _FailingResolve extends MockStoreActivityRepository {
  @override
  Future<void> resolveReport(String reportId, {String? note}) async {
    await Future.delayed(mockNetworkDelay);
    throw const StoreActivityException('boom');
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  StoreActivityRepository? repo,
}) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      if (repo != null) storeActivityRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ReportsTab()),
      ),
    ),
  );
  await tester.pump(mockNetworkDelay);
  await tester.pump();
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(mockNetworkDelay);
  await tester.pump();
}

void main() {
  testWidgets('shows the three cards and the first report card', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Total Reports'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('Unresolved Reports'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
    expect(find.text('Returned Orders'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('#R-2589'), findsOneWidget);
    expect(find.text('Unsolved'), findsWidgets);
    expect(find.text('Product Quality Issue'), findsWidgets);
    expect(find.text('Emily Richardson'), findsWidgets);
    expect(find.text('SoundPro Wireless Earbuds'), findsWidgets);
    expect(find.text('Order #002545'), findsOneWidget);
    expect(find.text('View details'), findsWidgets);
    expect(find.text('Resolve'), findsWidgets);
  });

  testWidgets('a resolved card has no Resolve button', (tester) async {
    final container = await _pump(tester);
    // The fourth report of the seed is resolved.
    final rows = container.read(storeReportsProvider).requireValue.reports;
    expect(rows[3].status.name, 'resolved');
    final resolved = find.text('Resolved').evaluate().length;
    expect(resolved, greaterThan(0));
    expect(
      find.text('Resolve').evaluate().length,
      find.text('View details').evaluate().length - resolved,
    );
  });

  testWidgets('cancelling the alert changes nothing', (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.text('Resolve').first);
    await tester.pumpAndSettle();
    expect(find.text('Confirm resolution'), findsOneWidget);
    expect(
      find.text('Are you sure you want to mark this report as resolved?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(storeReportsProvider)
          .requireValue
          .reports
          .first
          .status
          .name,
      'unsolved',
    );
    expect(find.text('19'), findsOneWidget);
  });

  testWidgets('confirming resolves the card and the Unresolved card at once', (
    tester,
  ) async {
    final container = await _pump(tester);
    await tester.tap(find.text('Resolve').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    // Before the server answers: already resolved, number already down.
    expect(
      container
          .read(storeReportsProvider)
          .requireValue
          .reports
          .first
          .status
          .name,
      'resolved',
    );
    expect(find.text('18'), findsOneWidget);
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(find.text('18'), findsOneWidget);
    expect(find.text("Couldn't resolve this report. Try again."), findsNothing);
  });

  testWidgets('a failed resolve puts the card back and says so', (
    tester,
  ) async {
    final container = await _pump(tester, repo: _FailingResolve());
    await tester.tap(find.text('Resolve').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(find.text('18'), findsOneWidget);
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(
      container
          .read(storeReportsProvider)
          .requireValue
          .reports
          .first
          .status
          .name,
      'unsolved',
    );
    expect(find.text('19'), findsOneWidget);
    expect(
      find.text("Couldn't resolve this report. Try again."),
      findsOneWidget,
    );
  });

  testWidgets('a search with no match says so, and the cards stay', (
    tester,
  ) async {
    final container = await _pump(tester);
    container.read(storeActivitySearchProvider.notifier).state = 'zzz';
    await _settle(tester);
    expect(find.text('No results found for “zzz”'), findsOneWidget);
    expect(find.text('Total Reports'), findsOneWidget);
  });

  testWidgets('reaching the end loads the next page', (tester) async {
    final container = await _pump(tester);
    expect(
      container.read(storeReportsProvider).requireValue.reports,
      hasLength(20),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -20000));
    await _settle(tester);
    await tester.pump();
    expect(
      container.read(storeReportsProvider).requireValue.reports,
      hasLength(25),
    );
  });

  testWidgets('View details and the card body open the report', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: ReportsTab()),
        ),
        GoRoute(
          path: '/store/activity/reports/:id',
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
    await tester.tap(find.text('View details').first);
    await tester.pumpAndSettle();
    expect(find.text('DETAIL mock-report-2589'), findsOneWidget);
  });
}
