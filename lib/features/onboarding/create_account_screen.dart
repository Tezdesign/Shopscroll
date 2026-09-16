import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import 'verify_email_screen.dart';

/// Reproduces the Figma "Sign up" screen (node 561:5289, "iPhone 14 & 15
/// Pro - 58"): a hand-built account creation form, opened from the welcome
/// screen's Sign up button. [SignInPromptScreen] (Log in) still uses
/// Clerk's prebuilt card — spec 0004 chose that specifically so "almost no
/// custom auth UI has to be built"; building this screen for Sign up is a
/// real change to that decision, not just a visual variant of it, and is
/// worth folding back into the spec rather than leaving it undocumented.
///
/// Two deviations from the literal source frame, both because the source
/// data itself doesn't hold up to a literal clone:
/// - Figma labels both fields "Enter your email" — read literally that's
///   two identical email fields, which doesn't match a sign up form or
///   AC-2 ("email + password"). Built here as email + password instead.
/// - The "Sign in using facebook" button's icon asset is, byte for byte,
///   the same file as the Apple button's own *invisible* spacer icon in
///   the source frame — not a real Facebook mark, a stray reference.
///   Facebook is also never configured anywhere in spec 0004 (only
///   email/password + Google + Apple were set up in Clerk's dashboard).
///   Dropped rather than shipping a broken or mislabelled button.
///
/// Continue calls Clerk's headless `attemptSignUp` twice in sequence — the
/// same two-step password-then-emailCode sequence `clerk_flutter`'s own
/// prebuilt sign up panel uses internally — then hands off to
/// [VerifyEmailScreen] for the code Clerk requires (AC-2). Errors surface
/// through the app's existing global `ClerkErrorListener` (AC-12); nothing
/// bespoke is added here for that.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _legalAccepted = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continue(ClerkAuthState authState) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!_legalAccepted || email.isEmpty || password.isEmpty) return;

    final client = await authState.safelyCall(context, () async {
      await authState.attemptSignUp(
        strategy: clerk.Strategy.password,
        emailAddress: email,
        password: password,
        passwordConfirmation: password,
        legalAccepted: _legalAccepted,
      );
      // A separate call, not part of the one above: this is what actually
      // triggers Clerk to send the verification email (see the class doc).
      return authState.attemptSignUp(strategy: clerk.Strategy.emailCode);
    });

    if (client != null && mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const VerifyEmailScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ClerkAuth.of(context);

    return Scaffold(
      backgroundColor: AppColors.neutral100,
      appBar: AppBar(
        backgroundColor: AppColors.neutral100,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text('Sign up', style: AppTypography.headlineLarge),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: authState,
          builder: (context, _) {
            final canContinue =
                _legalAccepted &&
                authState.passwordIsValid(
                  _passwordController.text,
                  _passwordController.text,
                );
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    'Create your account',
                    style: AppTypography.displaySmall.copyWith(
                      color: AppColors.neutral1100,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  AppTextField(
                    controller: _emailController,
                    hintText: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  AppTextField(
                    controller: _passwordController,
                    hintText: 'Enter your password',
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _legalAccepted,
                        activeColor: AppColors.primary400,
                        onChanged: (value) =>
                            setState(() => _legalAccepted = value ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text:
                                      'By tapping sign up you agree to our',
                                ),
                                TextSpan(
                                  text: ' terms of service',
                                  style: TextStyle(color: AppColors.primary400),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'privacy policy',
                                  style: TextStyle(color: AppColors.primary400),
                                ),
                              ],
                            ),
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.neutral1100,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: Text(
                      'or',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.neutral500,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SocialSignInButton(
                    label: 'Sign in using google',
                    icon: Image.asset(
                      'assets/icons/google_logo.png',
                      width: 24,
                      height: 24,
                    ),
                    onPressed: () =>
                        authState.ssoSignIn(context, clerk.Strategy.oauthGoogle),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SocialSignInButton(
                    label: 'Sign in using apple',
                    icon: Image.asset(
                      'assets/icons/apple_logo.png',
                      width: 24,
                      height: 24,
                    ),
                    onPressed: () =>
                        authState.ssoSignIn(context, clerk.Strategy.oauthApple),
                  ),
                  const SizedBox(height: AppSpacing.xl * 2),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: Center(
                      child: Text(
                        'Skip for now',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Continue',
                      enabled: canContinue,
                      onPressed: () => _continue(authState),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Interested in becoming a seller ? ',
                          ),
                          TextSpan(
                            text: 'Apply now',
                            style: TextStyle(color: AppColors.primary400),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.neutral1100,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A social sign in row: bordered black (Figma's `neutral1100`), an
/// invisible leading spacer the width of the trailing icon so the label
/// stays visually centered (matches the source frame's own construction —
/// its "opacity-0" spacer icon on the left of each button), then the real
/// brand icon on the right. Private to this screen: nothing else in the
/// app needs this shape yet (contrast [AppButton], which is a real shared
/// component because its 8 variants recur everywhere).
class _SocialSignInButton extends StatelessWidget {
  const _SocialSignInButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral1100),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              const SizedBox(width: _iconSize, height: _iconSize),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamilyDisplay,
                    fontSize: AppTypography.sizeSm,
                    height: AppTypography.lineHeightSm,
                    fontWeight: FontWeight.w500,
                    color: AppColors.neutral1100,
                  ),
                ),
              ),
              SizedBox(width: _iconSize, height: _iconSize, child: icon),
            ],
          ),
        ),
      ),
    );
  }
}
