import '../models/cart_item.dart';
import '../models/product.dart';

/// Access to the buyer's cart. See product_repository.dart for the
/// mock/Supabase swap pattern. Writes stand in for the REST calls named on
/// each method (spec 0007). Every write throws when it fails, so the
/// caller can undo what it showed.
abstract class CartRepository {
  /// As if fetched from `GET /cart`.
  Future<List<CartItem>> getCartItems();

  /// As if sent to `POST /cart/items`. When a line for the same product,
  /// size and colour exists, its quantity goes up (to 99 at most) and that
  /// line is returned instead of a second one being added.
  Future<CartItem> addItem(
    Product product,
    int quantity, {
    String? size,
    int? color,
  });

  /// As if sent to `PATCH /cart/items/:id`. Throws when the line is missing.
  Future<CartItem> setQuantity(String itemId, int quantity);

  /// As if sent to `DELETE /cart/items/:id`.
  Future<void> removeItem(String itemId);
}
