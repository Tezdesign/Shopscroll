import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';

import '../../data/models/store_report.dart';
import '../../data/providers/store_activity_providers.dart';
import 'activity_message.dart';
import 'report_widgets.dart';

/// The Reports tab of the seller's Activity area (spec 0018, AC-8, AC-9,
/// AC-11, AC-14): three number cards, then one card per report, newest first,
/// loading 20 at a time, with pull to refresh. The search field above applies
/// to the list, not to the cards.
///
/// Figma node 3001:11908. Deviations: the two round pictures on a card
/// (customer and product) are left out, `store_reports_list` returns no photos;
/// the first product shows with "and N more" when the report holds several; the
/// card shadow is left out (no shadow token); the date is [AppColors.neutral500]
/// where the frame uses `#9ea1ac` (no token); the button the frame spells
/// "Ressolve" is spelled "Resolve"; a card is [AppRadius.md] where the frame
/// uses 10 on the number cards.
class ReportsTab extends ConsumerWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(storeActivitySearchProvider);
    final reports = ref.watch(storeReportsProvider);

    Future<void> refresh() {
      ref.invalidate(storeReportsSummaryProvider);
      return ref.refresh(storeReportsProvider.future);
    }

    // A new search shows the spinner, not the old rows (like `when` does for
    // the Orders tab), while a pull to refresh keeps the rows on screen.
    final state = reports.isLoading && !reports.isRefreshing
        ? null
        : reports.value;
    final rows = state?.reports ?? const <StoreReport>[];
    final hasMore = state?.hasMore ?? false;
    // 1 for the number cards, then the rows (or one message), then the footer.
    final body = rows.isEmpty ? 1 : rows.length + (hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.base,
          AppSpacing.base,
          // Clears the "+" button.
          96,
        ),
        itemCount: 1 + body,
        itemBuilder: (context, index) {
          if (index == 0) return const _Summary();
          final at = index - 1;
          if (rows.isEmpty) {
            return SizedBox(
              height: 240,
              child: reports.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => ActivityMessage(
                  text: "Couldn't load your reports.",
                  onRetry: () => ref.invalidate(storeReportsProvider),
                ),
                data: (_) => search.isEmpty
                    ? const _EmptyReports()
                    : ActivityMessage(text: 'No results found for “$search”'),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.base),
            child: at < rows.length
                ? _ReportCard(report: rows[at])
                : _ListFooter(state: state!),
          );
        },
      ),
    );
  }
}

const _label = TextStyle(
  fontFamily: AppTypography.fontFamilyDisplay,
  fontSize: AppTypography.sizeBase,
  height: AppTypography.lineHeightBase,
  fontWeight: FontWeight.w600,
);
const _number = TextStyle(
  fontFamily: AppTypography.fontFamilyBody,
  fontSize: AppTypography.sizeXl,
  height: AppTypography.lineHeightXl,
  fontWeight: FontWeight.w700,
  color: AppColors.neutral1100,
);
const _note = TextStyle(
  fontFamily: AppTypography.fontFamilyBody,
  fontSize: AppTypography.sizeXs,
  height: AppTypography.lineHeightXs,
  fontWeight: FontWeight.w600,
  color: AppColors.error400,
);

