import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whichever [SupabaseClient] currently backs the app: the anonymous
/// capable one from spec 0003, or the Clerk backed one once someone signs
/// in for real (spec 0004). Repository providers watch this and rebuild
/// against whichever is active.
///
/// Two separate client instances exist because `supabase_flutter`'s
/// `accessToken` callback (needed to run Clerk through Supabase's Third
/// Party Auth) and the client's own native `auth` namespace
/// (`signInAnonymously`, session refresh) are mutually exclusive on one
/// client instance: configuring `accessToken` makes `client.auth` throw
/// outright. See spec 0004's Feature design, "Two Supabase clients, not
/// one", for the full reasoning.
///
/// `main.dart` overrides this with the real anonymous client at startup;
/// the auth session controller flips it to the Clerk backed client on sign
/// in, and back on sign out or an unrefreshable expired session.
final activeSupabaseClientProvider = StateProvider<SupabaseClient>((ref) {
  throw UnimplementedError(
    'activeSupabaseClientProvider must be overridden in main.dart before use',
  );
});
