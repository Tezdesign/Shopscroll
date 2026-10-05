import 'money.dart';
import 'product_variant.dart';

/// Whether shoppers can see a product. A draft is not a product, it lives in
/// `ProductDraft` until it is published (spec 0015).
enum ProductStatus { live, archived }

/// A product listed by a seller/store.
class Product {
  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.category,
    required this.storeId,
    required this.storeName,
    this.storeAvatarUrl,
    this.imageUrl,
    this.imageUrls = const [],
    this.colorOptions = const [],
    this.sizes = const [],
    this.isDeal = false,
    this.inStock = true,
    this.rating,
    this.reviewCount = 0,
    required this.createdAt,
    this.currency = 'USD',
    this.status = ProductStatus.live,
    this.attributes = const {},
    this.variants = const [],
  });

  final String id;

  /// Short product name, e.g. "Oversized Blazer Dress".
  final String title;

  /// Longer copy shown on the product details screen.
  final String description;

  final double price;

  /// Original (pre-discount) price, set when [isDeal] is true.
  final double? originalPrice;

  final String category;
  final String storeId;
  final String storeName;
  final String? storeAvatarUrl;
  final String? imageUrl;
  final List<String> imageUrls;

  /// Color-variant swatches, as ARGB ints (see [Color.new]).
  final List<int> colorOptions;

  final List<String> sizes;
  final bool isDeal;
  final bool inStock;
  final double? rating;
  final int reviewCount;
  final DateTime createdAt;

  /// ISO code of the store's currency. Real rows always carry their own; the
  /// default is the currency of the mock catalog.
  final String currency;
  final ProductStatus status;

  /// Optional specifications such as material, fit and care (spec 0015).
  final Map<String, String> attributes;

  /// The sellable combinations. Empty when the row was read without them (a
  /// list screen) or for an older mock product.
  final List<ProductVariant> variants;

  /// Display string in the product's currency, e.g. "$40" or "89.000 TND".
  /// [price] is the lowest variant price when variants exist.
  String get priceLabel => Money.format(price, currency);

  /// The variant a shopper picked, or null when none matches (or the product
  /// has no variant rows). Mirrors how `place_order` finds a cart line's
  /// variant: same color and same size, a missing choice matches a missing
  /// option.
  ProductVariant? variantFor({int? color, String? size}) {
    for (final v in variants) {
      if (v.colorValue == color && v.size == size) return v;
    }
    return null;
  }

  /// The price of the picked variant, or [price] when there is none.
  double priceFor({int? color, String? size}) =>
      variantFor(color: color, size: size)?.price ?? price;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      originalPrice: (json['originalPrice'] as num?)?.toDouble(),
      category: json['category'] as String,
      storeId: json['storeId'] as String,
      storeName: json['storeName'] as String,
      storeAvatarUrl: json['storeAvatarUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      imageUrls: (json['imageUrls'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      colorOptions: (json['colorOptions'] as List<dynamic>? ?? const [])
          .map((e) => e as int)
          .toList(),
      sizes: (json['sizes'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      isDeal: json['isDeal'] as bool? ?? false,
      inStock: json['inStock'] as bool? ?? true,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: json['reviewCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      currency: json['currency'] as String? ?? 'USD',
      status: ProductStatus.values.byName(json['status'] as String? ?? 'live'),
      attributes: (json['attributes'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, v as String)),
      variants: (json['variants'] as List<dynamic>? ?? const [])
          .map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'category': category,
      'storeId': storeId,
      'storeName': storeName,
      'storeAvatarUrl': storeAvatarUrl,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'colorOptions': colorOptions,
      'sizes': sizes,
      'isDeal': isDeal,
      'inStock': inStock,
      'rating': rating,
      'reviewCount': reviewCount,
      'createdAt': createdAt.toIso8601String(),
      'currency': currency,
      'status': status.name,
      'attributes': attributes,
      'variants': variants.map((v) => v.toJson()).toList(),
    };
  }

  Product copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    double? originalPrice,
    String? category,
    String? storeId,
    String? storeName,
    String? storeAvatarUrl,
    String? imageUrl,
    List<String>? imageUrls,
    List<int>? colorOptions,
    List<String>? sizes,
    bool? isDeal,
    bool? inStock,
    double? rating,
    int? reviewCount,
    DateTime? createdAt,
    String? currency,
    ProductStatus? status,
    Map<String, String>? attributes,
    List<ProductVariant>? variants,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      category: category ?? this.category,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      storeAvatarUrl: storeAvatarUrl ?? this.storeAvatarUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      colorOptions: colorOptions ?? this.colorOptions,
      sizes: sizes ?? this.sizes,
      isDeal: isDeal ?? this.isDeal,
      inStock: inStock ?? this.inStock,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt ?? this.createdAt,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      attributes: attributes ?? this.attributes,
      variants: variants ?? this.variants,
    );
  }
}
