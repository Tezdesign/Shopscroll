import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/store_report.dart';
import '../../data/providers/store_activity_providers.dart';
import '../activity/list_states.dart';
import '../store/seller_gate.dart';
import 'report_widgets.dart';

/// The seller's report details at `/store/activity/reports/:id` (spec 0018,
/// AC-10, AC-11). Only a seller stays ([SellerGate]). The seller can only
/// resolve the report, nothing else (AC-17).
///
/// Figma node 3001:11979. Deviations: the status bar and the bottom tab bar
/// belong to the seller shell, which has no spec yet; the round customer
/// picture is left out (the order has no photo of the customer); the "+" button
/// of the frame is not drawn here; "Mark as resolved" stays pinned at the
/// bottom instead of following the last block; the frame's "Attachement" is
/// spelled "Attachment". The product pictures overlap like the frame and come
/// from the order lines.
class StoreReportDetailScreen extends ConsumerWidget {
  const StoreReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(storeReportDetailProvider(reportId));

    return SellerGate(
      // Dark clock and icons on this light page. The Activity screen under it
      // asks for light ones, so this page has to say otherwise.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.white100,
          body: SafeArea(
            child: Column(
              children: [
                const _Header(),
                Expanded(
                  child: detail.when(
                    loading: () => const ListLoading(),
                    error: (error, stackTrace) => ListMessage(
                      "Couldn't load this report.",
                      buttonLabel: 'Try again',
                      onPressed: () =>
                          ref.invalidate(storeReportDetailProvider(reportId)),
                    ),
                    data: (report) => report == null
                        ? const ListMessage('Report not found')
                        : _Body(report: report),
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Back',
              onTap: () => context.pop(),
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => context.pop(),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: AppIcon(
                      AppIconGlyph.back,
                      color: AppColors.neutral1100,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Text(
            'Report details',
            style: TextStyle(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontSize: AppTypography.sizeLg,
              height: AppTypography.lineHeightLg,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral1100,
            ),
          ),
        ],
      ),
    );
  }
}

const _heading = TextStyle(
  fontFamily: AppTypography.fontFamilyDisplay,
  fontSize: AppTypography.sizeLg,
  height: AppTypography.lineHeightLg,
  fontWeight: FontWeight.w600,
  color: AppColors.neutral1100,
);

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.report});

