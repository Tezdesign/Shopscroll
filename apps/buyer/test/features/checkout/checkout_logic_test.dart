import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/models/contact_info.dart';
import 'package:marketplace_app/data/models/place_order_request.dart';
import 'package:shopscroll_shared/models/shipping_address.dart';
import 'package:marketplace_app/data/repositories/order_repository.dart';
import 'package:marketplace_app/features/checkout/checkout_logic.dart';
import 'package:shopscroll_shared/widgets/country_dial_code.dart';

void main() {
  group('prices', () {
    test('moneyLabel writes whole dollars like the rest of the app', () {
      expect(moneyLabel(45), r'$45');
      expect(moneyLabel(0), r'$0');
    });

    test('orderTotal adds the fee, and treats no fee as zero (AC-8)', () {
      expect(orderTotal(45, 10), 55);
      expect(orderTotal(45, null), 45);
    });

    test('the two delivery methods carry their fee and days (AC-7)', () {
      expect(DeliveryMethod.standard.fee, 10);
      expect(DeliveryMethod.exclusive.fee, 16);
      expect(DeliveryMethod.standard.title, contains('5 to 6 working days'));
      expect(DeliveryMethod.exclusive.title, contains('1 to 2 working days'));
    });

    test('deliveryMethodOf reads stored names and ignores free text', () {
      expect(deliveryMethodOf('standard'), DeliveryMethod.standard);
      expect(deliveryMethodOf('exclusive'), DeliveryMethod.exclusive);
      expect(deliveryMethodOf('Express delivery'), isNull);
      expect(deliveryMethodOf(null), isNull);
    });
  });

  group('arrivalDate', () {
    // Friday 25 September 2026, 10:00 in Tunis (UTC+1).
    final friday = DateTime.utc(2026, 9, 25, 9);

    test('skips Saturday and Sunday', () {
      expect(arrivalDate(friday, 6), DateTime.utc(2026, 10, 5, 12));
      expect(arrivalDate(friday, 2), DateTime.utc(2026, 9, 29, 12));
    });

    test('counts on the Tunis calendar, not UTC', () {
      // 23:30 UTC on Friday is already Saturday 00:30 in Tunis.
      final lateFriday = DateTime.utc(2026, 9, 25, 23, 30);
      expect(arrivalDate(lateFriday, 1), DateTime.utc(2026, 9, 28, 12));
    });

    test('arrivalLabel writes the day and short month', () {
      expect(arrivalLabel(DateTime.utc(2026, 10, 5, 12)), '5 Oct');
      expect(arrivalLabel(DateTime.utc(2026, 5, 28, 12)), '28 May');
    });
  });

  group('names and numbers', () {
    test('orderNumberLabel pads to six digits', () {
      expect(orderNumberLabel(1), 'Order#000001');
      expect(orderNumberLabel(123456), 'Order#123456');
      expect(orderNumberLabel(null), 'Order');
    });

    test('firstNameOf is the first word (AC-17)', () {
      expect(firstNameOf('Moetez ben attia'), 'Moetez');
      expect(firstNameOf('  Sara  '), 'Sara');
    });

    test('newOrderId makes a version 4 id, different every time', () {
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final first = newOrderId();
      expect(pattern.hasMatch(first), isTrue);
      expect(newOrderId(), isNot(first));
    });

    test('placeOrderFailureMessage covers every reason (AC-13)', () {
      expect(
        placeOrderFailureMessage(PlaceOrderFailure.itemsChanged),
        'Some items changed. Check your cart.',
      );
      expect(
        placeOrderFailureMessage(PlaceOrderFailure.failed),
        "Couldn't place your order. Try again.",
      );
      expect(
        placeOrderFailureMessage(PlaceOrderFailure.invalid),
        "Couldn't place your order. Try again.",
      );
      expect(
        placeOrderFailureMessage(PlaceOrderFailure.cartEmpty),
        'Your cart is empty.',
      );
    });
  });

  group('field checks (AC-4, AC-6)', () {
    test('full name needs two characters and at most 120', () {
      expect(validateFullName('Sara Ben Ali'), isNull);
      expect(validateFullName(' A '), isNotNull);
      expect(validateFullName('a' * 121), isNotNull);
    });

    test('email needs a name, an @ and a domain', () {
      expect(validateEmail(' sara@example.com '), isNull);
      expect(validateEmail('sara@example'), isNotNull);
      expect(validateEmail('sara example@x.com'), isNotNull);
      expect(validateEmail(''), isNotNull);
    });

    test('phone is checked against the country plausible length', () {
      expect(validatePhone(tunisiaDialCode, '50 460 604'), isNull);
      expect(validatePhone(tunisiaDialCode, '12'), isNotNull);
      expect(validatePhone(tunisiaDialCode, ''), isNotNull);
    });

    test('required fields and zip', () {
      expect(validateRequired('  ', 'city'), 'Please enter your city.');
      expect(validateRequired('Tunis', 'city'), isNull);
      expect(validateZip('1000'), isNull);
      expect(validateZip('12'), isNotNull);
      expect(validateZip('1' * 13), isNotNull);
    });

    test('note is optional but capped at 300', () {
      expect(validateNote(''), isNull);
      expect(validateNote('n' * 300), isNull);
      expect(validateNote('n' * 301), isNotNull);
    });

    test('isContactValid and isAddressValid check the whole value', () {
      const contact = ContactInfo(
        name: 'Sara Ben Ali',
        email: 'sara@example.com',
        phone: '+21650460604',
      );
      expect(isContactValid(contact), isTrue);
      expect(isContactValid(contact.copyWith(email: 'nope')), isFalse);
      expect(isContactValid(contact.copyWith(phone: '123')), isFalse);

      const address = ShippingAddress(
        city: 'Tunis',
        address: '13 Bahloul Street',
        zip: '1000',
      );
      expect(isAddressValid(address), isTrue);
      expect(isAddressValid(address.copyWith(city: ' ')), isFalse);
      expect(isAddressValid(address.copyWith(zip: '1')), isFalse);
    });
  });

  group('splitPhone', () {
    test('takes the known dial code off the front', () {
      final tn = splitPhone('+21650460604');
      expect(tn.country.isoCode, 'TN');
      expect(tn.national, '50460604');

      final us = splitPhone('+1 (555) 123-4567');
      expect(us.country.dialCode, '+1');
      expect(us.national, '5551234567');
    });

    test('an empty or code less number starts on Tunisia', () {
      expect(splitPhone('').country, tunisiaDialCode);
      expect(splitPhone('50460604').national, '50460604');
    });

    test('tunisiaDialCode is the +216 entry of the picker list', () {
      expect(tunisiaDialCode.dialCode, '+216');
      expect(countryDialCodes, contains(tunisiaDialCode));
    });
  });
}
