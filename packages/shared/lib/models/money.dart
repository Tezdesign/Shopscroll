/// Price text for the app (spec 0015, AC-9). A product carries its own
/// currency; this turns an amount into the label a person reads and back.
///
/// Amounts travel to the server as text with 3 decimals (`toWire`), because
/// the database stores `numeric(12,3)` and a Dart `double` can drift.
class Money {
  const Money._();

  /// `USD` keeps the app's older whole dollar look (`$40`), `TND` shows its
  /// 3 decimals (`89.000 TND`), any other code shows 2 decimals and the code.
  static String format(double amount, String currency) {
    switch (currency) {
      case 'USD':
        return '\$${amount.toStringAsFixed(0)}';
      case 'TND':
        return '${amount.toStringAsFixed(3)} TND';
      default:
        return '${amount.toStringAsFixed(2)} $currency';
    }
  }

  /// The text sent to the server, always 3 decimals: `89.000`.
  static String toWire(double amount) => amount.toStringAsFixed(3);

  /// Reads what a person typed: `89`, `89.5`, `89,500`. Returns null for empty
  /// text, a negative sign, letters, or more than 3 decimals. Does not check
  /// that the amount is above 0, the caller decides that.
  static double? tryParse(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,8}(\.\d{1,3})?$').hasMatch(cleaned)) return null;
    return double.parse(cleaned);
  }
}
