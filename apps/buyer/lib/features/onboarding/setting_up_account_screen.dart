import 'package:flutter/material.dart';

import 'package:shopscroll_shared/theme/app_theme.dart';

/// Reproduces the Figma "Setting up your account" screen (node 5284:8251):
/// a spinning ring over a single line of text, shown once the sign up steps
/// are done and before the app opens — see
/// `lib/features/onboarding/AGENTS.md`.
///
/// The screen waits [duration] and then calls [onDone]. It awaits nothing
/// real yet: the work this stands for (merging the anonymous cart, writing
/// the buyer profile) is already running in `AuthSessionController`, which
/// exposes no progress to wait on. Give this a future to await once it does,
/// rather than leaving the wait purely cosmetic.
///
/// Deviations from the source frame:
/// - The frame has no nav bar, no back arrow and no way out, which is right
///   for a step that finishes on its own. That is kept, so there is nothing
///   to tap here.
/// - The ring is the frame's own exported artwork rather than a
///   [CircularProgressIndicator], which would not match its gradient. The
///   frame is a still image, so the rotation and its speed are this app's.
class SettingUpAccountScreen extends StatefulWidget {
  const SettingUpAccountScreen({
    super.key,
    required this.onDone,
    this.duration = const Duration(seconds: 2),
  });

  /// Called once [duration] has passed and the screen is done.
  final VoidCallback onDone;

  /// How long the screen stays up.
  final Duration duration;

  /// One turn of the ring.
  static const Duration rotationPeriod = Duration(milliseconds: 1200);

  @override
  State<SettingUpAccountScreen> createState() => _SettingUpAccountScreenState();
}

class _SettingUpAccountScreenState extends State<SettingUpAccountScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: SettingUpAccountScreen.rotationPeriod,
  )..repeat();

  /// The ring is 177 square in the frame, and the text sits 24 below it.
  static const double _ringSize = 177;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.duration, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _rotation,
                child: Image.asset(
                  'assets/illustrations/account_loader.png',
                  width: _ringSize,
                  height: _ringSize,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Setting up your account',
                textAlign: TextAlign.center,
                style: AppTypography.displaySmall.copyWith(
                  color: AppColors.neutral1100,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
