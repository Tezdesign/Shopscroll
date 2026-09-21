import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import 'verification_code_section.dart';

/// Reproduces the Figma "Email address" screen and its verification state
/// (nodes 5298:7977 and 5298:8283), the email alternative to
/// [PhoneNumberScreen] in the redesigned onboarding flow, opened at
/// `/sign-up/email` from that screen's "Use email instead". See
/// `lib/features/onboarding/AGENTS.md`.
///
/// One screen, two stages that advance in place, mirroring
/// [PhoneNumberScreen]:
/// 1. **Enter address** (node 5298:7977): an [AppTextField] + "Use phone
///    number instead". Continue validates the address and calls
///    [onSendCode].
/// 2. **Verify** (node 5298:8283): a [VerificationCodeSection] appears under
///    the address. Continue validates the 6 digit code and calls
///    [onVerify].
///
/// Deviations from the source frames:
/// - The address stays an ordinary, editable field in the verify stage
///   (Figma shows it in its plain "Filled" state, unlike the locked number
///   on the phone frames). Editing it there returns to the first stage,
///   since a code sent to the old address wouldn't match the new one.
/// - The verify stage spaces "Use phone number instead" 12px under the
///   resend line, as in the frame, where the phone frames use 8px.
/// - Back arrow in the verify stage returns to the first stage instead of
///   leaving the screen; Figma doesn't specify either.
/// - The error copy, "Please enter a valid email address.", matches the
///   "Flexible" field's error variant in Figma (node 5310:9651).
///
/// Leading icon is a back arrow, as on [PhoneNumberScreen], following the
/// source frame.
class EmailAddressScreen extends StatefulWidget {
  const EmailAddressScreen({
    super.key,
    required this.onSendCode,
    required this.onVerify,
    required this.onResendCode,
    required this.onUsePhoneInstead,
    this.resendCooldown = const Duration(seconds: 30),
  });

  /// Called with the trimmed address once it passes validation; the caller
  /// sends the code. The screen then moves to the verify stage.
  final void Function(String email) onSendCode;

  /// Called with the address and the entered 6 digit code once the code
  /// passes validation; the caller checks it and decides what comes next.
  final void Function(String email, String code) onVerify;

  /// Called when "Resend code" is tapped after the countdown ends.
  final void Function(String email) onResendCode;

  /// "Use phone number instead" — this screen just signals the choice rather
  /// than navigating itself.
  final VoidCallback onUsePhoneInstead;

  /// How long "Resend code" stays disabled after a code is sent.
  final Duration resendCooldown;

  @override
  State<EmailAddressScreen> createState() => _EmailAddressScreenState();
}

class _EmailAddressScreenState extends State<EmailAddressScreen> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  String? _emailError;
  String? _codeError;
  bool _verifying = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  String? _validateEmail(String value) {
    if (!_emailPattern.hasMatch(value.trim())) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  void _onEmailChanged(String value) {
    if (_verifying) {
      // A different address needs a new code.
      _codeController.clear();
      setState(() {
        _verifying = false;
        _codeError = null;
      });
    }
    // Clear a shown error as soon as the address becomes valid, the same
    // "fix it and the error goes away immediately" feel as the other screens.
    if (_emailError != null && _validateEmail(value) == null) {
      setState(() => _emailError = null);
    }
  }

  void _onCodeChanged(String value) {
    if (_codeError != null && VerificationCodeSection.validate(value) == null) {
      setState(() => _codeError = null);
    }
  }

  void _continue() {
    if (!_verifying) {
      final error = _validateEmail(_emailController.text);
      if (error != null) {
        setState(() => _emailError = error);
        return;
      }
      setState(() {
        _emailError = null;
        _verifying = true;
      });
      widget.onSendCode(_email);
      return;
    }

    final error = VerificationCodeSection.validate(_codeController.text);
    if (error != null) {
      setState(() => _codeError = error);
      return;
    }
    widget.onVerify(_email, _codeController.text.replaceAll(RegExp(r'\D'), ''));
  }

  void _resend() {
    setState(() => _codeError = null);
    widget.onResendCode(_email);
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
                'Email address',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.neutral1100,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Enter your email address. we will send you a confirmation code',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _emailController,
                hintText: 'Email address',
                errorText: _emailError,
                keyboardType: TextInputType.emailAddress,
                onChanged: _onEmailChanged,
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
                const SizedBox(height: AppSpacing.md),
              ] else
                const SizedBox(height: AppSpacing.sm),
              GestureDetector(
                onTap: widget.onUsePhoneInstead,
                child: Text(
                  'Use phone number instead',
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
