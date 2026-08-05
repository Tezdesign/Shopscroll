import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The app's first launch screen (spec 0004, AC-1), reproducing Figma node
/// 561:5267 ("iPhone 14 & 15 Pro - 56"). Shown once per device, before the
/// main app shell, then never again (see `core/onboarding/onboarding_prefs.dart`
/// and `core/router/app_router.dart`). "Sign up" and "Log in" both open
/// [SignInPromptScreen] (Clerk's own prebuilt card already has a link to
/// switch between the two modes); "Skip for now" goes straight to
/// browsing, matching the copy already used for this exact choice
/// elsewhere in the source Figma file. "Apply now" is left as a static
/// label: seller onboarding is out of scope (see AGENTS.md, buyer side
/// only).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onSignUp,
    required this.onLogIn,
    required this.onSkip,
  });

  final VoidCallback onSignUp;
  final VoidCallback onLogIn;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Column(
            children: [
              const Spacer(flex: 5),
              Text(
                'Shopscroll',
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium.copyWith(
                  color: AppColors.primary400,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'All of your online shopping in one place.',
                textAlign: TextAlign.center,
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.neutral1100,
                ),
              ),
              const Spacer(flex: 6),
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'Skip for now',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.neutral700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onSignUp,
                      child: const Text('Sign up'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onLogIn,
                      child: const Text('Log in'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.base),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Interested in becoming a seller ? '),
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
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
