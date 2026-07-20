import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reproduces the Figma "add to cart" component set (node 504:1419): a
/// plain icon(+label) toggle used standalone on Product details next to the
/// quantity stepper — distinct from [ProductCard]'s pill-shaped "Add to
/// cart" button, which has its own background/border styling.
///
/// Figma's "icon ony"/"icon only" variants (a duplicated typo'd pair) both
/// just hide the label, so that's exposed here as [AddToCartDisplay].
enum AddToCartDisplay { iconAndLabel, iconOnly }

class AddToCartToggle extends StatelessWidget {
  const AddToCartToggle({
    super.key,
    required this.added,
    this.display = AddToCartDisplay.iconAndLabel,
    this.onTap,
  });

  final bool added;
  final AddToCartDisplay display;
  final VoidCallback? onTap;

  static const double _iconSize = 24;
  // Figma tracks this label at -0.43 letterspacing, same value already
  // seen on InfoRow's Product-details text — kept local, same reasoning.
  static const double _letterSpacing = -0.43;

  @override
  Widget build(BuildContext context) {
    final color = added ? AppColors.success400 : AppColors.neutral1000;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_shopping_cart, size: _iconSize, color: color),
          if (display == AddToCartDisplay.iconAndLabel) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              added ? 'Added to cart' : 'Add to cart',
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeSm,
                height: AppTypography.lineHeightBase,
                fontWeight: FontWeight.w500,
                letterSpacing: _letterSpacing,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