/// Total Reports, Unresolved Reports (red) and Returned Orders (spec 0018,
/// AC-8).
class _Summary extends ConsumerWidget {
  const _Summary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(storeReportsSummaryProvider);
    return summary.when(
      loading: () => const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => SizedBox(
        height: 150,
        child: ActivityMessage(
          text: "Couldn't load your report numbers.",
          onRetry: () => ref.invalidate(storeReportsSummaryProvider),
        ),
      ),
      data: (data) {
        final open = data.unresolved > 0;
        return Column(
          children: [
            _SummaryCard(
              label: 'Unresolved Reports',
              value: '${data.unresolved}',
              note: open ? 'Needs your attention' : 'All caught up',
              noteColor: open ? AppColors.error400 : AppColors.success600,
              color: open ? AppColors.error400 : AppColors.success600,
              tint: open ? AppColors.errorAlpha10 : AppColors.successAlpha10,
              inline: true,
            ),
            const SizedBox(height: AppSpacing.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Total Reports',
                      value: '${data.total}',
                      note: '${data.newToday} new reports today',
                      noteColor: data.newToday > 0
                          ? AppColors.error400
                          : AppColors.neutral500,
                      color: AppColors.neutral700,
                      border: AppColors.neutral200,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Returned Orders',
                      value: '${data.returnedOrders}',
                      color: AppColors.neutral700,
                      border: AppColors.neutral200,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One number card: the label, the number and an optional note. An [inline]
/// card puts the label and the number side by side. [tint] fills the card,
/// [border] overrides the outline (default [color]).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    this.note,
    this.noteColor = AppColors.error400,
    this.inline = false,
    this.color = AppColors.primary400,
    this.border,
    this.tint,
  });

  final String label;
  final String value;
  final String? note;
  final Color noteColor;
  final bool inline;
  final Color color;
  final Color? border;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(label, style: _label.copyWith(color: color));
    final noteStyle = _note.copyWith(color: noteColor);
    final numbers = Column(
      crossAxisAlignment: inline
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: _number),
        if (note != null)
          Text(
            note!,
            textAlign: inline ? TextAlign.end : TextAlign.start,
            style: noteStyle,
          ),
      ],
    );

    return Semantics(
      container: true,
      label: '$label, $value${note == null ? '' : ', $note'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: tint ?? AppColors.neutral100,
          border: Border.all(color: border ?? color),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: inline
            ? Row(
                children: [
                  Expanded(child: labelText),
                  const SizedBox(width: AppSpacing.base),
                  numbers,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelText,
                  const SizedBox(height: AppSpacing.md),
                  numbers,
                ],
              ),
      ),
    );
  }
}

/// One report (Figma "Report card", node 3001:11975). The body opens the
/// details, like the frame's link, and the buttons do their own thing.
class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});

  final StoreReport report;

  static const _text = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeLg,
    height: AppTypography.lineHeightLg,
    color: AppColors.neutral1000,
  );
  static const _small = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
  );

  void _open(BuildContext context) =>
      context.push('/store/activity/reports/${report.id}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = reportNumberLabel(report.reportNumber);
    final name = report.customerName ?? 'Customer';
    final order = 'Order #${report.orderNumber.toString().padLeft(6, '0')}';
    final more = report.itemCount - 1;
    final first = report.firstItemTitle;
    final resolved = report.status == StoreReportStatus.resolved;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        border: Border.all(color: AppColors.neutral200),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label:
                '$number, ${resolved ? 'resolved' : 'unsolved'}, '
                '${report.title}, $name, $order. Opens the details',
            excludeSemantics: true,
            onTap: () => _open(context),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _open(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              number,
                              style: _text.copyWith(
                                fontSize: AppTypography.sizeBase,
                                color: AppColors.neutral700,
                              ),
                            ),
                            Text(
                              reportDateLabel(report.createdAt),
                              style: _small.copyWith(
                                color: AppColors.neutral500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ReportStatusBadge(status: report.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    report.title,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamilyDisplay,
                      fontSize: AppTypography.sizeXl,
                      height: AppTypography.lineHeightXl,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral1000,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(name, style: _text),
                  if (first != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      more > 0 ? '$first and $more more' : first,
                      style: _text,
                    ),
                    Text(
                      order,
                      style: _small.copyWith(color: AppColors.neutral600),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    report.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: _text.copyWith(color: AppColors.neutral700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                ReportButton(
                  label: 'View details',
                  glyph: AppIconGlyph.view,
                  onPressed: () => _open(context),
                ),
                if (!resolved)
                  ReportButton(
                    label: 'Resolve',
                    glyph: AppIconGlyph.check,
                    filled: true,
                    onPressed: () =>
                        confirmAndResolveReport(context, ref, report.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The end of the list: a spinner while the next page loads, or a retry when
/// that load failed.
class _ListFooter extends ConsumerWidget {
  const _ListFooter({required this.state});

  final StoreReportsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loadMoreFailed) {
      return Center(
        child: RetryButton(
          onPressed: () => ref.read(storeReportsProvider.notifier).loadMore(),
        ),
      );
    }
    // The next page starts as soon as this row is built (it is built only when
    // the list has scrolled near its end).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(storeReportsProvider.notifier).loadMore(),
    );
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.base),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// The list when the store has no reports at all.
class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIconGlyph.report, size: 32, color: AppColors.neutral400),
          SizedBox(height: AppSpacing.md),
          Text(
            'No reports yet',
            style: TextStyle(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontSize: AppTypography.sizeBase,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral1100,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'When a customer reports an order,\nit shows up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.sizeSm,
              height: AppTypography.lineHeightSm,
              color: AppColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }
}
