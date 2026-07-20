import 'cart_item.dart';

/// Also the single source of truth for `OrderStatusBadge`'s three visual
/// states (see lib/shared/widgets/order_status_badge.dart).
enum OrderStatus { delivered, inProgress, canceled }

class Order {
  const Order({
    required this.id,
    required this.items,
    required this.status,
    required this.totalAmount,
    this.deliveryFee,
    this.deliveryMethod,
    this.shippingAddress,
    this.paymentMethod,
    required this.createdAt,
    this.estimatedDelivery,
  });

  final String id;
  final List<CartItem> items;
  final OrderStatus status;
  final double totalAmount;
  final double? deliveryFee;
  final String? deliveryMethod;
  final String? shippingAddress;
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime? estimatedDelivery;

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: OrderStatus.values.byName(json['status'] as String),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
      deliveryMethod: json['deliveryMethod'] as String?,
      shippingAddress: json['shippingAddress'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      estimatedDelivery: json['estimatedDelivery'] != null
          ? DateTime.parse(json['estimatedDelivery'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((e) => e.toJson()).toList(),
      'status': status.name,
      'totalAmount': totalAmount,
      'deliveryFee': deliveryFee,
      'deliveryMethod': deliveryMethod,
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt.toIso8601String(),
      'estimatedDelivery': estimatedDelivery?.toIso8601String(),
    };
  }

  Order copyWith({
    String? id,
    List<CartItem>? items,
    OrderStatus? status,
    double? totalAmount,
    double? deliveryFee,
    String? deliveryMethod,
    String? shippingAddress,
    String? paymentMethod,
    DateTime? createdAt,
    DateTime? estimatedDelivery,
  }) {
    return Order(
      id: id ?? this.id,
      items: items ?? this.items,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
    );
  }
}

