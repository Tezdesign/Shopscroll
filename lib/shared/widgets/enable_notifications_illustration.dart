import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_theme.dart';

/// Hero illustration for the "Enable Notifications" onboarding screen: a
/// claymorphic phone + glossy bell group, per the design brief in
/// docs/specs. Not sourced from Figma — no matching node exists yet.
///
/// The source SVG (assets/illustrations/enable_notifications.svg) exposes
/// its colors as `var(--illustration-primary/-accent/-highlight)` so it
/// stays themeable outside Flutter (e.g. opened directly in a browser);
/// since flutter_svg doesn't resolve CSS custom properties, this widget
/// substitutes them with real hex values before parsing.
class EnableNotificationsIllustration extends StatelessWidget {
  const EnableNotificationsIllustration({
    super.key,
    this.size = 280,
    this.primaryColor = AppColors.primary400,
    this.accentColor = AppColors.secondary400,
    this.highlightColor = AppColors.white100,
  });

  final double size;
  final Color primaryColor;
  final Color accentColor;
  final Color highlightColor;

  static const _assetPath = 'assets/illustrations/enable_notifications.svg';

  String _hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2)}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: DefaultAssetBundle.of(context).loadString(_assetPath),
      builder: (context, snapshot) {
        final raw = snapshot.data;
        if (raw == null) {
          return SizedBox(width: size, height: size);
        }
        final svg = raw
            .replaceAll('var(--illustration-primary)', _hex(primaryColor))
            .replaceAll('var(--illustration-accent)', _hex(accentColor))
            .replaceAll('var(--illustration-highlight)', _hex(highlightColor));
        return SvgPicture.string(svg, width: size, height: size);
      },
    );
  }
}
