import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/area/app_area.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/providers/user_profile_providers.dart';
import 'package:marketplace_app/features/seller_activity/store_order_detail_screen.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

Future<void> _pump(WidgetTester tester, String orderId) async {
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
        home: StoreOrderDetailScreen(orderId: orderId),
      ),
    ),
  );
  // Profile read, then the order read.
  await tester.pump();
  await tester.pump(mockNetworkDelay);
  await tester.pump();
}

void main() {
  testWidgets(
    'shows this store only: lines, subtotal, customer, delivery, payment',
    (tester) async {
      await _pump(tester, 'mock-order-002545');
      expect(find.text('Order#002545'), findsOneWidget);
      expect(find.text('Wrap dress'), findsOneWidget);
      expect(find.text('Size M'), findsOneWidget);
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('450.000 TND'), findsOneWidget);
      expect(find.text('Moetez ben attia'), findsOneWidget);
      expect(find.text('customer@example.com'), findsOneWidget);
      expect(find.text('+216 20 123 456'), findsOneWidget);
      expect(find.text('sahloul, Sousse, 4054'), findsOneWidget);
      expect(find.text('Call before delivery'), findsOneWidget);
      expect(find.text('Standard shipping'), findsOneWidget);
      expect(find.text('Pay on delivery'), findsOneWidget);
      // The receipt's delivery fee and whole order total never show here.
      expect(find.text('Delivery'), findsNothing);
      expect(find.text('Total price'), findsNothing);
    },
  );

  testWidgets('an unknown order says Order not found', (tester) async {
    await _pump(tester, 'unknown');
    expect(find.text('Order not found'), findsOneWidget);
  });
}
