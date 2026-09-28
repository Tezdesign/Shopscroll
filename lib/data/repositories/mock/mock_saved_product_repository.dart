import '../../mock/mock_saved_products.dart';
import '../../models/product.dart';
import '../../models/saved_product.dart';
import '../../providers/network_delay.dart';
import '../saved_product_repository.dart';

/// Keeps its own in memory copy of [mockSavedProducts], so writes last for
/// the run of the app and never leak into the shared seed list.
class MockSavedProductRepository implements SavedProductRepository {
  final Map<String, SavedProduct> _saved = {
    for (final s in mockSavedProducts) s.product.id: s,
  };

  @override
  Future<List<SavedProduct>> getSavedProducts() async {
    await Future.delayed(mockNetworkDelay);
    return _saved.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  @override
  Future<SavedProduct> saveProduct(Product product, {DateTime? savedAt}) async {
    await Future.delayed(mockNetworkDelay);
    return _saved.putIfAbsent(
      product.id,
      () => SavedProduct(product, savedAt ?? DateTime.now()),
    );
  }

  @override
  Future<void> unsaveProduct(String productId) async {
    await Future.delayed(mockNetworkDelay);
    _saved.remove(productId);
  }
}
