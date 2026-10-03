import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The phone and bell illustration on [EnableNotificationsScreen] (Figma node
/// 5288:9844, "enable_notifications 2", drawn at 250 in the frame).
///
/// This replaces an earlier stand-in drawn from a written brief, back when no
/// Figma node existed: that one took [AppColors] for its fills and had to
/// substitute CSS custom properties before parsing. The real artwork carries
/// its own greyscale palette and no variables, so it is rendered straight
/// from the asset and takes no colors.
class EnableNotificationsIllustration extends StatelessWidget {
  const EnableNotificationsIllustration({super.key, this.size = 250});

  final double size;

  static const _assetPath = 'assets/illustrations/enable_notifications.svg';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _assetPath,
      package: 'shopscroll_shared',
      width: size,
      height: size,
    );
  }
}
