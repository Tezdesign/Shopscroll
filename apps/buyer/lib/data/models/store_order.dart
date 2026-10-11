/// The status of one store's part of an order (spec 0018). It is not the
/// buyer's [OrderStatus]: a store order can also be `returned`, and the buyer's
/// order screens stay untouched.
enum StoreOrderStatus { inProgress, delivered, canceled, returned }

/// Where the next page of the seller's order list starts: the last row's
/// `created_at` exactly as the server wrote it and its order id. The timestamp
/// stays a string on purpose, a Dart [DateTime] would drop microseconds and
/// the paging would repeat or skip a row (spec 0018).
class StoreOrderCursor {
  const StoreOrderCursor({required this.createdAt, required this.orderId});

  final String createdAt;
  final String orderId;
}

/// One row of the seller's Orders list: this store's part of an order, as
/// returned by `store_orders_list` (spec 0018, AC-2). [total] is this store's
/// lines only, never the whole order.
class StoreOrder {
  const StoreOrder({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.total,
    required this.currency,
    required this.createdAt,
    required this.createdAtRaw,
    this.customerName,
    this.city,
    this.address,
  });

  final String orderId;
  final int orderNumber;
  final StoreOrderStatus status;

  /// Null on orders placed before the contact details existed.
  final String? customerName;
  final String? city;
  final String? address;
  final double total;
  final String currency;
  final DateTime createdAt;

  /// [createdAt] as the server wrote it, kept for [cursor].
  final String createdAtRaw;

  StoreOrderCursor get cursor =>
      StoreOrderCursor(createdAt: createdAtRaw, orderId: orderId);

  /// The delivery place on one line, `city, address`, or only the part that
  /// exists. Empty when the order has neither.
  String get place => [
    city,
    address,
  ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

  factory StoreOrder.fromJson(Map<String, dynamic> json) {
    final raw = json['createdAt'] as String;
    return StoreOrder(
      orderId: json['orderId'] as String,
      orderNumber: json['orderNumber'] as int,
      status: StoreOrderStatus.values.byName(json['status'] as String),
      customerName: json['customerName'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      total: (json['total'] as num).toDouble(),
      currency: json['currency'] as String,
      createdAt: DateTime.parse(raw),
      createdAtRaw: raw,
    );
  }

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'orderNumber': orderNumber,
    'status': status.name,
    'customerName': customerName,
    'city': city,
    'address': address,
    'total': total,
    'currency': currency,
    'createdAt': createdAtRaw,
  };

  StoreOrder copyWith({
    StoreOrderStatus? status,
    String? customerName,
    String? city,
    String? address,
    double? total,
    String? currency,
  }) {
    return StoreOrder(
      orderId: orderId,
      orderNumber: orderNumber,
      status: status ?? this.status,
      customerName: customerName ?? this.customerName,
      city: city ?? this.city,
      address: address ?? this.address,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      createdAt: createdAt,
      createdAtRaw: createdAtRaw,
    );
  }
}

/// One line of an order, as this store sold it (spec 0018, AC-5). No other
/// store's lines ever reach the app.
class StoreOrderLine {
  const StoreOrderLine({
    required this.title,
    required this.unitPrice,
    required this.quantity,
    this.imageUrl,
    this.size,
    this.color,
  });

  final String title;
  final String? imageUrl;
  final String? size;

  /// The chosen color as an ARGB number, like the cart's `selectedColor`.
  final int? color;
  final double unitPrice;
  final int quantity;

  double get total => unitPrice * quantity;

