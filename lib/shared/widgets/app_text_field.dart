import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reproduces the Figma "Field / Flexible" component (node 383:640, also
/// shown standalone at node 561:5293): a bordered, single-line-by-default
/// text field — neutral500 border, radius 8 (`AppRadius.md`), ~48px
/// height, a muted neutral500 placeholder in Plus Jakarta Sans. Figma's
/// horizontal padding (9px) has no matching spacing token, so this rounds
/// down to `AppSpacing.sm` (8) rather than add a one-off literal, the same
/// tradeoff [SearchField] documents for its own off-token padding.
///
/// A thin [TextFormField] wrapper, not a from-scratch [Container] (contrast
/// [SearchField]): this needs to plug into [Form]/`validator` the way
/// `edit_profile_screen.dart` already does, so Flutter's own helper/error
/// text slots stand in for the optional "Hint" caption Figma shows below
/// the field, rather than hand-rolling that. Figma shows no dedicated error
/// look for this component, so the error state below borrows the app's
/// existing [AppColors.error400] — the same red already used for
/// destructive/error state elsewhere (e.g. the delete account
/// confirmation) — and `focusedBorder` borrows [AppColors.primary400] for
/// the same reason: reasonable, undocumented-in-Figma extrapolations from
/// the app's own tokens, not invented colors.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.helperText,
    this.errorText,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
    this.maxLines = 1,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;
  final int maxLines;

  static const TextStyle _textStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral1000,
  );

  static final TextStyle _hintStyle = _textStyle.copyWith(
    color: AppColors.neutral500,
  );

  // Figma's "Hint text.." caption below the field (shown both as a plain
  // helper and, per this widget's own extrapolation, as an error message).
  static const TextStyle _helperStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral900,
  );

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color),
      );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      enabled: enabled,
      maxLines: maxLines,
      style: _textStyle,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.white100,
        hintText: hintText,
        hintStyle: _hintStyle,
        helperText: helperText,
        helperStyle: _helperStyle,
        helperMaxLines: 2,
        errorText: errorText,
        errorStyle: _helperStyle.copyWith(color: AppColors.error400),
        errorMaxLines: 2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        border: _border(AppColors.neutral500),
        enabledBorder: _border(AppColors.neutral500),
        disabledBorder: _border(AppColors.neutral300),
        focusedBorder: _border(AppColors.primary400),
        errorBorder: _border(AppColors.error400),
        focusedErrorBorder: _border(AppColors.error400),
      ),
    );
  }
}
