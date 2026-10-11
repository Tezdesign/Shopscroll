import '../models/store_notification.dart';

/// What the seller's Notifications screen reads. One implementation keeps mock
/// data in memory, the other calls the database. Swapped via
/// [storeNotificationRepositoryProvider] in repository_providers.dart.
abstract class StoreNotificationRepository {
  /// This store's notifications, newest first, up to [limit]. Pass the last
  /// row's [StoreNotification.createdAtRaw] + [StoreNotification.id] as
  /// [afterCreatedAt] / [afterId] for keyset paging. Set [onlyAlerts] to true
  /// to get only [StoreNotificationType.newReport] and
  /// [StoreNotificationType.stockAlert] rows (the Alerts tab).
  Future<List<StoreNotification>> list({
    bool onlyAlerts = false,
    int limit = 20,
    String? afterCreatedAt,
    String? afterId,
  });

  /// How many notifications are unread (badge count).
  Future<int> unreadCount();

  /// Mark every notification read as if sent to `POST /store/notifications/read-all`.
  Future<void> markAllRead();
}
