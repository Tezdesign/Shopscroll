import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_icon.dart';

/// Opens a bottom sheet with a [SheetHeader] on top of [child], for the
/// Contact information and Shipping address sheets (Figma 3001:10570 and
/// 3001:10551). The sheet is a plain white surface with rounded top corners,
/// not Figma's translucent blur material. It scrolls, and lifts above the
/// keyboard. Resolves to what the child pops with, or null when it is closed.
Future<T?> showCheckoutSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white100,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.sm,
            AppSpacing.base,
            AppSpacing.base,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.base,
            children: [
              SheetHeader(
                title: title,
                onClose: () => Navigator.of(context).pop(),
              ),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

/// The title row of a checkout sheet (Figma node 3001:10572): the title in
/// Inter 20 semibold and a round close button on the right. Figma draws the
/// button 30 across, the tap area is 44 (spec 0009, AC-23).
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  static const TextStyle _titleStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXl,
    height: AppTypography.lineHeightXl,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1100,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: _titleStyle),
          ),
        ),
        Semantics(
          button: true,
          label: 'Close',
          onTap: onClose,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: AppColors.neutral200,
                    shape: BoxShape.circle,
                  ),
                  child: const AppIcon(
                    AppIconGlyph.close,
                    size: 16,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
