import 'package:flutter/material.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/models/product_draft.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_text_field.dart';
import 'package:shopscroll_shared/widgets/spec_table.dart';

import 'flow_widgets.dart';
import 'product_flow_controller.dart';
import 'product_messages.dart';
import 'variant_options.dart';

/// The details a clothing product asks for, with the key saved in the draft
/// (spec 0015, AC-3). Other categories use free key and value rows.
const _clothingDetails = <(String, String)>[
  ('material', 'Material'),
  ('fit', 'Fit'),
  ('sleeve_length', 'Sleeve length'),
  ('care', 'Care instructions'),
];

String _detailLabel(String key) {
  for (final (k, label) in _clothingDetails) {
    if (k == key) return label;
  }
  return key;
}

/// Step 3, "Review your product" (Figma nodes 5523:27981 ready and
/// 5523:28746 with an error). It shows what shoppers will see, the optional
/// "More details", and what blocks publishing.
///
/// Deviations from the frames (spec 0015): the Delivery, payment and returns
/// block and the "Authentic product" line are not shown, "Details" is an
/// optional section here instead of its own step, and a missing price can be
/// typed on this screen instead of going back to step 2.
class PreviewStep extends StatefulWidget {
  const PreviewStep({
    super.key,
    required this.controller,
    required this.currency,
    required this.storeName,
    required this.onGoToStep,
    this.extraIssues = const [],
  });

  final ProductFlowController controller;
  final String currency;
  final String storeName;
  final ValueChanged<int> onGoToStep;

  /// Reasons the last Publish was refused, shown with the ones found here.
  final List<DraftIssue> extraIssues;

  @override
  State<PreviewStep> createState() => _PreviewStepState();
}

class _PreviewStepState extends State<PreviewStep> {
  ProductFlowController get c => widget.controller;

  List<DraftIssue> get _issues {
    final out = [...c.data.issues()];
    for (final extra in widget.extraIssues) {
      if (!out.any((i) => i.code == extra.code && i.variantId == extra.variantId)) {
        out.add(extra);
      }
    }
    return out;
  }

  String _labelOf(String? variantId) {
    for (final v in c.variants) {
      if (v.id == variantId) return variantLabel(v);
    }
    return 'a variant';
  }

