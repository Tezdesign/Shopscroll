import '../../models/store_notification.dart';
import '../../providers/network_delay.dart';
import '../store_notification_repository.dart';

/// Keeps the seller's notification data in memory so the Notifications screen
/// runs with no backend. The seed mixes new-order, new-report and stock-alert
/// rows; some are unread, some read, so the unread badge and the "Mark all as
/// read" CTA have something to act on.
class MockStoreNotificationRepository implements StoreNotificationRepository {
  MockStoreNotificationRepository({DateTime? now})
    : _rows = _seed(now ?? DateTime.now());

  List<StoreNotification> _rows;

  static List<StoreNotification> _seed(DateTime base) {
    final rows = <StoreNotification>[
      _row(
        base,
        offset: 0,
        id: 'n-001',
        type: StoreNotificationType.newOrder,
        title: 'New order from Amel Trabelsi',
        body: 'Order #002548 — 450.000 TND',
        isRead: false,
        resourceId: 'mock-order-002548',
      ),
      _row(
        base,
        offset: 1,
        id: 'n-002',
        type: StoreNotificationType.newReport,
        title: 'New report filed',
        body: '#R-0004 — Product arrived damaged',
        isRead: false,
        resourceId: 'mock-report-0004',
      ),
      _row(
        base,
        offset: 3,
        id: 'n-003',
        type: StoreNotificationType.stockAlert,
        title: 'Low stock: Running Shoes M/42',
        body: 'Only 2 items left',
        isRead: false,
      ),
      _row(
        base,
        offset: 5,
        id: 'n-004',
        type: StoreNotificationType.newOrder,
        title: 'New order from Yassine Gharbi',
        body: 'Order #002547 — 320.000 TND',
        isRead: true,
        resourceId: 'mock-order-002547',
      ),
      _row(
        base,
        offset: 8,
        id: 'n-005',
        type: StoreNotificationType.newReport,
        title: 'New report filed',
        body: '#R-0003 — Wrong item sent',
        isRead: true,
        resourceId: 'mock-report-0003',
      ),
      _row(
        base,
        offset: 12,
        id: 'n-006',
        type: StoreNotificationType.stockAlert,
        title: 'Out of stock: Leather Belt L',
        body: '0 items left — remove listing or restock',
        isRead: true,
      ),
      _row(
        base,
        offset: 24,
        id: 'n-007',
        type: StoreNotificationType.newOrder,
        title: 'New order from Moetez ben Attia',
        body: 'Order #002546 — 450.000 TND',
        isRead: true,
        resourceId: 'mock-order-002546',
      ),
      _row(
        base,
        offset: 30,
        id: 'n-008',
        type: StoreNotificationType.newOrder,
        title: 'New order from Salma Bouzid',
        body: 'Order #002545 — 180.000 TND',
        isRead: true,
        resourceId: 'mock-order-002545',
      ),
    ];
    return rows;
  }

  static StoreNotification _row(
    DateTime base, {
    required int offset,
    required String id,
    required StoreNotificationType type,
    required String title,
    required String body,
    required bool isRead,
    String? resourceId,
  }) {
    final at = base.subtract(Duration(hours: offset)).toUtc();
    return StoreNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      isRead: isRead,
      createdAt: at,
      createdAtRaw: at.toIso8601String(),
      resourceId: resourceId,
    );
  }

  @override
  Future<List<StoreNotification>> list({
    bool onlyAlerts = false,
    int limit = 20,
    String? afterCreatedAt,
    String? afterId,
  }) async {
    await Future.delayed(mockNetworkDelay);
    var rows = _rows.where((n) {
      if (onlyAlerts) {
        return n.type == StoreNotificationType.newReport ||
            n.type == StoreNotificationType.stockAlert;
      }
      return true;
    }).toList();

    if (afterCreatedAt != null && afterId != null) {
      final cutoff = DateTime.parse(afterCreatedAt);
      rows = rows
          .where(
            (n) =>
                n.createdAt.isBefore(cutoff) ||
                (n.createdAt.isAtSameMomentAs(cutoff) && n.id != afterId),
          )
          .toList();
    }

    return rows.take(limit).toList();
  }

  @override
  Future<int> unreadCount() async {
    await Future.delayed(mockNetworkDelay);
    return _rows.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markAllRead() async {
    await Future.delayed(mockNetworkDelay);
    _rows = [for (final n in _rows) n.copyWith(isRead: true)];
  }
}
