import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/core/area/app_area.dart';
import 'package:marketplace_app/core/onboarding/onboarding_prefs.dart';
import 'package:marketplace_app/core/router/app_shell.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/user_profile_repository.dart';
import 'package:marketplace_app/features/store/store_area_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

class _Profiles implements UserProfileRepository {
  _Profiles(this.role, {this.fail = false});

  final UserRole role;
  final bool fail;

  @override
  Future<UserProfile?> getUserProfileById(String id) async {
    if (fail) throw StateError('offline');
    return UserProfile(id: id, name: 'N', username: 'n', role: role);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The real [AppShell] and [StoreAreaScreen] in a small router: five tabs, a
/// cart under Home like the app has, and `/store` outside the shell.
GoRouter router({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          AppShell(navigationShell: shell, location: state.uri.path),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Center(
                child: TextButton(
                  onPressed: () => context.push('/cart'),
                  child: const Text('home tab'),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'cart',
                  builder: (context, state) => const Text('cart page'),
                ),
              ],
            ),
          ],
        ),
        for (final path in ['/discover', '/reels', '/activity', '/profile'])
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: path,
                builder: (context, state) => Text('tab $path'),
              ),
            ],
          ),
      ],
    ),
    GoRoute(
      path: '/store',
      builder: (context, state) => const StoreAreaScreen(),
    ),
    GoRoute(
      path: '/seller-app',
      builder: (context, state) => const Text('seller application page'),
    ),
    GoRoute(
      path: '/profile/seller-application',
      builder: (context, state) => const Text('seller application page'),
    ),
  ],
);

late SharedPreferences prefs;

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  UserRole? role,
  bool failProfile = false,
  String? userId = 'u1',
  String initialLocation = '/',
  List<Override> extra = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      onboardingPrefsProvider.overrideWithValue(OnboardingPrefs(prefs)),
      userProfileRepositoryProvider.overrideWithValue(
        _Profiles(role ?? UserRole.buyer, fail: failProfile),
      ),
      signedInUserIdProvider.overrideWith((ref) => userId),
      ...extra,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router(initialLocation: initialLocation),
      ),
    ),
  );
  // Past the profile load.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  return container;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('the area toggle in the buyer area (spec 0014, AC-4)', () {
    testWidgets('a seller sees it on a tab screen', (tester) async {
      await pumpApp(tester, role: UserRole.seller);

      expect(find.text('Buyer'), findsOneWidget);
      expect(find.text('Store owner'), findsOneWidget);
    });

    testWidgets('a buyer never sees it', (tester) async {
      await pumpApp(tester, role: UserRole.buyer);

      expect(find.text('home tab'), findsOneWidget);
      expect(find.text('Store owner'), findsNothing);
    });

    testWidgets('a visitor never sees it', (tester) async {
      await pumpApp(tester, role: UserRole.seller, userId: null);

      expect(find.text('Store owner'), findsNothing);
    });

    testWidgets(
      'a pushed screen inside the shell, the cart, does not show it',
      (tester) async {
        await pumpApp(tester, role: UserRole.seller);
        expect(find.text('Store owner'), findsOneWidget);

        await tester.tap(find.text('home tab'));
        await tester.pumpAndSettle();

        expect(find.text('cart page'), findsOneWidget);
        expect(find.text('Store owner'), findsNothing);
      },
    );

    testWidgets('it stays on every tab and keeps a tab\'s own state', (
      tester,
    ) async {
      await pumpApp(tester, role: UserRole.seller);

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      expect(find.text('tab /discover'), findsOneWidget);
      expect(find.text('Store owner'), findsOneWidget);
    });

    testWidgets('tapping Store owner opens the store area and remembers it', (
      tester,
    ) async {
      await pumpApp(tester, role: UserRole.seller);

      await tester.tap(find.text('Store owner'));
      await tester.pumpAndSettle();

      // Spec 0015: the placeholder now holds the two product entry buttons.
      expect(find.text('Your store'), findsOneWidget);
      expect(find.text('Add product'), findsOneWidget);
      expect(OnboardingPrefs(prefs).lastArea, 'store');
    });
  });

  group('the store area (spec 0014, AC-3, AC-5)', () {
    testWidgets('shows the toggle and the product entry buttons', (
      tester,
    ) async {
      await pumpApp(tester, role: UserRole.seller, initialLocation: '/store');

      expect(find.text('Your store'), findsOneWidget);
      expect(find.text('Add product'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Buyer'), findsOneWidget);
    });

    testWidgets('tapping Buyer goes back to the buyer area and remembers it', (
      tester,
    ) async {
      await pumpApp(tester, role: UserRole.seller, initialLocation: '/store');

      await tester.tap(find.text('Buyer'));
      await tester.pumpAndSettle();

      expect(find.text('home tab'), findsOneWidget);
      expect(OnboardingPrefs(prefs).lastArea, 'buyer');
    });

    testWidgets('a profile that is no longer a seller opens the buyer area', (
      tester,
    ) async {
      await prefs.setString('last_area', 'store');
      await pumpApp(tester, role: UserRole.buyer, initialLocation: '/store');
      await tester.pumpAndSettle();

      expect(find.text('home tab'), findsOneWidget);
      expect(find.text('Store owner'), findsNothing);
      expect(OnboardingPrefs(prefs).lastArea, 'buyer');
    });

    testWidgets('a visitor opens the buyer area', (tester) async {
      await pumpApp(
        tester,
        role: UserRole.seller,
        userId: null,
        initialLocation: '/store',
      );
      await tester.pumpAndSettle();

      expect(find.text('home tab'), findsOneWidget);
    });

    testWidgets(
      'a profile that fails to load opens the buyer area but keeps the memory',
      (tester) async {
        await prefs.setString('last_area', 'store');
        await pumpApp(tester, failProfile: true, initialLocation: '/store');
        await tester.pumpAndSettle();

        expect(find.text('home tab'), findsOneWidget);
        expect(OnboardingPrefs(prefs).lastArea, 'store');
      },
    );
  });

  group('the notice after Log in (spec 0014, AC-1)', () {
    testWidgets('shows once, with an action to the Seller application screen', (
      tester,
    ) async {
      final container = await pumpApp(tester);

      container.read(areaNoticeProvider.notifier).state = const AreaNotice(
        AreaNoticeKind.reviewing,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Your application is being reviewed.'), findsOneWidget);
      expect(container.read(areaNoticeProvider), isNull);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('seller application page'), findsOneWidget);
    });

    testWidgets('a notice set before the shell is built still shows', (
      tester,
    ) async {
      await pumpApp(
        tester,
        extra: [
          areaNoticeProvider.overrideWith(
            (ref) => const AreaNotice(AreaNoticeKind.none),
          ),
        ],
      );
      await tester.pump();

      expect(
        find.text(
          'You are not a store owner yet. Apply from Settings, Seller application.',
        ),
        findsOneWidget,
      );
    });
  });
}