  @override
  Widget build(BuildContext context) {
    final data = c.data;
    final issues = _issues;
    final photos = c.photos.where((p) => p.status == PhotoStatus.done).toList();
    final lowest = data.lowestPrice;
    final inStock = data.totalStock > 0;
    final specs = <(String, String)>[
      if (data.category.isNotEmpty) ('Category', data.category),
      for (final e in data.attributes.entries) (_detailLabel(e.key), e.value),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (issues.isEmpty && !c.hasFailedPhoto)
          FlowNotice(
            title: 'All required information is complete',
            message:
                '${data.photos.length} ${data.photos.length == 1 ? 'photo' : 'photos'} · '
                '${data.variants.length} ${data.variants.length == 1 ? 'variant' : 'variants'} · '
                '${data.totalStock} units in stock',
          )
        else
          _IssueList(
            issues: issues,
            failedPhoto: c.hasFailedPhoto,
            labelOf: _labelOf,
            onGoToStep: widget.onGoToStep,
            onPrice: c.setVariantPrice,
            variants: c.variants,
            bulkRevision: c.bulkRevision,
          ),
        const SizedBox(height: AppSpacing.base),
        Row(
          children: [
            const Expanded(child: Text('Shopper preview', style: flowSectionStyle)),
            FlowLink('Edit basics', onTap: () => widget.onGoToStep(1)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                photos.isEmpty
                    ? const ColoredBox(color: AppColors.neutral200)
                    : PhotoImage(bytes: photos.first.bytes, path: photos.first.path),
                if (photos.length > 1)
                  Positioned(
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neutralAlpha50,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '1/${photos.length}',
                        style: flowHelperStyle.copyWith(color: AppColors.white100),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                lowest == null
                    ? 'Set a price'
                    : Money.format(lowest, widget.currency),
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamilyBody,
                  fontSize: AppTypography.size2xl,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral1000,
                ),
              ),
            ),
            Text(
              inStock ? 'In stock' : 'Out of stock',
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeSm,
                fontWeight: FontWeight.w600,
                color: inStock ? AppColors.success400 : AppColors.error400,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(widget.storeName, style: flowBodyStyle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          data.title.isEmpty ? 'Your product title' : data.title,
          style: flowSectionStyle.copyWith(color: AppColors.primary400),
        ),
        if (data.description.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(data.description.trim(), style: flowBodyStyle),
        ],
        if (c.colors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Colors', style: flowLabelStyle),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final color in c.colors)
                Semantics(
                  label: color.name,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(color.value),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.neutral300),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (c.sizes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Sizes available', style: flowLabelStyle),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final size in c.sizes)
                OptionChip(label: size, selected: false, onTap: () {}),
            ],
          ),
        ],
        if (specs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.base),
          const Text('Product details', style: flowSectionStyle),
          const SizedBox(height: AppSpacing.xs),
          SpecTable(rows: specs),
        ],
        const SizedBox(height: AppSpacing.base),
        _MoreDetails(controller: c),
        const SizedBox(height: AppSpacing.base),
        const Text('Ready to publish', style: flowSectionStyle),
        const SizedBox(height: AppSpacing.xs),
        _SummaryRow(
          title: 'Basics',
          detail:
              '${data.photos.length} ${data.photos.length == 1 ? 'photo' : 'photos'} · title & category',
          onEdit: () => widget.onGoToStep(1),
        ),
        _SummaryRow(
          title: 'Price & stock',
          detail:
              '${data.variants.length} ${data.variants.length == 1 ? 'variant' : 'variants'} · '
              '${data.totalStock} units${lowest == null ? '' : ' · from ${Money.format(lowest, widget.currency)}'}',
          onEdit: () => widget.onGoToStep(2),
        ),
        _SummaryRow(
          title: 'More details',
          detail: data.attributes.isEmpty
              ? 'None added'
              : '${data.attributes.length} added',
          onEdit: null,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Publishing makes this product visible in ${widget.storeName} and discoverable on Shopscroll.',
          style: flowHelperStyle,
        ),
      ],
    );
  }
}

/// The red box listing what blocks publishing, each with a Fix link. A
/// missing price can be typed right here.
class _IssueList extends StatelessWidget {
  const _IssueList({
    required this.issues,
    required this.failedPhoto,
    required this.labelOf,
    required this.onGoToStep,
    required this.onPrice,
    required this.variants,
    required this.bulkRevision,
  });

  final List<DraftIssue> issues;
  final bool failedPhoto;
  final String Function(String?) labelOf;
  final ValueChanged<int> onGoToStep;
  final void Function(String id, String price) onPrice;
  final List<DraftVariant> variants;
  final int bulkRevision;

  @override
  Widget build(BuildContext context) {
    final count = issues.length + (failedPhoto ? 1 : 0);
    return FlowNotice(
      error: true,
      title: count == 1 ? 'Fix one item to publish' : 'Fix $count items to publish',
      message: 'Your product information is kept.',
      children: [
      if (failedPhoto)
        _IssueRow(
          message: 'A photo did not upload. Retry it or remove it.',
          onFix: () => onGoToStep(1),
        ),
      for (final issue in issues)
        if (issue.code == 'missing_price' && issue.variantId != null)
          _PriceFix(
            key: ValueKey('fix-${issue.variantId}-$bulkRevision'),
            label: labelOf(issue.variantId),
            onChanged: (text) => onPrice(issue.variantId!, text),
          )
        else
          _IssueRow(
            message: issueMessage(issue, variantLabel: labelOf(issue.variantId)),
            onFix: () => onGoToStep(stepFor(issue)),
          ),
      ],
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.message, required this.onFix});

