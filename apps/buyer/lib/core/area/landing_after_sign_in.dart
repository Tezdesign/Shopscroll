import 'package:shopscroll_shared/models/seller_application.dart';
import 'package:shopscroll_shared/models/user_profile.dart';

import '../../shared/widgets/account_type_toggle.dart';
import 'app_area.dart';

/// Where a sign in lands: the area to open, and the notice to show there.
class SignInLanding {
  const SignInLanding(this.area, {this.notice});

  final AppArea area;
  final AreaNotice? notice;
}

/// Decides the area after Log in from the Buyer or Store owner choice and the
/// signed in profile's role (spec 0014, AC-1). Buyer always opens the buyer
/// area. Store owner opens the store area only for a seller, and otherwise the
/// buyer area with a notice for the state of their application. A lookup that
/// fails counts as "not a seller" and "no applications": the person still
/// signs in, in the buyer area.
Future<SignInLanding> landingAfterSignIn({
  required AccountType choice,
  required Future<UserRole?> Function() role,
  required Future<List<SellerApplication>> Function() applications,
}) async {
  if (choice == AccountType.buyer) return const SignInLanding(AppArea.buyer);

  UserRole? signedInRole;
  try {
    signedInRole = await role();
  } catch (_) {}
  if (signedInRole == UserRole.seller) {
    return const SignInLanding(AppArea.store);
  }

  List<SellerApplication> mine = const [];
  try {
    mine = await applications();
  } catch (_) {}
  return SignInLanding(AppArea.buyer, notice: areaNoticeFor(mine));
}
