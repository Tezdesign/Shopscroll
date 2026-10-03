import '../../../features/cart/cart_logic.dart';
import '../../../features/checkout/checkout_logic.dart';
import '../../mock/mock_orders.dart';
import '../../models/cart_item.dart';
import '../../models/order.dart';
import '../../models/place_order_request.dart';
import '../../providers/network_delay.dart';
import '../cart_repository.dart';
import '../order_repository.dart';

/// Keeps its own in memory copy of [mockOrders], so a placed order lasts for
/// the run of the app and never leaks into the shared seed list. [cart] is
/// the cart the order is built from, without it every order is refused as an
/// empty cart.
class MockOrderRepository implements OrderRepository {
  // A named parameter cannot start with an underscore, so no `this._cart`.
  // ignore: prefer_initializing_formals
  MockOrderRepository({CartRepository? cart}) : _cart = cart;

  final CartRepository? _cart;
  final List<Order> _orders = List.of(mockOrders);
  int _nextNumber = 1;

  @override
  Future<List<Order>> getOrders() async {
    await Future.delayed(mockNetworkDelay);
    return List.of(_orders);
  }

  @override
  Future<Order?> getOrderById(String id) async {
    await Future.delayed(mockNetworkDelay);
    for (final order in _orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  @override
  Future<Order> placeOrder(PlaceOrderRequest request) async {
    await Future.delayed(mockNetworkDelay);

    for (final order in _orders) {
      if (order.id == request.orderId) return order;
    }
    // Same refusals as the `place_order` SQL function: bad fields, a payment
    // method that cannot place an order yet, an empty cart, an item out of
    // stock, or a subtotal that is not the one Checkout showed.
    if (!isContactValid(request.contact) ||
        !isAddressValid(request.address) ||
        request.paymentMethod != PaymentMethod.cashOnDelivery) {
      throw const PlaceOrderException(PlaceOrderFailure.invalid);
    }
    final cart = _cart;
    final lines = cart == null ? <CartItem>[] : await cart.getCartItems();
    if (lines.isEmpty) {
      throw const PlaceOrderException(PlaceOrderFailure.cartEmpty);
    }
    final subtotal = cartTotal(lines);
    if (lines.any((line) => !line.product.inStock) ||
        (subtotal - request.expectedSubtotal).abs() > 0.005) {
      throw const PlaceOrderException(PlaceOrderFailure.itemsChanged);
    }

    final now = DateTime.now();
    final method = request.deliveryMethod;
    final order = Order(
      id: request.orderId,
      items: [
        for (var i = 0; i < lines.length; i++)
          lines[i].copyWith(id: '${request.orderId}-item-$i', addedAt: now),
      ],
      status: OrderStatus.inProgress,
      totalAmount: orderTotal(subtotal, method.fee),
      orderNumber: _nextNumber++,
      subtotal: subtotal,
      deliveryFee: method.fee,
      deliveryMethod: method.name,
      contact: request.contact,
      shippingAddress: request.address,
      paymentMethod: request.paymentMethod.name,
      createdAt: now,
      estimatedDelivery: arrivalDate(now, method.workingDays),
    );
    _orders.insert(0, order);
    for (final line in lines) {
      await cart!.removeItem(line.id);
    }
    return order;
  }
}
