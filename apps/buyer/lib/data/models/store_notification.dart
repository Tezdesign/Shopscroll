/// The type of an event in the seller's notification feed (seller side only —
/// no buyer notifications here). Chat messages are excluded on purpose: they
/// belong in the future Messages feature and never appear on the Notifications
/// screen (design fix, audit Oct-2026).
enum StoreNotificationType {
  /// A buyer placed a new order.
  newOrder,

  /// A buyer filed a report against this store.
  newReport,

  /// A product's stock is running low or hit zero.
  stockAlert,
}

/// One entry in the seller's notification feed.
class StoreNotification {
  const StoreNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    required this.createdAtRaw,
    this.resourceId,
  });

  final String id;
  final StoreNotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  /// [createdAt] as the server wrote it, kept for keyset paging.
  final String createdAtRaw;

  /// Order id, report id, or product id — whichever the row links to.
  final String? resourceId;

  StoreNotification copyWith({bool? isRead}) => StoreNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    createdAtRaw: createdAtRaw,
    resourceId: resourceId,
  );

  factory StoreNotification.fromJson(Map<String, dynamic> json) {
    final raw = json['createdAt'] as String;
    return StoreNotification(
      id: json['id'] as String,
      type: StoreNotificationType.values.byName(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['isRead'] as bool,
      createdAt: DateTime.parse(raw),
      createdAtRaw: raw,
      resourceId: json['resourceId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'isRead': isRead,
    'createdAt': createdAtRaw,
    'resourceId': resourceId,
  };
}
