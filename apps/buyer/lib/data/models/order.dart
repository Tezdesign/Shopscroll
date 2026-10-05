import 'cart_item.dart';
import 'package:shopscroll_shared/models/contact_info.dart';
import 'package:shopscroll_shared/models/shipping_address.dart';

/// Also the single source of truth for `OrderStatusBadge`'s three visual
/// states (see lib/shared/widgets/order_status_badge.dart).
enum OrderStatus { delivered, inProgress, canceled }

class Order {
  const Order({
    required this.id,
    required this.items,
    required this.status,
    required this.totalAmount,
    this.orderNumber,
    this.subtotal,
    this.deliveryFee,
    this.deliveryMethod,
    this.contact,
    this.shippingAddress,
    this.paymentMethod,
    required this.createdAt,
    this.estimatedDelivery,
    this.currency = 'USD',
  });

  final String id;
  final List<CartItem> items;
  final OrderStatus status;
  final double totalAmount;

  /// The number shown as `Order#000001`. Null on older orders (spec 0009).
  final int? orderNumber;

  /// Sum of price times quantity. Null on older orders, where it is
  /// [totalAmount] minus [deliveryFee].
  final double? subtotal;
  final double? deliveryFee;

  /// `standard` or `exclusive` on orders placed in the app, free text on the
  /// older mock ones.
  final String? deliveryMethod;
  final ContactInfo? contact;
  final ShippingAddress? shippingAddress;

  /// `cashOnDelivery` or `card` on orders placed in the app, free text on the
  /// older mock ones.
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime? estimatedDelivery;

  /// The currency every amount of this order is in (spec 0015, AC-19). The
  /// default is the currency of the mock orders.
  final String currency;

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: OrderStatus.values.byName(json['status'] as String),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      orderNumber: json['orderNumber'] as int?,
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
      deliveryMethod: json['deliveryMethod'] as String?,
      contact: json['contact'] == null
          ? null
          : ContactInfo.fromJson(json['contact'] as Map<String, dynamic>),
      shippingAddress: json['shippingAddress'] == null
          ? null
          : ShippingAddress.fromJson(
              json['shippingAddress'] as Map<String, dynamic>,
            ),
      paymentMethod: json['paymentMethod'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      estimatedDelivery: json['estimatedDelivery'] != null
          ? DateTime.parse(json['estimatedDelivery'] as String)
          : null,
      currency: json['currency'] as String? ?? 'USD',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((e) => e.toJson()).toList(),
      'status': status.name,
      'totalAmount': totalAmount,
      'orderNumber': orderNumber,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'deliveryMethod': deliveryMethod,
      'contact': contact?.toJson(),
      'shippingAddress': shippingAddress?.toJson(),
      'paymentMethod': paymentMethod,
      'createdAt': createdAt.toIso8601String(),
      'estimatedDelivery': estimatedDelivery?.toIso8601String(),
      'currency': currency,
    };
  }

  Order copyWith({
    String? id,
    List<CartItem>? items,
    OrderStatus? status,
    double? totalAmount,
    int? orderNumber,
    double? subtotal,
    double? deliveryFee,
    String? deliveryMethod,
    ContactInfo? contact,
    ShippingAddress? shippingAddress,
    String? paymentMethod,
    DateTime? createdAt,
    DateTime? estimatedDelivery,
    String? currency,
  }) {
    return Order(
      id: id ?? this.id,
      items: items ?? this.items,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      orderNumber: orderNumber ?? this.orderNumber,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      contact: contact ?? this.contact,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      currency: currency ?? this.currency,
    );
  }
}
