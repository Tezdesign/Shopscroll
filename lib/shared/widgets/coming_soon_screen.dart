import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A lightweight stand in for a bottom nav tab that has no real screen yet
/// (Reels, Activity, Profile as of spec 0001). Keeps the nav shell's branch
/// list complete without designing those features ahead of time; replace
/// with the real screen when each one gets its own spec.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.neutral400),
            const SizedBox(height: AppSpacing.base),
            Text(
              '$label coming soon',
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyDisplay,
                fontSize: AppTypography.sizeLg,
                height: AppTypography.lineHeightSm,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