  final String message;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: flowErrorStyle.copyWith(fontSize: AppTypography.sizeSm)),
          ),
          FlowLink('Fix', onTap: onFix),
        ],
      ),
    );
  }
}

class _PriceFix extends StatefulWidget {
  const _PriceFix({super.key, required this.label, required this.onChanged});

  final String label;
  final ValueChanged<String> onChanged;

  @override
  State<_PriceFix> createState() => _PriceFixState();
}

class _PriceFixState extends State<_PriceFix> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Price for ${widget.label}',
              style: flowErrorStyle.copyWith(fontSize: AppTypography.sizeSm),
            ),
          ),
          CellField(
            controller: _text,
            decimal: true,
            hint: 'Not set',
            error: true,
            semanticLabel: 'Price for ${widget.label}',
            onChanged: widget.onChanged,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.title, required this.detail, required this.onEdit});

  final String title;
  final String detail;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: flowLabelStyle),
                Text(detail, style: flowHelperStyle),
              ],
            ),
          ),
          if (onEdit != null) FlowLink('Edit', onTap: onEdit!),
        ],
      ),
    );
  }
}

/// The optional "More details" section (spec 0015, AC-3): Material, Fit,
/// Sleeve length and Care for a Fashion product, and free key and value rows
/// for any category.
class _MoreDetails extends StatefulWidget {
  const _MoreDetails({required this.controller});

  final ProductFlowController controller;

  @override
  State<_MoreDetails> createState() => _MoreDetailsState();
}

class _MoreDetailsState extends State<_MoreDetails> {
  final _customKey = TextEditingController();
  final _customValue = TextEditingController();
  final Map<String, TextEditingController> _fields = {};

  ProductFlowController get c => widget.controller;

  TextEditingController _field(String key) => _fields.putIfAbsent(
    key,
    () => TextEditingController(text: c.data.attributes[key] ?? ''),
  );

  @override
  void dispose() {
    _customKey.dispose();
    _customValue.dispose();
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fashion = c.data.category == 'Fashion';
    final predefined = _clothingDetails.map((e) => e.$1).toSet();
    final custom = c.data.attributes.entries
        .where((e) => !fashion || !predefined.contains(e.key))
        .toList();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: c.data.attributes.isNotEmpty,
        title: const Text('More details (optional)', style: flowSectionStyle),
        subtitle: const Text(
          'Material, fit and care help shoppers decide.',
          style: flowHelperStyle,
        ),
        children: [
          if (fashion)
            for (final (key, label) in _clothingDetails) ...[
              FieldLabel(label),
              AppTextField(
                controller: _field(key),
                hintText: label == 'Care instructions'
                    ? 'e.g. Machine wash at 30°C'
                    : null,
                onChanged: (text) => c.setAttribute(key, text),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          for (final entry in custom)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${entry.key}: ${entry.value}', style: flowBodyStyle),
                  ),
                  IconButton(
                    tooltip: 'Remove ${entry.key}',
                    onPressed: () => setState(() => c.setAttribute(entry.key, '')),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          const FieldLabel('Add another detail'),
          Row(
            children: [
              Expanded(child: AppTextField(controller: _customKey, hintText: 'Name, e.g. Origin')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: AppTextField(controller: _customValue, hintText: 'Value')),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FlowLink(
              'Add detail',
              onTap: () {
                final key = _customKey.text.trim();
                final value = _customValue.text.trim();
                if (key.isEmpty || value.isEmpty || key.length > 40 || value.length > 200) {
                  return;
                }
                if (c.data.attributes.length >= 20) return;
                setState(() => c.setAttribute(key, value));
                _customKey.clear();
                _customValue.clear();
              },
            ),
          ),
        ],
      ),
    );
  }
}
