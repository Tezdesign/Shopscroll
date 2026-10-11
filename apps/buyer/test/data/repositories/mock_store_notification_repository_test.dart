import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/models/store_notification.dart';
import 'package:marketplace_app/data/repositories/mock/mock_store_notification_repository.dart';

// The seller's Notifications feed has no spec yet. These tests pin what the
// mock does today, so a Supabase version can be made to behave the same.
void main() {
  late MockStoreNotificationRepository repo;
  setUp(
    () => repo = MockStoreNotificationRepository(now: DateTime.utc(2026, 5, 1)),
  );

  test('lists the feed newest first', () async {
    final rows = await repo.list();
    expect(rows, hasLength(8));
    expect(rows.first.id, 'n-001');
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].createdAt.isBefore(rows[i - 1].createdAt), isTrue);
    }
  });

  test(
    'the Alerts tab keeps reports and stock alerts, and never orders',
    () async {
      final rows = await repo.list(onlyAlerts: true);
      expect(rows, isNotEmpty);
      expect(
        rows.every((n) => n.type != StoreNotificationType.newOrder),
        isTrue,
      );
      expect(rows.map((n) => n.type).toSet(), {
        StoreNotificationType.newReport,
        StoreNotificationType.stockAlert,
      });
    },
  );

  test('keyset paging continues after the last row with no repeat', () async {
    final first = await repo.list(limit: 3);
    final second = await repo.list(
      limit: 3,
      afterCreatedAt: first.last.createdAtRaw,
      afterId: first.last.id,
    );
    final third = await repo.list(
      limit: 3,
      afterCreatedAt: second.last.createdAtRaw,
      afterId: second.last.id,
    );
    final ids = [...first, ...second, ...third].map((n) => n.id).toList();
    expect(ids, hasLength(8));
    expect(ids.toSet(), hasLength(8));
  });

  test(
    'counts the unread rows, and Mark all as read clears the count',
    () async {
      expect(await repo.unreadCount(), 3);
      await repo.markAllRead();
      expect(await repo.unreadCount(), 0);
      expect((await repo.list()).every((n) => n.isRead), isTrue);
    },
  );

  test(
    'a notification survives a json round trip and copyWith changes only isRead',
    () {
      final original = StoreNotification(
        id: 'n-x',
        type: StoreNotificationType.stockAlert,
        title: 'Low stock',
        body: 'Only 2 left',
        isRead: false,
        createdAt: DateTime.utc(2026, 5, 1, 10, 0, 0, 123, 456),
        createdAtRaw: '2026-05-01T10:00:00.123456Z',
        resourceId: 'p-1',
      );
      final again = StoreNotification.fromJson(original.toJson());
      expect(again.toJson(), original.toJson());
      final read = original.copyWith(isRead: true);
      expect(read.isRead, isTrue);
      expect(read.id, original.id);
      expect(read.createdAtRaw, original.createdAtRaw);
      expect(read.resourceId, 'p-1');
    },
  );
}
