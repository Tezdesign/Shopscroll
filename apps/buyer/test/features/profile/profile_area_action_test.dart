import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/core/area/app_area.dart';
import 'package:marketplace_app/core/onboarding/onboarding_prefs.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/user_profile_repository.dart';
import 'package:marketplace_app/features/profile/profile_area_action.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

class _Profiles implements UserProfileRepository {
  _Profiles(this.role);

  final UserRole role;

  @override
  Future<UserProfile?> getUserProfileById(String id) async =>
      UserProfile(id: id, name: 'N', username: 'n', role: role);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> pumpAction(WidgetTester tester, UserRole role) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: ProfileAreaAction())),
      ),
      GoRoute(
        path: '/profile/seller-application',
        builder: (context, state) => const Text('seller application page'),
      ),
      GoRoute(path: '/store', builder: (context, state) => const Text('store')),
    ],
  );
  final overrides = <Override>[
    onboardingPrefsProvider.overrideWithValue(OnboardingPrefs(prefs)),
    userProfileRepositoryProvider.overrideWithValue(_Profiles(role)),
    signedInUserIdProvider.overrideWith((ref) => 'u1'),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
}

void main() {
  testWidgets('a buyer sees Become a seller, which opens the application', (
    tester,
  ) async {
    await pumpAction(tester, UserRole.buyer);

    expect(find.text('Become a seller'), findsOneWidget);
    expect(find.text('Store owner'), findsNothing);

    await tester.tap(find.text('Become a seller'));
    await tester.pumpAndSettle();
    expect(find.text('seller application page'), findsOneWidget);
  });

  testWidgets('a seller sees the Buyer | Store owner switch instead', (
    tester,
  ) async {
    await pumpAction(tester, UserRole.seller);

    expect(find.text('Become a seller'), findsNothing);
    expect(find.text('Buyer'), findsOneWidget);
    expect(find.text('Store owner'), findsOneWidget);

    await tester.tap(find.text('Store owner'));
    await tester.pumpAndSettle();
    expect(find.text('store'), findsOneWidget);
  });
}
