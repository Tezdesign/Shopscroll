import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reproduces one line of the Figma Order Summary (Checkout node 3001:9861,
/// confirmation node 3001:10454): a label on the left and its value on the
/// right, both in Inter 16. The default line is semibold and
/// [AppColors.neutral500]. [emphasized] (Price to pay, Total price) is bold
/// and [AppColors.neutral1000].
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppTypography.fontFamilyBody,
      fontSize: AppTypography.sizeBase,
      height: AppTypography.lineHeightBase,
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
      color: emphasized ? AppColors.neutral1000 : AppColors.neutral500,
    );
    return MergeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
