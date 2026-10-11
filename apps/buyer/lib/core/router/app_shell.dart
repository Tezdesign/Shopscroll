import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shopscroll_shared/widgets/app_bottom_nav_bar.dart';

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
/// It also shows the notice a non seller gets after choosing Store owner on
/// Log in (spec 0014, AC-1). The Buyer | Seller switch is not here: a seller
/// finds it in the Profile tab's header (`ProfileAreaAction`).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: navigationShell,
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
