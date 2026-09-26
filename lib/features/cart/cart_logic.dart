import '../../data/models/cart_item.dart';
import '../../data/models/product.dart';

/// Plain cart rules, kept free of Flutter and Riverpod so they are easy to
/// test (spec 0007). The repositories, the notifier and the screens all use
/// these, so the merge and clamp rules live in one place.

/// The most of one line a shopper can hold (spec 0007, AC-4).
const int maxCartQuantity = 99;

int clampQuantity(int quantity) => quantity.clamp(1, maxCartQuantity);

/// The sum of price times quantity over every line (AC-3).
double cartTotal(List<CartItem> items) =>
    items.fold(0, (sum, item) => sum + item.subtotal);

/// Whole dollar total, written like the app's prices: `$170`.
String cartTotalLabel(List<CartItem> items) =>
    '\$${cartTotal(items).toStringAsFixed(0)}';

/// Oldest added first (AC-2).
List<CartItem> sortedByAddedAt(List<CartItem> items) =>
    [...items]..sort((a, b) => a.addedAt.compareTo(b.addedAt));

/// The line for this product, size and colour, or null. Size and colour
/// compare as equal when both are empty (AC-13).
CartItem? findLine(
  List<CartItem> items,
  String productId,
  String? size,
  int? color,
) {
  for (final item in items) {
    if (item.product.id == productId &&
        item.selectedSize == size &&
        item.selectedColor == color) {
      return item;
    }
  }
  return null;
}

/// True when the cart holds any line of this product.
bool hasProduct(List<CartItem> items, String productId) =>
    items.any((item) => item.product.id == productId);

/// The variant a quick add picks (AC-11, AC-12).
String? firstSize(Product product) =>
    product.sizes.isEmpty ? null : product.sizes.first;

int? firstColor(Product product) =>
    product.colorOptions.isEmpty ? null : product.colorOptions.first;
