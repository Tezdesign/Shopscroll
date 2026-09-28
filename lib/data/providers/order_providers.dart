import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import '../repositories/repository_providers.dart';

/// The buyer's past orders, as if fetched from a `GET /orders` endpoint. No
/// automatic retry, so a failed load reaches the Purchases tab as an error
/// with its own "Try again" (spec 0008, AC-12).
final ordersProvider = FutureProvider<List<Order>>(
  (ref) => ref.watch(orderRepositoryProvider).getOrders(),
  retry: (retryCount, error) => null,
);

/// A single order by id, as if fetched from `GET /orders/:id`.
final orderByIdProvider = FutureProvider.family<Order?, String>((ref, id) {
  return ref.watch(orderRepositoryProvider).getOrderById(id);
});
