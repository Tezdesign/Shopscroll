import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/country_dial_code.dart';
import '../../shared/widgets/phone_field.dart';
import 'verification_code_section.dart';

/// Which identifier someone is signing in with. Picks the Clerk strategy
/// (`emailCode` or `phoneCode`) that `sign_in_verification.dart` uses.
enum LogInChannel { email, phone }

/// The two halves of the "Who are you" toggle (Figma component 620:3086).
/// Presentational for now: buyer and seller share one onboarding flow, and
/// what separates them is the seller only interfaces that come later, so
/// nothing downstream reads this yet (no role on Clerk, no role column in
/// Supabase). Kept in the screen so the element exists and toggles.
enum AccountType { buyer, storeOwner }

/// Reproduces the Figma "Log in" screen and its states (nodes 3001:11087
/// empty, 5369:2154 typing, 5368:7329 filled, 5364:7369 verification,
/// 5369:2384 loading, 5369:2267 error), the way a returning person signs
/// back in. See `lib/features/onboarding/AGENTS.md`.
///
/// One screen, two stages that advance in place, mirroring
/// [EmailAddressScreen] and [PhoneNumberScreen]:
/// 1. **Enter identifier**: the "Who are you" toggle and an identifier
///    field, nothing else. Log in validates the identifier and calls
///    [onSendCode].
/// 2. **Verify**: a [VerificationCodeSection] appears under the identifier,
///    followed by the channel switch link. Log in validates the 6 digit
///    code and calls [onVerify].
///
/// There is no password anywhere, matching sign up (spec 0004 decision,
/// "a one time code sent to a phone number, or to an email address").
/// Figma's "Forgot password ?" line sits hidden in the frames for the same
/// reason, so it is not built here.
///
/// Deviations from the source frames:
/// - The first stage has no "Use phone number instead" link, unlike the
///   frames, which draw it there too. The field's own "Email or phone
///   number" placeholder already says both are accepted, so the link only
///   appears in the verify stage, where it means "the code did not reach
///   me, try the other channel".
/// - That link swaps the identifier field for a [PhoneField], so a phone
///   identifier gets the country picker and is sent in E.164, the way
///   [PhoneNumberScreen] does it, and returns to the first stage because a
///   code sent to the old identifier would not match the new one.
/// - Switching channel, or editing the identifier during the verify stage,
///   returns to the first stage: a code sent to the old identifier would
///   not match the new one.
/// - The leading icon is the frame's close cross, and it leaves the screen
///   from either stage. [EmailAddressScreen] uses a back arrow that steps
///   back a stage instead; editing the identifier already covers that here.
/// - The error frame (5369:2267) draws "Invalid code . check it and try
///   again" under the field. A code Clerk rejects is a Clerk error, so it
///   surfaces in the app wide `ClerkErrorListener` snack bar per spec 0004
///   AC-12, the same as every other screen in this flow. The field's own
///   red message is kept for what this screen can check itself, a code
///   that is not 6 digits.
/// - The toggle is 40px tall as drawn, under the 44px minimum tap target.
///   Its height comes from the shared component, so it is worth fixing
///   there rather than here.
class LogInScreen extends StatefulWidget {
  const LogInScreen({
    super.key,
    required this.onSendCode,
    required this.onVerify,
    required this.onResendCode,
    required this.onSignUp,
    this.resendCooldown = const Duration(seconds: 30),
  });

  /// Called with the validated identifier (an email address, or an E.164
  /// number) once Log in is pressed on the first stage; the caller asks
  /// Clerk to send the code. The screen moves to the verify stage only if
  /// this resolves `true` — a failed send (e.g. no account for that
  /// identifier) stays on this stage instead of showing a countdown for a
  /// code that was never sent.
  final Future<bool> Function(LogInChannel channel, String identifier)
  onSendCode;

  /// Called with the identifier and the entered 6 digit code once the code
  /// passes validation; the caller checks it and decides what comes next.
  final Future<void> Function(
    LogInChannel channel,
    String identifier,
    String code,
  )
  onVerify;

  /// Called when "Resend code" is tapped after the countdown ends.
  final Future<void> Function(LogInChannel channel, String identifier)
  onResendCode;

  /// "Sign up" in the footer. The screen signals the choice rather than
  /// navigating itself, the same shape the other onboarding screens use.
  final VoidCallback onSignUp;

  /// How long "Resend code" stays disabled after a code is sent.
  final Duration resendCooldown;

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  LogInChannel _channel = LogInChannel.email;
  AccountType _accountType = AccountType.buyer;
  CountryDialCode _country = defaultCountryDialCode;
  String? _identifierError;
  String? _codeError;
  bool _verifying = false;

  /// True while a send or verify call is in flight, which disables the
  /// button, reproducing the loading frame (5369:2384).
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _isPhone => _channel == LogInChannel.phone;

