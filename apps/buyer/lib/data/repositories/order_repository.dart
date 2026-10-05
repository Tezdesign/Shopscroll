import '../models/order.dart';
import '../models/place_order_request.dart';

/// Why [OrderRepository.placeOrder] failed (spec 0009, AC-13). The screen
/// turns each into a message. [failed] is any other failure, like no network.
enum PlaceOrderFailure {
  cartEmpty,
  itemsChanged,

  /// A color and size has less stock than the cart asks for (spec 0015, AC-10).
  outOfStock,

  /// The cart holds products priced in different currencies (AC-19).
  mixedCurrency,
  invalid,
  failed,
}

class PlaceOrderException implements Exception {
  const PlaceOrderException(this.reason);

  final PlaceOrderFailure reason;

  @override
  String toString() => 'PlaceOrderException($reason)';
}

/// Access to the signed in buyer's orders. See product_repository.dart for
/// the mock/Supabase swap pattern.
abstract class OrderRepository {
  /// As if fetched from `GET /orders`, newest first.
  Future<List<Order>> getOrders();

  /// As if fetched from `GET /orders/:id`.
  Future<Order?> getOrderById(String id);

  /// As if sent to `POST /orders`. Builds one order from the buyer's whole
  /// cart, prices it on the server, clears the cart, and returns the order.
  /// Sending the same [PlaceOrderRequest.orderId] again returns that order.
  /// Throws a [PlaceOrderException] when nothing was created.
  Future<Order> placeOrder(PlaceOrderRequest request);
}
