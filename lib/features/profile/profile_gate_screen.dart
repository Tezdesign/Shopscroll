import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'account_screen.dart';
import 'sign_in_prompt_screen.dart';

/// The `/profile` tab's real entry point once Clerk is configured (spec
/// 0004, AC-1): [ClerkAuthBuilder] rebuilds between [SignInPromptScreen] and
/// [AccountScreen] as sign in state changes, with a brief loading state
/// while the Clerk environment is still being fetched.
class ProfileGateScreen extends StatelessWidget {
  const ProfileGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ClerkAuthBuilder(
      signedInBuilder: (context, authState) =>
          AccountScreen(authState: authState),
      signedOutBuilder: (context, authState) => const SignInPromptScreen(),
      builder: (context, authState) => Scaffold(
        backgroundColor: AppColors.neutral100,
        body: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
