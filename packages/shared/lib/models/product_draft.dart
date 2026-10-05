import 'ids.dart';
import 'money.dart';

/// A seller's half finished product (spec 0015). It is a working copy the app
/// saves as the seller types, kept apart from the catalog. Publishing turns it
/// into a product (or, when [sourceProductId] is set, replaces that product's
/// fields) through the `save_product` function.
class ProductDraft {
  const ProductDraft({
    required this.id,
    required this.storeId,
    this.sourceProductId,
    this.step = 1,
    this.data = const ProductDraftData(),
    required this.updatedAt,
  });

  /// Made by the app. It becomes the product id when a new product is saved.
  final String id;
  final String storeId;

  /// Set when this draft is a working copy of a live product being edited.
  final String? sourceProductId;

  /// The step the seller was on, 1 to 3, so the draft reopens there.
  final int step;
  final ProductDraftData data;
  final DateTime updatedAt;

  bool get isEdit => sourceProductId != null;

  ProductDraft copyWith({
    int? step,
    ProductDraftData? data,
    DateTime? updatedAt,
  }) {
    return ProductDraft(
      id: id,
      storeId: storeId,
      sourceProductId: sourceProductId,
      step: step ?? this.step,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ProductDraft.fromJson(Map<String, dynamic> json) {
    return ProductDraft(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      sourceProductId: json['sourceProductId'] as String?,
      step: (json['step'] as num?)?.toInt() ?? 1,
      data: ProductDraftData.fromJson(
        json['payload'] as Map<String, dynamic>? ?? const {},
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeId': storeId,
      'sourceProductId': sourceProductId,
      'step': step,
      'payload': data.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// The payload saved in `product_drafts.payload`. The key names are the
/// contract with `save_product` in `supabase/migrations/0008_seller_products.sql`.
class ProductDraftData {
  const ProductDraftData({
    this.title = '',
    this.description = '',
    this.category = '',
    this.attributes = const {},
    this.originalPrice,
    this.photos = const [],
    this.variants = const [],
  });

  final String title;
  final String description;
  final String category;

  /// Optional specifications, e.g. `material`, `fit`, `sleeve_length`, `care`.
  final Map<String, String> attributes;

  /// The price before a discount, as text with up to 3 decimals. Optional.
  final String? originalPrice;

  /// Storage paths in the order shown, the first is the cover. The bucket name
  /// is not part of the path.
  final List<String> photos;
  final List<DraftVariant> variants;

  static const maxPhotos = 8;
  static const maxVariants = 100;

  /// True when the product has colors or sizes to choose from.
  bool get hasOptions =>
      variants.any((v) => v.colorValue != null || v.size != null);

  int get totalStock => variants.fold(0, (sum, v) => sum + v.stock);

  /// The lowest variant price that parses, or null when none does.
  double? get lowestPrice {
    double? lowest;
    for (final v in variants) {
      final p = Money.tryParse(v.price);
      if (p != null && p > 0 && (lowest == null || p < lowest)) lowest = p;
    }
    return lowest;
  }

  /// What is still missing before the product can be published. These use the
  /// same codes `save_product` answers with, so the screen shows one message
  /// per code whether the check ran here or on the server. The server stays
  /// the final judge.
  List<DraftIssue> issues() {
    final out = <DraftIssue>[];
    final t = title.trim();
    if (t.length < 2 || t.length > 100) out.add(const DraftIssue('bad_title'));
    if (category.isEmpty) out.add(const DraftIssue('bad_category'));
    if (photos.isEmpty) out.add(const DraftIssue('no_photo'));
    if (photos.length > maxPhotos) out.add(const DraftIssue('too_many_photos'));
    if (variants.isEmpty) {
      out.add(const DraftIssue('no_variants'));
    } else if (variants.length > maxVariants) {
      out.add(const DraftIssue('too_many_variants'));
    }
    final seen = <String>{};
    var duplicate = false;
    for (final v in variants) {
      final p = Money.tryParse(v.price);
      if (p == null || p <= 0) out.add(DraftIssue('missing_price', v.id));
      if (v.stock < 0) out.add(DraftIssue('bad_stock', v.id));
      if (!seen.add('${v.colorValue ?? -1}|${v.size?.trim() ?? ''}')) {
        duplicate = true;
      }
    }
    if (duplicate) out.add(const DraftIssue('duplicate_variant'));
    return out;
  }

  /// The starting point of "Create similar" (spec 0015, AC-14): the same
  /// words, details and variants with fresh ids, stock set to 0 and no photos
  /// (the new product has different pictures).
  ProductDraftData asSimilar() {
    return ProductDraftData(
      title: title,
      description: description,
      category: category,
      attributes: attributes,
      originalPrice: originalPrice,
      photos: const [],
      variants: [
        for (final v in variants)
          DraftVariant(
            id: newUuid(),
            colorName: v.colorName,
            colorValue: v.colorValue,
            size: v.size,
            price: v.price,
            stock: 0,
            stockSet: true,
            sku: v.sku,
          ),
      ],
    );
  }

  ProductDraftData copyWith({
    String? title,
    String? description,
    String? category,
    Map<String, String>? attributes,
    String? originalPrice,
    bool clearOriginalPrice = false,
    List<String>? photos,
    List<DraftVariant>? variants,
  }) {
    return ProductDraftData(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      attributes: attributes ?? this.attributes,
      originalPrice: clearOriginalPrice
          ? null
          : (originalPrice ?? this.originalPrice),
      photos: photos ?? this.photos,
      variants: variants ?? this.variants,
    );
  }

  factory ProductDraftData.fromJson(Map<String, dynamic> json) {
    return ProductDraftData(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      attributes: (json['attributes'] as Map<String, dynamic>? ?? const {}).map(
        (k, v) => MapEntry(k, v as String),
      ),
      originalPrice: json['originalPrice'] as String?,
      photos: (json['photos'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      variants: (json['variants'] as List<dynamic>? ?? const [])
          .map((e) => DraftVariant.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'attributes': attributes,
      'originalPrice': originalPrice,
      'photos': photos,
      'variants': variants.map((v) => v.toJson()).toList(),
    };
  }
}

/// One color and size row in a draft. [price] is text so no decimal drifts on
/// the way to the server. [stockSet] says the seller typed this stock on
/// purpose, so an edit of a live product overwrites the real stock only then.
class DraftVariant {
  const DraftVariant({
    required this.id,
    this.colorName,
    this.colorValue,
    this.size,
    this.price = '',
    this.stock = 0,
    this.stockSet = false,
    this.sku,
    this.imagePath,
  });

  final String id;
  final String? colorName;
  final int? colorValue;
  final String? size;
  final String price;
  final int stock;
  final bool stockSet;
  final String? sku;
  final String? imagePath;

  DraftVariant copyWith({
    String? price,
    int? stock,
    bool? stockSet,
    String? sku,
    String? imagePath,
    bool clearImagePath = false,
  }) {
    return DraftVariant(
      id: id,
      colorName: colorName,
      colorValue: colorValue,
      size: size,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      stockSet: stockSet ?? this.stockSet,
      sku: sku ?? this.sku,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
    );
  }

  factory DraftVariant.fromJson(Map<String, dynamic> json) {
    return DraftVariant(
      id: json['id'] as String,
      colorName: json['colorName'] as String?,
      colorValue: (json['colorValue'] as num?)?.toInt(),
      size: json['size'] as String?,
      price: json['price'] as String? ?? '',
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      stockSet: json['stockSet'] as bool? ?? false,
      sku: json['sku'] as String?,
      imagePath: json['imagePath'] as String?,
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
      'stockSet': stockSet,
      'sku': sku,
      'imagePath': imagePath,
    };
  }
}

/// One thing still to fix, with the variant it concerns when there is one.
class DraftIssue {
  const DraftIssue(this.code, [this.variantId]);
  final String code;
  final String? variantId;
}

/// A refusal from `save_product`, `set_product_archived` or
/// `update_variant_quick`. The server raises the code as the whole message,
/// with a variant id after a colon when one applies.
class SellerProductException implements Exception {
  const SellerProductException(this.code, [this.variantId]);

  final String code;
  final String? variantId;

  factory SellerProductException.fromMessage(String message) {
    final match = RegExp(r'([a-z_]+)(?::([0-9a-fA-F-]{36}))?').firstMatch(message);
    return SellerProductException(match?.group(1) ?? 'unknown', match?.group(2));
  }

  @override
  String toString() => 'SellerProductException($code, $variantId)';
}

/// What "Fill from photos" suggests (spec 0015, AC-13). Nothing here is saved
/// until the seller accepts it. [category] is empty when the model named one
/// that does not exist. [remaining] is how many runs the seller has left today.
class AutofillSuggestion {
  const AutofillSuggestion({
    required this.title,
    required this.description,
    required this.category,
    required this.colors,
    this.material,
    this.remaining,
  });

  final String title;
  final String description;
  final String category;
  final List<String> colors;
  final String? material;
  final int? remaining;

  factory AutofillSuggestion.fromJson(Map<String, dynamic> json) {
    return AutofillSuggestion(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      colors: (json['colors'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      material: json['material'] as String?,
      remaining: (json['remaining'] as num?)?.toInt(),
    );
  }
}
