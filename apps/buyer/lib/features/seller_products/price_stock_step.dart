import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/models/product_draft.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_text_field.dart';

import 'flow_widgets.dart';
import 'product_flow_controller.dart';
import 'product_messages.dart';
import 'variant_options.dart';

/// Step 2, "Price & stock" (Figma nodes 5523:28572 for a product without
/// options and 5523:27585 for the colors and sizes table).
///
/// Deviations from the frames (spec 0015): size presets and a custom size, a
/// photo can be linked to each color, "Set all" for price and stock and a row
/// menu that copies a value down, and the error for a row is shown on the row.
class PriceStockStep extends StatefulWidget {
  const PriceStockStep({
    super.key,
    required this.controller,
    required this.currency,
  });

  final ProductFlowController controller;
  final String currency;

  @override
  State<PriceStockStep> createState() => _PriceStockStepState();
}

class _PriceStockStepState extends State<PriceStockStep> {
  late final TextEditingController _defaultPrice;
  bool _showShoeSizes = false;
  bool _showSku = false;
  final _customSize = TextEditingController();

  ProductFlowController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _defaultPrice = TextEditingController(text: c.defaultPrice);
  }

  @override
  void dispose() {
    _defaultPrice.dispose();
    _customSize.dispose();
    super.dispose();
  }

  bool _hasIssue(String code, [String? variantId]) =>
      c.attempted(2) &&
      c.issuesFor(2).any(
        (i) => i.code == code && (variantId == null || i.variantId == variantId),
      );

  Future<void> _askAll({required bool price}) async {
    final input = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(price ? 'Set all prices' : 'Set all stock'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: price),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              price ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
            ),
          ],
          decoration: InputDecoration(
            hintText: price ? 'Price in ${widget.currency}' : 'Units in stock',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, input.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    input.dispose();
    if (value == null || value.trim().isEmpty) return;
    if (price) {
      final parsed = Money.tryParse(value);
      if (parsed != null) c.setAllPrices(Money.toWire(parsed));
    } else {
      final stock = int.tryParse(value);
      if (stock != null) c.setAllStock(stock);
    }
  }

  void _showColorSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white100,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add a color', style: flowSectionStyle),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final color in colorPalette)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(sheet);
                        c.addColor(color);
                      },
                      child: Semantics(
                        button: true,
                        label: 'Add ${color.name}',
                        child: SizedBox(
                          width: 72,
                          child: Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Color(color.value),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.neutral300),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                color.name,
                                style: flowHelperStyle,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPhotoSheet(ColorOption color) {
    final done = c.photos.where((p) => p.status == PhotoStatus.done).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white100,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Photo for ${color.name}', style: flowSectionStyle),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Shoppers see this photo when they pick this color.',
                style: flowHelperStyle,
              ),
              const SizedBox(height: AppSpacing.md),
              if (done.isEmpty)
                const Text('Add photos in step 1 first.', style: flowBodyStyle)
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final p in done)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(sheet);
                          c.setColorPhoto(color.value, p.path);
                        },
                        child: Semantics(
                          button: true,
                          label: 'Use this photo for ${color.name}',
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: c.colorPhoto(color.value) == p.path
                                    ? AppColors.primary400
                                    : AppColors.neutral200,
                                width: 2,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: PhotoImage(bytes: p.bytes, path: p.path),
                          ),
                        ),
                      ),
                  ],
                ),
              if (c.colorPhoto(color.value) != null)
                FlowLink(
                  'No photo for this color',
                  color: AppColors.neutral900,
                  onTap: () {
                    Navigator.pop(sheet);
                    c.setColorPhoto(color.value, null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = c.data;
    final lowest = data.lowestPrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryCard(controller: c, currency: widget.currency, lowest: lowest),
        const SizedBox(height: AppSpacing.base),
        FieldLabel('Default price (${widget.currency})', required: true),
        AppTextField(
          controller: _defaultPrice,
          hintText: '0.000',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: c.setDefaultPrice,
          errorText:
              _hasIssue('missing_price') && !c.optionsEnabled
              ? issueMessage(const DraftIssue('missing_price'), variantLabel: 'this product')
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Prices are in ${widget.currency}, your store currency. This is what shoppers pay, up to 3 decimals.',
          style: flowHelperStyle,
        ),
        const SizedBox(height: AppSpacing.base),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: c.optionsEnabled,
          onChanged: c.setOptionsEnabled,
          title: const Text('This product has options', style: flowLabelStyle),
          subtitle: const Text(
            'Colors or sizes with their own stock and price.',
            style: flowHelperStyle,
          ),
        ),
        if (!c.optionsEnabled) _buildPlain() else ..._buildOptions(),
      ],
    );
  }

  Widget _buildPlain() {
    final v = c.variants.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        const FieldLabel('Stock quantity', required: true),
        _StockField(
          key: ValueKey('plain-${v.id}'),
          initial: v.stock,
          onChanged: (n) => c.setVariantStock(v.id, n),
          error: _hasIssue('bad_stock'),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Stock goes down by itself when an order is placed.',
          style: flowHelperStyle,
        ),
        const SizedBox(height: AppSpacing.base),
        const FieldLabel('SKU (optional)'),
        _SkuField(
          key: ValueKey('sku-${v.id}'),
          initial: v.sku ?? '',
          onChanged: (text) => c.setVariantSku(v.id, text),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Your own reference for this product. Shoppers do not see it.',
          style: flowHelperStyle,
        ),
      ],
    );
  }

  List<Widget> _buildOptions() {
    final colors = c.colors;
    final sizes = c.sizes;
    final rows = c.variants;
    final presets = _showShoeSizes ? shoeSizes : letterSizes;
    final custom = sizes.where((s) => !letterSizes.contains(s) && !shoeSizes.contains(s));
    return [
      const SizedBox(height: AppSpacing.md),
      const FieldLabel('Colors'),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final color in colors)
            OptionChip(
              label: color.name,
              selected: true,
              onTap: () => _showColorPhotoSheet(color),
              onRemove: () => c.removeColor(color.value),
            ),
          OptionChip(label: '+ Add color', selected: false, onTap: _showColorSheet),
        ],
      ),
      if (colors.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Tap a color to choose the photo shoppers see for it.',
          style: flowHelperStyle,
        ),
      ],
      const SizedBox(height: AppSpacing.base),
      FieldLabel(
        'Sizes',
        trailing: null,
      ),
      Row(
        children: [
          FlowLink(
            'Clothing',
            color: _showShoeSizes ? AppColors.neutral700 : AppColors.primary400,
            onTap: () => setState(() => _showShoeSizes = false),
          ),
          FlowLink(
            'Shoes',
            color: _showShoeSizes ? AppColors.primary400 : AppColors.neutral700,
            onTap: () => setState(() => _showShoeSizes = true),
          ),
        ],
      ),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final size in presets)
            OptionChip(
              label: size,
              selected: sizes.contains(size),
              onTap: () => c.toggleSize(size),
            ),
          for (final size in custom)
            OptionChip(
              label: size,
              selected: true,
              onTap: () => c.toggleSize(size),
              onRemove: () => c.toggleSize(size),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: _customSize,
              hintText: 'Another size, e.g. One size',
              textInputAction: TextInputAction.done,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FlowLink(
            'Add',
            onTap: () {
              if (c.addCustomSize(_customSize.text)) _customSize.clear();
            },
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.base),
      Text(
        '${colors.length} ${colors.length == 1 ? 'color' : 'colors'} × '
        '${sizes.length} ${sizes.length == 1 ? 'size' : 'sizes'} = '
        '${rows.length} ${rows.length == 1 ? 'variant' : 'variants'}',
        style: flowLabelStyle,
      ),
      if (_hasIssue('too_many_variants')) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          issueMessage(const DraftIssue('too_many_variants')),
          style: flowErrorStyle,
        ),
      ],
      if (_hasIssue('duplicate_variant')) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          issueMessage(const DraftIssue('duplicate_variant')),
          style: flowErrorStyle,
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      const Text('Stock by variant', style: flowSectionStyle),
      const SizedBox(height: AppSpacing.xs),
      const Text(
        'Tap a price or quantity to edit.',
        style: flowHelperStyle,
      ),
      Row(
        children: [
          FlowLink('Set all prices', onTap: () => _askAll(price: true)),
          const SizedBox(width: AppSpacing.base),
          FlowLink('Set all stock', onTap: () => _askAll(price: false)),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      const _TableHeader(),
      for (var i = 0; i < rows.length; i++)
        _VariantRow(
          key: ValueKey('${rows[i].id}-${c.bulkRevision}'),
          variant: rows[i],
          showSku: _showSku,
          priceError: _hasIssue('missing_price', rows[i].id),
          stockError: _hasIssue('bad_stock', rows[i].id),
          onPrice: (text) => c.setVariantPrice(rows[i].id, text),
          onStock: (n) => c.setVariantStock(rows[i].id, n),
          onSku: (text) => c.setVariantSku(rows[i].id, text),
          onCopyPrice: () => c.copyDown(i, price: true),
          onCopyStock: () => c.copyDown(i, price: false),
        ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            const Expanded(child: Text('Total stock', style: flowLabelStyle)),
            Text('${c.data.totalStock} units', style: flowLabelStyle),
          ],
        ),
      ),
      FlowLink(
        _showSku ? 'Hide SKUs' : 'Add optional SKUs',
        onTap: () => setState(() => _showSku = !_showSku),
      ),
    ];
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.controller,
    required this.currency,
    required this.lowest,
  });

  final ProductFlowController controller;
  final String currency;
  final double? lowest;

  @override
  Widget build(BuildContext context) {
    final data = controller.data;
    final cover = controller.photos.isEmpty ? null : controller.photos.first;
    final parts = [
      if (data.category.isNotEmpty) data.category,
      if (lowest != null) Money.format(lowest!, currency),
      '${data.totalStock} units',
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white100,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 48,
              height: 48,
              child: cover == null
                  ? const ColoredBox(color: AppColors.neutral200)
                  : PhotoImage(bytes: cover.bytes, path: cover.path),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title.isEmpty ? 'Untitled product' : data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: flowLabelStyle,
                ),
                Text(parts.join(' · '), style: flowHelperStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary50,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: const Row(
        children: [
          Expanded(child: Text('Variant', style: flowLabelStyle)),
          SizedBox(
            width: 84,
            child: Text('Price', style: flowLabelStyle, textAlign: TextAlign.end),
          ),
          SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 64,
            child: Text('Stock', style: flowLabelStyle, textAlign: TextAlign.end),
          ),
          SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _VariantRow extends StatefulWidget {
  const _VariantRow({
    super.key,
    required this.variant,
    required this.showSku,
    required this.priceError,
    required this.stockError,
    required this.onPrice,
    required this.onStock,
    required this.onSku,
    required this.onCopyPrice,
    required this.onCopyStock,
  });

  final DraftVariant variant;
  final bool showSku;
  final bool priceError;
  final bool stockError;
  final ValueChanged<String> onPrice;
  final ValueChanged<int> onStock;
  final ValueChanged<String> onSku;
  final VoidCallback onCopyPrice;
  final VoidCallback onCopyStock;

  @override
  State<_VariantRow> createState() => _VariantRowState();
}

class _VariantRowState extends State<_VariantRow> {
  late final TextEditingController _price;
  late final TextEditingController _stock;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(text: widget.variant.price);
    _stock = TextEditingController(
      text: widget.variant.stock == 0 && !widget.variant.stockSet
          ? ''
          : '${widget.variant.stock}',
    );
  }

  @override
  void dispose() {
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = variantLabel(widget.variant);
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.neutral200)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.variant.colorValue != null) ...[
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Color(widget.variant.colorValue!),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.neutral300),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(label, style: flowBodyStyle.copyWith(color: AppColors.neutral1000)),
              ),
              CellField(
                controller: _price,
                decimal: true,
                hint: '0.000',
                error: widget.priceError,
                semanticLabel: 'Price for $label',
                onChanged: widget.onPrice,
              ),
              const SizedBox(width: AppSpacing.sm),
              CellField(
                controller: _stock,
                hint: '0',
                width: 64,
                error: widget.stockError,
                semanticLabel: 'Stock for $label',
                onChanged: (text) => widget.onStock(int.tryParse(text) ?? 0),
              ),
              PopupMenuButton<String>(
                tooltip: 'More for $label',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) =>
                    value == 'price' ? widget.onCopyPrice() : widget.onCopyStock(),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'price', child: Text('Copy price to rows below')),
                  PopupMenuItem(value: 'stock', child: Text('Copy stock to rows below')),
                ],
              ),
            ],
          ),
          if (widget.priceError)
            Text(
              issueMessage(DraftIssue('missing_price', widget.variant.id), variantLabel: label),
              style: flowErrorStyle,
            ),
          if (widget.showSku)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _SkuField(
                initial: widget.variant.sku ?? '',
                onChanged: widget.onSku,
              ),
            ),
        ],
      ),
    );
  }
}

class _StockField extends StatefulWidget {
  const _StockField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.error = false,
  });

  final int initial;
  final ValueChanged<int> onChanged;
  final bool error;

  @override
  State<_StockField> createState() => _StockFieldState();
}

class _StockFieldState extends State<_StockField> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: widget.initial == 0 ? '' : '${widget.initial}',
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _text,
      hintText: '0',
      keyboardType: TextInputType.number,
      onChanged: (text) => widget.onChanged(int.tryParse(text) ?? 0),
      errorText: widget.error ? 'Stock must be 0 or more.' : null,
    );
  }
}

class _SkuField extends StatefulWidget {
  const _SkuField({super.key, required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_SkuField> createState() => _SkuFieldState();
}

class _SkuFieldState extends State<_SkuField> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _text,
      hintText: 'Add an internal reference',
      onChanged: widget.onChanged,
    );
  }
}
