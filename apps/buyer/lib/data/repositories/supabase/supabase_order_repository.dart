import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/cart_item.dart';
import 'package:shopscroll_shared/models/contact_info.dart';
import '../../models/order.dart';
import '../../models/place_order_request.dart';
import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/shipping_address.dart';
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
  CartItem _orderItemToCartItem(
    Map<String, dynamic> row,
    DateTime orderCreatedAt,
    String currency,
  ) {
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
        currency: currency,
      ),
      quantity: row['quantity'] as int? ?? 1,
      selectedSize: row['selected_size'] as String?,
      selectedColor: (row['selected_color'] as num?)?.toInt(),
      addedAt: orderCreatedAt,
    );
  }

  Order _fromRow(Map<String, dynamic> row) {
    final createdAt = DateTime.parse(row['created_at'] as String);
    final currency = row['currency'] as String? ?? 'TND';
    final items = (row['order_items'] as List<dynamic>? ?? const [])
        .map(
          (e) => _orderItemToCartItem(
            e as Map<String, dynamic>,
            createdAt,
            currency,
          ),
        )
        .toList();
    // Orders made before spec 0009 have no contact or address columns filled.
    final hasContact = row['contact_name'] != null;
    final hasAddress = row['ship_city'] != null;
    return Order(
      id: row['id'] as String,
      items: items,
      status: OrderStatus.values.byName(row['status'] as String),
      totalAmount: (row['total_amount'] as num).toDouble(),
      currency: currency,
      orderNumber: (row['order_number'] as num?)?.toInt(),
      subtotal: (row['subtotal'] as num?)?.toDouble(),
      deliveryFee: (row['delivery_fee'] as num?)?.toDouble(),
      deliveryMethod: row['delivery_method'] as String?,
      contact: hasContact
          ? ContactInfo(
              name: row['contact_name'] as String,
              email: row['contact_email'] as String? ?? '',
              phone: row['contact_phone'] as String? ?? '',
            )
          : null,
      shippingAddress: hasAddress
          ? ShippingAddress(
              country: row['ship_country'] as String? ?? 'Tunisia',
              city: row['ship_city'] as String,
              address: row['ship_address'] as String? ?? '',
              zip: row['ship_zip'] as String? ?? '',
              note: row['ship_note'] as String? ?? '',
            )
          : null,
      paymentMethod: row['payment_method'] as String?,
      createdAt: createdAt,
      estimatedDelivery: row['estimated_delivery'] != null
          ? DateTime.parse(row['estimated_delivery'] as String)
          : null,
    );
  }

  // No user filter: row level security already limits `orders` to the caller's
  // own rows, and `client.auth` is not usable on the Clerk backed client, so
  // reading `currentUser` here made Purchases fail after sign in (spec 0009).
  @override
  Future<List<Order>> getOrders() async {
    final rows = await _client
        .from('orders')
        .select(_selectWithItems)
        .order('created_at', ascending: false);
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

  /// Calls the `place_order` Postgres function (see
  /// `supabase/migrations/0003_place_order.sql`), which prices the cart on the
  /// server, and reads the new order back.
  @override
  Future<Order> placeOrder(PlaceOrderRequest request) async {
    try {
      await _client.rpc(
        'place_order',
        params: {
          'p_order_id': request.orderId,
          'p_contact_name': request.contact.name,
          'p_contact_email': request.contact.email,
          'p_contact_phone': request.contact.phone,
          'p_ship_city': request.address.city,
          'p_ship_address': request.address.address,
          'p_ship_zip': request.address.zip,
          'p_ship_note': request.address.note,
          'p_delivery_method': request.deliveryMethod.name,
          'p_payment_method': request.paymentMethod.name,
          // Summing prices as doubles can leave 44.99999999, and the function
          // compares this with an exact numeric, so send three decimals (a
          // dinar has three, spec 0015 AC-19).
          'p_expected_subtotal': double.parse(
            request.expectedSubtotal.toStringAsFixed(3),
          ),
        },
      );
    } on PostgrestException catch (error) {
      throw PlaceOrderException(placeOrderFailureFor(error.message));
    } catch (_) {
      throw const PlaceOrderException(PlaceOrderFailure.failed);
    }
    final order = await getOrderById(request.orderId);
    if (order == null) {
      throw const PlaceOrderException(PlaceOrderFailure.failed);
    }
    return order;
  }
}

/// What the `place_order` function's reason means for the app. The function
/// raises its reason as the whole error message. Public so a test can pin each
/// mapping.
PlaceOrderFailure placeOrderFailureFor(String message) {
  if (message.contains('cart_empty')) return PlaceOrderFailure.cartEmpty;
  if (message.contains('out_of_stock')) return PlaceOrderFailure.outOfStock;
  if (message.contains('mixed_currency')) return PlaceOrderFailure.mixedCurrency;
  if (message.contains('product_unavailable') ||
      message.contains('price_changed')) {
    return PlaceOrderFailure.itemsChanged;
  }
  if (message.contains('invalid_field') ||
      message.contains('invalid_method') ||
      message.contains('no_session')) {
    return PlaceOrderFailure.invalid;
  }
  return PlaceOrderFailure.failed;
}

