import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/seller_application_repository.dart';
import 'package:marketplace_app/features/seller_application/seller_application_wizard_screen.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

import 'fake_seller_application_repository.dart';

/// A real 1x1 PNG, so the preview decodes.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Future<PickedPhoto?> okPicker(ImageSource source) async =>
    PickedPhoto(name: 'photo.png', bytes: _png);

Future<void> pumpVisitorWizard(
  WidgetTester tester,
  FakeSellerApplicationRepository repository,
) async {
  final router = GoRouter(
    initialLocation: '/apply',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Text('home page')),
      GoRoute(
        path: '/apply',
        builder: (context, state) => const SellerApplicationWizardScreen(
          photoPicker: okPicker,
          isVisitor: true,
        ),
      ),
    ],
  );
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sellerApplicationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Steps 1 to 3, leaving the "About you" step open.
Future<void> reachAbout(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'My Shop');
  await tester.enterText(find.byType(TextFormField).at(1), 'my_shop');
  await tester.enterText(find.byType(TextFormField).at(2), 'Tunis');
  await tapText(tester, 'Next');
  await tapText(tester, 'Next');
  await tester.tap(find.text('Add photo').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose from your library'));
  await tester.pumpAndSettle();
  await tapText(tester, 'Next');
}

Future<void> fillAbout(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Visitor One');
  await tester.enterText(find.byType(TextFormField).at(1), 'v@example.com');
  await tester.enterText(find.byType(TextField).last, '2025550123');
}

void main() {
  testWidgets('a visitor has five steps, with About you before Review', (
    tester,
  ) async {
    await pumpVisitorWizard(tester, FakeSellerApplicationRepository());

    expect(find.bySemanticsLabel('Step 1 of 5'), findsOneWidget);
    await reachAbout(tester);

    expect(find.bySemanticsLabel('Step 4 of 5'), findsOneWidget);
    expect(find.text('About you'), findsOneWidget);
    expect(find.text('Your name'), findsOneWidget);
    expect(find.text('Your email'), findsOneWidget);
    expect(find.text('Your phone number'), findsOneWidget);
  });

  testWidgets('About you refuses an empty name, a bad email and a bad phone', (
    tester,
  ) async {
    await pumpVisitorWizard(tester, FakeSellerApplicationRepository());
    await reachAbout(tester);

    await tapText(tester, 'Next');

    expect(find.text('Use 2 to 60 characters.'), findsOneWidget);
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(find.text('Please enter a valid phone number.'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 4 of 5'), findsOneWidget);

    await fillAbout(tester);
    await tapText(tester, 'Next');
    expect(find.bySemanticsLabel('Step 5 of 5'), findsOneWidget);
  });

  testWidgets(
    'Send uploads as a visitor and sends the contact in international format',
    (tester) async {
      final repository = FakeSellerApplicationRepository();
      await pumpVisitorWizard(tester, repository);
      await reachAbout(tester);
      await fillAbout(tester);
      await tapText(tester, 'Next');

      // The review lists what the team will see.
      expect(find.text('v@example.com'), findsOneWidget);
      expect(find.text('+12025550123'), findsOneWidget);

      await tapText(tester, 'Send application');

      final request = repository.submitted.single;
      expect(request.applicant?.name, 'Visitor One');
      expect(request.applicant?.email, 'v@example.com');
      expect(request.applicant?.phone, '+12025550123');
      expect(repository.visitorUploads, isNotEmpty);
      expect(repository.visitorUploads.every((v) => v), isTrue);
    },
  );

  testWidgets(
    'after Send, a confirmation says the team will contact them there',
    (tester) async {
      await pumpVisitorWizard(tester, FakeSellerApplicationRepository());
      await reachAbout(tester);
      await fillAbout(tester);
      await tapText(tester, 'Next');
      await tapText(tester, 'Send application');

      expect(find.text('Application sent'), findsOneWidget);
      expect(
        find.text(
          'Our team will contact you at v@example.com and +12025550123.',
        ),
        findsOneWidget,
      );

      await tapText(tester, 'Done');
      expect(find.text('home page'), findsOneWidget);
    },
  );

  testWidgets(
    'a refusal stays on Review and says why, and Try again can retry',
    (tester) async {
      final repository = FakeSellerApplicationRepository()
        ..submitError = const SellerApplicationException(
          SellerApplicationFailure.alreadyOpen,
        );
      await pumpVisitorWizard(tester, repository);
      await reachAbout(tester);
      await fillAbout(tester);
      await tapText(tester, 'Next');

      await tapText(tester, 'Send application');

      expect(
        find.text('You already have an application under review.'),
        findsOneWidget,
      );
      expect(find.text('Application sent'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    },
  );
}
