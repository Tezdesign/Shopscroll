import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_icon.dart';

/// One line of the Profile screen's Generals / Help and Legal lists (Figma
/// node 322:2872, e.g. "Delivery addresses", "Privacy policy"): a label on
/// the left, a trailing glyph on the right (a chevron for most rows, an
/// "open outside the app" glyph for the legal pages, none for Log out /
/// Delete account, which set [labelColor] instead to read as a danger
/// action). Unlike [InfoRow] (a leading icon plus text), these rows carry
/// no leading icon in the source design.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.trailingIcon = AppIconGlyph.forward,
    this.labelColor,
    this.onTap,
  });

  final String label;
  final AppIconGlyph? trailingIcon;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyLarge.copyWith(
                  color: labelColor ?? AppColors.neutral1000,
                ),
              ),
            ),
            if (trailingIcon != null)
              AppIcon(
                trailingIcon!,
                size: 20,
                color: labelColor ?? AppColors.neutral600,
              ),
          ],
        ),
      ),
    );
  }
}
