import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/country_dial_code.dart';
import '../../shared/widgets/phone_field.dart';
import 'verification_code_section.dart';

/// Reproduces the Figma "Phone number" screen and its verification states,
/// the second step of the redesigned onboarding flow, opened at
/// `/sign-up/phone` after [GetStartedScreen] — see
/// `lib/features/onboarding/AGENTS.md`. The router backs its code callbacks
/// with Clerk's `phoneCode` sign up ([SignUpVerification]).
///
/// One screen, two stages, matching how the source frames advance in place
/// rather than navigating:
/// 1. **Enter number** (node 5284:9148): [PhoneField] + "Use email
///    instead". Continue validates the number and calls [onSendCode].
/// 2. **Verify** (nodes 5284:9424, 5284:9570, 5284:9654): the number locks
///    (disabled [PhoneField]) and a [VerificationCodeSection] appears
///    ("Resend code in 0:30" counting down, then a "Resend code" link).
///    Continue validates the 6 digit code and calls [onVerify]. "Use email
///    instead" stays in both stages.
///
/// Deviations from the source frames:
/// - The locked number in nodes 5284:9570/9654 is drawn with an older
///   "Phone Input" component (light grey border, Inter 16 text) rather than
///   the "Flexible" phone variants the field states are built from (see
///   [PhoneField]); the locked state here is [PhoneField] disabled, so it
///   stays consistent with those variants.
/// - Back arrow in the verify stage returns to the number stage (unlocking
///   the field so a wrong number can be fixed) instead of leaving the
///   screen; Figma doesn't specify either.
/// - Error copy is "Please enter a valid phone number." rather than the
///   source's "Invalide Phone Number" (node 5312:7273) — a typo in the
///   source, corrected rather than reproduced.
///
/// Leading icon is a back arrow (not the close "X" [GetStartedScreen] uses)
/// — the source frame's own nav icon differs here, so this follows it
/// rather than the sibling screen's shape.
class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({
    super.key,
    required this.onSendCode,
    required this.onVerify,
    required this.onResendCode,
    required this.onUseEmailInstead,
    this.resendCooldown = const Duration(seconds: 30),
  });

  /// Called with the number in E.164 (the picked country's dial code plus
  /// the entered digits, e.g. `+15551234567`) once it passes validation; the
  /// caller sends the code. The screen then moves to the verify stage.
  final void Function(String phoneNumber) onSendCode;

  /// Called with the number and the entered 6 digit code once the code
  /// passes validation; the caller checks it and decides what comes next,
  /// same shape as [GetStartedScreen.onContinue].
  final void Function(String phoneNumber, String code) onVerify;

  /// Called when "Resend code" is tapped after the countdown ends.
  final void Function(String phoneNumber) onResendCode;

  /// "Use email instead" — this screen just signals the choice rather than
  /// navigating itself.
  final VoidCallback onUseEmailInstead;

  /// How long "Resend code" stays disabled after a code is sent.
  final Duration resendCooldown;

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  CountryDialCode _country = defaultCountryDialCode;
  String? _phoneError;
  String? _codeError;
  bool _verifying = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// The number as Clerk takes it: the picked country's dial code followed
  /// by the entered digits, with any formatting the person typed stripped.
  String get _phoneNumber =>
      '${_country.dialCode}${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';

  String? _validatePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    // Length only, and against the picked country's own E.164 room rather
    // than a fixed minimum: Clerk is what actually validates the number.
    if (!_country.isPlausibleNationalNumber(digits)) {
      return 'Please enter a valid phone number.';
    }
    return null;
  }

  void _onPhoneChanged(String value) {
    // Clear a shown error as soon as the number becomes valid, the same
    // "fix it and the error goes away immediately" feel GetStartedScreen's
    // form gets for free from AutovalidateMode.onUserInteraction.
    if (_phoneError != null && _validatePhone(value) == null) {
      setState(() => _phoneError = null);
    }
  }

  void _onCodeChanged(String value) {
    if (_codeError != null && VerificationCodeSection.validate(value) == null) {
      setState(() => _codeError = null);
    }
  }

  void _continue() {
    if (!_verifying) {
      final error = _validatePhone(_phoneController.text);
      if (error != null) {
        setState(() => _phoneError = error);
        return;
      }
      setState(() {
        _phoneError = null;
        _verifying = true;
      });
      widget.onSendCode(_phoneNumber);
      return;
    }

    final error = VerificationCodeSection.validate(_codeController.text);
    if (error != null) {
      setState(() => _codeError = error);
      return;
    }
    widget.onVerify(
      _phoneNumber,
      _codeController.text.replaceAll(RegExp(r'\D'), ''),
    );
  }

  void _resend() {
    setState(() => _codeError = null);
    widget.onResendCode(_phoneNumber);
  }

  void _back() {
    if (!_verifying) {
      Navigator.of(context).maybePop();
      return;
    }
    _codeController.clear();
    setState(() {
      _verifying = false;
      _codeError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral100,
      appBar: AppBar(
        backgroundColor: AppColors.neutral100,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: Text('Sign up', style: AppTypography.headlineLarge),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.base),
              Text(
                'Phone number',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.neutral1100,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Enter your phone number . we will send you a confirmation code',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PhoneField(
                controller: _phoneController,
                errorText: _phoneError,
                enabled: !_verifying,
                onChanged: _onPhoneChanged,
                country: _country,
                onCountryChanged: (country) => setState(() {
                  _country = country;
                  // A number that was too long for the old country (or too
                  // short) may be fine for this one, and the reverse.
                  if (_phoneError != null) {
                    _phoneError = _validatePhone(_phoneController.text);
                  }
                }),
              ),
              if (_verifying) ...[
                const SizedBox(height: AppSpacing.base),
                VerificationCodeSection(
                  controller: _codeController,
                  errorText: _codeError,
                  onChanged: _onCodeChanged,
                  onResend: _resend,
                  resendCooldown: widget.resendCooldown,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              GestureDetector(
                onTap: widget.onUseEmailInstead,
                child: Text(
                  'Use email instead',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primary300,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: AppButton(label: 'Continue', onPressed: _continue),
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}
