import '../models/cart_item.dart';
import '../models/order.dart';
import 'mock_products.dart';

/// A few mocked past orders, one per [OrderStatus].
final List<Order> mockOrders = [
  Order(
    id: 'order-001',
    items: [
      CartItem(
        id: 'order-001-item-001',
        product: mockProducts[12], // Cloud Paint Blush
        quantity: 2,
        addedAt: DateTime(2026, 6, 15),
      ),
      CartItem(
        id: 'order-001-item-002',
        product: mockProducts[13], // Boy Brow Eyebrow Gel
        addedAt: DateTime(2026, 6, 15),
      ),
    ],
    status: OrderStatus.delivered,
    totalAmount: 62,
    deliveryFee: 0,
    deliveryMethod: 'Standard delivery',
    shippingAddress: '13 Bahloul Street, Tunis, Tunisia',
    paymentMethod: 'Visa •••• 4242',
    createdAt: DateTime(2026, 6, 15),
    estimatedDelivery: DateTime(2026, 6, 18),
  ),
  Order(
    id: 'order-002',
    items: [
      CartItem(
        id: 'order-002-item-001',
        product: mockProducts[9], // Air Max 270 Sneakers
        selectedSize: '42',
        addedAt: DateTime(2026, 7, 2),
      ),
    ],
    status: OrderStatus.inProgress,
    totalAmount: 150,
    deliveryFee: 5,
    deliveryMethod: 'Express delivery',
    shippingAddress: '13 Bahloul Street, Tunis, Tunisia',
    paymentMethod: 'Visa •••• 4242',
    createdAt: DateTime(2026, 7, 2),
    estimatedDelivery: DateTime(2026, 7, 10),
  ),
  Order(
    id: 'order-003',
    items: [
      CartItem(
        id: 'order-003-item-001',
        product: mockProducts[3], // Graphic Print Hoodie
        selectedSize: 'L',
        addedAt: DateTime(2026, 6, 25),
      ),
    ],
    status: OrderStatus.canceled,
    totalAmount: 42,
    deliveryFee: 0,
    deliveryMethod: 'Standard delivery',
    shippingAddress: '13 Bahloul Street, Tunis, Tunisia',
    paymentMethod: 'Cash on delivery',
    createdAt: DateTime(2026, 6, 25),
  ),
];
