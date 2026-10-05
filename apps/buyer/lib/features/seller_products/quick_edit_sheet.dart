import 'package:flutter/material.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/product_draft.dart';
import 'package:shopscroll_shared/models/product_variant.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';

import '../../data/repositories/seller_product_repository.dart';
import 'flow_widgets.dart';
import 'product_messages.dart';
import 'variant_options.dart';

/// Opens the quick edit sheet (spec 0015, AC-11): change the price and stock
/// of each variant without opening the whole flow. Returns true when
/// something was saved.
Future<bool?> showQuickEditSheet(
  BuildContext context,
  Product product,
  SellerProductRepository repository,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white100,
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: QuickEditSheet(product: product, repository: repository),
    ),
  );
}

class QuickEditSheet extends StatefulWidget {
  const QuickEditSheet({super.key, required this.product, required this.repository});

  final Product product;
  final SellerProductRepository repository;

  @override
  State<QuickEditSheet> createState() => _QuickEditSheetState();
}

class _Row {
  _Row(this.variant)
    : price = TextEditingController(text: Money.toWire(variant.price)),
      stock = TextEditingController(text: '${variant.stock}');

  final ProductVariant variant;
  final TextEditingController price;
  final TextEditingController stock;
  String? error;

  void dispose() {
    price.dispose();
    stock.dispose();
  }
}

class _QuickEditSheetState extends State<QuickEditSheet> {
  late final List<_Row> _rows;
  bool _saving = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _rows = [for (final v in widget.product.variants) _Row(v)];
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  String _label(ProductVariant v) => variantLabel(
    DraftVariant(id: v.id, colorName: v.colorName, colorValue: v.colorValue, size: v.size),
  );

  Future<void> _save() async {
    // Check every row first, so nothing is saved when one is wrong.
    var ok = true;
    final changes = <(ProductVariant, double, int)>[];
    for (final r in _rows) {
      final price = Money.tryParse(r.price.text);
      final stock = int.tryParse(r.stock.text.trim());
      if (price == null || price <= 0) {
        r.error = 'Enter a price above 0.';
        ok = false;
      } else if (stock == null || stock < 0) {
        r.error = 'Stock must be 0 or more.';
        ok = false;
      } else {
        r.error = null;
        if (price != r.variant.price || stock != r.variant.stock) {
          changes.add((r.variant, price, stock));
        }
      }
    }
    if (!ok) {
      setState(() {});
      return;
    }
    if (changes.isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      for (final (variant, price, stock) in changes) {
        await widget.repository.updateVariantQuick(variant.id, price: price, stock: stock);
      }
      if (mounted) Navigator.pop(context, true);
    } on SellerProductException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = issueMessage(DraftIssue(error.code, error.variantId));
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = "Couldn't save. Check your connection and try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.product.title, style: flowSectionStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Text('Edit price and stock', style: flowHelperStyle),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final r in _rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(_label(r.variant), style: flowBodyStyle)),
                                CellField(
                                  controller: r.price,
                                  decimal: true,
                                  error: r.error != null,
                                  semanticLabel: 'Price for ${_label(r.variant)}',
                                  onChanged: (_) {},
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                CellField(
                                  controller: r.stock,
                                  width: 64,
                                  error: r.error != null,
                                  semanticLabel: 'Stock for ${_label(r.variant)}',
                                  onChanged: (_) {},
                                ),
                              ],
                            ),
                            if (r.error != null) Text(r.error!, style: flowErrorStyle),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_failure != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(_failure!, style: flowErrorStyle),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: _saving ? 'Saving...' : 'Save',
              onPressed: _saving ? null : _save,
              enabled: !_saving,
            ),
          ],
        ),
      ),
    );
  }
}
