import 'package:flutter/material.dart';

import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_radio.dart';

/// Reproduces the Figma "Delivery type" tile (Checkout, component 497:1228):
/// a 52 high bordered box, radius 8, with a small ring, the method text in
/// Inter 14 semibold, and its price in Inter 16 medium on the right.
///
/// Figma draws only the unselected look. Selected is this app's own: the
/// border turns [AppColors.primary400] and the ring fills (see [AppRadio]).
/// The title wraps to two lines instead of the fixed 262 wide box, so it fits
/// narrow phones.
class DeliveryMethodTile extends StatelessWidget {
  const DeliveryMethodTile({
    super.key,
    required this.title,
    required this.priceLabel,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String priceLabel;
  final bool selected;
  final VoidCallback onTap;

  static const TextStyle _titleStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1100,
  );

  static const TextStyle _priceStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral1100,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$title, $priceLabel',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.primary400 : AppColors.neutral400,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            spacing: AppSpacing.sm,
            children: [
              AppRadio(
                selected: selected,
                size: 14,
                outlineColor: AppColors.neutral1100,
              ),
              Expanded(child: Text(title, style: _titleStyle)),
              Text(priceLabel, style: _priceStyle),
            ],
          ),
        ),
      ),
    );
  }
}
