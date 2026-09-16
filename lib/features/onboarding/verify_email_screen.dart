import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';

/// The email verification code step [CreateAccountScreen]'s sign up leads
/// into (spec 0004, AC-2 requires email verification). No frame for this
/// exists anywhere in the source Figma file — the "Sign up" frame
/// (561:5289) that screen reproduces jumps straight from Continue to
/// success — so this is built from the app's own design system
/// ([AppTextField], [AppButton]) rather than a Figma node reproduction.
///
/// Submitting the right 6-digit code is the call that actually completes
/// sign up and creates the session (`attemptSignUp(strategy: emailCode,
/// code:)`); [AuthSessionController] picks up the resulting sign in the
/// same way it does for the prebuilt card's own flow (anonymous merge,
/// buyer profile upsert), since both go through the same [ClerkAuthState].
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit(ClerkAuthState authState) async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    await authState.safelyCall(
      context,
      () => authState.attemptSignUp(
        strategy: clerk.Strategy.emailCode,
        code: code,
      ),
    );

    if (mounted && authState.isSignedIn) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ClerkAuth.of(context);
    final email = authState.signUp?.emailAddress;

    return Scaffold(
      backgroundColor: AppColors.neutral100,
      appBar: AppBar(
        backgroundColor: AppColors.neutral100,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
        title: Text('Verify your email', style: AppTypography.headlineLarge),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email == null
                    ? 'Enter the 6-digit code we sent you.'
                    : 'Enter the 6-digit code we sent to $email.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.neutral700,
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _codeController,
                hintText: 'Enter code',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.base),
              AppButton(label: 'Verify', onPressed: () => _submit(authState)),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: () =>
                      authState.resendCode(clerk.Strategy.emailCode),
                  child: Text(
                    'Resend code',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.primary400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
