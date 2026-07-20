import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/catalog/home_screen.dart';
import '../../features/catalog/product_detail_screen.dart';
import '../../features/discover/discover_screen.dart';
import '../../features/reels/reel_player_screen.dart';
import '../../features/reels/reels_screen.dart';
import '../../shared/widgets/coming_soon_screen.dart';
import 'app_shell.dart';

/// Root router. A [StatefulShellRoute] holds the 5 bottom nav tabs (Home,
/// Discover, Reels, Activity, Profile) as branches under [AppShell], so
/// switching tabs preserves each one's own navigation stack and scroll
/// position (see spec 0001). Activity/Profile are placeholder branches
/// (`ComingSoonScreen`) until those features get their own specs.
///
/// Product detail and the Reels full screen player stay top level routes,
/// outside the shell, so they open full screen without the bottom nav,
/// matching the app's existing behaviour.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
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
