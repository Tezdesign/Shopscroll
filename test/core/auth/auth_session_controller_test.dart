import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/auth/active_supabase_client.dart';
import 'package:marketplace_app/core/auth/auth_session_controller.dart';
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

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// Every call throws, so the merge call fails and is swallowed (its own retry
// rule); the client flip after it is what these tests look at.
class _FakeClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('fake');
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

void main() {
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
    final container = ProviderContainer(
      overrides: [activeSupabaseClientProvider.overrideWith((ref) => anon)],
    );
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
    final container = ProviderContainer(
      overrides: [activeSupabaseClientProvider.overrideWith((ref) => anon)],
    );
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
}
