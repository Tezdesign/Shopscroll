import '../../models/product.dart';
import '../../models/user_profile.dart';

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

/// Maps a `user_profiles` row to [UserProfile].
UserProfile userProfileFromRow(Map<String, dynamic> row) {
  return UserProfile(
    id: row['id'] as String,
    name: row['name'] as String,
    username: row['username'] as String,
    avatarUrl: row['avatar_url'] as String?,
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
