import 'package:flutter/material.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';

/// The two halves of the "Who are you" toggle (Figma component 620:3086):
/// what a person chose on the Log in screen, and which area a seller is in
/// (spec 0014).
enum AccountType { buyer, storeOwner }

/// The "Who are you" pill (Figma 620:3086): two equal halves, the selected
/// one filled [AppColors.primary100] with [AppColors.primary500] label and
/// icon, the other [AppColors.neutral200] with [AppColors.neutral400].
class AccountTypeToggle extends StatelessWidget {
  const AccountTypeToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// The frame's height. Not a spacing token, the same way [AppButton]
  /// carries its own 44.
  static const double _height = 40;

  final AccountType selected;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Row(
        children: [
          Expanded(child: _half(AccountType.buyer, AppIconGlyph.user, 'Buyer')),
          Expanded(
            child: _half(
              AccountType.storeOwner,
              AppIconGlyph.store,
              'Store owner',
            ),
          ),
        ],
      ),
    );
  }

  Widget _half(AccountType type, AppIconGlyph glyph, String label) {
    final active = type == selected;
    final foreground = active ? AppColors.primary500 : AppColors.neutral400;
    return GestureDetector(
      onTap: () => onChanged(type),
      child: Container(
        height: _height,
        alignment: Alignment.center,
        color: active ? AppColors.primary100 : AppColors.neutral200,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(glyph, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
