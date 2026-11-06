import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/widgets/seller_bottom_nav_bar.dart';

import '../../features/store/seller_gate.dart';

/// The store area's persistent tab bar (spec 0019): Home, Products,
/// Activity, Messages, Profile. Each tab is a [StatefulShellBranch] of the
/// store [StatefulShellRoute], so switching tabs keeps each tab's stack and
/// scroll. Only a seller stays ([SellerGate]). The buyer's [AppShell] is the
/// counterpart for the buyer area.
class SellerShell extends StatelessWidget {
  const SellerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return SellerGate(
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: SellerBottomNavBar(
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
