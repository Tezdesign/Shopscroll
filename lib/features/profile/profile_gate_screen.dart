import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'account_screen.dart';
import 'sign_in_prompt_screen.dart';
import 'welcome_screen.dart';

/// The `/profile` tab's real entry point once Clerk is configured (spec
/// 0004, AC-1): [ClerkAuthBuilder] rebuilds between [_SignedOutFlow] and
/// [AccountScreen] as sign in state changes, with a brief loading state
/// while the Clerk environment is still being fetched.
class ProfileGateScreen extends StatelessWidget {
  const ProfileGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ClerkAuthBuilder(
      signedInBuilder: (context, authState) =>
          AccountScreen(authState: authState),
      signedOutBuilder: (context, authState) => const _SignedOutFlow(),
      builder: (context, authState) => Scaffold(
        backgroundColor: AppColors.neutral100,
        body: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// [WelcomeScreen] (Figma node 561:5267) until "Sign up"/"Log in" is
/// tapped, then [SignInPromptScreen]'s Clerk card, which has its own link
/// to switch between the two modes internally.
class _SignedOutFlow extends StatefulWidget {
  const _SignedOutFlow();

  @override
  State<_SignedOutFlow> createState() => _SignedOutFlowState();
}

class _SignedOutFlowState extends State<_SignedOutFlow> {
  bool _showAuth = false;

  @override
  Widget build(BuildContext context) {
    if (_showAuth) return const SignInPromptScreen();
    return WelcomeScreen(
      onSignUp: () => setState(() => _showAuth = true),
      onLogIn: () => setState(() => _showAuth = true),
    );
  }
}
