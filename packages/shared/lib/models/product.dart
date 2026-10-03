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

  /// Whole-dollar display string, e.g. "$40".
  String get priceLabel => '\$${price.toStringAsFixed(0)}';

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
    );
  }
}
