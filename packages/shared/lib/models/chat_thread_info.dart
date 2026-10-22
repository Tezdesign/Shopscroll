/// What the thread screen shows about the other side, as `chat_thread_info`
/// returns it (spec 0011). For a buyer the other side is a store: [otherId]
/// is the store's id, [otherFollowerCount] its followers. [conversationId] is
/// null while the thread does not exist yet (nothing is stored until the
/// first message).
class ChatThreadInfo {
  const ChatThreadInfo({
    this.conversationId,
    this.otherId,
    required this.otherName,
    this.otherAvatarUrl,
    this.otherFollowerCount,
    this.buyerReadAt,
    this.storeReadAt,
    this.buyerBlocked = false,
    this.storeBlocked = false,
  });

  final String? conversationId;
  final String? otherId;
  final String otherName;
  final String? otherAvatarUrl;
  final int? otherFollowerCount;
  final DateTime? buyerReadAt;
  final DateTime? storeReadAt;
  final bool buyerBlocked;
  final bool storeBlocked;

  factory ChatThreadInfo.fromJson(Map<String, dynamic> json) {
    DateTime? time(String key) {
      final value = json[key] as String?;
      return value == null ? null : DateTime.parse(value);
    }

    return ChatThreadInfo(
      conversationId: json['conversation_id'] as String?,
      otherId: json['other_id'] as String?,
      otherName: json['other_name'] as String,
      otherAvatarUrl: json['other_avatar_url'] as String?,
      otherFollowerCount: json['other_follower_count'] as int?,
      buyerReadAt: time('buyer_read_at'),
      storeReadAt: time('store_read_at'),
      buyerBlocked: json['buyer_blocked'] as bool? ?? false,
      storeBlocked: json['store_blocked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'other_id': otherId,
      'other_name': otherName,
      'other_avatar_url': otherAvatarUrl,
      'other_follower_count': otherFollowerCount,
      'buyer_read_at': buyerReadAt?.toIso8601String(),
      'store_read_at': storeReadAt?.toIso8601String(),
      'buyer_blocked': buyerBlocked,
      'store_blocked': storeBlocked,
    };
  }

  ChatThreadInfo copyWith({
    String? conversationId,
    String? otherId,
    String? otherName,
    String? otherAvatarUrl,
    int? otherFollowerCount,
    DateTime? buyerReadAt,
    DateTime? storeReadAt,
    bool? buyerBlocked,
    bool? storeBlocked,
  }) {
    return ChatThreadInfo(
      conversationId: conversationId ?? this.conversationId,
      otherId: otherId ?? this.otherId,
      otherName: otherName ?? this.otherName,
      otherAvatarUrl: otherAvatarUrl ?? this.otherAvatarUrl,
      otherFollowerCount: otherFollowerCount ?? this.otherFollowerCount,
      buyerReadAt: buyerReadAt ?? this.buyerReadAt,
      storeReadAt: storeReadAt ?? this.storeReadAt,
      buyerBlocked: buyerBlocked ?? this.buyerBlocked,
      storeBlocked: storeBlocked ?? this.storeBlocked,
    );
  }
}
