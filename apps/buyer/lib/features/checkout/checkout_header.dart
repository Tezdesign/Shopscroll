import 'package:flutter/material.dart';

import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';

/// The title bar of the Checkout and Order confirmation pages (Figma nodes
/// 3001:9945 and 3001:10498): an X on the left and a centred title. Figma
/// draws the title in Inter 17 semibold, which has no token, so it is 16 here.
/// The X is 24 across in the design, its tap area is 56 (spec 0009, AC-23).
/// The device status bar is not built, the phone draws its own.
class CheckoutHeader extends StatelessWidget {
  const CheckoutHeader({super.key, required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Close',
              onTap: onClose,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: AppIcon(
                      AppIconGlyph.close,
                      color: AppColors.neutral1100,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeBase,
                height: AppTypography.lineHeightBase,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral1100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
