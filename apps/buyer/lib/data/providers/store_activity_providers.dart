import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/store_order.dart';
import '../models/store_report.dart';
import '../repositories/repository_providers.dart';
import '../repositories/store_activity_repository.dart';

/// How many rows each page of the seller's lists holds (spec 0018, AC-2).
const storeActivityPageSize = 20;

/// The text in the Activity search field, trimmed. One value for every tab
/// (spec 0018, AC-4), so it stays when the tab changes.
final storeActivitySearchProvider = StateProvider<String>((ref) => '');

/// The status chip on the Orders tab, or null for none (spec 0018, AC-3).
final storeOrderStatusFilterProvider = StateProvider<StoreOrderStatus?>(
  (ref) => null,
);

/// The rows loaded so far and whether more follow.
class StoreOrdersState {
  const StoreOrdersState({
    required this.orders,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<StoreOrder> orders;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  StoreOrdersState copyWith({
    List<StoreOrder>? orders,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) {
    return StoreOrdersState(
      orders: orders ?? this.orders,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// The seller's store orders for the current chip and search, newest first,
/// as if fetched from `GET /store/orders?status=&q=&cursor=` (spec 0018,
/// AC-2). The first page loads when the chip or the search changes; [loadMore]
/// adds the next 20 by keyset, so a new order arriving meanwhile never repeats
/// a row.
///
/// No automatic retry: a failed load must reach the tab as an error with its
/// own "Try again" button (AC-14).
final storeOrdersProvider =
    AsyncNotifierProvider.autoDispose<StoreOrdersNotifier, StoreOrdersState>(
      StoreOrdersNotifier.new,
      retry: (retryCount, error) => null,
    );

class StoreOrdersNotifier extends AsyncNotifier<StoreOrdersState> {
  // Bumped on every first load, so a page that finishes after the chip or the
  // search changed is dropped instead of added to the new list.
  int _generation = 0;

  @override
  Future<StoreOrdersState> build() async {
    _generation++;
    final status = ref.watch(storeOrderStatusFilterProvider);
    final search = ref.watch(storeActivitySearchProvider);
    final rows = await ref
        .watch(storeActivityRepositoryProvider)
        .listOrders(status: status, search: search);
    return StoreOrdersState(
      orders: rows,
      hasMore: rows.length == storeActivityPageSize,
    );
  }

  /// As if sent to `GET /store/orders` with the last row's cursor. A failure
  /// keeps the rows and sets [StoreOrdersState.loadMoreFailed], so the list
  /// can offer a retry at its end.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        current.orders.isEmpty) {
      return;
    }
    final generation = _generation;
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );
    try {
      final rows = await ref
          .read(storeActivityRepositoryProvider)
          .listOrders(
            status: ref.read(storeOrderStatusFilterProvider),
            search: ref.read(storeActivitySearchProvider),
            after: current.orders.last.cursor,
          );
      if (generation != _generation) return;
      state = AsyncData(
        StoreOrdersState(
          orders: [...current.orders, ...rows],
          hasMore: rows.length == storeActivityPageSize,
        ),
      );
    } catch (_) {
      if (generation != _generation) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }
}

/// One order as this store sees it, as if fetched from
/// `GET /store/orders/:id` (spec 0018, AC-5). Null when the order does not
/// exist or has no line from this store, so the screen can say "Order not
/// found". No automatic retry: a failed load reaches the screen with its own
/// "Try again".
final storeOrderDetailProvider = FutureProvider.autoDispose
    .family<StoreOrderDetail?, String>((ref, orderId) async {
      try {
        return await ref
            .watch(storeActivityRepositoryProvider)
            .orderDetail(orderId);
      } on StoreActivityException catch (error) {
        if (error.code == 'not_found') return null;
        rethrow;
      }
    }, retry: (retryCount, error) => null);

/// The Earnings tab numbers, as if fetched from `GET /store/earnings` (spec
/// 0018, AC-6, AC-7). No automatic retry: a failed load reaches the tab with
/// its own "Try again".
final storeEarningsProvider = FutureProvider.autoDispose<StoreEarnings>(
  (ref) => ref.watch(storeActivityRepositoryProvider).earnings(),
  retry: (retryCount, error) => null,
);

/// The three numbers on top of the Reports tab, as if fetched from
/// `GET /store/reports/summary` (spec 0018, AC-8). No automatic retry: a
/// failed load reaches the tab with its own "Try again".
final storeReportsSummaryProvider =
    AsyncNotifierProvider.autoDispose<
      StoreReportsSummaryNotifier,
      StoreReportsSummary
    >(StoreReportsSummaryNotifier.new, retry: (retryCount, error) => null);

class StoreReportsSummaryNotifier extends AsyncNotifier<StoreReportsSummary> {
  @override
  Future<StoreReportsSummary> build() =>
      ref.watch(storeActivityRepositoryProvider).reportsSummary();

  /// Moves the Unresolved card by [delta] without a reload, so it follows a
  /// resolve at once and goes back if the call fails (AC-11).
  void addUnresolved(int delta) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        unresolved: (current.unresolved + delta).clamp(0, current.total),
      ),
    );
  }
}

/// The report rows loaded so far and whether more follow.
class StoreReportsState {
  const StoreReportsState({
    required this.reports,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<StoreReport> reports;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  StoreReportsState copyWith({
    List<StoreReport>? reports,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) {
    return StoreReportsState(
      reports: reports ?? this.reports,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// The seller's reports for the current search, newest first, as if fetched
/// from `GET /store/reports?q=&cursor=` (spec 0018, AC-9). Paged like
/// [storeOrdersProvider]. No automatic retry (AC-14).
final storeReportsProvider =
    AsyncNotifierProvider.autoDispose<StoreReportsNotifier, StoreReportsState>(
      StoreReportsNotifier.new,
      retry: (retryCount, error) => null,
    );

class StoreReportsNotifier extends AsyncNotifier<StoreReportsState> {
  // Bumped on every first load, so a page that finishes after the search
  // changed is dropped instead of added to the new list.
  int _generation = 0;

  @override
  Future<StoreReportsState> build() async {
    _generation++;
    final search = ref.watch(storeActivitySearchProvider);
    final rows = await ref
        .watch(storeActivityRepositoryProvider)
        .listReports(search: search);
    return StoreReportsState(
      reports: rows,
      hasMore: rows.length == storeActivityPageSize,
    );
  }

  /// As if sent to `GET /store/reports` with the last row's cursor. A failure
  /// keeps the rows and sets [StoreReportsState.loadMoreFailed].
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        current.reports.isEmpty) {
      return;
    }
    final generation = _generation;
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );
    try {
      final rows = await ref
          .read(storeActivityRepositoryProvider)
          .listReports(
            search: ref.read(storeActivitySearchProvider),
            after: current.reports.last.cursor,
          );
      if (generation != _generation) return;
      state = AsyncData(
        StoreReportsState(
          reports: [...current.reports, ...rows],
          hasMore: rows.length == storeActivityPageSize,
        ),
      );
    } catch (_) {
      if (generation != _generation) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }

  /// Changes one row's status without a reload (AC-11). Rows loaded after a
  /// failed [loadMore] keep their place.
  void setStatus(String id, StoreReportStatus status) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        reports: [
          for (final report in current.reports)
            report.id == id ? report.copyWith(status: status) : report,
        ],
      ),
    );
  }
}

/// One report in full, as if fetched from `GET /store/reports/:id` (spec 0018,
/// AC-10). The state is null when the report does not exist or belongs to
/// another store, so the screen can say "Report not found". No automatic
/// retry.
final storeReportDetailProvider = AsyncNotifierProvider.autoDispose
    .family<StoreReportDetailNotifier, StoreReportDetail?, String>(
      StoreReportDetailNotifier.new,
      retry: (retryCount, error) => null,
    );

class StoreReportDetailNotifier extends AsyncNotifier<StoreReportDetail?> {
  StoreReportDetailNotifier(this.reportId);

