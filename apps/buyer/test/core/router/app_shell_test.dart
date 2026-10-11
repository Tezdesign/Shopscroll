import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/core/area/app_area.dart';
import 'package:marketplace_app/core/onboarding/onboarding_prefs.dart';
import 'package:marketplace_app/core/router/app_shell.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/user_profile_repository.dart';
import 'package:marketplace_app/features/profile/profile_area_action.dart';
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
      builder: (context, state, shell) => AppShell(navigationShell: shell),
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
        for (final path in ['/discover', '/reels', '/activity'])
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: path,
                builder: (context, state) => Text('tab $path'),
              ),
            ],
          ),
        // The Profile tab carries the switch in its header (ProfileAreaAction).
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const Column(
                children: [Text('tab /profile'), ProfileAreaAction()],
              ),
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

/// A tall screen, so the whole dashboard is built (a list builds only what is
/// near the viewport).
void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('the Buyer | Seller switch in the buyer area (spec 0014, AC-4)', () {
    testWidgets('a seller finds it on the Profile tab', (tester) async {
      await pumpApp(tester, role: UserRole.seller, initialLocation: '/profile');

      expect(find.text('Buyer'), findsOneWidget);
      expect(find.text('Seller'), findsOneWidget);
    });

    testWidgets('no other tab shows it, not even for a seller', (tester) async {
      await pumpApp(tester, role: UserRole.seller);
      expect(find.text('home tab'), findsOneWidget);
      expect(find.text('Seller'), findsNothing);

      for (final tab in ['Discover', 'Reels', 'Activity']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(find.text('Seller'), findsNothing, reason: tab);
      }
    });

    testWidgets('a buyer sees Become a seller instead, never the switch', (
      tester,
    ) async {
      await pumpApp(tester, role: UserRole.buyer, initialLocation: '/profile');

      expect(find.text('Become a seller'), findsOneWidget);
      expect(find.text('Seller'), findsNothing);
    });

    testWidgets('a visitor never sees it', (tester) async {
      await pumpApp(
        tester,
        role: UserRole.seller,
        userId: null,
        initialLocation: '/profile',
      );

      expect(find.text('Seller'), findsNothing);
    });

    testWidgets('tapping Seller opens the store area and remembers it', (
      tester,
    ) async {
      tallScreen(tester);
      await pumpApp(tester, role: UserRole.seller, initialLocation: '/profile');

      await tester.tap(find.text('Seller'));
      await tester.pumpAndSettle();
      // The dashboard numbers load after the mock delay.
      await tester.pump(mockNetworkDelay);
      await tester.pump();

      // The store area is the seller dashboard with its Quick Actions.
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Add Product'), findsOneWidget);
      expect(OnboardingPrefs(prefs).lastArea, 'store');
    });
  });

  group('the store area (spec 0014, AC-3, AC-5)', () {
    testWidgets('shows the toggle and the product entry buttons', (
      tester,
    ) async {
      tallScreen(tester);
      await pumpApp(tester, role: UserRole.seller, initialLocation: '/store');
      // The dashboard numbers load after the mock delay.
      await tester.pump(mockNetworkDelay);
      await tester.pump();

      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Add Product'), findsOneWidget);
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
      expect(find.text('Seller'), findsNothing);
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
