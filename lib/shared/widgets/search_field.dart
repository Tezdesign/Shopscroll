import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reproduces the Figma "Search Field" component (Property 1=Default,
/// node 968:9784): a bordered pill-ish input with a leading search icon and
/// a "Search for anything" placeholder.
///
/// Figma only shows the empty/placeholder state, so this is built as a real
/// interactive [TextField] rather than a static bar — [controller],
/// [onChanged], and [onSubmitted] drive real search behavior. [onTap] +
/// [readOnly] support the common pattern of using this as a button that
/// navigates to a dedicated search screen instead of editing in place.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hintText = 'Search for anything',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;

  // Layout constants intrinsic to this component (not shared design tokens).
  static const double _iconSize = 24;
  // Figma's vertical padding (7) doesn't land on a shared spacing token
  // (closest is AppSpacing.xs = 4 or AppSpacing.sm = 8), so it's kept local.
  static const double _verticalPadding = 7;

  static const TextStyle _textStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1100,
  );

  static const TextStyle _hintStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral600,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        border: Border.all(color: AppColors.neutral400),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: _verticalPadding,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: _iconSize,
            color: AppColors.neutral600,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              onTap: onTap,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: _textStyle,
              cursorColor: AppColors.primary400,
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                hintText: hintText,
                hintStyle: _hintStyle,
                border: InputBorder.none,
                // Override the app-wide InputDecorationTheme's gray fill
                // (AppColors.neutral200) — this field's background is the
                // white Container above, not the default filled look.
                filled: false,
                fillColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
