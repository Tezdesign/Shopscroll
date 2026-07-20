import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Reproduces the Figma "Table" component (Product details, node 205:2381):
/// a bordered two-column key/value table built from repeating `.Row` >
/// `Cell` > `Content` nodes (e.g. Material/Fit type/Size on the Product
/// details screen).
class SpecTable extends StatelessWidget {
  const SpecTable({super.key, required this.rows});

  /// Each entry is a (label, value) pair rendered as one table row.
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral200),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _SpecTableRow(
              label: rows[i].$1,
              value: rows[i].$2,
              topBorder: i > 0,
            ),
        ],
      ),
    );
  }
}

/// Reproduces one Figma `.Row` (node 205:2382 etc): two [_Cell]s side by side.
class _SpecTableRow extends StatelessWidget {
  const _SpecTableRow({
    required this.label,
    required this.value,
    required this.topBorder,
  });

  final String label;
  final String value;
  final bool topBorder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: topBorder
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.neutral200)),
            )
          : const BoxDecoration(),
      child: Row(
        children: [
          Expanded(child: _Cell(text: label, borderLeft: false)),
          Expanded(child: _Cell(text: value, borderLeft: true)),
        ],
      ),
    );
  }
}

/// Reproduces the Figma "Cell" component (node `205:735`/`205:738`): a
/// bordered content box holding a single line of text.
class _Cell extends StatelessWidget {
  const _Cell({required this.text, required this.borderLeft});

  final String text;
  final bool borderLeft;

  // Figma's cell padding (12/10) — 10 isn't on the shared spacing scale
  // (closest neighbors are sm=8 and md=12), so it's kept local like other
  // components' intrinsic one-off values.
  static const double _verticalPadding = 10;

  static const TextStyle _textStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeXs,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral1100,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: borderLeft
          ? const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.neutral200)),
            )
          : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: _verticalPadding,
      ),
      child: Text(text, style: _textStyle),
    );
  }
}
