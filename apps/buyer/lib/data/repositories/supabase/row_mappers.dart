import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/product_variant.dart';
import 'package:shopscroll_shared/models/seller_application.dart';
import 'package:shopscroll_shared/models/user_profile.dart';

import '../../../core/config/supabase_config.dart';

/// The select that reads a product with its variants, for screens that need
/// the price and stock of a color and size (product page, cart).
const productWithVariantsSelect = '*, variants:product_variants(*)';

/// Maps a `product_variants` row to [ProductVariant].
ProductVariant variantFromRow(Map<String, dynamic> row) {
  return ProductVariant(
    id: row['id'] as String,
    colorName: row['color_name'] as String?,
    colorValue: (row['color_value'] as num?)?.toInt(),
    size: row['size'] as String?,
    price: (row['price'] as num).toDouble(),
    stock: (row['stock'] as num?)?.toInt() ?? 0,
    sku: row['sku'] as String?,
    imagePath: row['image_path'] as String?,
    position: (row['position'] as num?)?.toInt() ?? 0,
  );
}

/// Maps a `products` row (snake_case Postgres columns) to [Product]. Shared
/// by every Supabase repository that embeds a product (catalog reads, cart).
/// Reads `variants` when the row was selected with
/// [productWithVariantsSelect]. [projectUrl] is only for tests.
Product productFromRow(
  Map<String, dynamic> row, {
  String projectUrl = SupabaseConfig.url,
}) {
  final variants =
      (row['variants'] as List<dynamic>? ?? const [])
          .map((e) => variantFromRow(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
  return Product(
    id: row['id'] as String,
    title: row['title'] as String,
    description: row['description'] as String,
    price: (row['price'] as num).toDouble(),
    originalPrice: (row['original_price'] as num?)?.toDouble(),
    category: row['category'] as String,
    storeId: row['store_id'] as String,
    storeName: row['store_name'] as String,
    storeAvatarUrl: row['store_avatar_url'] as String?,
    imageUrl: storageUrlFromColumn(
      row['image_url'] as String?,
      projectUrl: projectUrl,
    ),
    imageUrls: (row['image_urls'] as List<dynamic>? ?? const [])
        .map((e) => storageUrlFromColumn(e as String, projectUrl: projectUrl)!)
        .toList(),
    colorOptions: (row['color_options'] as List<dynamic>? ?? const [])
        .map((e) => (e as num).toInt())
        .toList(),
    sizes: (row['sizes'] as List<dynamic>? ?? const [])
        .map((e) => e as String)
        .toList(),
    isDeal: row['is_deal'] as bool? ?? false,
    inStock: row['in_stock'] as bool? ?? true,
    rating: (row['rating'] as num?)?.toDouble(),
    reviewCount: row['review_count'] as int? ?? 0,
    createdAt: DateTime.parse(row['created_at'] as String),
    currency: row['currency'] as String? ?? 'TND',
    status: ProductStatus.values.byName(row['status'] as String? ?? 'live'),
    attributes: (row['attributes'] as Map<String, dynamic>? ?? const {}).map(
      (k, v) => MapEntry(k, v as String),
    ),
    variants: variants,
  );
}

/// A seller's avatar is a full URL for profiles made before spec 0013, and a
/// bucket relative path (`store-logos/<id>/<name>`) once approval copied a
/// logo, because SQL does not know the project URL. Turns the second kind
/// into a public Storage URL, and leaves null and full URLs as they are.
String? avatarUrlFromColumn(
  String? value, {
  String projectUrl = SupabaseConfig.url,
}) => storageUrlFromColumn(value, projectUrl: projectUrl);

/// The same rule for any image column: a full URL stays as it is, a
/// bucket relative path (`product-images/<id>/<id>/<name>.jpg`) becomes a
/// public Storage URL (spec 0015: SQL does not know the project URL).
String? storageUrlFromColumn(
  String? value, {
  String projectUrl = SupabaseConfig.url,
}) {
  if (value == null || value.startsWith('http')) return value;
  return '$projectUrl/storage/v1/object/public/$value';
}

/// Maps a `user_profiles` row to [UserProfile]. [projectUrl] is only for
/// tests, it defaults to the configured Supabase project.
UserProfile userProfileFromRow(
  Map<String, dynamic> row, {
  String projectUrl = SupabaseConfig.url,
}) {
  return UserProfile(
    id: row['id'] as String,
    name: row['name'] as String,
    username: row['username'] as String,
    avatarUrl: avatarUrlFromColumn(
      row['avatar_url'] as String?,
      projectUrl: projectUrl,
    ),
    bio: row['bio'] as String?,
    role: UserRole.values.byName(row['role'] as String? ?? 'seller'),
    followerCount: row['follower_count'] as int? ?? 0,
    followingCount: row['following_count'] as int? ?? 0,
    productCount: row['product_count'] as int? ?? 0,
    isVerified: row['is_verified'] as bool? ?? false,
    websiteUrl: row['website_url'] as String?,
    location: row['location'] as String?,
    phone: row['phone'] as String?,
    email: row['email'] as String?,
    currency: row['currency'] as String? ?? 'TND',
  );
}

/// Maps a `seller_applications` row to [SellerApplication].
SellerApplication sellerApplicationFromRow(Map<String, dynamic> row) {
  return SellerApplication(
    id: row['id'] as String,
    applicantId: row['applicant_id'] as String?,
    status: SellerApplicationStatus.values.byName(row['status'] as String),
    storeName: row['store_name'] as String,
    username: row['username'] as String,
    bio: row['bio'] as String?,
    location: row['location'] as String,
    websiteUrl: row['website_url'] as String?,
    contactPhone: row['contact_phone'] as String?,
    contactEmail: row['contact_email'] as String?,
    logoPath: row['logo_path'] as String?,
    idDocumentPath: row['id_document_path'] as String,
    businessDocumentPath: row['business_document_path'] as String?,
    rejectionReason: row['rejection_reason'] as String?,
    reviewedAt: row['reviewed_at'] == null
        ? null
        : DateTime.parse(row['reviewed_at'] as String),
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}
