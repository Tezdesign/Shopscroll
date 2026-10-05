/// One sellable combination of a product: a color and a size with its own
/// price and stock (spec 0015). A product without options has one variant
/// with no color and no size.
class ProductVariant {
  const ProductVariant({
    required this.id,
    this.colorName,
    this.colorValue,
    this.size,
    required this.price,
    this.stock = 0,
    this.sku,
    this.imagePath,
    this.position = 0,
  });

  final String id;
  final String? colorName;

  /// ARGB int, same form as [Product.colorOptions].
  final int? colorValue;
  final String? size;
  final double price;
  final int stock;
  final String? sku;

  /// One of the product's photo paths (the bucket name is not part of it).
  final String? imagePath;
  final int position;

  bool get inStock => stock > 0;

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      colorName: json['colorName'] as String?,
      colorValue: (json['colorValue'] as num?)?.toInt(),
      size: json['size'] as String?,
      price: (json['price'] as num).toDouble(),
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      sku: json['sku'] as String?,
      imagePath: json['imagePath'] as String?,
      position: (json['position'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'colorName': colorName,
      'colorValue': colorValue,
      'size': size,
      'price': price,
      'stock': stock,
      'sku': sku,
      'imagePath': imagePath,
      'position': position,
    };
  }

  ProductVariant copyWith({
    String? id,
    String? colorName,
    int? colorValue,
    String? size,
    double? price,
    int? stock,
    String? sku,
    String? imagePath,
    int? position,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      colorName: colorName ?? this.colorName,
      colorValue: colorValue ?? this.colorValue,
      size: size ?? this.size,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      sku: sku ?? this.sku,
      imagePath: imagePath ?? this.imagePath,
      position: position ?? this.position,
    );
  }
}
