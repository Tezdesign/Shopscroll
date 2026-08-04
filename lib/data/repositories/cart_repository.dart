import '../models/cart_item.dart';

/// Read access to the signed in buyer's cart. See product_repository.dart
/// for the mock/Supabase swap pattern.
abstract class CartRepository {
  Future<List<CartItem>> getCartItems();
}
