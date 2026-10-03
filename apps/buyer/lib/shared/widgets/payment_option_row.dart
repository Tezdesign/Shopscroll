import 'package:flutter/material.dart';

import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_radio.dart';

/// Reproduces one row of the Figma "Payment method" list (Checkout, node
/// 3001:9876): a radio, the label in Inter 16 semibold, an optional small
/// icon after it (the lock on the card row), and an optional [footer] under
/// the label (the card logos). The whole row is one tap target, at least 44
/// high (spec 0009, AC-23).
///
/// Figma spaces the rows 20 apart with a 24 high header, here the header is 44
/// high to make the tap area, and the rows sit together. Label colour
/// `#191D23` has no token, [AppColors.neutral1000] is used.
class PaymentOptionRow extends StatelessWidget {
  const PaymentOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.footer,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? footer;

  static const TextStyle _labelStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1000,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  AppRadio(selected: selected),
                  Text(label, style: _labelStyle),
                  if (icon != null)
                    Icon(icon, size: 16, color: AppColors.neutral1000),
                ],
              ),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}
