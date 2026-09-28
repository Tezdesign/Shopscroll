import '../../data/models/conversation.dart';
import '../../data/models/order.dart';
import '../../data/models/saved_product.dart';
import '../../data/models/saved_reel.dart';

/// Plain functions for the Activity screens, with no Flutter code, so they
/// are easy to test (spec 0008).

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The search text, trimmed and lower cased, as every filter below reads it.
String normalizeQuery(String query) => query.trim().toLowerCase();

bool _matches(String query, Iterable<String> fields) {
  final q = normalizeQuery(query);
  return q.isEmpty || fields.any((f) => f.toLowerCase().contains(q));
}

/// Purchases match on any item's title or store name (AC-2).
List<Order> filterOrders(List<Order> orders, String query) => [
  for (final order in orders)
    if (_matches(query, [
      for (final item in order.items) ...[
        item.product.title,
        item.product.storeName,
      ],
    ]))
      order,
];

/// Saved products match on title or store name (AC-2).
List<SavedProduct> filterSavedProducts(
  List<SavedProduct> saved,
  String query,
) => [
  for (final s in saved)
    if (_matches(query, [s.product.title, s.product.storeName])) s,
];

/// Saved reels match on caption or store name (AC-2).
List<SavedReel> filterSavedReels(List<SavedReel> saved, String query) => [
  for (final s in saved)
    if (_matches(query, [s.reel.caption, s.reel.storeName])) s,
];

/// Conversations match on store name or last message (AC-2).
List<Conversation> filterConversations(
  List<Conversation> conversations,
  String query,
) => [
  for (final c in conversations)
    if (_matches(query, [c.storeName, c.lastMessage])) c,
];

/// Newest first, without changing the list it is given (AC-3).
List<Order> newestOrdersFirst(List<Order> orders) =>
    [...orders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

/// Newest first, without changing the list it is given (AC-11).
List<Conversation> newestConversationsFirst(List<Conversation> all) =>
    [...all]..sort((a, b) => b.sentAt.compareTo(a.sentAt));

/// Day and short month, like `27 Feb`, plus the year when it is not the
/// current one (AC-3).
String orderDateLabel(DateTime date, DateTime now) {
  final label = '${date.day} ${_months[date.month - 1]}';
  return date.year == now.year ? label : '$label ${date.year}';
}

/// `4:25am` when sent today, `27 Feb` otherwise (AC-11).
String messageTimeLabel(DateTime sentAt, DateTime now) {
  final today =
      sentAt.year == now.year &&
      sentAt.month == now.month &&
      sentAt.day == now.day;
  if (!today) return '${sentAt.day} ${_months[sentAt.month - 1]}';
  final hour = sentAt.hour % 12 == 0 ? 12 : sentAt.hour % 12;
  final minute = sentAt.minute.toString().padLeft(2, '0');
  return '$hour:$minute${sentAt.hour < 12 ? 'am' : 'pm'}';
}

/// "+ 1 products" for the items past the two shown, or null when there are
/// no more (AC-3). The wording keeps the plural the frame uses.
String? extraProductsLabel(Order order) {
  final extra = order.items.length - 2;
  return extra > 0 ? '+ $extra products' : null;
}

/// Whole dollars, like `$320` (AC-3).
String orderTotalLabel(Order order) =>
    '\$${order.totalAmount.toStringAsFixed(0)}';
