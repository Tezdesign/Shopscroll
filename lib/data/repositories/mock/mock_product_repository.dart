import '../../mock/mock_products.dart';
import '../../models/product.dart';
import '../../providers/network_delay.dart';
import '../product_repository.dart';

/// Reads straight from the mock catalog, with the artificial network delay
/// every mock provider already used. Kept as the default so existing tests
/// and dev workflows keep working with zero setup.
class MockProductRepository implements ProductRepository {
  @override
  Future<List<Product>> getProducts() async {
    await Future.delayed(mockNetworkDelay);
    return mockProducts;
  }

  @override
  Future<Product?> getProductById(String id) async {
    await Future.delayed(mockNetworkDelay);
    for (final product in mockProducts) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Future<List<Product>> getProductsByCategory(String category) async {
    await Future.delayed(mockNetworkDelay);
    return mockProducts.where((p) => p.category == category).toList();
  }

  @override
  Future<List<Product>> getDealsProducts() async {
    await Future.delayed(mockNetworkDelay);
    return mockProducts.where((p) => p.isDeal).toList();
  }
}
