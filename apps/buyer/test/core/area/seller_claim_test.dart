import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_app/core/area/app_area.dart';
import 'package:marketplace_app/core/area/seller_claim.dart';
import 'package:marketplace_app/core/auth/active_supabase_client.dart';
import 'package:marketplace_app/data/providers/seller_application_providers.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/user_profile_repository.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/seller_application/fake_seller_application_repository.dart';

class _Http extends http.BaseClient {
  _Http(this.status, this.body);

  final int status;
  final String body;
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

class _Profiles implements UserProfileRepository {
  _Profiles(this.role);

  UserRole role;
  int reads = 0;

  @override
  Future<UserProfile?> getUserProfileById(String id) async {
    reads++;
    return UserProfile(id: id, name: 'N', username: 'n', role: role);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ProviderContainer _makeContainer(
  _Http server,
  _Profiles profiles, {
  String? userId = 'u1',
  List<Override> extra = const [],
}) {
  final client = SupabaseClient(
    'http://localhost',
    'key',
    httpClient: server,
    accessToken: () async => 'token',
  );
  final c = ProviderContainer(
    overrides: [
      activeSupabaseClientProvider.overrideWith((ref) => client),
      userProfileRepositoryProvider.overrideWithValue(profiles),
      signedInUserIdProvider.overrideWith((ref) => userId),
      ...extra,
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test(
    'asks the Edge Function and reports a claim, then refreshes the profile',
    () async {
      final server = _Http(200, '{"claimed": true}');
      final profiles = _Profiles(UserRole.buyer);
      final c = _makeContainer(server, profiles);
      c.listen(isSellerProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(c.read(isSellerProvider), isFalse);

      profiles.role = UserRole.seller;
      final claimed = await c.read(sellerClaimProvider).claim();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(claimed, isTrue);
      expect(
        server.requests.single.url.path,
        '/functions/v1/claim-seller-application',
      );
      expect(server.requests.single.method, 'POST');
      // The stale buyer profile was dropped, so the role is read again.
      expect(c.read(isSellerProvider), isTrue);
    },
  );

  test('claimed false when there is nothing to claim', () async {
    final c = _makeContainer(
      _Http(200, '{"claimed": false}'),
      _Profiles(UserRole.buyer),
    );

    expect(await c.read(sellerClaimProvider).claim(), isFalse);
  });

  test('a failure is swallowed: the person stays a buyer', () async {
    final c = _makeContainer(
      _Http(500, '{"error": "x"}'),
      _Profiles(UserRole.buyer),
    );

    expect(await c.read(sellerClaimProvider).claim(), isFalse);
  });

  test('a visitor makes no call', () async {
    final server = _Http(200, '{"claimed": true}');
    final c = _makeContainer(server, _Profiles(UserRole.buyer), userId: null);

    expect(await c.read(sellerClaimProvider).claim(), isFalse);
    expect(server.requests, isEmpty);
  });

  test('a seller makes no call', () async {
    final server = _Http(200, '{"claimed": true}');
    final c = _makeContainer(server, _Profiles(UserRole.seller));
    c.listen(isSellerProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(await c.read(sellerClaimProvider).claim(), isFalse);
    expect(server.requests, isEmpty);
  });

  test('loading the applications asks for a claim first (AC-13)', () async {
    final server = _Http(200, '{"claimed": false}');
    final c = _makeContainer(
      server,
      _Profiles(UserRole.buyer),
      extra: [
        sellerApplicationRepositoryProvider.overrideWithValue(
          FakeSellerApplicationRepository(),
        ),
      ],
    );

    c.listen(sellerApplicationsProvider, (_, _) {});
    await c.read(sellerApplicationsProvider.future);

    expect(
      server.requests.map((r) => r.url.path),
      contains('/functions/v1/claim-seller-application'),
    );
  });
}
