import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_item.dart';
import '../repositories/repository_providers.dart';

/// The buyer's current cart contents, as if fetched from `GET /cart`.
final cartItemsProvider = FutureProvider<List<CartItem>>((ref) {
  return ref.watch(cartRepositoryProvider).getCartItems();
});
