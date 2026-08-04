import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
class AuthSessionController {
  AuthSessionController({
    required this.ref,
    required this.clerkAuth,
    required this.anonymousClient,
    required this.clerkBackedClient,
  }) {
    _wasSignedIn = clerkAuth.isSignedIn;
    clerkAuth.addListener(_onClerkAuthChanged);
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
      _handleSignedIn();
    } else {
      _handleSignedOut();
    }
  }

  Future<void> _handleSignedIn() async {
    if (_isHandlingSignIn) return;
    _isHandlingSignIn = true;
    try {
      final user = clerkAuth.user;
      if (user == null) return;
      final targetUserId = user.id;

      await _mergeAnonymousIdentity(targetUserId);

      // Only now does the app start reading/writing through the Clerk
      // backed client; the merge above ran while still on the anonymous
      // one, exactly as its own caller check requires.
      ref.read(activeSupabaseClientProvider.notifier).state =
          clerkBackedClient;

      await _upsertBuyerProfile(user, targetUserId);
    } finally {
      _isHandlingSignIn = false;
    }
  }

  Future<void> _mergeAnonymousIdentity(String targetUserId) async {
    const timeout = Duration(seconds: 10);
    Future<void> attempt() => anonymousClient.rpc(
      'merge_anonymous_identity',
      params: {'target_user_id': targetUserId},
    ).timeout(timeout);

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

  Future<void> _upsertBuyerProfile(clerk.User user, String targetUserId) async {
    final name = [
      user.firstName,
      user.lastName,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');

    await clerkBackedClient.from('user_profiles').upsert({
      'id': targetUserId,
      'name': name.isEmpty ? (user.username ?? 'Shopper') : name,
      'username': user.username ?? targetUserId,
      'role': 'buyer',
      'email': user.email,
      'phone': user.phoneNumber,
    });
  }

  void _handleSignedOut() {
    ref.read(activeSupabaseClientProvider.notifier).state = anonymousClient;
    if (anonymousClient.auth.currentSession == null) {
      anonymousClient.auth.signInAnonymously();
    }
  }

  void dispose() {
    clerkAuth.removeListener(_onClerkAuthChanged);
  }
}
