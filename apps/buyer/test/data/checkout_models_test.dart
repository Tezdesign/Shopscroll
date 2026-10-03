import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/mock/mock_orders.dart';
import 'package:shopscroll_shared/models/contact_info.dart';
import 'package:marketplace_app/data/models/order.dart';
import 'package:marketplace_app/data/models/place_order_request.dart';
import 'package:shopscroll_shared/models/shipping_address.dart';

void main() {
  const contact = ContactInfo(
    name: 'Sara Ben Ali',
    email: 'sara@example.com',
    phone: '+21650460604',
  );
  const address = ShippingAddress(
    city: 'Tunis',
    address: '13 Bahloul Street',
    zip: '1000',
    note: 'Ring twice',
  );

  test('ContactInfo round trips through json and copyWith', () {
    expect(ContactInfo.fromJson(contact.toJson()), contact);
    expect(contact.copyWith(email: 'x@y.co').email, 'x@y.co');
    expect(contact.copyWith(email: 'x@y.co').name, contact.name);
    expect(contact.hashCode, ContactInfo.fromJson(contact.toJson()).hashCode);
  });

  test('ShippingAddress defaults to Tunisia and prints one line', () {
    expect(address.country, 'Tunisia');
    expect(address.line, '13 Bahloul Street, Tunis, 1000');
    expect(ShippingAddress.fromJson(address.toJson()), address);
    // An older json with no country or note still reads.
    final plain = ShippingAddress.fromJson({
      'city': 'Tunis',
      'address': 'a',
      'zip': '1000',
    });
    expect(plain.country, 'Tunisia');
    expect(plain.note, '');
    expect(address.copyWith(zip: '2000').zip, '2000');
  });

  test('PlaceOrderRequest round trips through json', () {
    const request = PlaceOrderRequest(
      orderId: 'id-1',
      contact: contact,
      address: address,
      deliveryMethod: DeliveryMethod.exclusive,
      paymentMethod: PaymentMethod.cashOnDelivery,
      expectedSubtotal: 45,
    );

    final again = PlaceOrderRequest.fromJson(request.toJson());

    expect(again.orderId, 'id-1');
    expect(again.contact, contact);
    expect(again.address, address);
    expect(again.deliveryMethod, DeliveryMethod.exclusive);
    expect(again.paymentMethod, PaymentMethod.cashOnDelivery);
    expect(again.expectedSubtotal, 45);
    expect(request.copyWith(orderId: 'id-2').orderId, 'id-2');
  });

  test('Order carries the new fields through json and copyWith', () {
    final order = mockOrders.first.copyWith(
      orderNumber: 3,
      subtotal: 52,
      contact: contact,
      shippingAddress: address,
    );

    final again = Order.fromJson(order.toJson());

    expect(again.orderNumber, 3);
    expect(again.subtotal, 52);
    expect(again.contact, contact);
    expect(again.shippingAddress, address);
    expect(again.id, order.id);
  });

  test('an older Order json without the new fields still reads', () {
    final json = mockOrders.first.toJson()
      ..remove('orderNumber')
      ..remove('subtotal')
      ..remove('contact');
    final order = Order.fromJson(json);

    expect(order.orderNumber, isNull);
    expect(order.subtotal, isNull);
    expect(order.contact, isNull);
  });
}
