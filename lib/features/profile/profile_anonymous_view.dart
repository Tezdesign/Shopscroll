import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';

/// What the Profile tab shows to an anonymous browser (spec 0005, AC-2):
/// a short, friendly explanation plus one button to the existing sign in
/// screen, instead of the signed in page from [ProfileScreen], which needs
/// a real account's name, photo, and following count to mean anything.
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
                  onPressed: () => context.push('/sign-in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
