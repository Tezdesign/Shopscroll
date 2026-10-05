import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/repositories/mock/mock_seller_product_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/seller_product_repository.dart';
import 'package:marketplace_app/features/seller_products/photo_picker.dart';
import 'package:marketplace_app/features/seller_products/preview_step.dart';
import 'package:marketplace_app/features/seller_products/product_flow_controller.dart';
import 'package:marketplace_app/features/seller_products/product_flow_screen.dart';
import 'package:shopscroll_shared/models/product_draft.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

// A 1 by 1 PNG, enough for Image.memory to decode in a test.
final _pixel = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  ),
);

Future<MockSellerProductRepository> _pumpFlow(
  WidgetTester tester, {
  MockSellerProductRepository? repo,
  bool isNew = true,
  String draftId = 'd1',
}) async {
  final repository = repo ?? MockSellerProductRepository();
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => ProductFlowScreen(draftId: draftId, isNew: isNew),
      ),
      GoRoute(path: '/store', builder: (context, state) => const Scaffold(body: Text('STORE AREA'))),
      GoRoute(path: '/store/products', builder: (context, state) => const Scaffold(body: Text('PRODUCTS'))),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sellerProductRepositoryProvider.overrideWithValue(repository),
        photoPickerProvider.overrideWithValue(
          (source, {required max}) async => [_pixel],
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  return repository;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _addPhoto(WidgetTester tester) async {
  await tester.tap(find.text('Add photos'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose from library'));
  await tester.pump();
  await tester.pump();
}

Future<void> _fillBasics(WidgetTester tester) async {
  await _addPhoto(tester);
  await tester.enterText(find.byType(TextFormField).first, 'Wrap dress');
  await tester.tap(find.text('Fashion'));
  await tester.pump();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pump();
}

void main() {
  // Spec 0015, AC-2, AC-6, AC-7, AC-8, AC-15, AC-18.
  testWidgets('Continue on an empty step 1 says what is missing and stays', (tester) async {
    await _pumpFlow(tester);

    expect(find.text('Step 1 of 3'), findsOneWidget);
    await _tapButton(tester, 'Continue');

    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Add at least one photo.'), findsOneWidget);
    expect(find.text('Give the product a title of 2 to 100 characters.'), findsOneWidget);
    expect(find.text('Choose a category.'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('a product without options goes from Basics to the live screen', (tester) async {
    final repo = await _pumpFlow(tester);

    await _fillBasics(tester);
    expect(find.text('Cover'), findsOneWidget);
    await _tapButton(tester, 'Continue');
    expect(find.text('Step 2 of 3'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '89');
    await tester.enterText(find.byType(TextFormField).at(1), '5');
    await tester.pump();
    await _tapButton(tester, 'Continue');
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('All required information is complete'), findsOneWidget);
    expect(find.text('89.000 TND'), findsWidgets);

    await _tapButton(tester, 'Publish product');
    await tester.pump(mockNetworkDelay);
    await tester.pump();

    expect(find.text('Your product is live!'), findsOneWidget);
    expect(find.text('View product'), findsOneWidget);
    expect(find.text('Add another'), findsOneWidget);
    expect(find.textContaining('Create a reel'), findsNothing);
    // The mock list call waits on a real timer, so it runs outside the test clock.
    final live = await tester.runAsync(() => repo.listProducts(SellerProductTab.live));
    expect(live!.single.title, 'Wrap dress');
    expect(live.single.price, 89);
    expect(live.single.variants.single.stock, 5);
    await _unmount(tester);
  });

  testWidgets('colors and sizes build a table and a missing price blocks Continue', (tester) async {
    await _pumpFlow(tester);
    await _fillBasics(tester);
    await _tapButton(tester, 'Continue');

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('+ Add color'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Black'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('S').first);
    await tester.tap(find.text('S').first);
    await tester.pump();
    await tester.tap(find.text('M').first);
    await tester.pump();

    expect(find.text('1 color × 2 sizes = 2 variants'), findsOneWidget);
    expect(find.text('Black / S'), findsOneWidget);
    expect(find.text('Black / M'), findsOneWidget);

    await _tapButton(tester, 'Continue');
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.textContaining('Enter a price above 0 for Black / S'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('Save draft keeps the work and leaves', (tester) async {
    final repo = await _pumpFlow(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Half done');
    await tester.pump();

    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(find.text('STORE AREA'), findsOneWidget);
    expect(find.text('Saved as a draft'), findsOneWidget);
    expect((await repo.getDraft('d1'))!.data.title, 'Half done');
    await _unmount(tester);
  });

  testWidgets('an untouched new product leaves no draft behind', (tester) async {
    final repo = await _pumpFlow(tester);

    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(await repo.getDraft('d1'), isNull);
    await _unmount(tester);
  });

  testWidgets('an existing draft reopens at its step with its fields', (tester) async {
    final repo = MockSellerProductRepository();
    await repo.createDraft(id: 'd7');
    final draft = (await repo.getDraft('d7'))!;
    await repo.saveDraft(draft.copyWith(step: 2, data: draft.data.copyWith(title: 'Saved title')));

    await _pumpFlow(tester, repo: repo, isNew: false, draftId: 'd7');
    await tester.pump();

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Price & stock'), findsWidgets);
    await _unmount(tester);
  });

  testWidgets('a draft that is gone says so', (tester) async {
    await _pumpFlow(tester, isNew: false, draftId: 'missing');
    await tester.pump();

    expect(find.text('This draft is no longer here.'), findsOneWidget);
    await _unmount(tester);
  });

  _previewTests();
  _autofillTests();
}

class _QuotaRepo extends MockSellerProductRepository {
  @override
  Future<AutofillSuggestion> autofill(String draftId) async =>
      throw const SellerProductException('quota_exceeded');
}

// Spec 0015, AC-13: a suggestion is shown for editing and saved only when accepted.
void _autofillTests() {
  testWidgets('Fill from photos shows a suggestion and applies it only when accepted', (tester) async {
    await _pumpFlow(tester);
    expect(find.text('Fill from photos'), findsNothing); // no photo yet
    await _addPhoto(tester);
    await tester.enterText(find.byType(TextFormField).first, 'My own title');
    await tester.pump();

    await tester.ensureVisible(find.text('Fill from photos'));
    await tester.tap(find.text('Fill from photos'));
    await tester.pumpAndSettle();

    expect(find.text('Suggested from your photos'), findsOneWidget);
    expect(find.textContaining('29 runs left today'), findsOneWidget);
    // Not applied yet.
    expect(find.text('My own title'), findsOneWidget);

    await tester.tap(find.text('Use these'));
    await tester.pumpAndSettle();

    expect(find.text('Long-sleeve wrap dress'), findsOneWidget);
    expect(find.text('My own title'), findsNothing);
    expect(find.text('Fashion'), findsWidgets);
    await _unmount(tester);
  });

  testWidgets('leaving the suggestion changes nothing', (tester) async {
    await _pumpFlow(tester);
    await _addPhoto(tester);
    await tester.enterText(find.byType(TextFormField).first, 'My own title');
    await tester.pump();

    await tester.ensureVisible(find.text('Fill from photos'));
    await tester.tap(find.text('Fill from photos'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('My own title'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('a refused run says so and leaves the form alone', (tester) async {
    await _pumpFlow(tester, repo: _QuotaRepo());
    await _addPhoto(tester);
    await tester.enterText(find.byType(TextFormField).first, 'My own title');
    await tester.pump();

    await tester.ensureVisible(find.text('Fill from photos'));
    await tester.tap(find.text('Fill from photos'));
    await tester.pumpAndSettle();

    expect(find.textContaining("used all of today's runs"), findsOneWidget);
    expect(find.text('My own title'), findsOneWidget);
    expect(find.text('Suggested from your photos'), findsNothing);
    await _unmount(tester);
  });
}

// The Preview step is also where a refusal from the server shows, so a missing
// price is fixed on the spot (spec 0015, AC-7 and the deviation from the frames).
void _previewTests() {
  testWidgets('Preview lists what is missing and a price typed there clears it', (tester) async {
    final controller = ProductFlowController(
      repository: MockSellerProductRepository(),
      draft: ProductDraft(
        id: 'd1',
        storeId: '',
        step: 3,
        updatedAt: DateTime(2026),
        data: const ProductDraftData(
          title: 'Dress',
          category: 'Fashion',
          photos: ['mock_seller/d1/a.jpg'],
          variants: [DraftVariant(id: 'v1', size: 'S', price: '', stock: 2, stockSet: true)],
        ),
      ),
      persisted: true,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => SingleChildScrollView(
              child: PreviewStep(
                controller: controller,
                currency: 'TND',
                storeName: 'Bershka',
                onGoToStep: controller.setStep,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Fix one item to publish'), findsOneWidget);
    expect(find.text('Price for S'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '45.5');
    await tester.pump();

    expect(find.text('All required information is complete'), findsOneWidget);
    expect(find.text('45.500 TND'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
