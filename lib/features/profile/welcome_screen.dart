import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The signed out `/profile` tab's landing screen (spec 0004, AC-1),
/// reproducing Figma node 561:5267 ("iPhone 14 & 15 Pro - 56"). "Sign up"
/// and "Log in" both open [SignInPromptScreen] — Clerk's own prebuilt card
/// already exposes a link to switch between the two modes, so there's no
/// separate signed up/log in screen to build. "Apply now" is left as a
/// static label: seller onboarding is out of scope (see AGENTS.md, buyer
/// side only).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onSignUp, required this.onLogIn});

  final VoidCallback onSignUp;
  final VoidCallback onLogIn;

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
