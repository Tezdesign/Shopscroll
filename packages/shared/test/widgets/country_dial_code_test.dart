import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/widgets/country_dial_code.dart';

void main() {
  test('every entry is a plausible ISO code and E.164 prefix', () {
    final isoPattern = RegExp(r'^[A-Z]{2}$');
    final dialPattern = RegExp(r'^\+\d{1,4}$');
    for (final country in countryDialCodes) {
      expect(country.isoCode, matches(isoPattern), reason: country.name);
      expect(country.dialCode, matches(dialPattern), reason: country.name);
      expect(country.name, isNotEmpty);
    }
  });

  test('no country is listed twice', () {
    final isoCodes = countryDialCodes.map((country) => country.isoCode);
    expect(isoCodes.toSet(), hasLength(countryDialCodes.length));
  });

  test('the list is sorted by name, as the picker shows it', () {
    // Alphabetical the way a reader expects, so an accented name sorts with
    // its plain letter (Côte between Costa Rica and Croatia) rather than
    // after Z, where a raw code unit sort would put it.
    const accents = {
      'ã': 'a',
      'ç': 'c',
      'é': 'e',
      'í': 'i',
      'ô': 'o',
      'ü': 'u',
    };
    String fold(String name) => accents.entries.fold(
      name.toLowerCase(),
      (folded, accent) => folded.replaceAll(accent.key, accent.value),
    );

    final names = countryDialCodes.map((country) => country.name).toList();
    expect(
      names,
      orderedEquals([...names]..sort((a, b) => fold(a).compareTo(fold(b)))),
    );
  });

  test('the default is the +1 the Figma frames show', () {
    expect(defaultCountryDialCode.dialCode, '+1');
    expect(countryDialCodes, contains(defaultCountryDialCode));
  });

  test('flag is the ISO code shifted into the regional indicator block', () {
    expect(defaultCountryDialCode.flag, '🇺🇸');
    expect(const CountryDialCode('TN', '+216', 'Tunisia').flag, '🇹🇳');
  });

  group('isPlausibleNationalNumber', () {
    const unitedStates = defaultCountryDialCode; // +1, so 14 digits of room
    const tokelau = CountryDialCode('TK', '+690', 'Tokelau');

    test('rejects a number too short to be anyone\'s', () {
      expect(unitedStates.isPlausibleNationalNumber('123'), isFalse);
      expect(unitedStates.isPlausibleNationalNumber(''), isFalse);
    });

    test('accepts the short national numbers small plans really use', () {
      expect(tokelau.isPlausibleNationalNumber('1234'), isTrue);
    });

    test('rejects a number past the 15 digit E.164 cap', () {
      expect(unitedStates.isPlausibleNationalNumber('9' * 14), isTrue);
      expect(unitedStates.isPlausibleNationalNumber('9' * 15), isFalse);
    });

    test('leaves less room to a country with a longer dial code', () {
      expect(unitedStates.maxNationalDigits, 14);
      expect(tokelau.maxNationalDigits, 12);
    });

    test('accepts an ordinary number for every country in the list', () {
      for (final country in countryDialCodes) {
        expect(
          country.isPlausibleNationalNumber('5551234'),
          isTrue,
          reason: country.name,
        );
      }
    });
  });

  group('matches', () {
    const tunisia = CountryDialCode('TN', '+216', 'Tunisia');

    test('takes an empty query as everything', () {
      expect(tunisia.matches(''), isTrue);
      expect(tunisia.matches('  '), isTrue);
    });

    test('finds a name case insensitively, anywhere in it', () {
      expect(tunisia.matches('tun'), isTrue);
      expect(tunisia.matches('NISI'), isTrue);
      expect(tunisia.matches('Morocco'), isFalse);
    });

    test('finds an ISO code', () {
      expect(tunisia.matches('tn'), isTrue);
      expect(tunisia.matches('ma'), isFalse);
    });

    test('finds a dial code typed with or without the plus', () {
      expect(tunisia.matches('+216'), isTrue);
      expect(tunisia.matches('216'), isTrue);
      expect(tunisia.matches('44'), isFalse);
    });
  });
}
