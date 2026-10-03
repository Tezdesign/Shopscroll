import '../../../features/cart/cart_logic.dart';
import '../../mock/mock_cart_items.dart';
import '../../models/cart_item.dart';
import 'package:shopscroll_shared/models/product.dart';
import '../../providers/network_delay.dart';
import '../cart_repository.dart';

/// Keeps its own in memory copy of [mockCartItems], so writes last for the
/// run of the app and never leak into the shared seed list other tests read.
class MockCartRepository implements CartRepository {
  final List<CartItem> _items = List.of(mockCartItems);
  int _nextId = 1;

  @override
  Future<List<CartItem>> getCartItems() async {
    await Future.delayed(mockNetworkDelay);
    return List.of(_items);
  }

  @override
  Future<CartItem> addItem(
    Product product,
    int quantity, {
    String? size,
    int? color,
  }) async {
    await Future.delayed(mockNetworkDelay);
    final existing = findLine(_items, product.id, size, color);
    if (existing != null) {
      return _replace(
        existing,
        existing.copyWith(
          quantity: clampQuantity(existing.quantity + quantity),
        ),
      );
    }
    final item = CartItem(
      id: 'mock-cart-item-${_nextId++}',
      product: product,
      quantity: clampQuantity(quantity),
      selectedSize: size,
      selectedColor: color,
      addedAt: DateTime.now(),
    );
    _items.add(item);
    return item;
  }

  @override
  Future<CartItem> setQuantity(String itemId, int quantity) async {
    await Future.delayed(mockNetworkDelay);
    final existing = _items.firstWhere(
      (item) => item.id == itemId,
      orElse: () => throw StateError('No cart line $itemId'),
    );
    return _replace(
      existing,
      existing.copyWith(quantity: clampQuantity(quantity)),
    );
  }

  @override
  Future<void> removeItem(String itemId) async {
    await Future.delayed(mockNetworkDelay);
    _items.removeWhere((item) => item.id == itemId);
  }

  CartItem _replace(CartItem old, CartItem updated) {
    _items[_items.indexOf(old)] = updated;
    return updated;
  }
}
