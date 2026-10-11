import '../../models/store_order.dart';
import '../../models/store_report.dart';
import '../../providers/network_delay.dart';
import '../store_activity_repository.dart';

/// Keeps the seller's Activity data in memory, so the screens run with no
/// backend (spec 0018, AC-15). The orders carry the values drawn in the Figma
/// frames (`Order#002545`, `Sousse,sahloul`, 450) with a few other names so
/// search and paging have something to work on. Filter, search and paging
/// follow `store_orders_list` in `supabase/migrations/0014_store_orders.sql`,
/// so both backends behave the same to the screens.
class MockStoreActivityRepository implements StoreActivityRepository {
  MockStoreActivityRepository({DateTime? now})
    : _orders = _seed(now),
      _reports = _seedReports(now);

  final List<StoreOrder> _orders;

  /// Newest first. Resolving changes the entry in place, so the list, the
  /// summary and the detail stay in step.
  final List<StoreReportDetail> _reports;

  static const _statuses = [
    StoreOrderStatus.delivered,
    StoreOrderStatus.inProgress,
    StoreOrderStatus.delivered,
    StoreOrderStatus.delivered,
    StoreOrderStatus.canceled,
    StoreOrderStatus.inProgress,
    StoreOrderStatus.inProgress,
    StoreOrderStatus.canceled,
    StoreOrderStatus.returned,
  ];

  static const _names = [
    'Moetez ben attia',
    'Moetez ben attia',
    'Amel Trabelsi',
    'Moetez ben attia',
    'Yassine Gharbi',
    null,
  ];

  /// 30 orders, newest first, an hour apart.
  static List<StoreOrder> _seed(DateTime? now) {
    final start = (now ?? DateTime.now()).toUtc();
    return [
      for (var i = 0; i < 30; i++)
        () {
          final at = start.subtract(Duration(hours: i));
          final name = _names[i % _names.length];
          return StoreOrder(
            orderId: 'mock-order-${(2545 - i).toString().padLeft(6, '0')}',
            orderNumber: 2545 - i,
            status: _statuses[i % _statuses.length],
            customerName: name,
            // Orders from before the contact details existed have no place.
            city: name == null ? null : 'Sousse',
            address: name == null ? null : 'sahloul',
            total: 450,
            currency: 'TND',
            createdAt: at,
            createdAtRaw: at.toIso8601String(),
          );
        }(),
    ];
  }

  @override
  Future<List<StoreOrder>> listOrders({
    StoreOrderStatus? status,
    String search = '',
    int limit = 20,
    StoreOrderCursor? after,
  }) async {
    await Future.delayed(mockNetworkDelay);
    final text = search.trim().toLowerCase();
    final digits = text.replaceFirst(RegExp(r'^0+'), '');

    var rows = _orders.where((order) {
      if (status != null && order.status != status) return false;
      if (text.isEmpty) return true;
      final name = order.customerName?.toLowerCase();
      return (digits.isNotEmpty && '${order.orderNumber}'.contains(digits)) ||
          (name != null && name.contains(text));
    }).toList();

    if (after != null) {
      final at = rows.indexWhere((order) => order.orderId == after.orderId);
      rows = at < 0 ? [] : rows.sublist(at + 1);
    }
    return rows.take(limit.clamp(1, 50)).toList();
  }

  /// Two lines that add up to the order's 450, so the detail agrees with the
  /// list. An order with no contact name (placed before the contact details
  /// existed) has no contact or delivery fields.
  @override
  Future<StoreOrderDetail> orderDetail(String orderId) async {
    await Future.delayed(mockNetworkDelay);
    final order = _orders.where((o) => o.orderId == orderId).firstOrNull;
    if (order == null) throw const StoreActivityException('not_found');
    final contact = order.customerName != null;
    return StoreOrderDetail(
      orderId: order.orderId,
      orderNumber: order.orderNumber,
      status: order.status,
      createdAt: order.createdAt,
      customerName: order.customerName,
      customerEmail: contact ? 'customer@example.com' : null,
      customerPhone: contact ? '+216 20 123 456' : null,
      city: order.city,
      address: order.address,
      zip: contact ? '4054' : null,
      note: contact ? 'Call before delivery' : null,
      deliveryMethod: contact ? 'standard' : null,
      paymentMethod: contact ? 'cashOnDelivery' : null,
      subtotal: order.total,
      currency: order.currency,
      lines: const [
        StoreOrderLine(
          title: 'Wrap dress',
          size: 'M',
          color: 0xFF0066FF,
          unitPrice: 150,
          quantity: 2,
        ),
        StoreOrderLine(title: 'Linen shirt', unitPrice: 150, quantity: 1),
      ],
    );
  }

  /// The values drawn in the Figma Earnings frame (3001:11790).
  @override
  Future<StoreEarnings> earnings() async {
    await Future.delayed(mockNetworkDelay);
    return const StoreEarnings(
      totalSales: 478458,
      todaySales: 12426,
      todayOrders: 6,
      weekSales: 90458,
      // 90458 is 32% above this.
      prevWeekSameSpanSales: 68529,
      customers: 125,
      newCustomersToday: 5,
      currency: 'TND',
      recent: [
        StoreRecentSale(
          orderId: 'mock-order-002545',
          orderNumber: 2545,
          customerName: 'Moetez ben attia',
          city: 'Sousse',
          address: 'sahloul',
          amount: 450,
        ),
        StoreRecentSale(
          orderId: 'mock-order-002544',
          orderNumber: 2544,
          customerName: 'Moetez ben attia',
          city: 'Sousse',
          address: 'sahloul',
          amount: 520,
        ),
        StoreRecentSale(
          orderId: 'mock-order-002543',
          orderNumber: 2543,
          customerName: 'Moetez ben attia',
          city: 'Sousse',
          address: 'sahloul',
          amount: 600,
        ),
        StoreRecentSale(
          orderId: 'mock-order-002542',
          orderNumber: 2542,
          customerName: 'Moetez ben attia',
          city: 'Sousse',
          address: 'sahloul',
          amount: 600,
        ),
      ],
    );
  }

