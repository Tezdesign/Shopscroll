import '../models/saved_product.dart';
import 'mock_products.dart';

/// Three mocked saved products, newest saved first, so My collection is not
/// empty on the mock backend.
final List<SavedProduct> mockSavedProducts = [
  SavedProduct(mockProducts[9], DateTime(2026, 9, 20)),
  SavedProduct(mockProducts[0], DateTime(2026, 9, 12)),
  SavedProduct(mockProducts[12], DateTime(2026, 9, 3)),
];
