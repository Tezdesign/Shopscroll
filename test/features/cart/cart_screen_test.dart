import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/data/mock/mock_cart_items.dart';
import 'package:marketplace_app/data/mock/mock_products.dart';
import 'package:marketplace_app/data/models/cart_item.dart';
import 'package:marketplace_app/data/models/product.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/repositories/cart_repository.dart';
import 'package:marketplace_app/data/repositories/mock/mock_cart_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/features/cart/add_to_cart.dart';
import 'package:marketplace_app/features/cart/cart_logic.dart';
import 'package:marketplace_app/features/cart/cart_screen.dart';

/// A repository that starts empty, can fail to load, and can fail writes.
class _FlakyRepo extends MockCartRepository {
  _FlakyRepo({this.empty = false, this.failLoad = false});

  final bool empty;
  final bool failLoad;
  bool failWrites = false;

  @override
  Future<List<CartItem>> getCartItems() async {
    if (failLoad) throw Exception('no network');
    return empty ? const [] : super.getCartItems();
  }

  @override
  Future<CartItem> setQuantity(String itemId, int quantity) async {
    if (failWrites) throw Exception('boom');
    return super.setQuantity(itemId, quantity);
  }
}

void main() {
  Widget wrap(CartRepository repository, {String start = '/cart'}) {
    final router = GoRouter(
      initialLocation: start,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home page')),
          routes: [
            GoRoute(
              path: 'cart',
              builder: (context, state) => const CartScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) =>
              const Scaffold(body: Text('Checkout page')),
        ),
        GoRoute(
          path: '/product/:id',
          builder: (context, state) =>
              Scaffold(body: Text('Product ${state.pathParameters['id']}')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [cartRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
  }

  Future<void> openCart(WidgetTester tester, CartRepository repo) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pump(mockNetworkDelay);
    await tester.pump();
  }

  final total = cartTotalLabel(mockCartItems);

  testWidgets('lists every line, oldest first, with the total (AC-2, AC-3)', (
    tester,
  ) async {
    await openCart(tester, MockCartRepository());

    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('Items price'), findsOneWidget);
    expect(find.text(total), findsOneWidget);
    expect(find.text('Proceed to checkout'), findsOneWidget);
    for (final item in mockCartItems) {
      expect(find.text(item.product.title), findsOneWidget);
    }
    // Size label on the line that has one.
    expect(find.text('Size M'), findsOneWidget);
    final firstY = tester
        .getTopLeft(find.text(mockCartItems[0].product.title))
        .dy;
    final lastY = tester
        .getTopLeft(find.text(mockCartItems[2].product.title))
        .dy;
    expect(firstY, lessThan(lastY));
  });

  testWidgets('plus raises the quantity and the total at once (AC-3, AC-4)', (
    tester,
  ) async {
    await openCart(tester, MockCartRepository());

    await tester.tap(find.text('+').first);
    await tester.tap(find.text('+').first);
    await tester.pump();

    final raised = [
      mockCartItems[0].copyWith(quantity: 3),
      ...mockCartItems.skip(1),
    ];
    expect(find.text('3'), findsOneWidget);
    expect(find.text(cartTotalLabel(raised)), findsOneWidget);
    await tester.pump(mockNetworkDelay * 2);
  });

  testWidgets('minus is disabled at 1 (AC-5)', (tester) async {
    await openCart(tester, MockCartRepository());

    await tester.tap(find.text('-').first);
    await tester.pump();

    expect(find.text(total), findsOneWidget);
    expect(find.text(mockCartItems[0].product.title), findsOneWidget);
  });

  testWidgets('trash removes at once and Undo puts the line back (AC-6)', (
    tester,
  ) async {
    await openCart(tester, MockCartRepository());
    final title = mockCartItems[0].product.title;

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();

    expect(find.text(title), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400)); // slides in
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(find.text(title), findsOneWidget);
    expect(find.text(total), findsOneWidget);

    await tester.pump(mockNetworkDelay * 3);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the Undo snack bar goes away by itself (AC-6)', (tester) async {
    await openCart(tester, MockCartRepository());

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump(mockNetworkDelay);
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5)); // fully in, timer starts
    await tester.pump(const Duration(seconds: 5)); // timer ends, slides out
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('an empty cart offers Start shopping and no footer (AC-7)', (
    tester,
  ) async {
    await openCart(tester, _FlakyRepo(empty: true));

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Items price'), findsNothing);

    await tester.tap(find.text('Start shopping'));
    await tester.pumpAndSettle();
    expect(find.text('Home page'), findsOneWidget);
  });

  testWidgets('shows a spinner while loading and an error with retry (AC-8)', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_FlakyRepo(failLoad: true)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(find.text("Couldn't load your cart."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('Proceed to checkout opens /checkout (spec 0009, AC-1)', (
    tester,
  ) async {
    await openCart(tester, MockCartRepository());

    await tester.tap(find.text('Proceed to checkout'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout page'), findsOneWidget);
  });

  testWidgets('tapping a card opens its product (AC-2)', (tester) async {
    await openCart(tester, MockCartRepository());

    await tester.tap(find.text(mockCartItems[0].product.title));
    await tester.pumpAndSettle();

    expect(find.text('Product ${mockCartItems[0].product.id}'), findsOneWidget);
  });

  testWidgets('a failed write puts the quantity back and says so (AC-15)', (
    tester,
  ) async {
    final repo = _FlakyRepo();
    await openCart(tester, repo);
    repo.failWrites = true;

    await tester.tap(find.text('+').first);
    await tester.pump();
    expect(find.text('2'), findsWidgets); // shown first
    await tester.pump(mockNetworkDelay);
    await tester.pump();

    expect(find.text(total), findsOneWidget);
    expect(find.text("Couldn't update your cart. Try again."), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('controls have spoken labels and 44 pixel tap areas (AC-17)', (
    tester,
  ) async {
    await openCart(tester, MockCartRepository());

    for (final label in [
      'Increase quantity',
      'Decrease quantity',
      'Remove from cart',
      'Back',
    ]) {
      final finder = find.bySemanticsLabel(label).first;
      expect(finder, findsOneWidget, reason: label);
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(44), reason: label);
      expect(size.height, greaterThanOrEqualTo(44), reason: label);
    }
  });

  group('addToCart helper', () {
    Widget host(CartRepository repo, Product product, {String? message}) {
      return ProviderScope(
        overrides: [cartRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    addToCart(context, product, successMessage: message),
                child: const Text('Add'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'an out of stock product is refused and writes nothing (AC-14)',
      (tester) async {
        final repo = MockCartRepository();
        final soldOut = mockProducts[3].copyWith(inStock: false);
        await tester.pumpWidget(host(repo, soldOut));

        await tester.tap(find.text('Add'));
        await tester.pump();

        expect(find.text('This item is out of stock'), findsOneWidget);
        await tester.pump(mockNetworkDelay);
        final lines = await tester.runAsync(repo.getCartItems);
        expect(lines!.length, mockCartItems.length);
      },
    );

    testWidgets('a quick add takes the first size and colour (AC-11)', (
      tester,
    ) async {
      final repo = MockCartRepository();
      final product = mockProducts[3];
      await tester.pumpWidget(host(repo, product, message: 'Added to cart'));

      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(find.text('Added to cart'), findsOneWidget);
      // The cart loads first (never opened here), then the write saves.
      await tester.pump(mockNetworkDelay);
      await tester.pump(mockNetworkDelay);

      final added = (await tester.runAsync(repo.getCartItems))!.last;
      expect(added.product.id, product.id);
      expect(added.selectedSize, firstSize(product));
      expect(added.selectedColor, firstColor(product));
      await tester.pump(mockNetworkDelay);
    });
  });
}