  /// 25 reports, newest first, 5 hours apart. The first one is the card drawn
  /// in the Figma Reports frame (3001:11908): `#R-2589`, Emily Richardson,
  /// SoundPro Wireless Earbuds. Every third report holds three products, every
  /// fourth is resolved and every fifth comes from an order with no contact.
  static List<StoreReportDetail> _seedReports(DateTime? now) {
    final start = (now ?? DateTime.now()).toUtc();
    return [
      for (var i = 0; i < 25; i++)
        () {
          final at = start.subtract(Duration(hours: 5 * i));
          final contact = i % 5 != 4;
          return StoreReportDetail(
            id: 'mock-report-${(2589 - i).toString().padLeft(4, '0')}',
            reportNumber: 2589 - i,
            status: i % 4 == 3
                ? StoreReportStatus.resolved
                : StoreReportStatus.unsolved,
            title: 'Product Quality Issue',
            description:
                'Right earbud not charging properly. Customer received the '
                'product yesterday and is requesting a replacement.',
            customerName: contact ? 'Emily Richardson' : null,
            customerEmail: contact ? 'emily@example.com' : null,
            customerPhone: contact ? '+216 50 460 604' : null,
            orderNumber: 2545 - i,
            createdAt: at,
            purchasedAt: at.subtract(const Duration(days: 1)),
            items: [
              _item('SoundPro Wireless Earbuds', 'soundpro'),
              if (i % 3 == 1) ...[
                _item('Earbuds case', 'earbuds-case'),
                _item('Charging cable', 'charging-cable'),
              ],
            ],
            attachmentPaths: i < 3
                ? [
                    'mock-store/mock-report-${2589 - i}/a.png',
                    'mock-store/mock-report-${2589 - i}/b.png',
                  ]
                : const [],
          );
        }(),
    ];
  }

  static StoreReportItem _item(String title, String seed) => StoreReportItem(
    title: title,
    imageUrl: 'https://picsum.photos/seed/$seed/100/100',
  );

  StoreReport _row(StoreReportDetail d) => StoreReport(
    id: d.id,
    reportNumber: d.reportNumber,
    status: d.status,
    title: d.title,
    description: d.description,
    customerName: d.customerName,
    firstItemTitle: d.items.firstOrNull?.title,
    itemCount: d.items.length,
    orderNumber: d.orderNumber,
    createdAt: d.createdAt,
    createdAtRaw: d.createdAt.toIso8601String(),
  );

  /// Counts follow the in memory reports and orders, like
  /// `store_reports_summary` follows the tables.
  @override
  Future<StoreReportsSummary> reportsSummary() async {
    await Future.delayed(mockNetworkDelay);
    final now = DateTime.now();
    bool today(DateTime at) {
      final local = at.toLocal();
      return local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
    }

    return StoreReportsSummary(
      total: _reports.length,
      newToday: _reports.where((r) => today(r.createdAt)).length,
      unresolved: _reports
          .where((r) => r.status == StoreReportStatus.unsolved)
          .length,
      returnedOrders: _orders
          .where((o) => o.status == StoreOrderStatus.returned)
          .length,
    );
  }

  /// Filter, search and paging follow `store_reports_list` in
  /// `supabase/migrations/0017_reports.sql`.
  @override
  Future<List<StoreReport>> listReports({
    StoreReportStatus? status,
    String search = '',
    int limit = 20,
    StoreReportCursor? after,
  }) async {
    await Future.delayed(mockNetworkDelay);
    final text = search.trim().toLowerCase();
    final digits = text.replaceFirst(RegExp(r'^0+'), '');

    var rows = _reports.where((report) {
      if (status != null && report.status != status) return false;
      if (text.isEmpty) return true;
      final name = report.customerName?.toLowerCase();
      return (digits.isNotEmpty && '${report.reportNumber}'.contains(digits)) ||
          report.title.toLowerCase().contains(text) ||
          (name != null && name.contains(text));
    }).toList();

    if (after != null) {
      final at = rows.indexWhere((report) => report.id == after.id);
      rows = at < 0 ? [] : rows.sublist(at + 1);
    }
    return rows.take(limit.clamp(1, 50)).map(_row).toList();
  }

  @override
  Future<StoreReportDetail> reportDetail(String reportId) async {
    await Future.delayed(mockNetworkDelay);
    final report = _reports.where((r) => r.id == reportId).firstOrNull;
    if (report == null) throw const StoreActivityException('not_found');
    return report;
  }

  /// Placeholder photos, one per path.
  @override
  Future<List<String>> attachmentUrls(List<String> paths) async {
    await Future.delayed(mockNetworkDelay);
    return [
      for (final path in paths)
        'https://picsum.photos/seed/${path.replaceAll('/', '-')}/200/200',
    ];
  }

  @override
  Future<void> resolveReport(String reportId, {String? note}) async {
    await Future.delayed(mockNetworkDelay);
    final at = _reports.indexWhere((r) => r.id == reportId);
    if (at < 0) throw const StoreActivityException('not_found');
    _reports[at] = _reports[at].copyWith(status: StoreReportStatus.resolved);
  }
}
