import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';

/// Reproduces the Figma "Let's get started" screen (node 5284:7789, the
/// first step of the redesigned onboarding flow drafted in the file's
/// "Sign in" section — full name + username, collected before the
/// phone/email identity step). Not yet wired into `app_router.dart` or
/// spec 0004: [CreateAccountScreen] (node 561:5289) is still the live
/// `/sign-up` route; this screen is being built ahead of the rest of the
/// new flow, one screen at a time.
///
/// Close icon matches [CreateAccountScreen]'s own AppBar exactly (leading
/// [IconButton], `centerTitle: true`, no actions) — the source frame's
/// trailing nav icon (node 5284:7808) renders empty in the design, the same
/// invisible-spacer pattern [CreateAccountScreen] already documents for its
/// social buttons, so it's dropped rather than reproduced literally.
///
/// Both fields are [AppTextField] (already the shared field component, with
/// its own default/focused/error border states) inside a [Form] with
/// `AutovalidateMode.onUserInteraction`, so the error state shows itself
/// while typing after the first failed [Continue] tap rather than needing
/// bespoke per-field state tracking here.
class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key, required this.onContinue});

  /// Called with the entered full name and username once both fields pass
  /// validation. The caller decides what comes next — this screen doesn't
  /// navigate itself, matching [WelcomeScreen]'s callback-based shape.
  final void Function(String fullName, String username) onContinue;

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name.';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Please enter a username.';
    if (trimmed.contains(' ')) return 'Username can\'t contain spaces.';
    return null;
  }

  void _continue() {
    if (_formKey.currentState!.validate()) {
      widget.onContinue(
        _fullNameController.text.trim(),
        _usernameController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral100,
      appBar: AppBar(
        backgroundColor: AppColors.neutral100,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Sign up', style: AppTypography.headlineLarge),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.base),
                Text(
                  'Let’s get started',
                  style: AppTypography.displaySmall.copyWith(
                    color: AppColors.neutral1100,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Tell us about Yourself',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.neutral500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  controller: _fullNameController,
                  hintText: 'Fullname',
                  textInputAction: TextInputAction.next,
                  validator: _validateFullName,
                ),
                const SizedBox(height: AppSpacing.base),
                AppTextField(
                  controller: _usernameController,
                  hintText: 'Username',
                  textInputAction: TextInputAction.done,
                  validator: _validateUsername,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(label: 'Continue', onPressed: _continue),
                ),
                const SizedBox(height: AppSpacing.base),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
