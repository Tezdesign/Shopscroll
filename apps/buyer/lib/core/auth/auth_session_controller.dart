import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/providers/seller_application_providers.dart';
import '../area/app_area.dart';
import '../area/seller_claim.dart';
import '../onboarding/onboarding_prefs.dart';
import 'active_supabase_client.dart';

/// Drives the anonymous to real identity switch (spec 0004's "Two Supabase
/// clients, not one" and "State transitions").
///
/// Listens to [clerkAuth] for sign in/out transitions and, on sign in, runs
/// the merge call on the anonymous client BEFORE flipping
/// [activeSupabaseClientProvider] to the Clerk backed client: the merge
/// function's anonymous only check reads the caller's own current session
/// straight off its JWT, so it only succeeds while the anonymous client is
/// still the one making the call (AC-3, AC-10). Sign out, or Clerk itself
/// detecting an expired session with nothing to refresh, both surface here
/// as the same signed out transition, and both fall back to the anonymous
/// client the same way (AC-6, AC-7).
///
/// Spec 0014 adds three jobs. The merge also attaches the visitor
/// applications this phone sent to the account. After the switch it asks the
/// claim function to turn an approved application into a seller (AC-13),
/// before [signInSettledProvider] completes, so Log in routing sees the final
/// role (AC-2). And sign out forgets the remembered area (AC-3).
class AuthSessionController {
  AuthSessionController({
    required this.ref,
    required this.clerkAuth,
    required this.anonymousClient,
    required this.clerkBackedClient,
  }) {
    _wasSignedIn = clerkAuth.isSignedIn;
    clerkAuth.addListener(_onClerkAuthChanged);
    // A session Clerk restored from disk is already signed in when this is
    // built, so no transition ever fires for it. Without this the app would
    // show the signed in buyer but keep reading and writing (cart, orders)
    // through the anonymous client. The profile insert is skipped: the row
    // already exists from the sign in that created this session.
    if (_wasSignedIn) _handleSignedIn(createProfile: false);
  }

  final WidgetRef ref;
  final ClerkAuthState clerkAuth;
  final SupabaseClient anonymousClient;
  final SupabaseClient clerkBackedClient;

  late bool _wasSignedIn;
  bool _isHandlingSignIn = false;

  void _onClerkAuthChanged() {
    final isSignedIn = clerkAuth.isSignedIn;
    if (isSignedIn == _wasSignedIn) return;
    _wasSignedIn = isSignedIn;

    if (isSignedIn) {
      ref.read(signInSettledProvider.notifier).state = _handleSignedIn();
    } else {
      _handleSignedOut();
    }
  }

  Future<void> _handleSignedIn({bool createProfile = true}) async {
    if (_isHandlingSignIn) return;
    _isHandlingSignIn = true;
    try {
      final user = clerkAuth.user;
      if (user == null) return;
      final targetUserId = user.id;

      await _mergeAnonymousIdentity(targetUserId);
      ref.read(signedInUserIdProvider.notifier).state = targetUserId;

      // Only now does the app start reading/writing through the Clerk
      // backed client; the merge above ran while still on the anonymous
      // one, exactly as its own caller check requires.
      ref.read(activeSupabaseClientProvider.notifier).state = clerkBackedClient;

      if (createProfile) await _createProfileIfMissing(user, targetUserId);

      // A claim failure never blocks the sign in (AC-2): it is swallowed here
      // and retried at the next launch, resume or Seller application screen.
      await _claim();
    } finally {
      _isHandlingSignIn = false;
    }
  }

  Future<void> _claim() async {
    if (await ref.read(sellerClaimProvider).claim()) {
      ref.invalidate(sellerApplicationsProvider);
    }
  }

  /// The claim on app resume (AC-13), for a signed in buyer. Skipped while a
  /// sign in is still running, which claims at its end.
  Future<void> claimOnResume() async {
    if (!clerkAuth.isSignedIn || _isHandlingSignIn) return;
    await _claim();
  }

  Future<void> _mergeAnonymousIdentity(String targetUserId) async {
    const timeout = Duration(seconds: 10);
    Future<void> attempt() => anonymousClient
        .rpc(
          'merge_anonymous_identity',
          params: {'target_user_id': targetUserId},
        )
        .timeout(timeout);

    try {
      await attempt();
    } catch (_) {
      // One retry (AC-10); if it still fails, sign in still succeeds, just
      // without the unmigrated anonymous cart/orders.
      try {
        await attempt();
      } catch (_) {
        // Give up silently: the new account stays usable.
      }
    }
  }

  /// Creates the profile row on first sign in and leaves an existing one
  /// alone (spec 0012, AC-3). It never sends `role`: the column default is
  /// 'buyer', and a seller who signs in here must keep `role = 'seller'` and
  /// their edited store details. `ignoreDuplicates` makes the write an
  /// `ON CONFLICT DO NOTHING`, so a repeat sign in changes nothing.
  Future<void> _createProfileIfMissing(
    clerk.User user,
    String targetUserId,
  ) async {
    final name = [
      user.firstName,
      user.lastName,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');

    await clerkBackedClient.from('user_profiles').upsert({
      'id': targetUserId,
      'name': name.isEmpty ? (user.username ?? 'Shopper') : name,
      'username': user.username ?? targetUserId,
      'email': user.email,
      'phone': user.phoneNumber,
    }, ignoreDuplicates: true);
  }

  void _handleSignedOut() {
    ref.read(signedInUserIdProvider.notifier).state = null;
    ref.read(areaNoticeProvider.notifier).state = null;
    ref.read(onboardingPrefsProvider).clearLastArea();
    ref.read(activeSupabaseClientProvider.notifier).state = anonymousClient;
    if (anonymousClient.auth.currentSession == null) {
      anonymousClient.auth.signInAnonymously();
    }
  }

  void dispose() {
    clerkAuth.removeListener(_onClerkAuthChanged);
  }
}
