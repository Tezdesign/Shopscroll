import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_icon.dart';
import 'country_dial_code.dart';

/// Reproduces the Figma "Flexible" field component's phone variants
/// (component set node 5290:7177: Phone Number 5298:7498, Phone Number
/// filling 5298:7701, Variant6 (filled) 5298:7733, Phone numbererror
/// 5310:9619): a bordered field with a country flag + caret + area code
/// ahead of the number entry, plus an optional helper or error line below.
/// First wired up in `phone_number_screen.dart`, part of the redesigned
/// onboarding flow (see `lib/features/onboarding/AGENTS.md`) — spec 0004's
/// shipped flow still doesn't offer phone sign in (AC-2).
///
/// States match [AppTextField]'s (same component set), with the phone
/// variants' one extra detail:
/// - **Default**: [AppColors.neutral500] border, black "+1".
/// - **filling** (focused): [AppColors.primary500] border and typed text,
///   "+1" stays black.
/// - **Filled** (has text, unfocused): [AppColors.neutral500] border, black
///   text, "+1" turns [AppColors.neutral500].
/// - **disabled** ([enabled] false — the number is locked once a code has
///   been sent, nodes 5284:9570 / 5284:9654): [AppColors.neutral300] border,
///   same as [AppTextField]'s disabled border.
/// - **error**: [AppColors.error500] border, black text, grey "+1", message
///   below in Plus Jakarta Sans 12 [AppColors.error500]. Error wins over
///   filling while focused.
///
/// The flag is a Unicode flag emoji, not the Figma frame's exported SVG:
/// same reasoning [AppIcon]'s doc comment already gives for every other
/// glyph in this file — a short-lived per-asset URL isn't viable to embed
/// permanently, so this substitutes the semantically exact rendered
/// equivalent instead of the transient asset. The caret reuses
/// [AppIconGlyph.chevronDown], already mapped for this same glyph
/// elsewhere.
///
/// The flag, caret and prefix are one tap target that opens
/// [showCountryDialCodePicker] and reports the choice through
/// [onCountryChanged] — the picker Figma's caret implies but has no frame
/// for, so its sheet is this app's own design. [country] is held by the
/// caller, which needs the same dial code to build the full number.
class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    this.controller,
    this.hintText = 'Enter your phone number',
    this.helperText,
    this.errorText,
    this.onChanged,
    this.enabled = true,
    this.country = defaultCountryDialCode,
    this.onCountryChanged,
  });

  final TextEditingController? controller;
  final String hintText;
  final String? helperText;

  /// The country whose flag and dial code sit ahead of the number.
  final CountryDialCode country;

  /// Called with the country picked from the sheet. Null (or [enabled]
  /// false, when the number is locked) leaves the prefix inert.
  final ValueChanged<CountryDialCode>? onCountryChanged;

  /// Shown below the field instead of [helperText] when non-null, and turns
  /// the border red — the same convention as [AppTextField.errorText].
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  final _focusNode = FocusNode();
  late final TextEditingController _controller;
  late final bool _ownsController;

  static const double _height = 48;
  static const double _flagSize = AppSpacing.xl;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _focusNode.addListener(_rebuild);
    _controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_rebuild)
      ..dispose();
    _controller.removeListener(_rebuild);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _pickCountry() async {
    final picked = await showCountryDialCodePicker(
      context,
      selected: widget.country,
    );
    if (picked != null) widget.onCountryChanged?.call(picked);
  }

  static TextStyle _textStyle(Color color) => TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle _prefixStyle(Color color) => TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static const TextStyle _helperStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral800,
  );

  static const TextStyle _errorStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightXs,
    fontWeight: FontWeight.w400,
    color: AppColors.error500,
  );

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final focused = _focusNode.hasFocus;
    final hasText = _controller.text.isNotEmpty;

    final borderColor = hasError
        ? AppColors.error500
        : !widget.enabled
        ? AppColors.neutral300
        : focused
        ? AppColors.primary500
        : AppColors.neutral500;
    final textColor = !hasError && focused
        ? AppColors.primary500
        : AppColors.neutral1100;
    final prefixColor = hasText && (!focused || hasError)
        ? AppColors.neutral500
        : AppColors.neutral1100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.white100,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.enabled && widget.onCountryChanged != null
                    ? _pickCountry
                    : null,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Text(
                      widget.country.flag,
                      style: const TextStyle(fontSize: _flagSize),
                    ),
                    const AppIcon(
                      AppIconGlyph.chevronDown,
                      size: _flagSize,
                      color: AppColors.neutral1000,
                    ),
                    Text(
                      widget.country.dialCode,
                      style: _prefixStyle(prefixColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: widget.enabled ? widget.onChanged : null,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.phone,
                  style: _textStyle(textColor),
                  cursorColor: hasError
                      ? AppColors.error500
                      : AppColors.primary500,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: widget.hintText,
                    hintStyle: _textStyle(AppColors.neutral500),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(widget.errorText!, style: _errorStyle),
        ] else if (widget.helperText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(widget.helperText!, style: _helperStyle),
        ],
      ],
    );
  }
}
