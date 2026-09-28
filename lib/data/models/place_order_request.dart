import 'contact_info.dart';
import 'shipping_address.dart';

/// How fast the order arrives (spec 0009, AC-7). The fees and days are
/// placeholders the owner will change. The same numbers live in the
/// `place_order` SQL function, which is the truth, this copy is for display.
enum DeliveryMethod {
  standard(fee: 10, workingDays: 6),
  exclusive(fee: 16, workingDays: 2);

  const DeliveryMethod({required this.fee, required this.workingDays});

  final double fee;

  /// Working days (Saturday and Sunday skipped) until the order arrives.
  final int workingDays;
}

/// How the buyer pays. Only [cashOnDelivery] can place an order in spec 0009,
/// [card] is drawn on the screen and comes with its own spec.
enum PaymentMethod { cashOnDelivery, card }

/// What `POST /orders` carries: everything except prices. The server reads
/// the buyer's own cart and prices it, [expectedSubtotal] is only what
/// Checkout showed, so a changed price is caught instead of charged.
/// [orderId] is made once per checkout, so a repeat call returns the same
/// order (spec 0009, AC-12).
class PlaceOrderRequest {
  const PlaceOrderRequest({
    required this.orderId,
    required this.contact,
    required this.address,
    required this.deliveryMethod,
    required this.paymentMethod,
    required this.expectedSubtotal,
  });

  final String orderId;
  final ContactInfo contact;
  final ShippingAddress address;
  final DeliveryMethod deliveryMethod;
  final PaymentMethod paymentMethod;
  final double expectedSubtotal;

  factory PlaceOrderRequest.fromJson(Map<String, dynamic> json) {
    return PlaceOrderRequest(
      orderId: json['orderId'] as String,
      contact: ContactInfo.fromJson(json['contact'] as Map<String, dynamic>),
      address: ShippingAddress.fromJson(
        json['address'] as Map<String, dynamic>,
      ),
      deliveryMethod: DeliveryMethod.values.byName(
        json['deliveryMethod'] as String,
      ),
      paymentMethod: PaymentMethod.values.byName(
        json['paymentMethod'] as String,
      ),
      expectedSubtotal: (json['expectedSubtotal'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'contact': contact.toJson(),
    'address': address.toJson(),
    'deliveryMethod': deliveryMethod.name,
    'paymentMethod': paymentMethod.name,
    'expectedSubtotal': expectedSubtotal,
  };

  PlaceOrderRequest copyWith({
    String? orderId,
    ContactInfo? contact,
    ShippingAddress? address,
    DeliveryMethod? deliveryMethod,
    PaymentMethod? paymentMethod,
    double? expectedSubtotal,
  }) {
    return PlaceOrderRequest(
      orderId: orderId ?? this.orderId,
      contact: contact ?? this.contact,
      address: address ?? this.address,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      expectedSubtotal: expectedSubtotal ?? this.expectedSubtotal,
    );
  }
}
