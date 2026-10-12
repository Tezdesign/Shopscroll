import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/core/area/app_area.dart';
import 'package:marketplace_app/data/models/store_report.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/providers/user_profile_providers.dart';
import 'package:marketplace_app/data/repositories/mock/mock_store_activity_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/store_activity_repository.dart';
import 'package:marketplace_app/features/store/store_area_screen.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

/// The seller dashboard at `/store` (spec 0014, AC-5, with the Oct 2026 UI
/// audit): four number tiles, Quick Actions and Recent Sales, all from the
/// same providers as the Activity screens.
class _FlakyDashboard extends MockStoreActivityRepository {
  int calls = 0;

  @override
  Future<StoreReportsSummary> reportsSummary() async {
    calls++;
    if (calls == 1) {
      await Future.delayed(mockNetworkDelay);
      throw const StoreActivityException('boom');
    }
    return super.reportsSummary();
  }
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  StoreActivityRepository? repository,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/store',
    routes: [
      GoRoute(
        path: '/store',
        builder: (context, state) => const StoreAreaScreen(),
      ),
      for (final path in [
        '/store/activity',
        '/store/products',
        '/store/products/new',
      ])
        GoRoute(
          path: path,
          builder: (context, state) => Scaffold(body: Text('AT $path')),
        ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        signedInUserIdProvider.overrideWith((ref) => 'seller'),
        userProfileByIdProvider.overrideWith(
          (ref, id) async => const UserProfile(
            id: 'seller',
            name: 'Bershka',
            username: 'bershka',
            role: UserRole.seller,
          ),
        ),
        if (repository != null)
          storeActivityRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  // Profile read, then the dashboard numbers.
  await tester.pump();
  await tester.pump(mockNetworkDelay);
  await tester.pump();
  return router;
}

void main() {
  testWidgets('the first tiles sit one step under the header, even with a '
      'status bar', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 59);
    addTearDown(tester.view.resetPadding);
    await _pump(tester);

    final header = tester.getBottomLeft(find.text('Bershka')).dy;
    final tile = tester.getTopLeft(find.text("Today's Sale")).dy;
    // Tile padding (16) and the list's top padding (24), not the status bar.
    expect(tile - header, lessThan(80));
  });

  testWidgets('shows the four number tiles and Recent Sales', (tester) async {
    await _pump(tester);
    expect(find.text('Bershka'), findsOneWidget);
    expect(find.text("Today's Sale"), findsOneWidget);
    expect(find.text('12,426.000 TND'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('90,458.000 TND'), findsOneWidget);
    expect(find.text('unresolved'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
    expect(find.text('Recent Sales'), findsOneWidget);
    expect(find.text('Moetez ben attia'), findsWidgets);
    expect(find.text('450.000 TND'), findsOneWidget);
  });

  testWidgets('Quick Actions open the product and activity screens', (
    tester,
  ) async {
    for (final (label, path) in [
      ('Add Product', '/store/products/new'),
      ('Products', '/store/products'),
      ('Orders', '/store/activity'),
    ]) {
      final router = await _pump(tester);
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(find.text('AT $path'), findsOneWidget, reason: label);
      router.dispose();
    }
  });

  testWidgets('a failed load says so, and Try again reloads the dashboard', (
    tester,
  ) async {
    await _pump(tester, repository: _FlakyDashboard());
    expect(find.text("Couldn't load your dashboard."), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(find.text("Today's Sale"), findsOneWidget);
    expect(find.text("Couldn't load your dashboard."), findsNothing);
  });
}
