import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum SellerTabItem { home, products, activity, messages, profile }

/// The store area's bottom bar (spec 0019): Home, Products, Activity,
/// Messages, Profile.
///
/// Figma "tabbar-seller" (node 706:3719) for the look: height, icon size,
/// label style, the `neutral300` top border. Deviation: the component in the
/// file still carries the buyer labels (Discover, Reels), so the tab set,
/// labels and icons here are the ones in the spec, and the Figma component
/// should be updated to match. Icons are the closest Material pair, like
/// [AppBottomNavBar].
class SellerBottomNavBar extends StatelessWidget {
  const SellerBottomNavBar({
    super.key,
    required this.currentItem,
    required this.onItemSelected,
  });

  final SellerTabItem currentItem;
  final ValueChanged<SellerTabItem> onItemSelected;

  static const double _height = 65;
  static const double _iconSize = 24;

  static const Map<SellerTabItem, String> _labels = {
    SellerTabItem.home: 'Home',
    SellerTabItem.products: 'Products',
    SellerTabItem.activity: 'Activity',
    SellerTabItem.messages: 'Messages',
    SellerTabItem.profile: 'Profile',
  };

  static const Map<SellerTabItem, IconData> _outlineIcons = {
    SellerTabItem.home: Icons.shopping_bag_outlined,
    SellerTabItem.products: Icons.inventory_2_outlined,
    SellerTabItem.activity: Icons.receipt_long_outlined,
    SellerTabItem.messages: Icons.chat_bubble_outline,
    SellerTabItem.profile: Icons.person_outline,
  };

  static const Map<SellerTabItem, IconData> _filledIcons = {
    SellerTabItem.home: Icons.shopping_bag,
    SellerTabItem.products: Icons.inventory_2,
    SellerTabItem.activity: Icons.receipt_long,
    SellerTabItem.messages: Icons.chat_bubble,
    SellerTabItem.profile: Icons.person,
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
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.neutral300)),
          ),
          child: Row(
            children: [
              for (final item in SellerTabItem.values) _buildTab(item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(SellerTabItem item) {
    final isActive = item == currentItem;
    final color = isActive ? AppColors.primary400 : AppColors.neutral600;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: _labels[item],
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onItemSelected(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
                  maxLines: 1,
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
      ),
    );
  }
}