  String get _phoneDigits =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '');

  /// What Clerk receives: an E.164 number (country code included) or a
  /// trimmed email address.
  String get _identifier => _isPhone
      ? '${_country.dialCode}$_phoneDigits'
      : _emailController.text.trim();

  String? _validateIdentifier() {
    if (_isPhone) {
      if (!_country.isPlausibleNationalNumber(_phoneDigits)) {
        return 'Please enter a valid phone number.';
      }
      return null;
    }
    if (!_emailPattern.hasMatch(_emailController.text.trim())) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  void _onIdentifierChanged(String value) {
    if (_verifying) {
      // A different identifier needs a new code.
      _codeController.clear();
      setState(() {
        _verifying = false;
        _codeError = null;
      });
    }
    // Clear a shown error as soon as the identifier becomes valid, the same
    // "fix it and the error goes away immediately" feel as the other screens.
    if (_identifierError != null && _validateIdentifier() == null) {
      setState(() => _identifierError = null);
    }
  }

  void _onCodeChanged(String value) {
    if (_codeError != null && VerificationCodeSection.validate(value) == null) {
      setState(() => _codeError = null);
    }
  }

  void _switchChannel() {
    setState(() {
      _channel = _isPhone ? LogInChannel.email : LogInChannel.phone;
      _verifying = false;
      _identifierError = null;
      _codeError = null;
    });
    _codeController.clear();
  }

  Future<void> _continue() async {
    if (_busy) return;

    if (!_verifying) {
      final error = _validateIdentifier();
      if (error != null) {
        setState(() => _identifierError = error);
        return;
      }
      setState(() {
        _identifierError = null;
        _busy = true;
      });
      final sent = await widget.onSendCode(_channel, _identifier);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (sent) _verifying = true;
      });
      return;
    }

    final error = VerificationCodeSection.validate(_codeController.text);
    if (error != null) {
      setState(() => _codeError = error);
      return;
    }
    setState(() => _busy = true);
    await widget.onVerify(
      _channel,
      _identifier,
      _codeController.text.replaceAll(RegExp(r'\D'), ''),
    );
    if (!mounted) return;
    setState(() => _busy = false);
  }

  void _resend() {
    setState(() => _codeError = null);
    unawaited(widget.onResendCode(_channel, _identifier));
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
          icon: const AppIcon(AppIconGlyph.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Log in', style: AppTypography.headlineLarge),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.base),
              Text(
                'Welcome back !',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.neutral1100,
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              _AccountTypeToggle(
                selected: _accountType,
                onChanged: (type) => setState(() => _accountType = type),
              ),
              const SizedBox(height: AppSpacing.base),
              if (_isPhone)
                PhoneField(
                  controller: _phoneController,
                  errorText: _identifierError,
                  country: _country,
                  onCountryChanged: (country) =>
                      setState(() => _country = country),
                  onChanged: _onIdentifierChanged,
                )
              else
                AppTextField(
                  controller: _emailController,
                  hintText: 'Email or phone number',
                  errorText: _identifierError,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: _onIdentifierChanged,
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
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: _switchChannel,
                  child: Text(
                    _isPhone ? 'Use email instead' : 'Use phone number instead',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primary300,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Log in',
                  enabled: !_busy,
                  onPressed: () => unawaited(_continue()),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              _FooterLine(
                lead: 'Don’t have an account ? ',
                link: 'Sign up',
                onTap: widget.onSignUp,
              ),
              const SizedBox(height: AppSpacing.base),
              // No seller flow exists to route to yet (the app is buyer side
              // only), so this line is drawn but not tappable.
              const _FooterLine(
                lead: 'Interested in becoming a seller ? ',
                link: 'Apply now',
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Who are you" pill (Figma 620:3086): two equal halves, the selected
/// one filled [AppColors.primary100] with [AppColors.primary500] label and
/// icon, the other [AppColors.neutral200] with [AppColors.neutral400].
class _AccountTypeToggle extends StatelessWidget {
  const _AccountTypeToggle({required this.selected, required this.onChanged});

  /// The frame's height. Not a spacing token, the same way [AppButton]
  /// carries its own 44.
  static const double _height = 40;

  final AccountType selected;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Row(
        children: [
          Expanded(child: _half(AccountType.buyer, AppIconGlyph.user, 'Buyer')),
          Expanded(
            child: _half(
              AccountType.storeOwner,
              AppIconGlyph.store,
              'Store owner',
            ),
          ),
        ],
      ),
    );
  }

  Widget _half(AccountType type, AppIconGlyph glyph, String label) {
    final active = type == selected;
    final foreground = active ? AppColors.primary500 : AppColors.neutral400;
    return GestureDetector(
      onTap: () => onChanged(type),
      child: Container(
        height: _height,
        alignment: Alignment.center,
        color: active ? AppColors.primary100 : AppColors.neutral200,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(glyph, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the two centred footer lines under the button: plain lead text
/// followed by a blue tail. The whole line is the tap target when [onTap] is
/// given, which is a bigger target than the tail alone.
class _FooterLine extends StatelessWidget {
  const _FooterLine({required this.lead, required this.link, this.onTap});

  final String lead;
  final String link;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final line = SizedBox(
      width: double.infinity,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: lead,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.neutral1100,
              ),
            ),
            TextSpan(
              text: link,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.primary300,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
    if (onTap == null) return line;
    return GestureDetector(onTap: onTap, child: line);
  }
}
