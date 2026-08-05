import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/catalog/home_screen.dart';
import '../../features/catalog/product_detail_screen.dart';
import '../../features/discover/discover_screen.dart';
import '../../features/onboarding/sign_in_prompt_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/reels/reel_player_screen.dart';
import '../../features/reels/reels_screen.dart';
import '../../shared/widgets/coming_soon_screen.dart';
import '../onboarding/onboarding_prefs.dart';
import 'app_shell.dart';

/// Where [appRouterProvider] opens the app: `/welcome` the first time a
/// device is seen (and nobody is already signed in), `/` every time after
/// that. `main.dart` overrides this once, at startup, from
/// [OnboardingPrefs] and the Clerk session; nothing in the router itself
/// re-evaluates it later (spec 0004, AC-1).
final initialLocationProvider = Provider<String>((ref) => '/');

/// Root router. A [StatefulShellRoute] holds the 5 bottom nav tabs (Home,
/// Discover, Reels, Activity, Profile) as branches under [AppShell], so
/// switching tabs preserves each one's own navigation stack and scroll
/// position (see spec 0001). Activity and Profile are both placeholder
/// branches (`ComingSoonScreen`); Profile has no design of its own yet
/// (spec 0004 moved sign in off this tab and onto the first launch welcome
/// screen below, see `## Follow-up`).
///
/// `/welcome` and `/sign-in` (spec 0004, AC-1, AC-2), plus product detail
/// and the Reels full screen player, stay top level routes, outside the
/// shell, so they open full screen without the bottom nav.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: ref.watch(initialLocationProvider),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reels',
                builder: (context, state) => const ReelsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                builder: (context, state) => const ComingSoonScreen(
                  label: 'Activity',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ComingSoonScreen(
                  label: 'Profile',
                  icon: Icons.person_outline,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => WelcomeScreen(
          onSignUp: () {
            ref.read(onboardingPrefsProvider).markWelcomeSeen();
            context.push('/sign-in');
          },
          onLogIn: () {
            ref.read(onboardingPrefsProvider).markWelcomeSeen();
            context.push('/sign-in');
          },
          onSkip: () {
            ref.read(onboardingPrefsProvider).markWelcomeSeen();
            context.go('/');
          },
        ),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInPromptScreen(),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/reels/:id',
        builder: (context, state) => ReelPlayerScreen(
          initialReelId: state.pathParameters['id']!,
          orderedReelIds: state.extra as List<String>?,
        ),
      ),
    ],
  );
});
