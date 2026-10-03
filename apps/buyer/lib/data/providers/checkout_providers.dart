import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/checkout/checkout_logic.dart';
import 'package:shopscroll_shared/models/contact_info.dart';
import '../models/place_order_request.dart';
import 'package:shopscroll_shared/models/shipping_address.dart';

/// What the buyer has entered or chosen on the Checkout page so far. Held in
/// memory only (spec 0009: nothing persists beyond the order).
class CheckoutDraft {
  const CheckoutDraft({
    this.contact,
    this.address,
    this.deliveryMethod,
    this.paymentMethod,
    this.touched = false,
  });

  final ContactInfo? contact;
  final ShippingAddress? address;
  final DeliveryMethod? deliveryMethod;
  final PaymentMethod? paymentMethod;

  /// True once the buyer typed or chose something. A contact filled in from
  /// their profile does not count, so the X does not ask about it (AC-14).
  final bool touched;

  /// Place order is enabled only when all four parts are set (AC-10).
  bool get isComplete =>
      contact != null &&
      address != null &&
      deliveryMethod != null &&
      paymentMethod != null;

  CheckoutDraft copyWith({
    ContactInfo? contact,
    ShippingAddress? address,
    DeliveryMethod? deliveryMethod,
    PaymentMethod? paymentMethod,
    bool? touched,
  }) {
    return CheckoutDraft(
      contact: contact ?? this.contact,
      address: address ?? this.address,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      touched: touched ?? this.touched,
    );
  }
}

/// The Checkout draft. Auto disposed, so leaving the flow forgets it and the
/// next checkout starts clean with a new [orderId].
final checkoutDraftProvider =
    NotifierProvider.autoDispose<CheckoutDraftNotifier, CheckoutDraft>(
      CheckoutDraftNotifier.new,
    );

class CheckoutDraftNotifier extends Notifier<CheckoutDraft> {
  /// Made once per checkout, so sending the order twice makes one (AC-12).
  final String orderId = newOrderId();

  @override
  CheckoutDraft build() => const CheckoutDraft();

  /// Fills the contact from the signed in profile, unless the buyer already
  /// typed one.
  void prefillContact(ContactInfo contact) {
    if (state.contact == null) state = state.copyWith(contact: contact);
  }

  void setContact(ContactInfo contact) =>
      state = state.copyWith(contact: contact, touched: true);

  void setAddress(ShippingAddress address) =>
      state = state.copyWith(address: address, touched: true);

  void setDeliveryMethod(DeliveryMethod method) =>
      state = state.copyWith(deliveryMethod: method, touched: true);

  void setPaymentMethod(PaymentMethod method) =>
      state = state.copyWith(paymentMethod: method, touched: true);
}
