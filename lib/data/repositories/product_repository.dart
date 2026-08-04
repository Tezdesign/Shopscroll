import '../models/product.dart';

/// Read access to the product catalog. One implementation reads the mock
/// list ([lib/data/repositories/mock/mock_product_repository.dart]), the
/// other queries Supabase ([lib/data/repositories/supabase/supabase_product_repository.dart]);
/// the app swaps between them through [productRepositoryProvider].
abstract class ProductRepository {
  Future<List<Product>> getProducts();
  Future<Product?> getProductById(String id);
  Future<List<Product>> getProductsByCategory(String category);
  Future<List<Product>> getDealsProducts();
}
