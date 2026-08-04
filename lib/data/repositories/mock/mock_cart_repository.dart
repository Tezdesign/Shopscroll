import '../../mock/mock_cart_items.dart';
import '../../models/cart_item.dart';
import '../../providers/network_delay.dart';
import '../cart_repository.dart';

class MockCartRepository implements CartRepository {
  @override
  Future<List<CartItem>> getCartItems() async {
    await Future.delayed(mockNetworkDelay);
    return mockCartItems;
  }
}
