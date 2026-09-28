import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The current session's user id, read in a way that works for either of
/// spec 0004's two Supabase clients.
///
/// The anonymous client has no `accessToken` override, so `client.auth`
/// works normally and this reads `currentUser` straight off it. The Clerk
/// backed client sets `accessToken` (see
/// `core/auth/active_supabase_client.dart`), and `supabase`'s own
/// `SupabaseClient.auth` throws for any client configured that way, so the
/// id has to come from decoding the JWT `accessToken` itself hands out
/// instead (its `sub` claim, the same value every RLS policy and
/// `place_order` already key off of via `auth.jwt() ->> 'sub'`).
Future<String?> currentSessionUserId(SupabaseClient client) async {
  final tokenGetter = client.accessToken;
  if (tokenGetter == null) return client.auth.currentUser?.id;

  final jwt = await tokenGetter();
  final parts = jwt?.split('.');
  if (parts == null || parts.length != 3) return null;

  final payload =
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
          as Map<String, dynamic>;
  return payload['sub'] as String?;
}
