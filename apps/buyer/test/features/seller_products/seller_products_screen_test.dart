import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/repositories/mock/mock_seller_product_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/seller_product_repository.dart';
import 'package:marketplace_app/features/seller_products/seller_products_screen.dart';
import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/product_draft.dart';
import 'package:shopscroll_shared/models/product_variant.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

ProductDraftData _data(String title, {int stock = 4}) => ProductDraftData(
  title: title,
  category: 'Fashion',
  photos: const ['mock_seller/d/a.jpg'],
  variants: [
    DraftVariant(id: 'v-$title-1', size: 'S', price: '89.000', stock: stock, stockSet: true),
    DraftVariant(id: 'v-$title-2', size: 'M', price: '95.500', stock: stock, stockSet: true),
  ],
);

Future<MockSellerProductRepository> _seed(WidgetTester tester) async {
  final repo = MockSellerProductRepository();
  await tester.runAsync(() async {
    await repo.createDraft(id: 'p1', data: _data('Wrap dress'));
    await repo.publish('p1');
    await repo.createDraft(id: 'p2', data: _data('Sold out shirt', stock: 0));
    await repo.publish('p2');
    await repo.createDraft(id: 'd3', data: const ProductDraftData(title: 'Half done'));
  });
  return repo;
}

Future<void> _pump(WidgetTester tester, MockSellerProductRepository repo) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SellerProductsScreen()),
      GoRoute(path: '/store', builder: (context, state) => const Scaffold(body: Text('STORE AREA'))),
      GoRoute(path: '/store/products/new', builder: (context, state) => const Scaffold(body: Text('NEW PRODUCT'))),
      GoRoute(
        path: '/store/products/:id/edit',
        builder: (context, state) => Scaffold(body: Text('EDIT ${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sellerProductRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pump(mockNetworkDelay);
  await tester.pump();
}

Future<void> _openMenu(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('More for $title'));
  await tester.pumpAndSettle();
}

void main() {
  // Spec 0015, AC-11, AC-12, AC-14.
  testWidgets('Live shows the products with a price range and stock', (tester) async {
    final repo = await _seed(tester);
    await _pump(tester, repo);

    expect(find.text('Wrap dress'), findsOneWidget);
    expect(find.text('89.000 TND to 95.500 TND'), findsWidgets);
    expect(find.text('8 in stock'), findsOneWidget);
    expect(find.text('Half done'), findsNothing);
  });

  testWidgets('Drafts lists unfinished work and opens it', (tester) async {
    final repo = await _seed(tester);
    await _pump(tester, repo);

    await tester.tap(find.text('Drafts'));
    await tester.pump(mockNetworkDelay);
    await tester.pump();

    expect(find.text('Half done'), findsOneWidget);
    expect(find.text('Not published yet'), findsOneWidget);
    expect(find.text('Step 1 of 3 · just now'), findsOneWidget);

    await tester.tap(find.text('Half done'));
    await tester.pumpAndSettle();
    expect(find.text('EDIT d3'), findsOneWidget);
  });

  testWidgets('Out of stock shows only live products with no stock', (tester) async {
    final repo = await _seed(tester);
    await _pump(tester, repo);

    // The tab comes first in the tree, the Live row of the sold out shirt also says it.
    await tester.ensureVisible(find.text('Out of stock').first);
    await tester.tap(find.text('Out of stock').first);
    await tester.pump(mockNetworkDelay);
    await tester.pump();

    expect(find.text('Sold out shirt'), findsOneWidget);
    expect(find.text('Wrap dress'), findsNothing);
  });

  testWidgets('archive moves a product to Archived, where it can be restored or deleted', (tester) async {
    final repo = await _seed(tester);
    await _pump(tester, repo);

    await _openMenu(tester, 'Wrap dress');
    await tester.tap(find.text('Archive'));
    await tester.pump();
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(find.text('Wrap dress'), findsNothing);

    await tester.ensureVisible(find.text('Archived'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archived'));
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(find.text('Wrap dress'), findsOneWidget);

    await _openMenu(tester, 'Wrap dress');
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this product?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
    await tester.pump(mockNetworkDelay);
    await tester.pump();

    expect(find.text('No archived products.'), findsOneWidget);
  });

  testWidgets('a live product cannot be deleted from the menu', (tester) async {
    final repo = await _seed(tester);
    await _pump(tester, repo);

    await _openMenu(tester, 'Wrap dress');

    expect(find.text('Delete'), findsNothing);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Create similar'), findsOneWidget);
    expect(find.text('Edit price and stock'), findsOneWidget);
  });

  testWidgets('quick edit changes a variant price and stock', (tester) async {
    final repo = await _seed(tester);
    await _pump(tester, repo);

    await _openMenu(tester, 'Wrap dress');
    await tester.tap(find.text('Edit price and stock'));
    await tester.pumpAndSettle();
    expect(find.text('Edit price and stock'), findsWidgets);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '70.250');
    await tester.enterText(fields.at(1), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(() => repo.listProducts(SellerProductTab.live));
    final product = saved!.firstWhere((p) => p.title == 'Wrap dress');
    expect(product.price, 70.25);
    expect(product.variants.firstWhere((v) => v.id == 'v-Wrap dress-1').stock, 0);
    await tester.pump(mockNetworkDelay);
    await tester.pump();
  });

  testWidgets('quick edit refuses a price of 0 and saves nothing', (tester) async {
    final repo = await _seed(tester);
    await _pump(tester, repo);

    await _openMenu(tester, 'Wrap dress');
    await tester.tap(find.text('Edit price and stock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a price above 0.'), findsOneWidget);
    final product = (await tester.runAsync(() => repo.listProducts(SellerProductTab.live)))!
        .firstWhere((p) => p.title == 'Wrap dress');
    expect(product.price, 89);
  });

  testWidgets('Create similar opens a new draft', (tester) async {
    final repo = await _seed(tester);
    await _pump(tester, repo);

    await _openMenu(tester, 'Wrap dress');
    await tester.tap(find.text('Create similar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('EDIT '), findsOneWidget);
    final drafts = await tester.runAsync(() => repo.listDrafts());
    final copy = drafts!.firstWhere((d) => d.data.title == 'Wrap dress');
    expect(copy.data.variants.every((v) => v.stock == 0), isTrue);
    expect(copy.data.photos, isEmpty);
    await tester.pump(mockNetworkDelay);
    await tester.pump();
  });

  testWidgets('an empty tab says so', (tester) async {
    final repo = MockSellerProductRepository();
    await _pump(tester, repo);

    expect(find.text('No live products yet.'), findsOneWidget);
    expect(find.text('Add a product to start selling.'), findsOneWidget);
  });

  test('agoLabel reads in minutes, hours and days', () {
    final now = DateTime(2026, 10, 5, 12);
    expect(agoLabel(now, now: now), 'just now');
    expect(agoLabel(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
    expect(agoLabel(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
    expect(agoLabel(now.subtract(const Duration(days: 1)), now: now), '1 day ago');
    expect(agoLabel(now.subtract(const Duration(days: 4)), now: now), '4 days ago');
  });

  test('priceRangeLabel shows one price or a range', () {
    Product product(List<double> prices) => Product(
      id: 'p',
      title: 't',
      description: 'd',
      price: prices.first,
      category: 'Fashion',
      storeId: 's',
      storeName: 'S',
      createdAt: DateTime(2026),
      currency: 'TND',
      variants: [for (var i = 0; i < prices.length; i++) ProductVariant(id: 'v$i', price: prices[i])],
    );
    expect(priceRangeLabel(product([89])), '89.000 TND');
    expect(priceRangeLabel(product([95.5, 89])), '89.000 TND to 95.500 TND');
  });
}
