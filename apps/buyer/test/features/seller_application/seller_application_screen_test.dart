import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/data/providers/user_profile_providers.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/features/seller_application/seller_application_screen.dart';
import 'package:shopscroll_shared/models/seller_application.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

import 'fake_seller_application_repository.dart';

SellerApplication application(
  SellerApplicationStatus status, {
  String? reason,
}) => SellerApplication(
  id: 'a1',
  applicantId: 'u1',
  status: status,
  storeName: 'Borgi phone',
  username: 'borgi',
  location: 'Tunis',
  idDocumentPath: 'u1/a1/id.jpg',
  rejectionReason: reason,
  createdAt: DateTime(2025, 6, 25),
);

Future<void> pumpScreen(
  WidgetTester tester,
  FakeSellerApplicationRepository repository, {
  UserRole? role,
}) async {
  final router = GoRouter(
    initialLocation: '/profile/seller-application',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Text('profile page'),
        routes: [
          GoRoute(
            path: 'seller-application',
            builder: (context, state) =>
                SellerApplicationScreen(userId: role == null ? null : 'u1'),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const Text('wizard page'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sellerApplicationRepositoryProvider.overrideWithValue(repository),
        if (role != null)
          userProfileByIdProvider('u1').overrideWith(
            (ref) async =>
                UserProfile(id: 'u1', name: 'U', username: 'u', role: role),
          ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state offers to submit an application', (tester) async {
    await pumpScreen(tester, FakeSellerApplicationRepository());

    expect(find.text('Seller application'), findsOneWidget);
    expect(find.text('No applications yet'), findsOneWidget);
    expect(find.text('Submit an application'), findsOneWidget);

    await tester.tap(find.text('Submit an application'));
    await tester.pumpAndSettle();
    expect(find.text('wizard page'), findsOneWidget);
  });

  testWidgets('a reviewing application shows its chip and no button', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeSellerApplicationRepository(
        applications: [application(SellerApplicationStatus.reviewing)],
      ),
      role: UserRole.buyer,
    );

    expect(find.text('Borgi phone'), findsOneWidget);
    expect(find.text('Submitted 25/06/2025'), findsOneWidget);
    expect(find.text('Reviewing'), findsOneWidget);
    expect(find.text('Submit a new application'), findsNothing);
  });

  testWidgets('a rejected application shows the reason and a new button', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeSellerApplicationRepository(
        applications: [
          application(SellerApplicationStatus.rejected, reason: 'Blurry ID'),
        ],
      ),
      role: UserRole.buyer,
    );

    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Reason: Blurry ID'), findsOneWidget);
    expect(find.text('Submit a new application'), findsOneWidget);
  });

  testWidgets('attached visitor rows of every status show with their chip', (
    tester,
  ) async {
    // Rows attached to the account by a verified contact have no applicant id
    // yet (spec 0014, AC-12, AC-17): a pending one and a rejected one both show.
    SellerApplication attached(String id, SellerApplicationStatus status) =>
        SellerApplication(
          id: id,
          status: status,
          storeName: 'Store $id',
          username: 'store_$id',
          location: 'Tunis',
          idDocumentPath: 'anon/$id/id.jpg',
          rejectionReason: status == SellerApplicationStatus.rejected
              ? 'Blurry ID'
              : null,
          createdAt: DateTime(2025, 6, 25),
        );
    await pumpScreen(
      tester,
      FakeSellerApplicationRepository(
        applications: [
          attached('a', SellerApplicationStatus.reviewing),
          attached('b', SellerApplicationStatus.rejected),
        ],
      ),
      role: UserRole.buyer,
    );

    expect(find.text('Store a'), findsOneWidget);
    expect(find.text('Reviewing'), findsOneWidget);
    expect(find.text('Store b'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Reason: Blurry ID'), findsOneWidget);
  });

  testWidgets('a seller sees a note and no button', (tester) async {
    await pumpScreen(
      tester,
      FakeSellerApplicationRepository(
        applications: [application(SellerApplicationStatus.approved)],
      ),
      role: UserRole.seller,
    );

    expect(find.text('Approved'), findsOneWidget);
    expect(find.textContaining('You are a seller'), findsOneWidget);
    expect(find.text('Submit a new application'), findsNothing);
  });

  testWidgets('a seller with no application still gets no button', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeSellerApplicationRepository(),
      role: UserRole.seller,
    );

    expect(find.text('Submit an application'), findsNothing);
    expect(find.textContaining('You are a seller'), findsOneWidget);
  });

  testWidgets('pull to refresh reads the list again', (tester) async {
    final repository = FakeSellerApplicationRepository();
    await pumpScreen(tester, repository);
    expect(find.text('No applications yet'), findsOneWidget);

    repository.applications = [application(SellerApplicationStatus.reviewing)];
    await tester.fling(find.byType(Scrollable), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Borgi phone'), findsOneWidget);
  });

  testWidgets('the close button goes back to the profile', (tester) async {
    await pumpScreen(tester, FakeSellerApplicationRepository());

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();

    expect(find.text('profile page'), findsOneWidget);
  });
}
