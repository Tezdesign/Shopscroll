enum UserRole { buyer, seller }

/// A buyer or seller profile. Sellers additionally represent a "shop"
/// (product/reel storeId/storeName fields reference a seller's [id]/[name]).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.bio,
    this.role = UserRole.seller,
    this.followerCount = 0,
    this.followingCount = 0,
    this.productCount = 0,
    this.isVerified = false,
    this.websiteUrl,
    this.location,
    this.phone,
    this.email,
  });

  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final UserRole role;
  final int followerCount;
  final int followingCount;

  /// Number of products the seller has listed (0 for buyers).
  final int productCount;

  final bool isVerified;
  final String? websiteUrl;
  final String? location;
  final String? phone;
  final String? email;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      role: UserRole.values.byName(json['role'] as String? ?? 'seller'),
      followerCount: json['followerCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      productCount: json['productCount'] as int? ?? 0,
      isVerified: json['isVerified'] as bool? ?? false,
      websiteUrl: json['websiteUrl'] as String?,
      location: json['location'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'role': role.name,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'productCount': productCount,
      'isVerified': isVerified,
      'websiteUrl': websiteUrl,
      'location': location,
      'phone': phone,
      'email': email,
    };
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? username,
    String? avatarUrl,
    String? bio,
    UserRole? role,
    int? followerCount,
    int? followingCount,
    int? productCount,
    bool? isVerified,
    String? websiteUrl,
    String? location,
    String? phone,
    String? email,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      productCount: productCount ?? this.productCount,
      isVerified: isVerified ?? this.isVerified,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      location: location ?? this.location,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }
}