  final StoreReportDetail report;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  static const _small = TextStyle(
    fontFamily: AppTypography.fontFamilyBody,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    color: AppColors.neutral700,
  );

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final unsolved = report.status == StoreReportStatus.unsolved;
    final email = report.customerEmail;
    final phone = report.customerPhone;
    final order = 'Order #${report.orderNumber.toString().padLeft(6, '0')}';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.base),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.md,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          reportNumberLabel(report.reportNumber),
                          style: _small.copyWith(
                            fontSize: AppTypography.sizeBase,
                            height: AppTypography.lineHeightBase,
                          ),
                        ),
                        Text(
                          reportDateLabel(report.createdAt),
                          style: _small.copyWith(color: AppColors.neutral500),
                        ),
                      ],
                    ),
                  ),
                  ReportStatusBadge(status: report.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
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
              const SizedBox(height: AppSpacing.xl),
              const Text('Customer Information', style: _heading),
              const SizedBox(height: AppSpacing.base),
              Text(
                report.customerName ?? 'Customer',
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamilyBody,
                  fontSize: AppTypography.sizeBase,
                  height: AppTypography.lineHeightBase,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral1100,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (email != null || phone != null)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (email != null)
                      _ContactButton(
                        glyph: AppIconGlyph.email,
                        label: 'Email customer',
                        onTap: () => launchUrl(Uri.parse('mailto:$email')),
                      ),
                    if (phone != null)
                      _ContactButton(
                        glyph: AppIconGlyph.phone,
                        label: 'Call customer',
                        onTap: () => launchUrl(Uri.parse('tel:$phone')),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.xl),
              const Text('Products information', style: _heading),
              const SizedBox(height: AppSpacing.base),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (report.items.isNotEmpty) ...[
                    _StackedPictures(items: report.items),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.items.map((item) => item.title).join(', '),
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamilyBody,
                            fontSize: AppTypography.sizeLg,
                            height: AppTypography.lineHeightLg,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutral1100,
                          ),
                        ),
                        Text(order, style: _small),
                        Text(
                          'Purchase date : ${reportDateLabel(report.purchasedAt)}',
                          style: _small,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('Problem details', style: _heading),
              const SizedBox(height: AppSpacing.base),
              Text(
                report.description,
                style: _small.copyWith(
                  fontSize: AppTypography.sizeLg,
                  height: AppTypography.lineHeightLg,
                ),
              ),
              if (report.attachmentPaths.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _Attachments(report: report),
              ],
              if (unsolved) ...[
                const SizedBox(height: AppSpacing.xl),
                const Text('Resolution note', style: _heading),
                const SizedBox(height: AppSpacing.base),
                TextField(
                  controller: _noteController,
                  maxLines: 4,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Describe how the issue was resolved (optional)',
                    hintStyle: const TextStyle(color: AppColors.neutral500),
                    contentPadding: const EdgeInsets.all(AppSpacing.base),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.neutral300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.neutral300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.primary400),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (unsolved)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: SizedBox(
              width: double.infinity,
              child: ReportButton(
                label: 'Mark as resolved',
                glyph: AppIconGlyph.check,
                filled: true,
                radius: AppRadius.md,
                onPressed: () => confirmAndResolveReport(
                  context,
                  ref,
                  report.id,
                  note: _noteController.text,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// An outlined action button that launches a `mailto:` or `tel:` URL.
/// Shows the icon and label without exposing the raw address or number.
class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final AppIconGlyph glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.neutral300),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          onTap: onTap,
          // 44 high (spec 0018, AC-16); the row is centered in it.
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(glyph, color: AppColors.neutral700, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamilyBody,
                      fontSize: AppTypography.sizeSm,
                      height: AppTypography.lineHeightSm,
                      color: AppColors.neutral700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to three product pictures laid over each other (Figma node
/// 3001:12029, 40 wide circles overlapping by 24).
class _StackedPictures extends StatelessWidget {
  const _StackedPictures({required this.items});

  final List<StoreReportItem> items;

  static const double _size = 40;
  static const double _step = 16;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(3).toList();
    return Semantics(
      label: 'Product pictures',
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        key: const ValueKey('report-pictures'),
        width: _size + _step * (shown.length - 1),
        height: _size,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: _step * i,
                // One 40 by 40 circle. The photo fills all of it and the white
                // ring is drawn over it (a border on the decoration would
                // shrink the photo to 38 and cut its corners off).
                child: Container(
                  width: _size,
                  height: _size,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  foregroundDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.neutral100),
                  ),
                  child: _Picture(url: shown[i].imageUrl),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const empty = ColoredBox(color: AppColors.blackAlpha10);
    if (url == null) return empty;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => empty,
    );
  }
}

/// "Attachment (N)" and one 60 by 60 thumbnail per file, loaded through signed
/// links that are valid for one hour (spec 0018, AC-10). While the links load
/// the thumbnails are grey squares. A file that cannot be shown stays out.
class _Attachments extends ConsumerWidget {
  const _Attachments({required this.report});

  final StoreReportDetail report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = report.attachmentPaths.length;
    final urls = ref.watch(storeReportAttachmentsProvider(report.id));
    final shown = urls.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachment ($count)',
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeLg,
            height: AppTypography.lineHeightLg,
            color: AppColors.neutral700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            if (urls.hasError)
              const SizedBox.shrink()
            else
              for (var i = 0; i < (shown?.length ?? count); i++)
                Semantics(
                  label: 'Attachment ${i + 1}',
                  image: true,
                  excludeSemantics: true,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: _Picture(url: shown?[i]),
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}
