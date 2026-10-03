import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds a [SupabaseClient] backed by Clerk's session token instead of
/// Supabase's own auth. [getClerkToken] should return the current Clerk
/// session's JWT (or null if not signed in); it may be called concurrently
/// and often, per `SupabaseClient`'s own `accessToken` contract.
///
/// Shared by both apps; each passes its own project URL, key and Clerk
/// instance (spec 0011).
SupabaseClient buildClerkBackedClient(
  String supabaseUrl,
  String supabasePublishableKey,
  Future<String?> Function() getClerkToken,
) {
  return SupabaseClient(
    supabaseUrl,
    supabasePublishableKey,
    accessToken: getClerkToken,
  );
}