  factory StoreOrderLine.fromJson(Map<String, dynamic> json) {
    return StoreOrderLine(
      title: json['title'] as String,
      imageUrl: json['imageUrl'] as String?,
      size: json['size'] as String?,
      color: json['color'] as int?,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      quantity: json['quantity'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'imageUrl': imageUrl,
    'size': size,
    'color': color,
    'unitPrice': unitPrice,
    'quantity': quantity,
  };
}

/// One order as the calling store sees it, from `store_order_detail` (spec
/// 0018, AC-5): this store's lines and subtotal, the customer's contact and the
/// delivery fields. It has no delivery fee and no whole order total, on
/// purpose. The contact and delivery fields are null on orders placed before
/// migration `0003`.
class StoreOrderDetail {
  const StoreOrderDetail({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.createdAt,
    required this.subtotal,
    required this.currency,
    required this.lines,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.city,
    this.address,
    this.zip,
    this.note,
    this.deliveryMethod,
    this.paymentMethod,
  });

  final String orderId;
  final int orderNumber;
  final StoreOrderStatus status;
  final DateTime createdAt;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? city;
  final String? address;
  final String? zip;
  final String? note;

  /// `standard` or `exclusive`.
  final String? deliveryMethod;

  /// `cashOnDelivery` or `card`.
  final String? paymentMethod;

  /// This store's lines only.
  final double subtotal;
  final String currency;
  final List<StoreOrderLine> lines;

  factory StoreOrderDetail.fromJson(Map<String, dynamic> json) {
    return StoreOrderDetail(
      orderId: json['orderId'] as String,
      orderNumber: json['orderNumber'] as int,
      status: StoreOrderStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      customerName: json['customerName'] as String?,
      customerEmail: json['customerEmail'] as String?,
      customerPhone: json['customerPhone'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      zip: json['zip'] as String?,
      note: json['note'] as String?,
      deliveryMethod: json['deliveryMethod'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      subtotal: (json['subtotal'] as num).toDouble(),
      currency: json['currency'] as String,
      lines: [
        for (final line in json['lines'] as List<dynamic>)
          StoreOrderLine.fromJson(line as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'orderNumber': orderNumber,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'customerName': customerName,
    'customerEmail': customerEmail,
    'customerPhone': customerPhone,
    'city': city,
    'address': address,
    'zip': zip,
    'note': note,
    'deliveryMethod': deliveryMethod,
    'paymentMethod': paymentMethod,
    'subtotal': subtotal,
    'currency': currency,
    'lines': [for (final line in lines) line.toJson()],
  };
}

/// One row of "Recent sales" on the Earnings tab (spec 0018, AC-7): a counted
/// store order with this store's amount.
class StoreRecentSale {
  const StoreRecentSale({
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    this.customerName,
    this.city,
    this.address,
  });

  final String orderId;
  final int orderNumber;
  final double amount;

  /// Null on orders placed before the contact details existed.
  final String? customerName;
  final String? city;
  final String? address;

  /// The delivery place on one line, `city, address`, or only the part that
  /// exists.
  String get place => [
    city,
    address,
  ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

  factory StoreRecentSale.fromJson(Map<String, dynamic> json) {
    return StoreRecentSale(
      orderId: json['orderId'] as String,
      orderNumber: json['orderNumber'] as int,
      customerName: json['customerName'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      amount: (json['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'orderNumber': orderNumber,
    'customerName': customerName,
    'city': city,
    'address': address,
    'amount': amount,
  };
}

/// The numbers on the Earnings tab, from `store_earnings` (spec 0018, AC-6 and
/// AC-7). A sale is a store order that is not canceled and not returned.
class StoreEarnings {
  const StoreEarnings({
    required this.totalSales,
    required this.todaySales,
    required this.todayOrders,
    required this.weekSales,
    required this.prevWeekSameSpanSales,
    required this.customers,
    required this.newCustomersToday,
    required this.currency,
    required this.recent,
  });

  final double totalSales;
  final double todaySales;
  final int todayOrders;
  final double weekSales;

  /// Last week's sales up to the same weekday and time, so the percent
  /// compares like with like.
  final double prevWeekSameSpanSales;
  final int customers;
  final int newCustomersToday;
  final String currency;
  final List<StoreRecentSale> recent;

  /// How much more (positive) or less (negative) this week sold than the same
  /// span of last week, as a whole percent. Null when last week had no sales.
  int? get weekChangePercent => prevWeekSameSpanSales == 0
      ? null
      : ((weekSales - prevWeekSameSpanSales) / prevWeekSameSpanSales * 100)
            .round();

  factory StoreEarnings.fromJson(Map<String, dynamic> json) {
    return StoreEarnings(
      totalSales: (json['totalSales'] as num).toDouble(),
      todaySales: (json['todaySales'] as num).toDouble(),
      todayOrders: json['todayOrders'] as int,
      weekSales: (json['weekSales'] as num).toDouble(),
      prevWeekSameSpanSales: (json['prevWeekSameSpanSales'] as num).toDouble(),
      customers: json['customers'] as int,
      newCustomersToday: json['newCustomersToday'] as int,
      currency: json['currency'] as String,
      recent: [
        for (final sale in json['recent'] as List<dynamic>)
          StoreRecentSale.fromJson(sale as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'totalSales': totalSales,
    'todaySales': todaySales,
    'todayOrders': todayOrders,
    'weekSales': weekSales,
    'prevWeekSameSpanSales': prevWeekSameSpanSales,
    'customers': customers,
    'newCustomersToday': newCustomersToday,
    'currency': currency,
    'recent': [for (final sale in recent) sale.toJson()],
  };
}
