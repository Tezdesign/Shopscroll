/// The store-wide delivery, payment and returns defaults every product
/// inherits unless it sets its own exception (Figma: Store policies-seller,
/// node 5599:3306).
class StorePolicies {
  const StorePolicies({
    required this.deliveryArea,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.paymentMethod,
    required this.paymentMessage,
    required this.returnWindowDays,
    required this.returnCondition,
    required this.returnShipping,
    required this.refundMethod,
    this.freeDeliveryOver,
    this.maxCodOrder,
    this.currency = 'TND',
  });

  final String deliveryArea;
  final String deliveryTime;
  final double deliveryFee;

  /// Orders above this amount ship free. Null means the fee is always charged.
  final double? freeDeliveryOver;
  final String paymentMethod;
  final String paymentMessage;

  /// Largest order accepted as cash on delivery. Null means no limit.
  final double? maxCodOrder;
  final int returnWindowDays;
  final String returnCondition;
  final String returnShipping;
  final String refundMethod;
  final String currency;

  StorePolicies copyWith({
    String? deliveryArea,
    String? deliveryTime,
    double? deliveryFee,
    double? Function()? freeDeliveryOver,
    String? paymentMethod,
    String? paymentMessage,
    double? Function()? maxCodOrder,
    int? returnWindowDays,
    String? returnCondition,
    String? returnShipping,
    String? refundMethod,
  }) => StorePolicies(
    deliveryArea: deliveryArea ?? this.deliveryArea,
    deliveryTime: deliveryTime ?? this.deliveryTime,
    deliveryFee: deliveryFee ?? this.deliveryFee,
    freeDeliveryOver: freeDeliveryOver != null
        ? freeDeliveryOver()
        : this.freeDeliveryOver,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    paymentMessage: paymentMessage ?? this.paymentMessage,
    maxCodOrder: maxCodOrder != null ? maxCodOrder() : this.maxCodOrder,
    returnWindowDays: returnWindowDays ?? this.returnWindowDays,
    returnCondition: returnCondition ?? this.returnCondition,
    returnShipping: returnShipping ?? this.returnShipping,
    refundMethod: refundMethod ?? this.refundMethod,
    currency: currency,
  );

  factory StorePolicies.fromJson(Map<String, dynamic> json) => StorePolicies(
    deliveryArea: json['deliveryArea'] as String,
    deliveryTime: json['deliveryTime'] as String,
    deliveryFee: (json['deliveryFee'] as num).toDouble(),
    freeDeliveryOver: (json['freeDeliveryOver'] as num?)?.toDouble(),
    paymentMethod: json['paymentMethod'] as String,
    paymentMessage: json['paymentMessage'] as String,
    maxCodOrder: (json['maxCodOrder'] as num?)?.toDouble(),
    returnWindowDays: json['returnWindowDays'] as int,
    returnCondition: json['returnCondition'] as String,
    returnShipping: json['returnShipping'] as String,
    refundMethod: json['refundMethod'] as String,
    currency: json['currency'] as String? ?? 'TND',
  );

  Map<String, dynamic> toJson() => {
    'deliveryArea': deliveryArea,
    'deliveryTime': deliveryTime,
    'deliveryFee': deliveryFee,
    'freeDeliveryOver': freeDeliveryOver,
    'paymentMethod': paymentMethod,
    'paymentMessage': paymentMessage,
    'maxCodOrder': maxCodOrder,
    'returnWindowDays': returnWindowDays,
    'returnCondition': returnCondition,
    'returnShipping': returnShipping,
    'refundMethod': refundMethod,
    'currency': currency,
  };
}
