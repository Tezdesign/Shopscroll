import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';

import '../../data/models/store_report.dart';
import '../../data/providers/store_activity_providers.dart';

/// The pill beside a report number (Figma "Order-satus" instance in the report
/// card, node 849:5352): Unsolved on the warning tokens, Resolved on the
/// success tokens (the frame draws only Unsolved). Deviation: the text uses the
/// darker `warning600` and `success600` where the card draws `warning400`,
/// because the lighter yellow on the pale yellow does not read (the details
/// frame, node 3001:12006, already uses `warning600`).
class ReportStatusBadge extends StatelessWidget {
  const ReportStatusBadge({super.key, required this.status});

  final StoreReportStatus status;

  @override
  Widget build(BuildContext context) {
    final resolved = status == StoreReportStatus.resolved;
    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: resolved ? AppColors.successAlpha10 : AppColors.warning100,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        resolved ? 'Resolved' : 'Unsolved',
        textAlign: TextAlign.center,
        maxLines: 1,
        style: TextStyle(
          fontFamily: AppTypography.fontFamilyBody,
          fontSize: AppTypography.sizeSm,
          height: AppTypography.lineHeightSm,
          fontWeight: FontWeight.w600,
          color: resolved ? AppColors.success600 : AppColors.warning600,
        ),
      ),
    );
  }
}

/// A report button (Figma "Button" instances in the report card, nodes
/// 849:5368 and 849:5369, and "Mark as resolved", node 3001:12040): an icon and
/// a label, outlined or filled. [AppButton] hugs its content and is about 42
/// high, below the 44 touch size (spec 0018, AC-16), and takes a Material icon
/// instead of an [AppIconGlyph], so this draws the same look at 44.
class ReportButton extends StatelessWidget {
  const ReportButton({
    super.key,
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.filled = false,
    this.radius = AppRadius.sm,
  });

  final String label;
  final AppIconGlyph glyph;
  final VoidCallback onPressed;
  final bool filled;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = filled ? AppColors.white100 : AppColors.primary400;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: filled ? AppColors.primary400 : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: filled
              ? BorderSide.none
              : const BorderSide(color: AppColors.primary400),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(glyph, color: color),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamilyDisplay,
                      fontSize: AppTypography.sizeSm,
                      height: AppTypography.lineHeightSm,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `May 15, 2025`, the date on a report (Figma node 849:5351).
String reportDateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = date.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

/// The Figma alert "Are you sure you want to mark this report as resolved?"
/// (node 860:5916) and what follows (spec 0018, AC-11). Confirming marks the
/// report resolved at once, and a failure puts it back and says so in a snack
/// bar. Cancelling changes nothing. The alert is the platform's own
/// ([AlertDialog.adaptive]), which is the iOS alert the frame draws on iPhone.
///
/// Deviation: the frame's text reads "mark this reportas resolved ?", a typo,
/// so the question is written out cleanly.
Future<void> confirmAndResolveReport(
  BuildContext context,
  WidgetRef ref,
  String reportId, {
  String? note,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final resolve = ref.read(resolveStoreReportProvider);
  final confirmed = await showAdaptiveDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog.adaptive(
      title: const Text('Confirm resolution'),
      content: const Text(
        'Are you sure you want to mark this report as resolved?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  if (!await resolve(
    reportId,
    note: note?.trim().isEmpty == true ? null : note?.trim(),
  )) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Couldn't resolve this report. Try again.")),
    );
  }
}
