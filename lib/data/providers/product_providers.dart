import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../repositories/repository_providers.dart';

/// All products, as if fetched from a `GET /products` endpoint.
final productsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).getProducts();
});

/// A single product by id, as if fetched from `GET /products/:id`.
final productByIdProvider = FutureProvider.family<Product?, String>((
  ref,
  id,
) {
  return ref.watch(productRepositoryProvider).getProductById(id);
});

/// Products filtered by category, as if fetched from
/// `GET /products?category=:category`.
final productsByCategoryProvider = FutureProvider.family<List<Product>, String>(
  (ref, category) {
    return ref.watch(productRepositoryProvider).getProductsByCategory(category);
  },
);

/// Products currently on a deal, as if fetched from `GET /products?deal=true`.
final dealsProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).getDealsProducts();
});
