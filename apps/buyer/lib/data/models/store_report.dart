/// The state of a problem report (spec 0018). It only ever goes from unsolved
/// to resolved, through `resolve_report`.
enum StoreReportStatus { unsolved, resolved }

/// Where the next page of the seller's report list starts: the last row's
/// `created_at` exactly as the server wrote it and its id. The timestamp stays a
/// string on purpose, a Dart [DateTime] would drop microseconds and the paging
/// would repeat or skip a row (spec 0018).
class StoreReportCursor {
  const StoreReportCursor({required this.createdAt, required this.id});

  final String createdAt;
  final String id;
}

/// `#R-0001`: the report number with 4 digits (spec 0018, AC-9).
String reportNumberLabel(int number) =>
    '#R-${number.toString().padLeft(4, '0')}';

/// The three numbers on top of the Reports tab, from `store_reports_summary`
/// (spec 0018, AC-8).
class StoreReportsSummary {
  const StoreReportsSummary({
    required this.total,
    required this.newToday,
    required this.unresolved,
    required this.returnedOrders,
  });

  final int total;
  final int newToday;
  final int unresolved;

  /// This store's orders with status returned, not reports.
  final int returnedOrders;

  factory StoreReportsSummary.fromJson(Map<String, dynamic> json) {
    return StoreReportsSummary(
      total: json['total'] as int,
      newToday: json['newToday'] as int,
      unresolved: json['unresolved'] as int,
      returnedOrders: json['returnedOrders'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'newToday': newToday,
    'unresolved': unresolved,
    'returnedOrders': returnedOrders,
  };

  StoreReportsSummary copyWith({int? unresolved}) => StoreReportsSummary(
    total: total,
    newToday: newToday,
    unresolved: unresolved ?? this.unresolved,
    returnedOrders: returnedOrders,
  );
}

/// One row of the seller's Reports list, from `store_reports_list` (spec 0018,
/// AC-9).
class StoreReport {
  const StoreReport({
    required this.id,
    required this.reportNumber,
    required this.status,
    required this.title,
    required this.description,
    required this.orderNumber,
    required this.itemCount,
    required this.createdAt,
    required this.createdAtRaw,
    this.customerName,
    this.firstItemTitle,
  });

  final String id;
  final int reportNumber;
  final StoreReportStatus status;
  final String title;
  final String description;

  /// Null on orders placed before the contact details existed.
  final String? customerName;
  final String? firstItemTitle;
  final int itemCount;
  final int orderNumber;
  final DateTime createdAt;

  /// [createdAt] as the server wrote it, kept for [cursor].
  final String createdAtRaw;

  StoreReportCursor get cursor =>
      StoreReportCursor(createdAt: createdAtRaw, id: id);

  factory StoreReport.fromJson(Map<String, dynamic> json) {
    final raw = json['createdAt'] as String;
    return StoreReport(
      id: json['id'] as String,
      reportNumber: json['reportNumber'] as int,
      status: StoreReportStatus.values.byName(json['status'] as String),
      title: json['title'] as String,
      description: json['description'] as String,
      customerName: json['customerName'] as String?,
      firstItemTitle: json['firstItemTitle'] as String?,
      itemCount: json['itemCount'] as int,
      orderNumber: json['orderNumber'] as int,
      createdAt: DateTime.parse(raw),
      createdAtRaw: raw,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reportNumber': reportNumber,
    'status': status.name,
    'title': title,
    'description': description,
    'customerName': customerName,
    'firstItemTitle': firstItemTitle,
    'itemCount': itemCount,
    'orderNumber': orderNumber,
    'createdAt': createdAtRaw,
  };

  StoreReport copyWith({StoreReportStatus? status}) {
    return StoreReport(
      id: id,
      reportNumber: reportNumber,
      status: status ?? this.status,
      title: title,
      description: description,
      customerName: customerName,
      firstItemTitle: firstItemTitle,
      itemCount: itemCount,
      orderNumber: orderNumber,
      createdAt: createdAt,
      createdAtRaw: createdAtRaw,
    );
  }
}

/// One product of a report, as the order line sold it.
class StoreReportItem {
  const StoreReportItem({required this.title, this.imageUrl});

  final String title;
  final String? imageUrl;

  factory StoreReportItem.fromJson(Map<String, dynamic> json) {
    return StoreReportItem(
      title: json['title'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'title': title, 'imageUrl': imageUrl};
}

/// One report in full, from `store_report_detail` (spec 0018, AC-10). The
/// reporter's account id never reaches the app. [attachmentPaths] are storage
/// paths, turned into signed links by the repository.
class StoreReportDetail {
  const StoreReportDetail({
    required this.id,
    required this.reportNumber,
    required this.status,
    required this.title,
    required this.description,
    required this.orderNumber,
    required this.createdAt,
    required this.purchasedAt,
    required this.items,
    required this.attachmentPaths,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
  });

  final String id;
  final int reportNumber;
  final StoreReportStatus status;
  final String title;
  final String description;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final int orderNumber;
  final DateTime createdAt;

  /// When the order was placed.
  final DateTime purchasedAt;
  final List<StoreReportItem> items;
  final List<String> attachmentPaths;

  factory StoreReportDetail.fromJson(Map<String, dynamic> json) {
    return StoreReportDetail(
      id: json['id'] as String,
      reportNumber: json['reportNumber'] as int,
      status: StoreReportStatus.values.byName(json['status'] as String),
      title: json['title'] as String,
      description: json['description'] as String,
      customerName: json['customerName'] as String?,
      customerEmail: json['customerEmail'] as String?,
      customerPhone: json['customerPhone'] as String?,
      orderNumber: json['orderNumber'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      purchasedAt: DateTime.parse(json['purchasedAt'] as String),
      items: [
        for (final item in json['items'] as List<dynamic>)
          StoreReportItem.fromJson(item as Map<String, dynamic>),
      ],
      attachmentPaths: [
        for (final path in json['attachmentPaths'] as List<dynamic>)
          path as String,
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reportNumber': reportNumber,
    'status': status.name,
    'title': title,
    'description': description,
    'customerName': customerName,
    'customerEmail': customerEmail,
    'customerPhone': customerPhone,
    'orderNumber': orderNumber,
    'createdAt': createdAt.toIso8601String(),
    'purchasedAt': purchasedAt.toIso8601String(),
    'items': [for (final item in items) item.toJson()],
    'attachmentPaths': attachmentPaths,
  };

  StoreReportDetail copyWith({StoreReportStatus? status}) {
    return StoreReportDetail(
      id: id,
      reportNumber: reportNumber,
      status: status ?? this.status,
      title: title,
      description: description,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      orderNumber: orderNumber,
      createdAt: createdAt,
      purchasedAt: purchasedAt,
      items: items,
      attachmentPaths: attachmentPaths,
    );
  }
}
