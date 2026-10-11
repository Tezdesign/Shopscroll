import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/store_notification.dart';
import '../repositories/repository_providers.dart';

const _pageSize = 20;

/// The rows loaded so far for one tab and whether more follow.
class StoreNotificationsState {
  const StoreNotificationsState({
    required this.rows,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<StoreNotification> rows;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  StoreNotificationsState copyWith({
    List<StoreNotification>? rows,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) => StoreNotificationsState(
    rows: rows ?? this.rows,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

/// The seller's All-tab notifications, newest first, as if fetched from
/// `GET /store/notifications` (no spec number yet). Paged like
/// [storeOrdersProvider]. No automatic retry.
final storeNotificationsProvider = AsyncNotifierProvider.autoDispose<
  StoreNotificationsNotifier,
  StoreNotificationsState
>(StoreNotificationsNotifier.new, retry: (retryCount, error) => null);

class StoreNotificationsNotifier
    extends AsyncNotifier<StoreNotificationsState> {
  @override
  Future<StoreNotificationsState> build() async {
    final rows = await ref
        .watch(storeNotificationRepositoryProvider)
        .list(limit: _pageSize);
    return StoreNotificationsState(
      rows: rows,
      hasMore: rows.length == _pageSize,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        current.rows.isEmpty) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true, loadMoreFailed: false));
    final last = current.rows.last;
    try {
      final rows = await ref
          .read(storeNotificationRepositoryProvider)
          .list(
            limit: _pageSize,
            afterCreatedAt: last.createdAtRaw,
            afterId: last.id,
          );
      state = AsyncData(
        StoreNotificationsState(
          rows: [...current.rows, ...rows],
          hasMore: rows.length == _pageSize,
        ),
      );
    } catch (_) {
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }

  void setAllRead() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        rows: [for (final n in current.rows) n.copyWith(isRead: true)],
      ),
    );
  }
}

/// The seller's Alerts-tab notifications (reports + stock alerts only).
final storeAlertsProvider = AsyncNotifierProvider.autoDispose<
  StoreAlertsNotifier,
  StoreNotificationsState
>(StoreAlertsNotifier.new, retry: (retryCount, error) => null);

class StoreAlertsNotifier extends AsyncNotifier<StoreNotificationsState> {
  @override
  Future<StoreNotificationsState> build() async {
    final rows = await ref
        .watch(storeNotificationRepositoryProvider)
        .list(onlyAlerts: true, limit: _pageSize);
    return StoreNotificationsState(
      rows: rows,
      hasMore: rows.length == _pageSize,
    );
  }

  void setAllRead() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        rows: [for (final n in current.rows) n.copyWith(isRead: true)],
      ),
    );
  }
}

/// How many notifications are unread (for the bell badge). Refreshed after
/// markAllRead so the badge clears.
final storeNotificationUnreadProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(storeNotificationRepositoryProvider).unreadCount(),
  retry: (retryCount, error) => null,
);

/// Marks all notifications read: updates the server and optimistically clears
/// both list providers and the badge.
final markAllNotificationsReadProvider =
    Provider<Future<void> Function()>((ref) {
      return () async {
        // Optimistic clear in both list providers while alive.
        if (ref.exists(storeNotificationsProvider)) {
          ref.read(storeNotificationsProvider.notifier).setAllRead();
        }
        if (ref.exists(storeAlertsProvider)) {
          ref.read(storeAlertsProvider.notifier).setAllRead();
        }
        await ref
            .read(storeNotificationRepositoryProvider)
            .markAllRead();
        // Refresh the badge count.
        if (ref.exists(storeNotificationUnreadProvider)) {
          ref.invalidate(storeNotificationUnreadProvider);
        }
      };
    });
