import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/widgets/seller_bottom_nav_bar.dart';

import '../../data/providers/chat_providers.dart';
import '../../features/store/seller_gate.dart';

/// The store area's persistent tab bar (spec 0019): Home, Products,
/// Activity, Messages, Profile. Each tab is a [StatefulShellBranch] of the
/// store [StatefulShellRoute], so switching tabs keeps each tab's stack and
/// scroll. Only a seller stays ([SellerGate]). The buyer's [AppShell] is the
/// counterpart for the buyer area.
class SellerShell extends ConsumerWidget {
  const SellerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A dot on Messages while a customer thread is unread (spec 0020, AC-2).
    final hasUnread = (ref.watch(storeUnreadCountProvider).value ?? 0) > 0;
    return SellerGate(
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: SellerBottomNavBar(
          badged: hasUnread ? const {SellerTabItem.messages} : const {},
          currentItem: SellerTabItem.values[navigationShell.currentIndex],
          onItemSelected: (item) => navigationShell.goBranch(
            SellerTabItem.values.indexOf(item),
            initialLocation:
                item == SellerTabItem.values[navigationShell.currentIndex],
          ),
        ),
      ),
    );
  }
}
