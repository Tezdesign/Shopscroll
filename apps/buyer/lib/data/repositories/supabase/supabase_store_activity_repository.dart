import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/store_order.dart';
import '../../models/store_report.dart';
import '../store_activity_repository.dart';

/// Reads the seller's Activity data through database functions (spec 0018).
/// Clients have no table access to `store_orders`, `reports` or `report_items`,
/// and the functions return only the caller's own store's part of an order
/// (`supabase/migrations/0014_store_orders.sql`).
class SupabaseStoreActivityRepository implements StoreActivityRepository {
  SupabaseStoreActivityRepository(this._client);

  final SupabaseClient _client;

  /// Runs a call and turns the server's refusal into a typed exception. The
  /// functions raise their reason as the whole message.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (error) {
      throw StoreActivityException.fromMessage(error.message);
    }
  }

  @override
  Future<List<StoreOrder>> listOrders({
    StoreOrderStatus? status,
    String search = '',
    int limit = 20,
    StoreOrderCursor? after,
  }) async {
    final text = search.trim();
    final rows = await _guard(
      () => _client.rpc<List<dynamic>>(
        'store_orders_list',
        params: {
          'p_status': ?status?.name,
          'p_search': ?(text.isEmpty ? null : text),
          'p_limit': limit,
          'p_cursor_created_at': ?after?.createdAt,
          'p_cursor_order_id': ?after?.orderId,
        },
      ),
    );
    return [for (final row in rows) _fromRow(row as Map<String, dynamic>)];
  }

  StoreOrder _fromRow(Map<String, dynamic> row) {
    return StoreOrder.fromJson({
      'orderId': row['order_id'],
      'orderNumber': row['order_number'],
      'status': row['status'],
      'customerName': row['customer_name'],
      'city': row['city'],
      'address': row['address'],
      'total': row['total'],
      'currency': row['currency'],
      'createdAt': row['created_at'],
    });
  }

  @override
  Future<StoreOrderDetail> orderDetail(String orderId) async {
    final rows = await _guard(
      () => _client.rpc<List<dynamic>>(
        'store_order_detail',
        params: {'p_order_id': orderId},
      ),
    );
    if (rows.isEmpty) throw const StoreActivityException('not_found');
    final row = rows.first as Map<String, dynamic>;
    return StoreOrderDetail.fromJson({
      'orderId': row['order_id'],
      'orderNumber': row['order_number'],
      'status': row['status'],
      'createdAt': row['created_at'],
      'customerName': row['customer_name'],
      'customerEmail': row['customer_email'],
      'customerPhone': row['customer_phone'],
      'city': row['city'],
      'address': row['address'],
      'zip': row['zip'],
      'note': row['note'],
      'deliveryMethod': row['delivery_method'],
      'paymentMethod': row['payment_method'],
      'subtotal': row['subtotal'],
      'currency': row['currency'],
      'lines': [
        for (final line in row['lines'] as List<dynamic>)
          {
            'title': (line as Map<String, dynamic>)['title'],
            'imageUrl': line['image_url'],
            'size': line['selected_size'],
            'color': line['selected_color'],
            'unitPrice': line['unit_price'],
            'quantity': line['quantity'],
          },
      ],
    });
  }

  @override
  Future<StoreEarnings> earnings() async {
    final rows = await _guard(
      () => _client.rpc<List<dynamic>>('store_earnings'),
    );
    final row = rows.first as Map<String, dynamic>;
    return StoreEarnings.fromJson({
      'totalSales': row['total_sales'],
      'todaySales': row['today_sales'],
      'todayOrders': row['today_orders'],
      'weekSales': row['week_sales'],
      'prevWeekSameSpanSales': row['prev_week_same_span_sales'],
      'customers': row['customers'],
      'newCustomersToday': row['new_customers_today'],
      'currency': row['currency'],
      'recent': [
        for (final sale in row['recent'] as List<dynamic>)
          {
            'orderId': (sale as Map<String, dynamic>)['order_id'],
            'orderNumber': sale['order_number'],
            'customerName': sale['customer_name'],
            'city': sale['city'],
            'address': sale['address'],
            'amount': sale['amount'],
          },
      ],
    });
  }

  @override
  Future<StoreReportsSummary> reportsSummary() async {
    final rows = await _guard(
      () => _client.rpc<List<dynamic>>('store_reports_summary'),
    );
    final row = rows.first as Map<String, dynamic>;
    return StoreReportsSummary.fromJson({
      'total': row['total'],
      'newToday': row['new_today'],
      'unresolved': row['unresolved'],
      'returnedOrders': row['returned_orders'],
    });
  }

  @override
  Future<List<StoreReport>> listReports({
    StoreReportStatus? status,
    String search = '',
    int limit = 20,
    StoreReportCursor? after,
  }) async {
    final text = search.trim();
    final rows = await _guard(
      () => _client.rpc<List<dynamic>>(
        'store_reports_list',
        params: {
          'p_status': ?status?.name,
          'p_search': ?(text.isEmpty ? null : text),
          'p_limit': limit,
          'p_cursor_created_at': ?after?.createdAt,
          'p_cursor_id': ?after?.id,
        },
      ),
    );
    return [
      for (final row in rows)
        StoreReport.fromJson({
          'id': (row as Map<String, dynamic>)['id'],
          'reportNumber': row['report_number'],
          'status': row['status'],
          'title': row['title'],
          'description': row['description'],
          'customerName': row['customer_name'],
          'firstItemTitle': row['first_item_title'],
          'itemCount': row['item_count'],
          'orderNumber': row['order_number'],
          'createdAt': row['created_at'],
        }),
    ];
  }

  @override
  Future<StoreReportDetail> reportDetail(String reportId) async {
    final rows = await _guard(
      () => _client.rpc<List<dynamic>>(
        'store_report_detail',
        params: {'p_report_id': reportId},
      ),
    );
    if (rows.isEmpty) throw const StoreActivityException('not_found');
    final row = rows.first as Map<String, dynamic>;
    return StoreReportDetail.fromJson({
      'id': row['id'],
      'reportNumber': row['report_number'],
      'status': row['status'],
      'title': row['title'],
      'description': row['description'],
      'customerName': row['customer_name'],
      'customerEmail': row['customer_email'],
      'customerPhone': row['customer_phone'],
      'orderNumber': row['order_number'],
      'createdAt': row['created_at'],
      'purchasedAt': row['purchased_at'],
      'items': [
        for (final item in row['items'] as List<dynamic>)
          {
            'title': (item as Map<String, dynamic>)['title'],
            'imageUrl': item['image_url'],
          },
      ],
      'attachmentPaths': row['attachment_paths'],
    });
  }

  /// Signed links valid for one hour (spec 0018, AC-10). A path with no file
  /// is left out.
  @override
  Future<List<String>> attachmentUrls(List<String> paths) async {
    if (paths.isEmpty) return const [];
    final results = await _client.storage
        .from('report-attachments')
        .createSignedUrlsResult(paths, 3600);
    return [
      for (final result in results.whereType<SignedUrlSuccess>())
        result.signedUrl,
    ];
  }

  @override
  Future<void> resolveReport(String reportId, {String? note}) async {
    await _guard(
      () => _client.rpc<List<dynamic>>(
        'resolve_report',
        params: {
          'p_report_id': reportId,
          if (note != null && note.isNotEmpty) 'p_note': note,
        },
      ),
    );
  }
}
