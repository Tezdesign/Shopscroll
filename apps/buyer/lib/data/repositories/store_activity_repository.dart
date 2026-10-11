import '../models/store_order.dart';
import '../models/store_report.dart';

/// What the seller's Activity screens read (spec 0018). One implementation
/// keeps mock data in memory
/// ([lib/data/repositories/mock/mock_store_activity_repository.dart]), the
/// other calls the database functions
/// ([lib/data/repositories/supabase/supabase_store_activity_repository.dart]);
/// the app swaps between them through [storeActivityRepositoryProvider].
///
/// Refusals from the server are thrown as [StoreActivityException] with the
/// server's reason code.
abstract class StoreActivityRepository {
  /// This store's orders, newest first, [limit] at a time. [status] keeps one
  /// status, [search] narrows by order number or customer name, [after] is the
  /// [StoreOrder.cursor] of the last row already loaded.
  Future<List<StoreOrder>> listOrders({
    StoreOrderStatus? status,
    String search = '',
    int limit = 20,
    StoreOrderCursor? after,
  });

  /// One order as this store sees it (spec 0018, AC-5). Throws
  /// [StoreActivityException] with `not_found` for an unknown id and for an
  /// order that has no line from this store, which look the same on purpose.
  Future<StoreOrderDetail> orderDetail(String orderId);

  /// The Earnings tab numbers and the 4 latest sales (spec 0018, AC-6, AC-7).
  /// A store with no orders gets zeros and no recent sales.
  Future<StoreEarnings> earnings();

  /// The three numbers on top of the Reports tab (spec 0018, AC-8).
  Future<StoreReportsSummary> reportsSummary();

  /// This store's reports, newest first, [limit] at a time (spec 0018, AC-9).
  /// [status] keeps one status, [search] narrows by report number, title or
  /// customer name, [after] is the [StoreReport.cursor] of the last row
  /// already loaded.
  Future<List<StoreReport>> listReports({
    StoreReportStatus? status,
    String search = '',
    int limit = 20,
    StoreReportCursor? after,
  });

  /// One report in full (spec 0018, AC-10). Throws [StoreActivityException]
  /// with `not_found` for an unknown id and for another store's report, which
  /// look the same on purpose.
  Future<StoreReportDetail> reportDetail(String reportId);

  /// Links that show [paths] (a report's `attachmentPaths`) for one hour. A
  /// path with no file behind it is left out.
  Future<List<String>> attachmentUrls(List<String> paths);

  /// Marks a report resolved (spec 0018, AC-11). Resolving twice succeeds and
  /// changes nothing. Throws [StoreActivityException] with `not_found` for an
  /// unknown id and for another store's report. [note] is the seller's
  /// resolution note, sent when the backend supports it.
  Future<void> resolveReport(String reportId, {String? note});
}

/// A refusal from the Activity functions. [code] is the server's reason
/// (`no_session`, `not_seller`, `not_found`, `bad_status`, `bad_cursor`).
class StoreActivityException implements Exception {
  const StoreActivityException(this.code);

  final String code;

  /// The functions raise their reason as the whole message.
  factory StoreActivityException.fromMessage(String message) =>
      StoreActivityException(message.trim());

  @override
  String toString() => 'StoreActivityException($code)';
}
