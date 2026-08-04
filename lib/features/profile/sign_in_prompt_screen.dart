import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shown at the `/profile` tab (and, later, cart/checkout) when nobody is
/// signed in (spec 0004, AC-1, AC-2). [ClerkAuthentication] is Clerk's own
/// prebuilt sign in/sign up card; it renders nothing until the Clerk
/// environment has loaded, which briefly shows [_loading] first.
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
            child: const ClerkAuthentication(),
          ),
        ),
      ),
    );
  }
}
