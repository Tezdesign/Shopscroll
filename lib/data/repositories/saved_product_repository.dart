import '../models/product.dart';
import '../models/saved_product.dart';

/// Access to the buyer's saved products (spec 0008). See
/// product_repository.dart for the mock/Supabase swap pattern. Writes stand
/// in for the REST calls named on each method and throw when they fail, so
/// the caller can undo what it showed. Saving twice is not an error, and
/// neither is removing a product that is not saved.
abstract class SavedProductRepository {
  /// As if fetched from `GET /saved-products`. Newest saved first.
  Future<List<SavedProduct>> getSavedProducts();

  /// As if sent to `PUT /saved-products/:productId`. [savedAt] is only for
  /// Undo, which puts a product back with its old save time.
  Future<SavedProduct> saveProduct(Product product, {DateTime? savedAt});

  /// As if sent to `DELETE /saved-products/:productId`.
  Future<void> unsaveProduct(String productId);
}
