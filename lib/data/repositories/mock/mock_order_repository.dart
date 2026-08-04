import '../../mock/mock_orders.dart';
import '../../models/order.dart';
import '../../providers/network_delay.dart';
import '../order_repository.dart';

class MockOrderRepository implements OrderRepository {
  @override
  Future<List<Order>> getOrders() async {
    await Future.delayed(mockNetworkDelay);
    return mockOrders;
  }

  @override
  Future<Order?> getOrderById(String id) async {
    await Future.delayed(mockNetworkDelay);
    for (final order in mockOrders) {
      if (order.id == id) return order;
    }
    return null;
  }
}
