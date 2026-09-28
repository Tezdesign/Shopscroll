import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reproduces the pill tab row on Activity's My collection (Figma node
/// 309:1985): the active pill is light blue with blue text, the others are
/// plain with muted text. Each pill keeps a 44 pixel tall tap area and a
/// spoken label (spec 0008, AC-14).
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  static const double _tapHeight = 44;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Semantics(
            button: true,
            selected: i == activeIndex,
            label: labels[i],
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: _tapHeight,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: i == activeIndex
                          ? AppColors.primary50
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamilyDisplay,
                        fontSize: AppTypography.sizeSm,
                        height: AppTypography.lineHeightSm,
                        fontWeight: FontWeight.w600,
                        color: i == activeIndex
                            ? AppColors.primary400
                            : AppColors.neutral600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
