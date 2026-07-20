import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_cart_items.dart';
import '../models/cart_item.dart';
import 'network_delay.dart';

/// The buyer's current cart contents, as if fetched from `GET /cart`.
final cartItemsProvider = FutureProvider<List<CartItem>>((ref) async {
  await Future.delayed(mockNetworkDelay);
  return mockCartItems;
});
