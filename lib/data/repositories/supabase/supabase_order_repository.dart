import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/cart_item.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../order_repository.dart';

class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository(this._client);

  final SupabaseClient _client;

  static const _selectWithItems = '*, order_items(*)';

  // order_items only snapshots title/image_url/store_name/unit_price (by
  // design: see spec 0003's data model), not a full Product row, and its
  // product_id goes null once the source product is deleted. CartItem
  // still requires a full Product, so the fields order_items never
  // snapshotted (description, category, storeId) are filled with an empty
  // placeholder here; nothing in the order history UI reads them today.
  CartItem _orderItemToCartItem(Map<String, dynamic> row, DateTime orderCreatedAt) {
    return CartItem(
      id: row['id'] as String,
      product: Product(
        id: row['product_id'] as String? ?? row['id'] as String,
        title: row['title'] as String,
        description: '',
        price: (row['unit_price'] as num).toDouble(),
        category: '',
        storeId: '',
        storeName: row['store_name'] as String? ?? '',
        imageUrl: row['image_url'] as String?,
        createdAt: orderCreatedAt,
      ),
      quantity: row['quantity'] as int? ?? 1,
      selectedSize: row['selected_size'] as String?,
      selectedColor: (row['selected_color'] as num?)?.toInt(),
      addedAt: orderCreatedAt,
    );
  }

  Order _fromRow(Map<String, dynamic> row) {
    final createdAt = DateTime.parse(row['created_at'] as String);
    final items = (row['order_items'] as List<dynamic>? ?? const [])
        .map((e) => _orderItemToCartItem(e as Map<String, dynamic>, createdAt))
        .toList();
    return Order(
      id: row['id'] as String,
      items: items,
      status: OrderStatus.values.byName(row['status'] as String),
      totalAmount: (row['total_amount'] as num).toDouble(),
      deliveryFee: (row['delivery_fee'] as num?)?.toDouble(),
      deliveryMethod: row['delivery_method'] as String?,
      shippingAddress: row['shipping_address'] as String?,
      paymentMethod: row['payment_method'] as String?,
      createdAt: createdAt,
      estimatedDelivery: row['estimated_delivery'] != null
          ? DateTime.parse(row['estimated_delivery'] as String)
          : null,
    );
  }

  @override
  Future<List<Order>> getOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final rows = await _client
        .from('orders')
        .select(_selectWithItems)
        .eq('user_id', userId);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Order?> getOrderById(String id) async {
    final row = await _client
        .from('orders')
        .select(_selectWithItems)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _fromRow(row);
  }
}
