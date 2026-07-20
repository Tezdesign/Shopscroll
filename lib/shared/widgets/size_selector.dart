import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reproduces the Figma "Sizes available" chip row (Product details, node
/// 187:2966): a wrapped row of pill-shaped size chips — the selected size is
/// filled dark with white text, the rest are outlined in black.
class SizeSelector extends StatelessWidget {
  const SizeSelector({
    super.key,
    required this.sizes,
    required this.selected,
    required this.onChanged,
  });

  final List<String> sizes;
  final String? selected;
  final ValueChanged<String> onChanged;

  // Figma's chip padding (10/5) doesn't land on a shared spacing token, so
  // it's kept local like other components' intrinsic one-off values.
  static const double _horizontalPadding = 10;
  static const double _verticalPadding = 5;

  static const TextStyle _labelStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w400,
  );

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.base,
      runSpacing: AppSpacing.base,
      children: [
        for (final size in sizes)
          _SizeChip(
            label: size,
            active: size == selected,
            onTap: () => onChanged(size),
          ),
      ],
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SizeSelector._horizontalPadding,
          vertical: SizeSelector._verticalPadding,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.neutral1000 : null,
          border: active ? null : Border.all(color: AppColors.neutral1100),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: SizeSelector._labelStyle.copyWith(
            color: active ? AppColors.white100 : AppColors.neutral1100,
          ),
        ),
      ),
    );
  }
}
