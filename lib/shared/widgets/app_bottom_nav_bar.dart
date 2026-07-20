import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Which app surface the bar is shown in — the two Figma components
/// ("tabbar-user" node 706:3089, "tabbar-seller" node 706:3719) are
/// structurally identical and differ only in the border-top color
/// (`neutral200` vs `neutral300`, likely unintentional drift in the
/// source file, preserved here for fidelity).
enum AppTabBarVariant { user, seller }

enum AppTabItem { home, discover, reels, activity, profile }

/// Reproduces the Figma "tabbar-user"/"tabbar-seller" components: a fixed
/// 5-tab bottom nav (Home, Discover, Reels, Activity, Profile). The
/// component's own Figma prop (`property1`) only ever selects which tab is
/// active, so that's mirrored here as [currentItem] — the tab set itself
/// isn't caller-configurable, matching the source component's contract.
///
/// Figma renders each tab's icon as a per-state exported image (a filled
/// asset for the active tab, an outline asset otherwise); those assets are
/// short-lived Figma URLs, so this uses the semantically-closest Material
/// icon pair instead. The iOS "Home Indicator" pill baked into the Figma
/// frame is OS chrome, not app UI — omitted here in favor of [SafeArea].
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentItem,
    required this.onItemSelected,
    this.variant = AppTabBarVariant.user,
  });

  final AppTabItem currentItem;
  final ValueChanged<AppTabItem> onItemSelected;
  final AppTabBarVariant variant;

  static const double _height = 65;
  static const double _iconSize = 24;
  static const double _itemVerticalPadding = 6;

  static const Map<AppTabItem, String> _labels = {
    AppTabItem.home: 'Home',
    AppTabItem.discover: 'Discover',
    AppTabItem.reels: 'Reels',
    AppTabItem.activity: 'Activity',
    AppTabItem.profile: 'Profile',
  };

  static const Map<AppTabItem, IconData> _outlineIcons = {
    AppTabItem.home: Icons.shopping_bag_outlined,
    AppTabItem.discover: Icons.search,
    AppTabItem.reels: Icons.play_circle_outline,
    AppTabItem.activity: Icons.receipt_long_outlined,
    AppTabItem.profile: Icons.person_outline,
  };

  static const Map<AppTabItem, IconData> _filledIcons = {
    AppTabItem.home: Icons.shopping_bag,
    AppTabItem.discover: Icons.search,
    AppTabItem.reels: Icons.play_circle_filled,
    AppTabItem.activity: Icons.receipt_long,
    AppTabItem.profile: Icons.person,
  };

  Color get _borderColor => switch (variant) {
    AppTabBarVariant.user => AppColors.neutral200,
    AppTabBarVariant.seller => AppColors.neutral300,
  };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white100,
      child: SafeArea(
        top: false,
        child: Container(
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: _borderColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final item in AppTabItem.values) _buildTab(item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(AppTabItem item) {
    final isActive = item == currentItem;
    final color = isActive ? AppColors.primary400 : AppColors.neutral600;

    return Expanded(
      child: InkWell(
        onTap: () => onItemSelected(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: _itemVerticalPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? _filledIcons[item] : _outlineIcons[item],
                size: _iconSize,
                color: color,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _labels[item]!,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamilyDisplay,
                  fontSize: AppTypography.sizeXs,
                  height: AppTypography.lineHeightXs,
                  fontWeight: FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
