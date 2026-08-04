import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A [ClerkThemeExtension] built from the app's own tokens (Figma node
/// 561:5267's primary blue, `AppColors.primary400`), so Clerk's prebuilt
/// sign in/sign up card matches the app instead of Clerk's stock purple.
/// Scoped to this screen via a local [Theme] wrap rather than added to
/// [AppTheme] globally, so the rest of the app doesn't pick up a
/// `clerk_flutter` dependency it doesn't need.
final _clerkBrandTheme = ClerkThemeExtension(
  colors: ClerkThemeColors(
    background: AppColors.neutral100,
    altBackground: AppColors.neutral200,
    borderSide: AppColors.neutral300,
    text: AppColors.neutral1000,
    icon: AppColors.neutral600,
    lightweightText: AppColors.neutral600,
    error: AppColors.error400,
    accent: AppColors.primary400,
  ),
);

/// Shown at the `/profile` tab (and, later, cart/checkout) when nobody is
/// signed in (spec 0004, AC-1, AC-2). [ClerkAuthentication] is Clerk's own
/// prebuilt sign in/sign up card; it renders nothing until the Clerk
/// environment has loaded, which briefly shows a blank screen first.
class SignInPromptScreen extends StatelessWidget {
  const SignInPromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Theme(
              data: Theme.of(context).copyWith(
                extensions: [_clerkBrandTheme],
              ),
              child: const ClerkAuthentication(),
            ),
          ),
        ),
      ),
    );
  }
}
