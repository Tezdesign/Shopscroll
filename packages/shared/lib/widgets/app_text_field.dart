import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';

/// Reproduces the Figma "Flexible" field component (component set node
/// 5290:7177, single-field variants: Default node 383:638, filling
/// 5290:7178, Filled 5298:7271, error 5310:9651): a bordered, single-line-
/// by-default text field, radius 8 (`AppRadius.md`), ~48px height, Plus
/// Jakarta Sans. Figma's horizontal padding (9px) has no matching spacing
/// token, so this rounds down to `AppSpacing.sm` (8) rather than add a
/// one-off literal, the same tradeoff [SearchField] documents for its own
/// off-token padding.
///
/// The four Figma states, all reproduced here:
/// - **Default** (empty, unfocused): [AppColors.neutral500] border, muted
///   [AppColors.neutral500] placeholder.
/// - **filling** (focused): [AppColors.primary500] border *and* typed
///   text — Figma tints the text itself, not just the border, so this
///   widget owns a [FocusNode] to switch the text color, which a plain
///   [InputDecoration] border swap can't do.
/// - **Filled** (has text, unfocused): [AppColors.neutral500] border,
///   [AppColors.neutral1100] (black) text.
/// - **error**: [AppColors.error500] border, black text, and the message
///   below in Plus Jakarta Sans 12 [AppColors.error500]. Applies whether
///   the error comes from [errorText] or from a [validator] run by an
///   ancestor [Form], and holds while focused (error wins over filling).
///
/// A thin [TextFormField] wrapper, not a from-scratch [Container] (contrast
/// [SearchField]): this needs to plug into [Form]/`validator` the way
/// `edit_profile_screen.dart` already does. Flutter still owns the error
/// *state* (red border, validator results), but the message line is drawn
/// here, under the field, rather than in [InputDecoration]'s helper/error
/// slot: that slot indents its text 12px and sets its vertical position by
/// baseline, while Figma puts the message flush with the field's left edge,
/// 4px below it. The plain helper line (Figma's "Hint text..") keeps this
/// widget's earlier Inter styling: Figma draws it in "SF Pro Text", a font
/// that isn't in the design system's tokens.
class AppTextField extends StatefulWidget {
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
    this.obscureText = false,
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
  final bool obscureText;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _focusNode = FocusNode();
  String? _validatorError;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_rebuild);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  // Mirrors the validator's result so the message line and the text color
  // can follow the error state (a FormField's own error state isn't visible
  // to this widget otherwise). Called outside a build (Form.validate from a
  // button tap) it rebuilds right away; called during a build
  // (AutovalidateMode while typing) setState isn't allowed, so the rebuild
  // waits for the end of the frame.
  String? _validate(String? value) {
    final result = widget.validator!(value);
    if (result != _validatorError) {
      _validatorError = result;
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        setState(() {});
      }
    }
    return result;
  }

  static TextStyle _style(Color color) => TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w400,
    color: color,
  );

  // Figma's "Hint text.." caption below the field, as a plain helper.
  static const TextStyle _helperStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral900,
  );

  static const TextStyle _errorStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w400,
    color: AppColors.error500,
  );

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: BorderSide(color: color),
  );

  // Figma's field is a fixed 48px tall with the text centered; padding
  // derived so one line of text lands on exactly that height.
  static const double _fieldHeight = 48;
  static const double _verticalPadding =
      (_fieldHeight - AppTypography.sizeSm * AppTypography.lineHeightSm) / 2;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null || _validatorError != null;
    final textColor = !hasError && _focusNode.hasFocus
        ? AppColors.primary500
        : AppColors.neutral1100;

    final field = TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      validator: widget.validator == null ? null : _validate,
      errorBuilder: (context, error) => const SizedBox.shrink(),
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      obscureText: widget.obscureText,
      style: _style(textColor),
      cursorColor: hasError ? AppColors.error500 : AppColors.primary500,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.white100,
        hintText: widget.hintText,
        hintStyle: _style(AppColors.neutral500),
        error: widget.errorText == null ? null : const SizedBox.shrink(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: _verticalPadding,
        ),
        border: _border(AppColors.neutral500),
        enabledBorder: _border(AppColors.neutral500),
        disabledBorder: _border(AppColors.neutral300),
        focusedBorder: _border(AppColors.primary500),
        errorBorder: _border(AppColors.error500),
        focusedErrorBorder: _border(AppColors.error500),
      ),
    );

    final message = hasError
        ? widget.errorText ?? _validatorError
        : widget.helperText;
    // Always a Column, even with no message: swapping between a bare field
    // and a Column when a message appears would recreate the text field and
    // drop focus mid-typing.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        if (message != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: hasError ? _errorStyle : _helperStyle,
            maxLines: 2,
          ),
        ],
      ],
    );
  }
}
