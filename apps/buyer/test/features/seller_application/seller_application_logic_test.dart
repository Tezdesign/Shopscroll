import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/repositories/seller_application_repository.dart';
import 'package:marketplace_app/features/seller_application/seller_application_logic.dart';
import 'package:shopscroll_shared/models/seller_application.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:shopscroll_shared/widgets/country_dial_code.dart';

SellerApplication application(SellerApplicationStatus status) =>
    SellerApplication(
      id: 'a1',
      applicantId: 'u1',
      status: status,
      storeName: 'Shop',
      username: 'shop',
      location: 'Tunis',
      idDocumentPath: 'u1/a1/id.jpg',
      createdAt: DateTime(2026, 6, 25),
    );

void main() {
  test('store name takes 2 to 60 characters after trimming', () {
    expect(validateStoreName(' a '), isNotNull);
    expect(validateStoreName('ab'), isNull);
    expect(validateStoreName('x' * 60), isNull);
    expect(validateStoreName('x' * 61), isNotNull);
    expect(validateStoreName(null), isNotNull);
  });

  test('username takes 3 to 30 lowercase letters, digits, _ and .', () {
    expect(validateUsername('my_shop.1'), isNull);
    expect(validateUsername('ab'), isNotNull);
    expect(validateUsername('x' * 31), isNotNull);
    expect(validateUsername('My_shop'), isNotNull);
    expect(validateUsername('my shop'), isNotNull);
    expect(validateUsername('my-shop'), isNotNull);
  });

  test('location is required and bio stops at 280', () {
    expect(validateLocation('  '), isNotNull);
    expect(validateLocation('Tunis'), isNull);
    expect(validateBio('b' * 280), isNull);
    expect(validateBio('b' * 281), isNotNull);
    expect(validateBio(null), isNull);
  });

  test('only JPEG and PNG photos up to 5 MB pass', () {
    expect(checkPhoto(fileName: 'a.JPG', bytes: 10), isNull);
    expect(checkPhoto(fileName: 'a.jpeg', bytes: 10), isNull);
    expect(checkPhoto(fileName: 'a.png', bytes: maxPhotoBytes), isNull);
    expect(checkPhoto(fileName: 'a.png', bytes: maxPhotoBytes + 1), isNotNull);
    expect(checkPhoto(fileName: 'a.gif', bytes: 10), isNotNull);
    expect(checkPhoto(fileName: 'a.heic', bytes: 10), isNotNull);
    expect(checkPhoto(fileName: 'noextension', bytes: 10), isNotNull);
    expect(photoExtension('a.JPEG'), 'jpg');
    expect(photoExtension('a.png'), 'png');
  });

  test('submitted label is dd/mm/yyyy', () {
    expect(submittedLabel(DateTime(2025, 6, 25)), 'Submitted 25/06/2025');
    expect(submittedLabel(DateTime(2026, 1, 5)), 'Submitted 05/01/2026');
  });

  group('canSubmitNewApplication', () {
    test('a buyer with none, or only decided ones, can', () {
      expect(canSubmitNewApplication([], UserRole.buyer), isTrue);
      expect(canSubmitNewApplication([], null), isTrue);
      expect(
        canSubmitNewApplication([
          application(SellerApplicationStatus.rejected),
        ], UserRole.buyer),
        isTrue,
      );
    });

    test('not while one is reviewing', () {
      expect(
        canSubmitNewApplication([
          application(SellerApplicationStatus.reviewing),
        ], UserRole.buyer),
        isFalse,
      );
    });

    test('never for a seller', () {
      expect(canSubmitNewApplication([], UserRole.seller), isFalse);
    });
  });

  test('every failure has a message', () {
    for (final reason in SellerApplicationFailure.values) {
      expect(sellerApplicationFailureMessage(reason), isNotEmpty);
    }
  });

  group('About you checks for a visitor (spec 0014, AC-7)', () {
    test('name is 2 to 60 characters after trimming', () {
      expect(validateApplicantName('V'), isNotNull);
      expect(validateApplicantName('  V  '), isNotNull);
      expect(validateApplicantName(null), isNotNull);
      expect(validateApplicantName('Vi'), isNull);
      expect(validateApplicantName('x' * 60), isNull);
      expect(validateApplicantName('x' * 61), isNotNull);
    });

    test('email needs an @ and a dot in the domain', () {
      expect(validateApplicantEmail('a@b.co'), isNull);
      expect(validateApplicantEmail(' a@b.co '), isNull);
      for (final bad in ['', 'a', 'a@b', 'a@b.', '@b.co', 'a b@c.co']) {
        expect(validateApplicantEmail(bad), isNotNull, reason: bad);
      }
      expect(validateApplicantEmail('${'a' * 197}@b.co'), isNotNull);
    });

    test('the personal email is optional but must look like an email', () {
      for (final empty in [null, '', '   ']) {
        expect(validatePersonalEmail(empty), isNull);
      }
      expect(validatePersonalEmail(' a@b.co '), isNull);
      for (final bad in ['a', 'a@b', 'a b@c.co']) {
        expect(validatePersonalEmail(bad), isNotNull, reason: bad);
      }
      expect(validatePersonalEmail('${'a' * 197}@b.co'), isNotNull);
    });

    test('phone joins the picked dial code and the digits typed', () {
      const tunisia = CountryDialCode('TN', '+216', 'Tunisia');
      expect(internationalPhone(tunisia, '12 345-678'), '+21612345678');
      // One leading national 0 is dropped, as Clerk stores the number.
      const france = CountryDialCode('FR', '+33', 'France');
      expect(internationalPhone(france, '06 12 34 56 78'), '+33612345678');
      expect(internationalPhone(france, '612345678'), '+33612345678');
      expect(internationalPhone(france, '006 12'), '+330612');
      // Italy keeps it: Italian numbers can start with 0.
      const italy = CountryDialCode('IT', '+39', 'Italy');
      expect(internationalPhone(italy, '06 1234 5678'), '+390612345678');
      expect(validateApplicantPhone(tunisia, '12 345 678'), isNull);
      expect(validateApplicantPhone(tunisia, '123'), isNotNull);
      expect(validateApplicantPhone(tunisia, ''), isNotNull);
    });
  });

  test('useAccount tells a signed in person to apply from Settings', () {
    expect(
      sellerApplicationFailureMessage(SellerApplicationFailure.useAccount),
      contains('Settings'),
    );
  });
}
