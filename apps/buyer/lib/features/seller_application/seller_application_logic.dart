import 'package:shopscroll_shared/models/seller_application.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:shopscroll_shared/widgets/country_dial_code.dart';

import '../../data/repositories/seller_application_repository.dart';

// Field checks. Each returns the message to show, or null when the value is
// fine. They mirror the `submit_seller_application` SQL function (spec 0013,
// AC-3), which is the truth: these only save a round trip.

String? validateStoreName(String? value) {
  final length = (value ?? '').trim().length;
  if (length < 2 || length > 60) return 'Use 2 to 60 characters.';
  return null;
}

final _usernamePattern = RegExp(r'^[a-z0-9_.]{3,30}$');

String? validateUsername(String? value) {
  if (!_usernamePattern.hasMatch(value ?? '')) {
    return 'Use 3 to 30 lowercase letters, numbers, _ or .';
  }
  return null;
}

String? validateLocation(String? value) {
  if ((value ?? '').trim().isEmpty) return 'Please enter your location.';
  return null;
}

String? validateBio(String? value) {
  if ((value ?? '').trim().length > 280) return 'Use 280 characters or fewer.';
  return null;
}

// "About you" checks for a visitor (spec 0014, AC-7), mirroring
// `submit_visitor_application`.

String? validateApplicantName(String? value) {
  final length = (value ?? '').trim().length;
  if (length < 2 || length > 60) return 'Use 2 to 60 characters.';
  return null;
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateApplicantEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.length > 200 || !_emailPattern.hasMatch(email)) {
    return 'Please enter a valid email address.';
  }
  return null;
}

/// The phone as the server stores it: the picked country's dial code and the
/// digits typed, in international format.
String internationalPhone(CountryDialCode country, String typed) =>
    '${country.dialCode}${typed.replaceAll(RegExp(r'\D'), '')}';

String? validateApplicantPhone(CountryDialCode country, String typed) {
  final digits = typed.replaceAll(RegExp(r'\D'), '');
  if (!country.isPlausibleNationalNumber(digits)) {
    return 'Please enter a valid phone number.';
  }
  return null;
}

/// The biggest photo the Storage buckets take (spec 0013, AC-5).
const maxPhotoBytes = 5 * 1024 * 1024;

/// The file extension to store a photo under, `jpg` or `png`, or null when it
/// is another type. Only JPEG and PNG are accepted (AC-9).
String? photoExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  return switch (fileName.substring(dot + 1).toLowerCase()) {
    'jpg' || 'jpeg' => 'jpg',
    'png' => 'png',
    _ => null,
  };
}

/// The message for a picked photo that cannot be sent, or null when it can.
/// The type and size are checked on the phone so nobody waits for an upload
/// the server would refuse (AC-9).
String? checkPhoto({required String fileName, required int bytes}) {
  if (photoExtension(fileName) == null) return 'Use a JPEG or PNG photo.';
  if (bytes > maxPhotoBytes) {
    return 'This photo is over 5 MB. Choose a smaller one.';
  }
  return null;
}

/// `Submitted 25/06/2025`, the line under a store name (Figma node 3001:9565).
String submittedLabel(DateTime date) {
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Submitted ${two(local.day)}/${two(local.month)}/${local.year}';
}

/// Whether the screen offers "Submit a new application" (AC-8): only to a
/// buyer with no application under review. [role] is null while the profile
/// is unknown (no sign in configured), which counts as a buyer.
bool canSubmitNewApplication(
  List<SellerApplication> applications,
  UserRole? role,
) {
  if (role == UserRole.seller) return false;
  return !applications.any(
    (a) => a.status == SellerApplicationStatus.reviewing,
  );
}

/// What the wizard says for each reason a submit was refused.
String sellerApplicationFailureMessage(SellerApplicationFailure reason) =>
    switch (reason) {
      SellerApplicationFailure.usernameTaken => 'This username is taken.',
      SellerApplicationFailure.alreadyOpen =>
        'You already have an application under review.',
      SellerApplicationFailure.alreadySeller => 'You are already a seller.',
      SellerApplicationFailure.noSession ||
      SellerApplicationFailure.noProfile => 'Sign in to send an application.',
      SellerApplicationFailure.useAccount =>
        'You are signed in. Apply from Settings, Seller application.',
      SellerApplicationFailure.invalidField =>
        'Some details are not valid. Check each step.',
      SellerApplicationFailure.missingDocument ||
      SellerApplicationFailure.fileNotFound =>
        'A photo went missing. Add it again and retry.',
      SellerApplicationFailure.failed =>
        "Couldn't send your application. Try again.",
    };
