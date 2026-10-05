import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/seller_application.dart';
import 'package:shopscroll_shared/models/user_profile.dart';

import '../../../core/config/supabase_config.dart';

/// Maps a `products` row (snake_case Postgres columns) to [Product]. Shared
/// by every Supabase repository that embeds a product (catalog reads, cart).
Product productFromRow(Map<String, dynamic> row) {
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
    imageUrl: row['image_url'] as String?,
    imageUrls: (row['image_urls'] as List<dynamic>? ?? const [])
        .map((e) => e as String)
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
  );
}

/// A seller's avatar is a full URL for profiles made before spec 0013, and a
/// bucket relative path (`store-logos/<id>/<name>`) once approval copied a
/// logo, because SQL does not know the project URL. Turns the second kind
/// into a public Storage URL, and leaves null and full URLs as they are.
String? avatarUrlFromColumn(
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
