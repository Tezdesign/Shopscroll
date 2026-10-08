import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopscroll_shared/models/user_profile.dart';

import '../../data/providers/user_profile_providers.dart';
import '../auth/active_supabase_client.dart';
import 'app_area.dart';

/// Asks the `claim-seller-application` Edge Function to turn the signed in
/// account into a seller when an admin approved a visitor application that was
/// attached to it (spec 0014, AC-13). The function verifies the Clerk session
/// token itself and answers `{ "claimed": true or false }`.
///
/// Never throws: a failure (offline, Clerk down) leaves the person a buyer and
/// the next launch, resume or opening of the Seller application screen tries
/// again, and a claim failure never blocks a sign in (AC-2).
class SellerClaim {
  SellerClaim(this._ref);

  final Ref _ref;

  /// True only when this call made the account a seller through a claim. A
  /// seller, a visitor and an app with no backend return false without a claim
  /// call, and so does a profile that turns out to be a seller already.
  Future<bool> claim() async {
    final userId = _ref.read(signedInUserIdProvider);
    if (userId == null || _ref.read(isSellerProvider)) return false;

    // An admin approving an account application sets the role on the server and
    // tells the app nothing, so a cached buyer profile can be out of date. Read
    // it again first: a seller needs no claim, and every screen that shows the
    // role (the Profile switch, the area toggle) then catches up. A failed read
    // changes nothing, the claim below still runs.
    try {
      final profile = await _ref.refresh(
        userProfileByIdProvider(userId).future,
      );
      if (profile?.role == UserRole.seller) return false;
    } catch (error) {
      debugPrint('profile refresh before the claim failed: $error');
    }

    try {
      final response = await _ref
          .read(activeSupabaseClientProvider)
          .functions
          .invoke('claim-seller-application');
      final data = response.data;
      final claimed = data is Map && data['claimed'] == true;
      // The role changed, so the cached profile is stale. Not the applications
      // list: that provider calls this itself before it loads.
      if (claimed) _ref.invalidate(userProfileByIdProvider(userId));
      return claimed;
    } catch (error) {
      debugPrint('claim-seller-application failed: $error');
      return false;
    }
  }
}

final sellerClaimProvider = Provider<SellerClaim>(SellerClaim.new);
