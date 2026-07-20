import '../models/cart_item.dart';
import 'mock_products.dart';

/// A handful of mocked cart items, built from [mockProducts].
final List<CartItem> mockCartItems = [
  CartItem(
    id: 'cart-item-001',
    product: mockProducts[0], // Oversized Blazer Dress
    quantity: 1,
    selectedSize: 'M',
    selectedColor: 0xFF0066FF,
    addedAt: DateTime(2026, 7, 5),
  ),
  CartItem(
    id: 'cart-item-002',
    product: mockProducts[9], // Air Max 270 Sneakers
    quantity: 1,
    selectedSize: '42',
    selectedColor: 0xFF000000,
    addedAt: DateTime(2026, 7, 6),
  ),
  CartItem(
    id: 'cart-item-003',
    product: mockProducts[6], // iPhone 15 Pro Silicone Case
    quantity: 2,
    selectedColor: 0xFFFEFEFE,
    addedAt: DateTime(2026, 7, 7),
  ),
];
