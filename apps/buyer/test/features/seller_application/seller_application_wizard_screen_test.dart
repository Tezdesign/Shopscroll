import 'dart:async';
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

Future<void> pumpWizard(
  WidgetTester tester,
  FakeSellerApplicationRepository repository, {
  PhotoPicker picker = okPicker,
}) async {
  final router = GoRouter(
    initialLocation: '/wizard',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => const Text('profile page'),
      ),
      GoRoute(
        path: '/wizard',
        builder: (context, state) =>
            SellerApplicationWizardScreen(photoPicker: picker),
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

Future<void> fillDetails(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'My Shop');
  await tester.enterText(find.byType(TextFormField).at(1), 'my_shop');
  await tester.enterText(find.byType(TextFormField).at(2), 'Tunis');
}

Future<void> addPhoto(WidgetTester tester, {int slot = 0}) async {
  await tester.tap(find.text('Add photo').at(slot));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose from your library'));
  await tester.pumpAndSettle();
}

/// Goes through all four steps, adding the ID photo, and stops on Review.
Future<void> reachReview(WidgetTester tester) async {
  await fillDetails(tester);
  await tapText(tester, 'Next');
  await tapText(tester, 'Next');
  await addPhoto(tester);
  await tapText(tester, 'Next');
}

void main() {
  testWidgets('step 1 opens with no errors showing', (tester) async {
    await pumpWizard(tester, FakeSellerApplicationRepository());

    expect(find.text('Use 2 to 60 characters.'), findsNothing);
    expect(find.text('Please enter your location.'), findsNothing);
    expect(
      find.text('Use 3 to 30 lowercase letters, numbers, _ or .'),
      findsNothing,
    );
    expect(find.text('Lowercase letters, numbers, _ and .'), findsOneWidget);
  });

  testWidgets('typing in one field does not flag the empty ones', (
    tester,
  ) async {
    await pumpWizard(tester, FakeSellerApplicationRepository());

    await tester.enterText(find.byType(TextFormField).at(1), 'my_shop');
    await tester.pump();

    expect(find.text('Use 2 to 60 characters.'), findsNothing);
    expect(find.text('Please enter your location.'), findsNothing);
  });

  testWidgets('after a failed Next the fields check as you type', (
    tester,
  ) async {
    await pumpWizard(tester, FakeSellerApplicationRepository());
    await tapText(tester, 'Next');
    expect(find.text('Use 2 to 60 characters.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'My Shop');
    await tester.pump();

    expect(find.text('Use 2 to 60 characters.'), findsNothing);
    expect(find.text('Please enter your location.'), findsOneWidget);
  });

  testWidgets('step 1 refuses bad fields and shows a progress bar', (
    tester,
  ) async {
    await pumpWizard(tester, FakeSellerApplicationRepository());

    expect(find.bySemanticsLabel('Step 1 of 4'), findsOneWidget);
    await tapText(tester, 'Next');

    expect(find.text('Use 2 to 60 characters.'), findsOneWidget);
    expect(find.text('Please enter your location.'), findsOneWidget);
    expect(find.text('Store details'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'My Shop');
    await tester.enterText(find.byType(TextFormField).at(1), 'My Shop');
    await tester.enterText(find.byType(TextFormField).at(2), 'Tunis');
    await tapText(tester, 'Next');
    expect(
      find.text('Use 3 to 30 lowercase letters, numbers, _ or .'),
      findsOneWidget,
    );
  });

  testWidgets('Back keeps what was typed', (tester) async {
    await pumpWizard(tester, FakeSellerApplicationRepository());
    await fillDetails(tester);
    await tapText(tester, 'Next');
    expect(find.bySemanticsLabel('Step 2 of 4'), findsOneWidget);

    await tapText(tester, 'Back');

    expect(find.text('My Shop'), findsOneWidget);
    expect(find.text('my_shop'), findsOneWidget);
    expect(find.text('Tunis'), findsOneWidget);
  });

  testWidgets('the ID photo is required, the others are not', (tester) async {
    await pumpWizard(tester, FakeSellerApplicationRepository());
    await fillDetails(tester);
    await tapText(tester, 'Next');
    await tapText(tester, 'Next'); // contact and logo are all optional
    expect(find.text('Documents'), findsOneWidget);

    await tapText(tester, 'Next');
    expect(find.text('Add a photo of your ID.'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);

    await addPhoto(tester);
    await tapText(tester, 'Next');
    expect(find.text('Review and send'), findsOneWidget);
  });

  testWidgets('a photo of the wrong type is refused on the phone', (
    tester,
  ) async {
    await pumpWizard(
      tester,
      FakeSellerApplicationRepository(),
      picker: (source) async => PickedPhoto(name: 'scan.pdf', bytes: _png),
    );
    await fillDetails(tester);
    await tapText(tester, 'Next');
    await tapText(tester, 'Next');
    await addPhoto(tester);

    expect(find.text('Use a JPEG or PNG photo.'), findsOneWidget);
    await tapText(tester, 'Next');
    expect(find.text('Add a photo of your ID.'), findsOneWidget);
  });

  testWidgets('a photo over 5 MB is refused on the phone', (tester) async {
    await pumpWizard(
      tester,
      FakeSellerApplicationRepository(),
      picker: (source) async =>
          PickedPhoto(name: 'big.jpg', bytes: Uint8List(5 * 1024 * 1024 + 1)),
    );
    await fillDetails(tester);
    await tapText(tester, 'Next');
    await tapText(tester, 'Next');
    await addPhoto(tester);

    expect(
      find.text('This photo is over 5 MB. Choose a smaller one.'),
      findsOneWidget,
    );
  });

  testWidgets('sending uploads the photos, then submits once', (tester) async {
    final repository = FakeSellerApplicationRepository();
    await pumpWizard(tester, repository);
    await reachReview(tester);

    expect(find.text('My Shop'), findsOneWidget);
    await tapText(tester, 'Send application');

    expect(repository.uploads, [SellerApplicationPhoto.idDocument]);
    expect(repository.submitted, hasLength(1));
    final request = repository.submitted.single;
    expect(request.storeName, 'My Shop');
    expect(request.username, 'my_shop');
    expect(request.location, 'Tunis');
    expect(request.bio, isNull);
    expect(request.logoPath, isNull);
    expect(request.personalEmail, isNull);
    expect(request.idDocumentPath, contains('idDocument'));
    expect(find.text('profile page'), findsOneWidget);
  });

  testWidgets('the optional personal email is private and sent with the form', (
    tester,
  ) async {
    final repository = FakeSellerApplicationRepository();
    await pumpWizard(tester, repository);
    await fillDetails(tester);
    await tapText(tester, 'Next');

    expect(find.text('Your email (optional)'), findsOneWidget);
    expect(find.textContaining('Private.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(3), 'me@example.com');
    await tapText(tester, 'Next');
    await addPhoto(tester);
    await tapText(tester, 'Next');

    expect(find.text('me@example.com'), findsOneWidget);
    await tapText(tester, 'Send application');
    expect(repository.submitted.single.personalEmail, 'me@example.com');
  });

  testWidgets('a bad personal email keeps the person on the contact step', (
    tester,
  ) async {
    await pumpWizard(tester, FakeSellerApplicationRepository());
    await fillDetails(tester);
    await tapText(tester, 'Next');

    await tester.enterText(find.byType(TextFormField).at(3), 'nope');
    await tapText(tester, 'Next');

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(find.text('Your email (optional)'), findsOneWidget);
    expect(find.text('Documents'), findsNothing);
  });

  testWidgets('a double tap sends one application', (tester) async {
    final repository = FakeSellerApplicationRepository()
      ..gate = Completer<void>();
    await pumpWizard(tester, repository);
    await reachReview(tester);

    await tester.tap(find.text('Send application'));
    await tester.pump();
    await tester.tap(find.text('Sending...'), warnIfMissed: false);
    await tester.pump();
    repository.gate!.complete();
    await tester.pumpAndSettle();

    expect(repository.submitted, hasLength(1));
    expect(repository.uploads, hasLength(1));
  });

  testWidgets('a failed upload shows a retry and submits nothing', (
    tester,
  ) async {
    final repository = FakeSellerApplicationRepository()
      ..uploadError = const SellerApplicationException(
        SellerApplicationFailure.failed,
      );
    await pumpWizard(tester, repository);
    await reachReview(tester);

    await tapText(tester, 'Send application');

    expect(
      find.text("Couldn't send your application. Try again."),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(repository.submitted, isEmpty);

    repository.uploadError = null;
    await tapText(tester, 'Try again');
    expect(repository.submitted, hasLength(1));
  });

  testWidgets('a retry after a failed submit does not upload again', (
    tester,
  ) async {
    final repository = FakeSellerApplicationRepository()
      ..submitError = const SellerApplicationException(
        SellerApplicationFailure.failed,
      );
    await pumpWizard(tester, repository);
    await reachReview(tester);

    await tapText(tester, 'Send application');
    expect(repository.uploads, hasLength(1));
    expect(find.text('Try again'), findsOneWidget);

    repository.submitError = null;
    await tapText(tester, 'Try again');

    expect(repository.uploads, hasLength(1));
    expect(repository.submitted, hasLength(1));
  });

  testWidgets('a taken username sends the person back to step 1', (
    tester,
  ) async {
    final repository = FakeSellerApplicationRepository()
      ..submitError = const SellerApplicationException(
        SellerApplicationFailure.usernameTaken,
      );
    await pumpWizard(tester, repository);
    await reachReview(tester);

    await tapText(tester, 'Send application');

    expect(find.text('Store details'), findsOneWidget);
    expect(find.text('This username is taken.'), findsOneWidget);
    expect(find.text('my_shop'), findsOneWidget);
  });
}
