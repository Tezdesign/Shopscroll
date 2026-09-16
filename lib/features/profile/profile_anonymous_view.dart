import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';

/// What the Profile tab shows to an anonymous browser (spec 0005, AC-2):
/// a short, friendly explanation plus one button into the first-launch
/// onboarding flow (`lib/features/onboarding/`, spec 0004's welcome
/// screen, Sign up/Log in/Skip), instead of the signed in page from
/// [ProfileScreen], which needs a real account's name, photo, and
/// following count to mean anything. Deliberately not a direct link to
/// Clerk's prebuilt sign in card: every entry into sign in/up goes through
/// the same onboarding screens, not a second, differently-styled path.
class ProfileAnonymousView extends StatelessWidget {
  const ProfileAnonymousView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 48,
                  color: AppColors.neutral400,
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  'Sign in to see your profile',
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your name, photo, and account settings will show up '
                  'here once you have signed in.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.neutral700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Sign up or log in',
                  onPressed: () => context.push('/welcome'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