  final String reportId;

  @override
  Future<StoreReportDetail?> build() async {
    try {
      return await ref
          .watch(storeActivityRepositoryProvider)
          .reportDetail(reportId);
    } on StoreActivityException catch (error) {
      if (error.code == 'not_found') return null;
      rethrow;
    }
  }

  void setStatus(StoreReportStatus status) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(status: status));
  }
}

/// Signed links for a report's attachments, valid for one hour (spec 0018,
/// AC-10). Watches only the paths, so a status change does not sign them
/// again.
final storeReportAttachmentsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, reportId) async {
      final paths = ref.watch(
        storeReportDetailProvider(
          reportId,
        ).select((detail) => detail.value?.attachmentPaths),
      );
      if (paths == null || paths.isEmpty) return const [];
      return ref.watch(storeActivityRepositoryProvider).attachmentUrls(paths);
    }, retry: (retryCount, error) => null);

/// Marks a report resolved as if sent to `POST /store/reports/:id/resolve`
/// (spec 0018, AC-11). The card, the detail page and the Unresolved card show
/// Resolved at once, and go back if the call fails. Returns whether it worked.
/// Only the providers that are alive are touched, so resolving from a detail
/// page opened with no list behind it loads nothing extra.
final resolveStoreReportProvider =
    Provider<Future<bool> Function(String, {String? note})>((ref) {
  void show(String id, StoreReportStatus status) {
    if (ref.exists(storeReportsProvider)) {
      ref.read(storeReportsProvider.notifier).setStatus(id, status);
    }
    if (ref.exists(storeReportDetailProvider(id))) {
      ref.read(storeReportDetailProvider(id).notifier).setStatus(status);
    }
    if (ref.exists(storeReportsSummaryProvider)) {
      ref
          .read(storeReportsSummaryProvider.notifier)
          .addUnresolved(status == StoreReportStatus.resolved ? -1 : 1);
    }
  }

  return (id, {String? note}) async {
    show(id, StoreReportStatus.resolved);
    try {
      await ref
          .read(storeActivityRepositoryProvider)
          .resolveReport(id, note: note);
      return true;
    } catch (_) {
      show(id, StoreReportStatus.unsolved);
      return false;
    }
  };
});
