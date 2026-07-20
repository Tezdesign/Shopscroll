import 'product.dart';

/// A product placed in the buyer's cart, with the chosen quantity/variant.
class CartItem {
  const CartItem({
    required this.id,
    required this.product,
    this.quantity = 1,
    this.selectedSize,
    this.selectedColor,
    required this.addedAt,
  });

  final String id;
  final Product product;
  final int quantity;
  final String? selectedSize;

  /// ARGB int, see [Color.new].
  final int? selectedColor;

  final DateTime addedAt;

  double get subtotal => product.price * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: json['quantity'] as int? ?? 1,
      selectedSize: json['selectedSize'] as String?,
      selectedColor: json['selectedColor'] as int?,
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product.toJson(),
      'quantity': quantity,
      'selectedSize': selectedSize,
      'selectedColor': selectedColor,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  CartItem copyWith({
    String? id,
    Product? product,
    int? quantity,
    String? selectedSize,
    int? selectedColor,
    DateTime? addedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedSize: selectedSize ?? this.selectedSize,
      selectedColor: selectedColor ?? this.selectedColor,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
