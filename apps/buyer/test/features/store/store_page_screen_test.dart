import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/reel.dart';
import 'package:marketplace_app/data/models/saved_reel.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:marketplace_app/data/repositories/product_repository.dart';
import 'package:marketplace_app/data/repositories/reel_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/user_profile_repository.dart';
import 'package:marketplace_app/features/store/store_page_screen.dart';

/// Serves one seller (or fails, or finds nothing) for any id, with no
/// artificial delay, same reasoning as `order_receipt_screen_test.dart`'s
/// `_Orders` fake.
class _Sellers implements UserProfileRepository {
  _Sellers({this.seller, this.fail = false});

  final UserProfile? seller;
  final bool fail;
  int reads = 0;

  @override
  Future<UserProfile?> getUserProfileById(String id) async {
    reads++;
    if (fail) throw Exception('no network');
    return seller;
  }

  @override
  Future<List<UserProfile>> getSellers() => throw UnimplementedError();

  @override
  Future<void> updateUserProfile(
    String id, {
    required String name,
    required String username,
    String? bio,
  }) => throw UnimplementedError();
}

class _Products implements ProductRepository {
  _Products({this.products = const [], this.fail = false});

  final List<Product> products;
  final bool fail;
  int reads = 0;

  @override
  Future<List<Product>> getProductsByStore(String storeId) async {
    reads++;
    if (fail) throw Exception('no network');
    return products;
  }

  @override
  Future<List<Product>> getProducts() => throw UnimplementedError();

  @override
  Future<Product?> getProductById(String id) => throw UnimplementedError();

  @override
  Future<List<Product>> getProductsByCategory(String category) =>
      throw UnimplementedError();

  @override
  Future<List<Product>> getDealsProducts() => throw UnimplementedError();
}

class _Reels implements ReelRepository {
  _Reels({this.reels = const [], this.fail = false});

  final List<Reel> reels;
  final bool fail;
  int reads = 0;

  @override
  Future<List<Reel>> getReelsByStore(String storeId) async {
    reads++;
    if (fail) throw Exception('no network');
    return reels;
  }

  @override
  Future<List<Reel>> getReels() => throw UnimplementedError();

  @override
  Future<Reel?> getReelById(String id) => throw UnimplementedError();

  @override
  Future<List<SavedReel>> getSavedReels() => throw UnimplementedError();

  @override
  Future<SavedReel> saveReel(Reel reel, {DateTime? savedAt}) =>
      throw UnimplementedError();

  @override
  Future<void> unsaveReel(String reelId) => throw UnimplementedError();
}

