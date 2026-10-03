import 'dart:async';

import 'package:flutter/material.dart';

import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_text_field.dart';

/// The "Verification code" field with its resend countdown, shared by
/// [PhoneNumberScreen] (Figma nodes 5284:9424, 5284:9570, 5284:9654) and
/// [EmailAddressScreen] (node 5298:8283), whose verify stages are the same
/// group in the source frames: an [AppTextField] and, 8px under it, either
/// "Resend code in 0:14" ([AppColors.neutral500]) while counting down or a
/// "Resend code" link ([AppColors.primary300]) once it reaches zero.
///
/// The countdown starts when this widget is first shown (the screens only
/// insert it when moving to their verify stage) and restarts on each resend,
/// so the timer needs no handling from the parent. [resendCooldown] defaults
/// to 30s; Figma only shows a "0:14" snapshot, not the starting value.
class VerificationCodeSection extends StatefulWidget {
  const VerificationCodeSection({
    super.key,
    required this.controller,
    required this.onResend,
    this.errorText,
    this.onChanged,
    this.resendCooldown = const Duration(seconds: 30),
  });

  static const int codeLength = 6;

  /// Error text for a code that isn't [codeLength] digits, or null when it is.
  static String? validate(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != codeLength) {
      return 'Please enter the $codeLength digit code.';
    }
    return null;
  }

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  /// Called when the "Resend code" link is tapped; the countdown restarts.
  final VoidCallback onResend;
  final Duration resendCooldown;

  @override
  State<VerificationCodeSection> createState() =>
      _VerificationCodeSectionState();
}

class _VerificationCodeSectionState extends State<VerificationCodeSection> {
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _secondsLeft = widget.resendCooldown.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  void _resend() {
    setState(_startCountdown);
    widget.onResend();
  }

  String get _countdownLabel {
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return 'Resend code in ${_secondsLeft ~/ 60}:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: widget.controller,
          hintText: 'Verification code',
          errorText: widget.errorText,
          keyboardType: TextInputType.number,
          onChanged: widget.onChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_secondsLeft > 0)
          Text(
            _countdownLabel,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.neutral500,
            ),
          )
        else
          GestureDetector(
            onTap: _resend,
            child: Text(
              'Resend code',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.primary300,
              ),
            ),
          ),
      ],
    );
  }
}
