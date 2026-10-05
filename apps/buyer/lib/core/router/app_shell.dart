import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shopscroll_shared/widgets/app_bottom_nav_bar.dart';

import '../../features/store/area_toggle.dart';
import '../area/app_area.dart';

/// The persistent bottom nav shell wrapping every top level tab (Home,
/// Discover, Reels, Activity, Profile). Each tab is a [StatefulShellBranch]
/// in [AppRouter]'s [StatefulShellRoute], so switching tabs preserves each
/// branch's own navigation stack and scroll position instead of rebuilding
/// it from scratch (see spec 0001, the Discover screen's build spec, for
/// why this replaced the previous no-op nav bar).
///
/// Owns the [AppBottomNavBar] once, here; branch screens (e.g. [HomeScreen],
/// `DiscoverScreen`) must not render their own bottom nav bar.
///
/// For an approved seller it also owns the [AreaToggle] above the tab screens
/// (spec 0014, AC-4), and only on a tab's own screen: [location] is the
/// current path, and pushed screens inside the shell (the cart, search) do not
/// show it. It also shows the notice a non seller gets after choosing Store
/// owner on Log in (AC-1).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell, this.location});

  final StatefulNavigationShell navigationShell;

  /// The current path, or null when unknown (counts as a tab screen).
  final String? location;

  static const _tabRoots = {
    '/',
    '/discover',
    '/reels',
    '/activity',
    '/profile',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showToggle =
        ref.watch(isSellerProvider) &&
        (location == null || _tabRoots.contains(location));

    // Log in sets the notice before this shell is built, so it is read here
    // and shown once after the frame, then cleared.
    if (ref.watch(areaNoticeProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notice = ref.read(areaNoticeProvider);
        if (!context.mounted || notice == null) return;
        ref.read(areaNoticeProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notice.message),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => context.push('/profile/seller-application'),
            ),
          ),
        );
      });
    }

    return Scaffold(
      // The toggle sits in the top safe area, so the screen below drops its own
      // top padding. Same widgets in the same slots either way, so showing or
      // hiding the toggle never rebuilds the tabs and loses their state.
      body: Column(
        children: [
          showToggle
              ? const SafeArea(
                  bottom: false,
                  child: AreaToggle(current: AppArea.buyer),
                )
              : const SizedBox.shrink(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: showToggle,
              child: navigationShell,
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentItem: AppTabItem.values[navigationShell.currentIndex],
        onItemSelected: (item) => navigationShell.goBranch(
          AppTabItem.values.indexOf(item),
          initialLocation:
              item == AppTabItem.values[navigationShell.currentIndex],
        ),
      ),
    );
  }
}
