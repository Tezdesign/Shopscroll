import 'package:flutter/material.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

/// The Buyer | Seller switch of the seller Profile (Figma node 3001:9360,
/// frame "Who are you" in "The design - seller"): a compact pill on
/// [AppColors.primary50] with 2 px of padding, two halves that hug their label,
/// and the selected half filled white. Labels are Inter bold 14 in
/// [AppColors.primary400] in both states, as drawn.
///
/// Not the Log in screen's full width "Who are you" pill (Figma 620:3086,
/// `AccountTypeToggle`): that one is a different component. Deviation from the
/// source design: the settings gear drawn next to the pill is not built here,
/// Settings stays a row list on the Profile tab.
class AreaSwitch extends StatelessWidget {
  const AreaSwitch({
    super.key,
    required this.sellerSelected,
    required this.onChanged,
  });

  /// True when the Seller half is selected (the store area), false for Buyer.
  final bool sellerSelected;

  /// Called with true when Seller is tapped, false when Buyer is tapped.
  final ValueChanged<bool> onChanged;

  /// The pill's inner padding, a Figma value that is not a spacing token.
  static const double _trackPadding = 2;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_trackPadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _half('Buyer', selected: !sellerSelected, seller: false),
            _half('Seller', selected: sellerSelected, seller: true),
          ],
        ),
      ),
    );
  }

  Widget _half(String label, {required bool selected, required bool seller}) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(seller),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? AppColors.neutral100 : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              label,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
