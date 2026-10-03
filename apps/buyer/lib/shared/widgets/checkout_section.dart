import 'package:flutter/material.dart';

import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';

/// Reproduces one block of the Figma Checkout page (node 3001:9830): a white
/// panel with 16 of padding, a title in Plus Jakarta Sans 18 semibold, and a
/// hairline [AppColors.neutral200] border under it (Order Summary and Payment
/// method carry it on top instead, set with [topBorder]).
class CheckoutSection extends StatelessWidget {
  const CheckoutSection({
    super.key,
    required this.title,
    required this.child,
    this.topBorder = false,
  });

  final String title;
  final Widget child;
  final bool topBorder;

  static const TextStyle titleStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeLg,
    height: AppTypography.lineHeightLg,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1000,
  );

  @override
  Widget build(BuildContext context) {
    const line = BorderSide(color: AppColors.neutral200);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        border: Border(
          top: topBorder ? line : BorderSide.none,
          bottom: topBorder ? BorderSide.none : line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Semantics(header: true, child: Text(title, style: titleStyle)),
          child,
        ],
      ),
    );
  }
}

/// The blue "+ Add your contact info" link of an empty section (Figma node
/// 3001:9836): a plus and a label in Inter 14 semibold, [AppColors.primary400].
/// Figma draws it 24 high, the tap area here is 44 (spec 0009, AC-23).
class AddInfoRow extends StatelessWidget {
  const AddInfoRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const TextStyle _style = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w600,
    color: AppColors.primary400,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.sm,
            children: [
              const AppIcon(AppIconGlyph.add, color: AppColors.primary400),
              Text(label, style: _style),
            ],
          ),
        ),
      ),
    );
  }
}

/// A filled section (Figma node 3001:9956): a bold first line, grey lines
/// under it, and a pencil on the right that reopens the editor. The design
/// gives the phone line a heavier weight than the email, here every grey line
/// has the same one.
class InfoSummaryRow extends StatelessWidget {
  const InfoSummaryRow({
    super.key,
    required this.title,
    required this.lines,
    required this.editLabel,
    required this.onEdit,
  });

  final String title;
  final List<String> lines;

  /// What a screen reader says for the pencil, like "Edit contact information".
  final String editLabel;
  final VoidCallback onEdit;

  static const TextStyle _titleStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeBase,
    height: AppTypography.lineHeightBase,
    fontWeight: FontWeight.w600,
    color: AppColors.neutral1000,
  );

  static const TextStyle _lineStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w500,
    color: AppColors.neutral600,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xs,
            children: [
              Text(title, style: _titleStyle),
              for (final line in lines) Text(line, style: _lineStyle),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: editLabel,
          onTap: onEdit,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: AppIcon(AppIconGlyph.edit, color: AppColors.neutral1100),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
