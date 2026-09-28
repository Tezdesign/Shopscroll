import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/mock/mock_cart_items.dart';
import 'package:marketplace_app/data/models/cart_item.dart';
import 'package:marketplace_app/data/models/contact_info.dart';
import 'package:marketplace_app/data/models/order.dart';
import 'package:marketplace_app/data/models/place_order_request.dart';
import 'package:marketplace_app/data/models/product.dart';
import 'package:marketplace_app/data/models/shipping_address.dart';
import 'package:marketplace_app/data/repositories/mock/mock_cart_repository.dart';
import 'package:marketplace_app/data/repositories/mock/mock_order_repository.dart';
import 'package:marketplace_app/data/repositories/order_repository.dart';
import 'package:marketplace_app/features/cart/cart_logic.dart';

/// A cart holding these lines and nothing else.
class _CartWith extends MockCartRepository {
  _CartWith(this.lines);

  final List<CartItem> lines;
  final removed = <String>[];

  @override
  Future<List<CartItem>> getCartItems() async => List.of(lines);

  @override
  Future<void> removeItem(String itemId) async {
    removed.add(itemId);
    lines.removeWhere((line) => line.id == itemId);
  }
}

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
    note: 'Next to the bank',
  );

  PlaceOrderRequest request(
    double subtotal, {
    String id = 'order-a',
    DeliveryMethod method = DeliveryMethod.standard,
    PaymentMethod payment = PaymentMethod.cashOnDelivery,
    ContactInfo? who,
  }) => PlaceOrderRequest(
    orderId: id,
    contact: who ?? contact,
    address: address,
    deliveryMethod: method,
    paymentMethod: payment,
    expectedSubtotal: subtotal,
  );

  Future<void> expectRefused(
    Future<Order> call,
    PlaceOrderFailure reason,
  ) async {
    await expectLater(
      call,
      throwsA(
        isA<PlaceOrderException>().having((e) => e.reason, 'reason', reason),
      ),
    );
  }

  test('placeOrder builds one priced order from the whole cart (AC-12, '
      'AC-15, AC-16)', () async {
    final cart = _CartWith(List.of(mockCartItems));
    final repo = MockOrderRepository(cart: cart);
    final subtotal = cartTotal(mockCartItems);

    final order = await repo.placeOrder(request(subtotal));

    expect(order.id, 'order-a');
    expect(order.status, OrderStatus.inProgress);
    expect(order.orderNumber, 1);
    expect(order.subtotal, subtotal);
    expect(order.deliveryFee, 10);
    expect(order.totalAmount, subtotal + 10);
    expect(order.deliveryMethod, 'standard');
    expect(order.paymentMethod, 'cashOnDelivery');
    expect(order.contact, contact);
    expect(order.shippingAddress, address);
    expect(order.items, hasLength(mockCartItems.length));
    expect(order.estimatedDelivery, isNotNull);

    // The cart is emptied, and the order is listed first.
    expect(cart.lines, isEmpty);
    final orders = await repo.getOrders();
    expect(orders.first.id, 'order-a');
    expect((await repo.getOrderById('order-a'))?.orderNumber, 1);
  });

  test('exclusive delivery charges its own fee', () async {
    final repo = MockOrderRepository(cart: _CartWith(List.of(mockCartItems)));
    final order = await repo.placeOrder(
      request(cartTotal(mockCartItems), method: DeliveryMethod.exclusive),
    );

    expect(order.deliveryFee, 16);
    expect(order.totalAmount, cartTotal(mockCartItems) + 16);
  });

  test(
    'the same order id returns the same order and makes one (AC-12)',
    () async {
      final cart = _CartWith(List.of(mockCartItems));
      final repo = MockOrderRepository(cart: cart);
      final subtotal = cartTotal(mockCartItems);

      final first = await repo.placeOrder(request(subtotal));
      final again = await repo.placeOrder(request(subtotal));

      expect(again, same(first));
      final seeded = (await MockOrderRepository().getOrders()).length;
      expect((await repo.getOrders()).length, seeded + 1);
    },
  );

  test('order numbers count up', () async {
    final repo = MockOrderRepository(cart: _CartWith(List.of(mockCartItems)));
    final first = await repo.placeOrder(request(cartTotal(mockCartItems)));

    final cart = _CartWith(List.of(mockCartItems));
    final other = MockOrderRepository(cart: cart);
    await other.placeOrder(request(cartTotal(mockCartItems), id: 'x'));
    cart.lines.addAll(mockCartItems);
    final second = await other.placeOrder(
      request(cartTotal(mockCartItems), id: 'y'),
    );

    expect(first.orderNumber, 1);
    expect(second.orderNumber, 2);
  });

  test('an empty cart, or no cart, is refused (AC-21)', () async {
    await expectRefused(
      MockOrderRepository(cart: _CartWith([])).placeOrder(request(10)),
      PlaceOrderFailure.cartEmpty,
    );
    await expectRefused(
      MockOrderRepository().placeOrder(request(10)),
      PlaceOrderFailure.cartEmpty,
    );
  });

  test('a subtotal different from the shown one is refused and nothing '
      'changes (AC-13, AC-21)', () async {
    final cart = _CartWith(List.of(mockCartItems));
    final repo = MockOrderRepository(cart: cart);

    await expectRefused(
      repo.placeOrder(request(cartTotal(mockCartItems) + 1)),
      PlaceOrderFailure.itemsChanged,
    );

    expect(cart.removed, isEmpty);
    expect(cart.lines, hasLength(mockCartItems.length));
  });

  test('a product that is out of stock is refused (AC-13, AC-21)', () async {
    final soldOut = CartItem(
      id: 'gone',
      addedAt: DateTime(2026, 7, 1),
      product: Product(
        id: 'p-gone',
        title: 'Sold out',
        description: '',
        price: 10,
        category: 'Fashion',
        storeId: 's',
        storeName: 's',
        inStock: false,
        createdAt: DateTime(2026, 7, 1),
      ),
    );
    final cart = _CartWith([soldOut]);

    await expectRefused(
      MockOrderRepository(cart: cart).placeOrder(request(10)),
      PlaceOrderFailure.itemsChanged,
    );
    expect(cart.lines, hasLength(1));
  });

  test('bad fields and the card method are refused (AC-21)', () async {
    final subtotal = cartTotal(mockCartItems);
    Future<Order> withCart(PlaceOrderRequest r) => MockOrderRepository(
      cart: _CartWith(List.of(mockCartItems)),
    ).placeOrder(r);

    await expectRefused(
      withCart(request(subtotal, who: contact.copyWith(email: 'nope'))),
      PlaceOrderFailure.invalid,
    );
    await expectRefused(
      withCart(request(subtotal, payment: PaymentMethod.card)),
      PlaceOrderFailure.invalid,
    );
  });
}
