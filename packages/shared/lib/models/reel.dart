/// A short-form video posted by a seller/store.
class Reel {
  const Reel({
    required this.id,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.storeId,
    required this.storeName,
    this.storeAvatarUrl,
    required this.caption,
    this.likeCount = 0,
    this.commentCount = 0,
    this.productIds = const [],
    this.isAvailable = true,
    this.isSaved = false,
    required this.createdAt,
  });

  final String id;
  final String videoUrl;
  final String thumbnailUrl;
  final String storeId;
  final String storeName;
  final String? storeAvatarUrl;
  final String caption;
  final int likeCount;
  final int commentCount;

  /// Products tagged/shown in this reel (the "shop the look" flow).
  final List<String> productIds;

  /// False when the tagged products/store are no longer reachable
  /// (matches the ReelCard "unavailable" overlay state seen in Figma).
  final bool isAvailable;

  final bool isSaved;
  final DateTime createdAt;

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['id'] as String,
      videoUrl: json['videoUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      storeId: json['storeId'] as String,
      storeName: json['storeName'] as String,
      storeAvatarUrl: json['storeAvatarUrl'] as String?,
      caption: json['caption'] as String,
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      productIds: (json['productIds'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      isAvailable: json['isAvailable'] as bool? ?? true,
      isSaved: json['isSaved'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'storeId': storeId,
      'storeName': storeName,
      'storeAvatarUrl': storeAvatarUrl,
      'caption': caption,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'productIds': productIds,
      'isAvailable': isAvailable,
      'isSaved': isSaved,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Reel copyWith({
    String? id,
    String? videoUrl,
    String? thumbnailUrl,
    String? storeId,
    String? storeName,
    String? storeAvatarUrl,
    String? caption,
    int? likeCount,
    int? commentCount,
    List<String>? productIds,
    bool? isAvailable,
    bool? isSaved,
    DateTime? createdAt,
  }) {
    return Reel(
      id: id ?? this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      storeAvatarUrl: storeAvatarUrl ?? this.storeAvatarUrl,
      caption: caption ?? this.caption,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      productIds: productIds ?? this.productIds,
      isAvailable: isAvailable ?? this.isAvailable,
      isSaved: isSaved ?? this.isSaved,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
