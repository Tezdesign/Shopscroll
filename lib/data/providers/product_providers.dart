import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_products.dart';
import '../models/product.dart';
import 'network_delay.dart';

/// All products, as if fetched from a `GET /products` endpoint.
final productsProvider = FutureProvider<List<Product>>((ref) async {
  await Future.delayed(mockNetworkDelay);
  return mockProducts;
});

/// A single product by id, as if fetched from `GET /products/:id`.
final productByIdProvider = FutureProvider.family<Product?, String>((
  ref,
  id,
) async {
  await Future.delayed(mockNetworkDelay);
  for (final product in mockProducts) {
    if (product.id == id) return product;
  }
  return null;
});

/// Products filtered by category, as if fetched from
/// `GET /products?category=:category`.
final productsByCategoryProvider = FutureProvider.family<List<Product>, String>(
  (ref, category) async {
    await Future.delayed(mockNetworkDelay);
    return mockProducts.where((p) => p.category == category).toList();
  },
);

/// Products currently on a deal, as if fetched from `GET /products?deal=true`.
final dealsProductsProvider = FutureProvider<List<Product>>((ref) async {
  await Future.delayed(mockNetworkDelay);
  return mockProducts.where((p) => p.isDeal).toList();
});
