import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reproduces the Figma "Button" component set (Design System-mobile,
/// node 443:2488): 8 variants across Primary/Secondary x active/inactive x
/// big/small.
///
/// Figma's "active"/"inactive" states are the enabled/disabled look of the
/// button (inactive = lighter, desaturated colors), so that's exposed here
/// as [enabled] — it drives both the visual state and whether [onPressed]
/// fires, rather than being a separate concern the caller has to keep in
/// sync.
enum AppButtonVariant { primary, secondary }

enum AppButtonSize { big, small }

class _ButtonSpec {
  const _ButtonSpec({
    required this.verticalPadding,
    required this.cornerRadius,
    this.height,
    this.fixedWidth,
    required this.textColor,
    this.background,
    this.borderColor,
  });

  final double verticalPadding;
  final double cornerRadius;
  final double? height;
  final double? fixedWidth;
  final Color textColor;
  final Color? background;
  final Color? borderColor;
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.big,
    this.enabled = true,
    this.leadingIcon,
    this.trailingIcon,
    this.onPressed,
  });

  final String label;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool enabled;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;

  static const double _iconSize = 24;
  // Fixed width for the "big" variants only — every big instance in Figma
  // uses this same 274 width; "small" variants all hug their content.
  static const double _bigWidth = 274;

  // Per-variant geometry/color, matching each of the 8 Figma instances.
  // Every variant shares the same 12px vertical padding (Figma's `py-12`
  // is uniform across the whole component set); only "big" primary and
  // "small" inactive fix a height (44/40/48) beyond what that padding
  // would naturally hug to — everything else, including both "secondary
  // big" instances, hugs its content instead of taking a fixed height.
  // Most values land exactly on shared tokens (radius sm/md, spacing
  // sm/md/base); horizontal padding is the one approximation (Figma's
  // `px-18` has no matching token, so this rounds down to `AppSpacing.base`
  // (16) rather than introduce a one-off literal).
  _ButtonSpec get _spec {
    switch (variant) {
      case AppButtonVariant.primary:
        if (size == AppButtonSize.big) {
          return _ButtonSpec(
            verticalPadding: AppSpacing.md,
            cornerRadius: AppRadius.md,
            height: 44,
            fixedWidth: _bigWidth,
            background: enabled ? AppColors.primary400 : AppColors.primary100,
            textColor: enabled ? AppColors.white100 : AppColors.primary200,
          );
        }
        return _ButtonSpec(
          verticalPadding: AppSpacing.md,
          cornerRadius: AppRadius.sm,
          height: enabled ? null : 40,
          background: enabled ? AppColors.primary400 : AppColors.primary100,
          textColor: enabled ? AppColors.white100 : AppColors.primary200,
        );
      case AppButtonVariant.secondary:
        if (size == AppButtonSize.big) {
          return _ButtonSpec(
            verticalPadding: AppSpacing.md,
            cornerRadius: AppRadius.sm,
            fixedWidth: _bigWidth,
            borderColor: enabled ? AppColors.primary400 : AppColors.primary100,
            textColor: enabled ? AppColors.primary400 : AppColors.primary200,
          );
        }
        return _ButtonSpec(
          verticalPadding: AppSpacing.md,
          cornerRadius: AppRadius.sm,
          height: enabled ? null : 48,
          borderColor: enabled ? AppColors.primary400 : AppColors.primary100,
          textColor: enabled ? AppColors.primary400 : AppColors.primary200,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;

    return Container(
      width: spec.fixedWidth,
      height: spec.height,
      decoration: BoxDecoration(
        color: spec.background,
        border: spec.borderColor != null
            ? Border.all(color: spec.borderColor!)
            : null,
        borderRadius: BorderRadius.circular(spec.cornerRadius),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(spec.cornerRadius),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(spec.cornerRadius),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: spec.verticalPadding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: _iconSize, color: spec.textColor),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamilyDisplay,
                      fontSize: AppTypography.sizeSm,
                      height: AppTypography.lineHeightSm,
                      fontWeight: FontWeight.w500,
                      color: spec.textColor,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(trailingIcon, size: _iconSize, color: spec.textColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