void main() {
  const seller = UserProfile(
    id: 'seller-x',
    name: 'Acme',
    username: '@teststore',
    avatarUrl: 'https://example.com/avatar.png',
    followerCount: 128400,
    websiteUrl: 'https://example.com',
    location: 'Testville',
    bio: 'a secret bio',
    email: 'secret@example.com',
    phone: '+1 555 0000',
  );

  final product = Product(
    id: 'prod-x',
    title: 'Test Product',
    description: 'desc',
    price: 10,
    category: 'Fashion',
    storeId: 'seller-x',
    storeName: 'Acme',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  final reel = Reel(
    id: 'reel-x',
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: 'https://example.com/thumb.png',
    storeId: 'seller-x',
    storeName: 'Acme',
    caption: 'A caption',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  Future<GoRouter> open(
    WidgetTester tester, {
    _Sellers? sellers,
    _Products? products,
    _Reels? reels,
  }) async {
    final router = GoRouter(
      initialLocation: '/store/seller-x',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home page')),
          routes: [
            GoRoute(
              path: 'store/:id',
              builder: (context, state) =>
                  StorePageScreen(storeId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(
            sellers ?? _Sellers(seller: seller),
          ),
          productRepositoryProvider.overrideWithValue(
            products ?? _Products(products: [product]),
          ),
          reelRepositoryProvider.overrideWithValue(
            reels ?? _Reels(reels: [reel]),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    return router;
  }

  Future<void> load(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the seller avatar, name, follower count and products', (
    tester,
  ) async {
    await open(tester);
    await load(tester);

    expect(find.text('Acme'), findsWidgets);
    expect(find.text('128K Followers'), findsOneWidget);
    expect(find.text('Test Product'), findsOneWidget);
  });

  testWidgets(
    'never shows the bio, email or phone the UserProfile model carries '
    '(AC-11)',
    (tester) async {
      await open(tester);
      await load(tester);

      expect(find.text('a secret bio'), findsNothing);
      expect(find.text('secret@example.com'), findsNothing);
      expect(find.text('+1 555 0000'), findsNothing);
    },
  );

  testWidgets(
    'shows the website and location rows only when those fields are set '
    '(AC-4)',
    (tester) async {
      await open(tester);
      await load(tester);
      expect(find.text('Go to website'), findsOneWidget);
      expect(find.text('Testville'), findsOneWidget);

      const noLinks = UserProfile(
        id: 'seller-y',
        name: 'No Links Store',
        username: '@nolinks',
        followerCount: 10,
      );
      await open(tester, sellers: _Sellers(seller: noLinks));
      await load(tester);

      expect(find.text('Go to website'), findsNothing);
      expect(find.text('Testville'), findsNothing);
    },
  );

  testWidgets("the Reels tab shows the store's reels, scoped to it", (
    tester,
  ) async {
    await open(tester);
    await load(tester);

    await tester.tap(find.text('Reels'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(GridView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GridView),
        matching: find.byType(CachedNetworkImage),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an empty Products tab names the store', (tester) async {
    await open(tester, products: _Products());
    await load(tester);

    expect(find.text("Acme hasn't listed any products yet."), findsOneWidget);
  });

  testWidgets('an empty Reels tab names the store', (tester) async {
    await open(tester, reels: _Reels());
    await load(tester);

    await tester.tap(find.text('Reels'));
    await tester.pump();
    await tester.pump();

    expect(find.text("Acme hasn't posted any reels yet."), findsOneWidget);
  });

  testWidgets('a failed Products tab load shows "Try again" (AC-9)', (
    tester,
  ) async {
    final products = _Products(fail: true);
    await open(tester, products: products);
    await load(tester);

    expect(find.text("Couldn't load products."), findsOneWidget);
    expect(products.reads, 1);

    await tester.tap(find.text('Try again'));
    await load(tester);
    expect(products.reads, 2);
  });

  testWidgets('a failed Reels tab load shows "Try again" (AC-9)', (
    tester,
  ) async {
    final reels = _Reels(fail: true);
    await open(tester, reels: reels);
    await load(tester);

    await tester.tap(find.text('Reels'));
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't load reels."), findsOneWidget);
    expect(reels.reads, 1);

    await tester.tap(find.text('Try again'));
    await load(tester);
    expect(reels.reads, 2);
  });

  testWidgets('shows a loading indicator while the seller loads', (
    tester,
  ) async {
    await open(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await load(tester);
  });

  testWidgets('a failed seller load shows the message, and Try again '
      'reloads it', (tester) async {
    final sellers = _Sellers(fail: true);
    await open(tester, sellers: sellers);
    await load(tester);

    expect(find.text("Couldn't load this store."), findsOneWidget);
    expect(sellers.reads, 1);

    await tester.tap(find.text('Try again'));
    await load(tester);
    expect(sellers.reads, 2);
  });

  testWidgets('an unknown storeId shows a not found message (AC-10)', (
    tester,
  ) async {
    await open(tester, sellers: _Sellers());
    await load(tester);

    expect(find.text('Store not found'), findsOneWidget);
  });

  testWidgets('the back button leaves the screen', (tester) async {
    await open(tester);
    await load(tester);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('Home page'), findsOneWidget);
    expect(find.text('Acme'), findsNothing);
  });
}
