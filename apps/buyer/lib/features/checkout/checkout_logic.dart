import 'package:shopscroll_shared/models/contact_info.dart';
import 'package:shopscroll_shared/models/ids.dart';
import 'package:shopscroll_shared/models/money.dart';
import '../../data/models/place_order_request.dart';
import 'package:shopscroll_shared/models/shipping_address.dart';
import '../../data/repositories/order_repository.dart';
import 'package:shopscroll_shared/widgets/country_dial_code.dart';

/// Plain checkout rules with no Flutter widgets, so they are easy to test
/// (spec 0009). The mock repository, the screens and the sheets all use
/// these, so the limits live in one place. The limits match the
/// `place_order` SQL function, which is the one that enforces them.

/// An amount written like the app's prices: `$45` or `89.000 TND`. The
/// currency is the one of the cart or the order; it defaults to the mock
/// catalog's (spec 0015, AC-19).
String moneyLabel(double amount, [String currency = 'USD']) =>
    Money.format(amount, currency);

double orderTotal(double subtotal, double? fee) => subtotal + (fee ?? 0);

extension DeliveryMethodLabels on DeliveryMethod {
  /// The tile text (Figma 3001:9851).
  String get title => switch (this) {
    DeliveryMethod.standard => 'Standard Delivery (in 5 to 6 working days)',
    DeliveryMethod.exclusive => 'Exclusive delivery (in 1 to 2 working days)',
  };

  /// The name on the confirmation (Figma 3001:10486).
  String get orderName => switch (this) {
    DeliveryMethod.standard => 'Standard shipping',
    DeliveryMethod.exclusive => 'Exclusive shipping',
  };
}

/// The delivery method an order holds, or null for the free text the older
/// mock orders carry.
DeliveryMethod? deliveryMethodOf(String? stored) {
  for (final method in DeliveryMethod.values) {
    if (method.name == stored) return method;
  }
  return null;
}

/// The date `workingDays` working days after [from] (Saturday and Sunday
/// skipped), counted on the Tunis calendar, which is UTC+1 all year. Returned
/// as noon UTC of that date so no time zone moves it to a neighbouring day.
DateTime arrivalDate(DateTime from, int workingDays) {
  final tunis = from.toUtc().add(const Duration(hours: 1));
  var day = DateTime.utc(tunis.year, tunis.month, tunis.day, 12);
  var left = workingDays;
  while (left > 0) {
    day = day.add(const Duration(days: 1));
    if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) {
      left--;
    }
  }
  return day;
}

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

/// `28 May`.
String arrivalLabel(DateTime date) {
  final utc = date.toUtc();
  return '${utc.day} ${_months[utc.month - 1]}';
}

/// `Order#000001`.
String orderNumberLabel(int? number) =>
    number == null ? 'Order' : 'Order#${number.toString().padLeft(6, '0')}';

/// The first word of a full name, for "Thank you for your order, Moetez!".
String firstNameOf(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  return parts.first;
}

/// A random version 4 id, made once per checkout (spec 0009, AC-12).
String newOrderId() => newUuid();

/// What Checkout says for each reason an order was not made (AC-13).
String placeOrderFailureMessage(PlaceOrderFailure reason) => switch (reason) {
  PlaceOrderFailure.itemsChanged => 'Some items changed. Check your cart.',
  PlaceOrderFailure.cartEmpty => 'Your cart is empty.',
  PlaceOrderFailure.outOfStock =>
    'An item you chose just sold out. Check your cart.',
  PlaceOrderFailure.mixedCurrency =>
    'Your cart has items in different currencies. Order them one currency at a time.',
  PlaceOrderFailure.invalid ||
  PlaceOrderFailure.failed => "Couldn't place your order. Try again.",
};

// Field checks. Each returns the message to show, or null when the value is
// fine. Limits: name, city and address up to 120, email up to 254, phone 6 to
// 20 characters with its dial code, zip 3 to 12, note up to 300.

String? validateFullName(String value) {
  final text = value.trim();
  if (text.length < 2) return 'Please enter your full name.';
  if (text.length > 120) return 'That name is too long.';
  return null;
}

String? validateEmail(String value) {
  final text = value.trim();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text) ||
      text.length > 254) {
    return 'Please enter a valid email address.';
  }
  return null;
}

String? validatePhone(CountryDialCode country, String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (!country.isPlausibleNationalNumber(digits)) {
    return 'Please enter a valid phone number.';
  }
  return null;
}

String? validateRequired(String value, String label) {
  final text = value.trim();
  if (text.isEmpty) return 'Please enter your $label.';
  if (text.length > 120) return 'That $label is too long.';
  return null;
}

String? validateZip(String value) {
  final text = value.trim();
  if (text.length < 3 || text.length > 12) {
    return 'Please enter a valid zip code.';
  }
  return null;
}

String? validateNote(String value) =>
    value.trim().length > 300 ? 'That note is too long.' : null;

/// Whole contact checks, for the mock repository (the SQL function does the
/// same on Supabase).
bool isContactValid(ContactInfo contact) {
  final digits = contact.phone.replaceAll(RegExp(r'\D'), '');
  return validateFullName(contact.name) == null &&
      validateEmail(contact.email) == null &&
      contact.phone.length >= 6 &&
      contact.phone.length <= 20 &&
      digits.isNotEmpty;
}

bool isAddressValid(ShippingAddress address) =>
    validateRequired(address.city, 'city') == null &&
    validateRequired(address.address, 'address') == null &&
    validateZip(address.zip) == null &&
    validateNote(address.note) == null;

/// The dial code a phone starts with (the longest match), and the rest of the
/// number. A number with no known code keeps the default country.
({CountryDialCode country, String national}) splitPhone(String full) {
  final text = full.replaceAll(RegExp(r'[\s()-]'), '');
  CountryDialCode? best;
  for (final country in countryDialCodes) {
    if (text.startsWith(country.dialCode) &&
        (best == null || country.dialCode.length > best.dialCode.length)) {
      best = country;
    }
  }
  if (best == null) return (country: tunisiaDialCode, national: text);
  return (country: best, national: text.substring(best.dialCode.length));
}

/// The country the contact sheet starts on: orders are delivered in Tunisia.
CountryDialCode get tunisiaDialCode => countryDialCodes.firstWhere(
  (country) => country.isoCode == 'TN',
  orElse: () => defaultCountryDialCode,
);
