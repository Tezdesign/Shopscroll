import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reproduces the recurring underline-tab-row pattern found across the
/// user-facing screens (Discover 228:3130, Activity/My collection/Messages
/// 322:2859, Profile-user_view-products/reels 818:4865): the active tab is
/// bold black text with a bottom border, inactive tabs are a muted gray with
/// no border.
///
/// The three real instances differ slightly in layout distribution, font
/// size (14 vs 16), bottom padding (8 vs 4), and inactive color (neutral600
/// vs neutral500 on Activity) — rather than forcing one look, those are
/// exposed as params with defaults matching the majority case, so each
/// screen can reproduce its exact instance faithfully. Figma also uses three
/// different font families here (SF Pro Display / Poppins / Inter, all
/// Semibold) — normalized to [AppTypography.fontFamilyDisplay] like the
/// rest of this project's ad-hoc font drift.
enum SegmentedTabsDistribution {
  /// Tabs hug their content with a fixed gap between them (Discover's
  /// scrollable category row).
  compact,

  /// Tabs hug their content, spread across the full width via
  /// space-between (Activity/My collection/Messages).
  spaceBetween,

  /// Tabs split the full width evenly (Profile-user_view-products/reels).
  equal,
}

class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
    this.distribution = SegmentedTabsDistribution.compact,
    this.fontSize = AppTypography.sizeSm,
    this.bottomPadding = AppSpacing.sm,
    this.inactiveColor = AppColors.neutral600,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final SegmentedTabsDistribution distribution;
  final double fontSize;
  final double bottomPadding;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final tabs = List.generate(
      labels.length,
      (index) => _Tab(
        label: labels[index],
        active: index == activeIndex,
        fontSize: fontSize,
        bottomPadding: bottomPadding,
        inactiveColor: inactiveColor,
        onTap: () => onChanged(index),
      ),
    );

    switch (distribution) {
      case SegmentedTabsDistribution.compact:
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.base),
                tabs[i],
              ],
            ],
          ),
        );
      case SegmentedTabsDistribution.spaceBetween:
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: tabs);
      case SegmentedTabsDistribution.equal:
        return Row(
          children: [
            for (final tab in tabs) Expanded(child: Center(child: tab)),
          ],
        );
    }
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.active,
    required this.fontSize,
    required this.bottomPadding,
    required this.inactiveColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final double fontSize;
  final double bottomPadding;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.neutral1100 : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.only(bottom: bottomPadding),
        decoration: active
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.neutral1100),
                ),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.fontFamilyDisplay,
            fontSize: fontSize,
            height: AppTypography.lineHeightSm,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
