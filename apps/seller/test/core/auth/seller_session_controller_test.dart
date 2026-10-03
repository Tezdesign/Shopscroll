import 'dart:convert';

import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shopscroll_seller/core/auth/seller_session_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeUser implements clerk.User {
  @override
  String get id => 'user_1';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeClerk extends ChangeNotifier implements ClerkAuthState {
  _FakeClerk({required this.isSignedIn});

  @override
  bool isSignedIn;

  @override
  clerk.User? get user => isSignedIn ? _FakeUser() : null;

  void becomeSignedIn() {
    isSignedIn = true;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Records what the client would send, so the test sees the real requests.
class _RecordingHttp extends http.BaseClient {
  final requests = <http.Request>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request as http.Request);
    return http.StreamedResponse(const Stream.empty(), 201, request: request);
  }
}

void main() {
  late _RecordingHttp recorder;
  late SupabaseClient client;

  setUp(() {
    recorder = _RecordingHttp();
    client = SupabaseClient(
      'http://localhost',
      'key',
      httpClient: recorder,
      accessToken: () async => null,
    );
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test(
    'sign in creates the profile without a role, then calls become_seller',
    () async {
      final clerk = _FakeClerk(isSignedIn: false);
      final controller = SellerSessionController(
        clerkAuth: clerk,
        client: client,
      );
      addTearDown(controller.dispose);

      clerk.becomeSignedIn();
      await settle();

      expect(recorder.requests, hasLength(2));
      final insert = recorder.requests[0];
      expect(insert.url.path, '/rest/v1/user_profiles');
      expect(
        insert.headers['Prefer'],
        contains('resolution=ignore-duplicates'),
      );
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body['id'], 'user_1');
      expect(body.containsKey('role'), isFalse);
      expect(recorder.requests[1].url.path, '/rest/v1/rpc/become_seller');
    },
  );

  test('a session restored at launch also runs it once', () async {
    final controller = SellerSessionController(
      clerkAuth: _FakeClerk(isSignedIn: true),
      client: client,
    );
    addTearDown(controller.dispose);
    await settle();

    expect(recorder.requests.map((r) => r.url.path), [
      '/rest/v1/user_profiles',
      '/rest/v1/rpc/become_seller',
    ]);
  });

  test('signed out makes no request', () async {
    final controller = SellerSessionController(
      clerkAuth: _FakeClerk(isSignedIn: false),
      client: client,
    );
    addTearDown(controller.dispose);
    await settle();

    expect(recorder.requests, isEmpty);
  });
}
