import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_icon.dart';

/// Reproduces the recurring icon+text row (Product details node 199:173,
/// e.g. "Fast delivery in 1-2 days", "100% authentic product"; also used on
/// Profile screens for "Go to website" / the address line).
///
/// Some instances (like "Go to website") are tappable, others are plain
/// info lines — [onTap] is optional so both work without two widgets.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor,
    this.onTap,
  });

  final AppIconGlyph icon;
  final String text;
  final Color? iconColor;
  final VoidCallback? onTap;

  static const double _iconSize = 24;
  // Figma tracks this line at -0.43 letterspacing; no shared tracking token
  // exists yet, so it's kept local like the other intrinsic text details.
  static const double _letterSpacing = -0.43;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(
          icon,
          size: _iconSize,
          color: iconColor ?? AppColors.neutral1000,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeSm,
            height: AppTypography.lineHeightBase,
            fontWeight: FontWeight.w500,
            letterSpacing: _letterSpacing,
            color: AppColors.neutral1000,
          ),
        ),
      ],
    );

    if (onTap == null) return row;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }
}
