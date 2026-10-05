import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/repository_providers.dart';

/// The category names a seller can choose for a product, as if fetched from
/// `GET /product-categories` (spec 0015). Auto disposed, and no automatic
/// retry: a failed load reaches the screen so it can say so.
final sellerCategoriesProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(sellerProductRepositoryProvider).categories(),
  retry: (retryCount, error) => null,
);
