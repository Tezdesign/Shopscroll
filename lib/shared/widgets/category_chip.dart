import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reproduces the Figma "Order-satus-category" component (node 860:5950): a
/// selectable filter chip (e.g. "Deals") with a leading icon.
///
/// The source instance also renders a second, identical icon after the
/// label and a second, differently-colored duplicate text layer stacked on
/// top of the visible one — the same kind of stray duplicate-layer artifact
/// already seen elsewhere in this file (e.g. MostVisitedItem's buried
/// "Amazon" text), so only one icon and one text layer are reproduced here.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  static const double _iconSize = 24;
  // Figma tracks this label at 0.28 letterspacing; no shared tracking
  // token exists yet, so it's kept local like elsewhere in this project.
  static const double _letterSpacing = 0.28;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.white100 : AppColors.neutral1100;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary400 : AppColors.neutral100,
          border: selected
              ? null
              : Border.all(color: AppColors.neutral1100),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: _iconSize, color: color),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyDisplay,
                fontSize: AppTypography.sizeSm,
                height: AppTypography.lineHeightSm,
                fontWeight: FontWeight.w600,
                letterSpacing: _letterSpacing,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
