import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/features/onboarding/sign_up_verification.dart';

void main() {
  group('describeOutstandingFields', () {
    test('turns Clerk field names into readable words', () {
      expect(
        describeOutstandingFields(['phone_number', 'email_address']),
        'phone number, email address',
      );
    });

    test('drops a field listed as both missing and unverified', () {
      expect(
        describeOutstandingFields(['phone_number', 'phone_number']),
        'phone number',
      );
    });

    test('is empty when nothing is outstanding', () {
      expect(describeOutstandingFields([]), isEmpty);
    });
  });

  group('splitFullName', () {
    test('splits on the first space', () {
      expect(splitFullName('Ada Lovelace').firstName, 'Ada');
      expect(splitFullName('Ada Lovelace').lastName, 'Lovelace');
    });

    test('keeps every later part in the last name', () {
      expect(splitFullName('Ada King Lovelace').lastName, 'King Lovelace');
    });

    test('leaves the last name null for a single word', () {
      expect(splitFullName('Ada').firstName, 'Ada');
      expect(splitFullName('Ada').lastName, isNull);
    });

    test('gives both as null for nothing usable', () {
      for (final value in [null, '', '   ']) {
        expect(splitFullName(value).firstName, isNull, reason: '$value');
        expect(splitFullName(value).lastName, isNull, reason: '$value');
      }
    });

    test('ignores extra whitespace', () {
      expect(splitFullName('  Ada   Lovelace  ').firstName, 'Ada');
      expect(splitFullName('  Ada   Lovelace  ').lastName, 'Lovelace');
    });
  });
}
