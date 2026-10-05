import 'dart:convert';

import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:marketplace_app/core/area/app_area.dart';
import 'package:marketplace_app/core/auth/active_supabase_client.dart';
import 'package:marketplace_app/core/auth/auth_session_controller.dart';
import 'package:marketplace_app/core/onboarding/onboarding_prefs.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/user_profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
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

  void becomeSignedOut() {
    isSignedIn = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// Every call throws, so the merge call fails and is swallowed (its own retry
// rule); the client flip after it is what these tests look at.
class _FakeClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('fake');
}

/// Answers every profile lookup with "no profile", at once. The mock
/// repository waits 300 ms, which would leave a timer pending at the end of a
/// test.
class _NoProfiles implements UserProfileRepository {
  @override
  Future<UserProfile?> getUserProfileById(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The anonymous client, with just enough `auth` for sign out to look at.
class _AnonClient extends _FakeClient {
  @override
  GoTrueClient get auth => _FakeAuth();
}

class _FakeAuth implements GoTrueClient {
  @override
  Session? get currentSession => Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: const User(
      id: 'anon',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('fake');
}

/// A real [SupabaseClient] whose HTTP layer only records what it is asked to
/// send, so the test sees the actual wire request of the profile write.
class _RecordingHttp extends http.BaseClient {
  final requests = <http.Request>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request as http.Request);
    return http.StreamedResponse(const Stream.empty(), 201, request: request);
  }
}

class _Host extends ConsumerStatefulWidget {
  const _Host({required this.clerk, required this.anon, required this.real});

  final ClerkAuthState clerk;
  final SupabaseClient anon;
  final SupabaseClient real;

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> {
  late final AuthSessionController controller;

  @override
  void initState() {
    super.initState();
    controller = AuthSessionController(
      ref: ref,
      clerkAuth: widget.clerk,
      anonymousClient: widget.anon,
      clerkBackedClient: widget.real,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

late SharedPreferences _prefs;

List<Override> _overrides(SupabaseClient anon) => [
  activeSupabaseClientProvider.overrideWith((ref) => anon),
  onboardingPrefsProvider.overrideWithValue(OnboardingPrefs(_prefs)),
  userProfileRepositoryProvider.overrideWithValue(_NoProfiles()),
];

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  Future<void> launch(
    WidgetTester tester, {
    required bool signedIn,
    required SupabaseClient anon,
    required SupabaseClient real,
    required ProviderContainer container,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: _Host(
            clerk: _FakeClerk(isSignedIn: signedIn),
            anon: anon,
            real: real,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a Clerk session restored at launch uses the Clerk client', (
    tester,
  ) async {
    final anon = _FakeClient();
    final real = _FakeClient();
    final container = ProviderContainer(overrides: _overrides(anon));
    addTearDown(container.dispose);
    await launch(
      tester,
      signedIn: true,
      anon: anon,
      real: real,
      container: container,
    );
    expect(container.read(activeSupabaseClientProvider), same(real));
  });

  testWidgets('signed out at launch stays on the anonymous client', (
    tester,
  ) async {
    final anon = _FakeClient();
    final real = _FakeClient();
    final container = ProviderContainer(overrides: _overrides(anon));
    addTearDown(container.dispose);
    await launch(
      tester,
      signedIn: false,
      anon: anon,
      real: real,
      container: container,
    );
    expect(container.read(activeSupabaseClientProvider), same(anon));
  });

  testWidgets(
    'sign in only creates the profile row: no role, ignore duplicates (spec 0012, AC-3)',
    (tester) async {
      final recorder = _RecordingHttp();
      // Built outside the fake async zone: the client starts its own timers.
      final real = (await tester.runAsync(
        () async => SupabaseClient(
          'http://localhost',
          'key',
          httpClient: recorder,
          accessToken: () async => null,
        ),
      ))!;
      final anon = _FakeClient();
      final clerk = _FakeClerk(isSignedIn: false);
      final container = ProviderContainer(overrides: _overrides(anon));
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: _Host(clerk: clerk, anon: anon, real: real),
          ),
        ),
      );

      clerk.becomeSignedIn();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      final request = recorder.requests.singleWhere(
        (r) => r.url.path == '/rest/v1/user_profiles',
      );
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/user_profiles');
      // ON CONFLICT DO NOTHING: an existing profile is never overwritten.
      expect(
        request.headers['Prefer'],
        contains('resolution=ignore-duplicates'),
      );
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['id'], 'user_1');
      expect(body.containsKey('role'), isFalse);
    },
  );

  testWidgets(
    'sign in asks the claim function after the switch and publishes the user id '
    '(spec 0014, AC-2, AC-13)',
    (tester) async {
      final recorder = _RecordingHttp();
      final real = (await tester.runAsync(
        () async => SupabaseClient(
          'http://localhost',
          'key',
          httpClient: recorder,
          accessToken: () async => null,
        ),
      ))!;
      final anon = _FakeClient();
      final clerk = _FakeClerk(isSignedIn: false);
      final container = ProviderContainer(overrides: _overrides(anon));
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: _Host(clerk: clerk, anon: anon, real: real),
          ),
        ),
      );

      clerk.becomeSignedIn();
      // Routing after Log in waits on this, so it has to cover the claim.
      final settled = container.read(signInSettledProvider);
      await tester.runAsync(() => settled);

      final paths = recorder.requests.map((r) => r.url.path).toList();
      expect(paths, contains('/functions/v1/claim-seller-application'));
      expect(
        paths.indexOf('/functions/v1/claim-seller-application'),
        greaterThan(paths.indexOf('/rest/v1/user_profiles')),
      );
      expect(container.read(signedInUserIdProvider), 'user_1');
    },
  );

  testWidgets(
    'signing out clears the remembered area and the signed in user (spec 0014, AC-3)',
    (tester) async {
      await _prefs.setString('last_area', 'store');
      final anon = _AnonClient();
      final real = _FakeClient();
      final clerk = _FakeClerk(isSignedIn: true);
      final container = ProviderContainer(overrides: _overrides(anon));
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: _Host(clerk: clerk, anon: anon, real: real),
          ),
        ),
      );
      await tester.pump();

      clerk.becomeSignedOut();
      await tester.pump();

      expect(OnboardingPrefs(_prefs).lastArea, isNull);
      expect(container.read(signedInUserIdProvider), isNull);
      expect(container.read(activeSupabaseClientProvider), same(anon));
    },
  );
}
