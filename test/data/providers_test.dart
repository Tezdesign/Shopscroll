import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/mock/mock_products.dart';
import 'package:marketplace_app/data/mock/mock_reels.dart';
import 'package:marketplace_app/data/mock/mock_sellers.dart';
import 'package:marketplace_app/data/providers/cart_providers.dart';
import 'package:marketplace_app/data/providers/order_providers.dart';
import 'package:marketplace_app/data/providers/product_providers.dart';
import 'package:marketplace_app/data/providers/reel_providers.dart';
import 'package:marketplace_app/data/providers/user_profile_providers.dart';

void main() {
  test('mock data meets the minimum realistic volume', () {
    expect(mockProducts.length, greaterThanOrEqualTo(15));
    expect(mockReels.length, 10);
    expect(mockSellers.length, 5);
  });

  test('productsProvider resolves all mock products after the network delay', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(productsProvider.future);

    expect(result, mockProducts);
  });

  test('productByIdProvider resolves a known product and null for unknown', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final found = await container.read(
      productByIdProvider('prod-001').future,
    );
    final missing = await container.read(
      productByIdProvider('does-not-exist').future,
    );

    expect(found?.id, 'prod-001');
    expect(missing, isNull);
  });

  test('productsByCategoryProvider filters by category', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(
      productsByCategoryProvider('Tech').future,
    );

    expect(result, isNotEmpty);
    expect(result.every((p) => p.category == 'Tech'), isTrue);
  });

  test('dealsProductsProvider only returns products marked as a deal', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(dealsProductsProvider.future);

    expect(result, isNotEmpty);
    expect(result.every((p) => p.isDeal), isTrue);
  });

  test('reelsProvider resolves all mock reels', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(reelsProvider.future);

    expect(result, mockReels);
  });

  test('reelsByStoreProvider filters by storeId', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(
      reelsByStoreProvider('seller-nike').future,
    );

    expect(result, isNotEmpty);
    expect(result.every((r) => r.storeId == 'seller-nike'), isTrue);
  });

  test('sellersProvider resolves all mock sellers', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(sellersProvider.future);

    expect(result, mockSellers);
  });

  test('userProfileByIdProvider resolves a known seller', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(
      userProfileByIdProvider('seller-apple').future,
    );

    expect(result?.name, 'Apple');
  });

  test('cartItemsProvider resolves the mock cart', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(cartItemsProvider.future);

    expect(result, isNotEmpty);
  });

  test('ordersProvider and orderByIdProvider resolve mock orders', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final orders = await container.read(ordersProvider.future);
    final order = await container.read(
      orderByIdProvider(orders.first.id).future,
    );

    expect(orders, isNotEmpty);
    expect(order?.id, orders.first.id);
  });
}
