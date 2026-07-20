import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_bottom_nav_bar.dart';

/// The persistent bottom nav shell wrapping every top level tab (Home,
/// Discover, Reels, Activity, Profile). Each tab is a [StatefulShellBranch]
/// in [AppRouter]'s [StatefulShellRoute], so switching tabs preserves each
/// branch's own navigation stack and scroll position instead of rebuilding
/// it from scratch (see spec 0001, the Discover screen's build spec, for
/// why this replaced the previous no-op nav bar).
///
/// Owns the [AppBottomNavBar] once, here; branch screens (e.g. [HomeScreen],
/// `DiscoverScreen`) must not render their own bottom nav bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNavBar(
        currentItem: AppTabItem.values[navigationShell.currentIndex],
        onItemSelected: (item) => navigationShell.goBranch(
          AppTabItem.values.indexOf(item),
          initialLocation: item == AppTabItem.values[navigationShell.currentIndex],
        ),
      ),
    );
  }
}
