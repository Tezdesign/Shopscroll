import '../models/order.dart';

/// Read access to the signed in buyer's past orders. See
/// product_repository.dart for the mock/Supabase swap pattern.
abstract class OrderRepository {
  Future<List<Order>> getOrders();
  Future<Order?> getOrderById(String id);
}
