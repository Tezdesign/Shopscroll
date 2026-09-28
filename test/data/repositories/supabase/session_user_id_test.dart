import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/repositories/supabase/session_user_id.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Regression for spec 0009: a Clerk backed client (accessToken set) made
// every Supabase repository that read `client.auth.currentUser?.id` throw,
// because `SupabaseClient.auth` refuses to work once `accessToken` is
// configured. `currentSessionUserId` has to work for both clients instead.
void main() {
  String fakeJwt(String sub) {
    String segment(Map<String, dynamic> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return '${segment({'alg': 'none'})}.${segment({'sub': sub})}.signature';
  }

  test(
    'reads the sub claim off a Clerk backed client\'s access token',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        accessToken: () async => fakeJwt('user_clerk_123'),
      );
      addTearDown(client.dispose);

      expect(await currentSessionUserId(client), 'user_clerk_123');
    },
  );

  test('falls back to client.auth on the anonymous client', () async {
    final client = SupabaseClient('https://example.supabase.co', 'anon-key');
    addTearDown(client.dispose);

    // No session signed in, so there is no current user yet, same as
    // client.auth.currentUser?.id would have returned before.
    expect(await currentSessionUserId(client), isNull);
  });
}
