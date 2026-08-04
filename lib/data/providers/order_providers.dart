import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import '../repositories/repository_providers.dart';

/// The buyer's past orders, as if fetched from a `GET /orders` endpoint.
final ordersProvider = FutureProvider<List<Order>>((ref) {
  return ref.watch(orderRepositoryProvider).getOrders();
});

/// A single order by id, as if fetched from `GET /orders/:id`.
final orderByIdProvider = FutureProvider.family<Order?, String>((ref, id) {
  return ref.watch(orderRepositoryProvider).getOrderById(id);
});
