import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';

/// The app's first launch screen (spec 0004, AC-1), reproducing Figma node
/// 561:5267 ("iPhone 14 & 15 Pro - 56"). Shown once per device, before the
/// main app shell, then never again (see `core/onboarding/onboarding_prefs.dart`
/// and `core/router/app_router.dart`). "Log in" opens [SignInPromptScreen]
/// (Clerk's own prebuilt card); "Sign up" opens [CreateAccountScreen], a
/// hand-built form matching its own Figma frame (node 561:5289) — the two
/// buttons lead to different screens, not the same prebuilt card in two
/// modes (see [CreateAccountScreen]'s doc comment for why). "Skip for now"
/// goes straight to browsing, matching the copy already used for this
/// exact choice elsewhere in the source Figma file. "Apply now" is left as
/// a static label: seller onboarding is out of scope (see AGENTS.md, buyer
/// side only).
///
/// Sign up/Log in are [AppButton] (`AppButtonSize.small`, primary/secondary)
/// stretched to share the row via [Expanded] — the source frame instances
/// this exact "small" variant with `flex-1` rather than the component's
/// standalone 274px "big" width, so `AppButton` already renders correctly
/// here without a dedicated full-width variant.
///
/// Vertical layout: the source frame absolutely positions the wordmark
/// block dead center of the screen (`top: 50%`, `translate(-50%,-50%)`)
/// and the Skip/buttons/seller-line block pinned near the bottom. A
/// [Stack] reproduces that directly — [Center] for the wordmark block,
/// [Positioned] pinning the bottom block — rather than approximating the
/// two gaps around it with [Spacer] flex weights, which only ever
/// coincidentally lines up with true centering on one specific screen
/// size. The three rows inside the bottom block (Skip for now / buttons
/// row / seller line) share one uniform 8px gap in the source frame, not a
/// bigger gap before the seller line.
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
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Shopscroll',
                      textAlign: TextAlign.center,
                      // Figma sets this instance at 32px with -0.86
                      // tracking; 32 has no matching size token (nearest is
                      // displayMedium's 30), so the size stays token-based
                      // while the literal tracking value — a real
                      // per-instance Figma detail, not a spacing/size token
                      // question — is kept as-is.
                      style: AppTypography.displayMedium.copyWith(
                        color: AppColors.primary400,
                        letterSpacing: -0.86,
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
                  ],
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.base,
              right: AppSpacing.base,
              bottom: AppSpacing.xl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: onSkip,
                    child: Text(
                      'Skip for now',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.neutral500,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Sign up',
                          size: AppButtonSize.small,
                          onPressed: onSignUp,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.base),
                      Expanded(
                        child: AppButton(
                          label: 'Log in',
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          onPressed: onLogIn,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text.rich(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
