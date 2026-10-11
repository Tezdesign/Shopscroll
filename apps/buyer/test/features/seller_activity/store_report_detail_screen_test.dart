import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/area/app_area.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/providers/user_profile_providers.dart';
import 'package:marketplace_app/features/seller_activity/store_report_detail_screen.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

Future<void> _pump(WidgetTester tester, String reportId) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
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
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: StoreReportDetailScreen(reportId: reportId),
      ),
    ),
  );
  // Profile read, then the report read.
  await tester.pump();
  await tester.pump(mockNetworkDelay);
  await tester.pump();
  // The attachment links load after the report.
  await tester.pump(mockNetworkDelay);
  await tester.pump();
}

void main() {
  testWidgets(
    'shows the report, the customer, the products and the attachments',
    (tester) async {
      await _pump(tester, 'mock-report-2589');
      expect(find.text('Report details'), findsOneWidget);
      expect(find.text('#R-2589'), findsOneWidget);
      expect(find.text('Unsolved'), findsOneWidget);
      expect(find.text('Product Quality Issue'), findsOneWidget);
      expect(find.text('Customer Information'), findsOneWidget);
      expect(find.text('Emily Richardson'), findsOneWidget);
      // The contact shows as two buttons (UI audit, Oct 2026), not as text.
      expect(find.text('Email customer'), findsOneWidget);
      expect(find.text('Call customer'), findsOneWidget);
      expect(find.text('Products information'), findsOneWidget);
      expect(find.text('SoundPro Wireless Earbuds'), findsOneWidget);
      expect(find.text('Order #002545'), findsOneWidget);
      expect(find.textContaining('Purchase date : '), findsOneWidget);
      expect(find.text('Problem details'), findsOneWidget);
      expect(find.text('Attachment (2)'), findsOneWidget);
      expect(find.text('Mark as resolved'), findsOneWidget);
    },
  );

  testWidgets('a report with no contact has no contact buttons', (
    tester,
  ) async {
    // The fifth report of the seed comes from an order with no contact.
    await _pump(tester, 'mock-report-2585');
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Email customer'), findsNothing);
    expect(find.text('Call customer'), findsNothing);
  });

  testWidgets(
    'the contact buttons have a spoken name and a 44 high tap area (AC-16)',
    (tester) async {
      await _pump(tester, 'mock-report-2589');
      for (final label in ['Email customer', 'Call customer']) {
        final button = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label,
        );
        expect(button, findsOneWidget, reason: label);
        expect(
          tester.getSize(button).height,
          greaterThanOrEqualTo(44),
          reason: '$label tap area',
        );
      }
    },
  );

  testWidgets('Mark as resolved asks first, then shows Resolved at once', (
    tester,
  ) async {
    await _pump(tester, 'mock-report-2589');
    await tester.tap(find.text('Mark as resolved'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm resolution'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Unsolved'), findsOneWidget);

    await tester.tap(find.text('Mark as resolved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('Mark as resolved'), findsNothing);
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(find.text('Resolved'), findsOneWidget);
  });

  testWidgets('each product photo fills its whole 40 by 40 circle', (
    tester,
  ) async {
    await _pump(tester, 'mock-report-2588'); // three products
    final slot = find.byKey(const ValueKey('report-pictures'));
    expect(tester.getSize(slot), const Size(40 + 16 * 2, 40));
    final photos = find.descendant(
      of: slot,
      matching: find.byType(CachedNetworkImage),
    );
    expect(photos, findsNWidgets(3));
    // A border on the circle's decoration would shrink the photo below 40 and
    // cut its corners off.
    for (final photo in photos.evaluate()) {
      expect(tester.getSize(find.byWidget(photo.widget)), const Size(40, 40));
    }
  });

  testWidgets('a resolved report has no Mark as resolved button', (
    tester,
  ) async {
    await _pump(tester, 'mock-report-2586'); // the fourth report
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('Mark as resolved'), findsNothing);
  });

  testWidgets('an unknown report says Report not found', (tester) async {
    await _pump(tester, 'unknown');
    expect(find.text('Report not found'), findsOneWidget);
  });
}
