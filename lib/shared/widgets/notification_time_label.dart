import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reproduces the Figma "Notification time" component set (node 732:3721):
/// a small timestamp label (e.g. "Now", "2h") shown on the Notifications
/// screen, in one of two states — [checked] mirrors Figma's own
/// "checked"/"not checked" property name.
class NotificationTimeLabel extends StatelessWidget {
  const NotificationTimeLabel({
    super.key,
    required this.text,
    this.checked = false,
  });

  final String text;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTypography.fontFamilyBody,
        fontSize: AppTypography.sizeSm,
        height: AppTypography.lineHeightSm,
        fontWeight: FontWeight.w600,
        color: checked ? AppColors.neutral1000 : AppColors.neutral500,
      ),
    );
  }
}
