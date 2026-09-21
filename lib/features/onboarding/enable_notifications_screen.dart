import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/enable_notifications_illustration.dart';

/// Reproduces the Figma "Enable Notifications" screen (node 5288:9738), the
/// last step of the redesigned sign up flow, after [InterestsScreen] — see
/// `lib/features/onboarding/AGENTS.md`.
///
/// A heading, a line of copy, the phone and bell illustration, then the
/// primary "Enable notifications" button with "Remind me Later" under it.
/// Both choices move on; asking after the value has been shown, and letting
/// the ask be declined without cost, is the point of putting this last.
///
/// Deviations from the source frame:
/// - The nav bar title reads "Enable Notifcations" in the frame. The typo is
///   corrected here, as with "Invalide Phone Number" on [PhoneNumberScreen].
/// - The frame's trailing nav icon (node 5288:9757) is drawn at opacity 0,
///   the same placeholder as on [InterestsScreen], so it is left out.
/// - The body copy's spaces before its commas ("Offers , new articles") are
///   kept, since that is the copy as written; only the title typo is fixed.
class EnableNotificationsScreen extends StatelessWidget {
  const EnableNotificationsScreen({
    super.key,
    required this.onEnable,
    required this.onRemindLater,
    this.onBack,
  });

  /// The primary button. The caller asks the system for permission; this
  /// screen only reports the choice.
  final VoidCallback onEnable;

  /// "Remind me Later" — moves on without asking.
  final VoidCallback onRemindLater;

  /// The nav bar's back arrow. Defaults to popping the route.
  final VoidCallback? onBack;

  /// The illustration is 250 square in the frame.
  static const double _illustrationSize = 250;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral100,
      appBar: AppBar(
        backgroundColor: AppColors.neutral100,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        title: Text('Enable notifications', style: AppTypography.headlineLarge),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stay up to date',
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.neutral1100,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Get notified about Offers , new articles , your favorite '
                'stores',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutral500,
                ),
              ),
              const Expanded(
                child: Center(
                  child: EnableNotificationsIllustration(
                    size: _illustrationSize,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Enable notifications',
                  onPressed: onEnable,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: GestureDetector(
                  onTap: onRemindLater,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Remind me Later',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}
