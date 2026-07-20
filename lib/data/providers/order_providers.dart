import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_orders.dart';
import '../models/order.dart';
import 'network_delay.dart';

/// The buyer's past orders, as if fetched from a `GET /orders` endpoint.
final ordersProvider = FutureProvider<List<Order>>((ref) async {
  await Future.delayed(mockNetworkDelay);
  return mockOrders;
});

/// A single order by id, as if fetched from `GET /orders/:id`.
final orderByIdProvider = FutureProvider.family<Order?, String>((
  ref,
  id,
) async {
  await Future.delayed(mockNetworkDelay);
  for (final order in mockOrders) {
    if (order.id == id) return order;
  }
  return null;
});
