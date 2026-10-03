import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reproduces the Figma "Radio button" (Checkout, node 3001:9879): a white
/// circle with a 2 wide [AppColors.primary100] outline, 16 across. The
/// delivery tiles draw a smaller, darker ring (Figma 497:1237), set with
/// [size] and [outlineColor].
///
/// Figma only draws the unselected state. Selected is this app's own: the
/// outline turns [AppColors.primary400] and an inner dot fills half the size.
///
/// A picture, not a control: the row or tile around it owns the tap and the
/// spoken label.
class AppRadio extends StatelessWidget {
  const AppRadio({
    super.key,
    required this.selected,
    this.size = 16,
    this.outlineColor = AppColors.primary100,
  });

  final bool selected;
  final double size;
  final Color outlineColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary400 : outlineColor,
          width: 2,
        ),
      ),
      child: selected
          ? Container(
              width: size / 2,
              height: size / 2,
              decoration: const BoxDecoration(
                color: AppColors.primary400,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
