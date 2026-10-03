/// One buyer to store conversation as listed on the Activity Messages tab
/// (spec 0008). There is no conversations table yet: a chat feature will
/// design it, until then only mock data produces these.
class Conversation {
  const Conversation({
    required this.id,
    required this.storeId,
    required this.storeName,
    this.storeAvatarUrl,
    required this.lastMessage,
    required this.sentAt,
    this.isUnread = false,
  });

  final String id;
  final String storeId;
  final String storeName;
  final String? storeAvatarUrl;
  final String lastMessage;
  final DateTime sentAt;
  final bool isUnread;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      storeName: json['storeName'] as String,
      storeAvatarUrl: json['storeAvatarUrl'] as String?,
      lastMessage: json['lastMessage'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
      isUnread: json['isUnread'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeId': storeId,
      'storeName': storeName,
      'storeAvatarUrl': storeAvatarUrl,
      'lastMessage': lastMessage,
      'sentAt': sentAt.toIso8601String(),
      'isUnread': isUnread,
    };
  }

  Conversation copyWith({
    String? id,
    String? storeId,
    String? storeName,
    String? storeAvatarUrl,
    String? lastMessage,
    DateTime? sentAt,
    bool? isUnread,
  }) {
    return Conversation(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      storeAvatarUrl: storeAvatarUrl ?? this.storeAvatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      sentAt: sentAt ?? this.sentAt,
      isUnread: isUnread ?? this.isUnread,
    );
  }
}
