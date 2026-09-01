import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_icon.dart';

/// Reproduces the Figma "PhoneInput" component (node 550:3637): a bordered
/// field with a country flag + caret + area code ahead of the number
/// entry, plus an optional helper line below. Not wired into any screen
/// yet — phone sign in is off (spec 0004, AC-2) and nothing else in the
/// app collects a phone number today — but built to the full spec now so
/// it's ready when something does, the same way [AppButton] ships every
/// documented variant ahead of full call-site coverage.
///
/// The flag is a Unicode flag emoji, not the Figma frame's exported SVG:
/// same reasoning [AppIcon]'s doc comment already gives for every other
/// glyph in this file — a short-lived per-asset URL isn't viable to embed
/// permanently, so this substitutes the semantically exact rendered
/// equivalent instead of the transient asset. The caret reuses
/// [AppIconGlyph.chevronDown], already mapped for this same glyph
/// elsewhere. Both the flag and "+1" are static: Figma's caret implies a
/// country picker, but no picker UI or country list exists anywhere in the
/// file, so wiring one is future work, not a deviation being papered over.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    this.controller,
    this.hintText = 'Enter your phone number',
    this.helperText,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String hintText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  static const double _height = 48;
  static const double _flagSize = 24;

  static const TextStyle _prefixStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral1000,
  );

  static const TextStyle _textStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral1000,
  );

  static final TextStyle _hintStyle = _textStyle.copyWith(
    color: AppColors.neutral500,
  );

  static const TextStyle _helperStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral800,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: BoxDecoration(
            color: AppColors.white100,
            border: Border.all(color: AppColors.neutral500),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              const Text(
                '🇺🇸',
                style: TextStyle(fontSize: _flagSize),
              ),
              const AppIcon(
                AppIconGlyph.chevronDown,
                size: _flagSize,
                color: AppColors.neutral1000,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text('+1', style: _prefixStyle),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: enabled ? onChanged : null,
                  enabled: enabled,
                  keyboardType: TextInputType.phone,
                  style: _textStyle,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: _hintStyle,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.base),
            child: Text(helperText!, style: _helperStyle),
          ),
        ],
      ],
    );
  }
}
