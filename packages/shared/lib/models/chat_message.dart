/// Where a message is on its way to the server. Only the phone knows this, it
/// is never sent or stored (spec 0011, AC-4, AC-19).
enum ChatMessageStatus { sent, sending, failed }

/// One chat message (spec 0011). `body`, `imagePath` and `productId` are all
/// null once the message is deleted (`deletedAt` is set). [status] is client
/// only.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.body,
    this.imagePath,
    this.productId,
    required this.createdAt,
    this.deletedAt,
    this.status = ChatMessageStatus.sent,
  });

  final String id;

  /// Empty for a message waiting to be sent in a thread that does not exist
  /// yet.
  final String conversationId;
  final String senderId;
  final String? body;
  final String? imagePath;
  final String? productId;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final ChatMessageStatus status;

  bool get isDeleted => deletedAt != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final deletedAt = json['deleted_at'] as String?;
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      body: json['body'] as String?,
      imagePath: json['image_path'] as String?,
      productId: json['product_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      deletedAt: deletedAt == null ? null : DateTime.parse(deletedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'body': body,
      'image_path': imagePath,
      'product_id': productId,
      'created_at': createdAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? body,
    String? imagePath,
    String? productId,
    DateTime? createdAt,
    DateTime? deletedAt,
    ChatMessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      body: body ?? this.body,
      imagePath: imagePath ?? this.imagePath,
      productId: productId ?? this.productId,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
    );
  }
}
