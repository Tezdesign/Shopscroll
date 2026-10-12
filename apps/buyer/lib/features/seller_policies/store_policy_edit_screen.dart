import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

import '../../data/models/store_policies.dart';
import '../../data/providers/store_policies_providers.dart';
import '../store/seller_gate.dart';
import 'store_policies_screen.dart';

enum StorePolicySection { delivery, payment, returns }

/// Edits one section of the store policies at `/store/policies/:section`.
///
/// Figma nodes 5599:3483 (Edit delivery), 5601:3532 (Edit payment), 5601:3639
/// (Edit returns). Deviations: the "Different fee for specific cities" and
/// "Online payment (coming soon)" and "Non-returnable categories" rows are
/// left out, the data has no place for them yet; the header "Save" is the
/// bottom button only.
class StorePolicyEditScreen extends ConsumerWidget {
  const StorePolicyEditScreen({super.key, required this.section});

  final StorePolicySection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policies = ref.watch(storePoliciesProvider);
    final title = switch (section) {
      StorePolicySection.delivery => 'Edit delivery',
      StorePolicySection.payment => 'Edit payment',
      StorePolicySection.returns => 'Edit returns',
    };
    return SellerGate(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.white100,
          body: SafeArea(
            child: Column(
              children: [
                PolicyHeader(title: title),
                Expanded(
                  child: policies.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => const Center(
                      child: Text("Couldn't load your store policies."),
                    ),
                    data: (p) => _Form(section: section, policies: p),
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

List<String> _options(List<String> base, String current) =>
    base.contains(current) ? base : [current, ...base];

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.section, required this.policies});

  final StorePolicySection section;
  final StorePolicies policies;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _formKey = GlobalKey<FormState>();
  late String _area = widget.policies.deliveryArea;
  late String _time = widget.policies.deliveryTime;
  late final _fee = TextEditingController(
    text: widget.policies.deliveryFee.toStringAsFixed(3),
  );
  late final _freeOver = TextEditingController(
    text: widget.policies.freeDeliveryOver?.toStringAsFixed(3) ?? '',
  );
  late String _payMethod = widget.policies.paymentMethod;
  late final _payMessage = TextEditingController(
    text: widget.policies.paymentMessage,
  );
  late final _maxCod = TextEditingController(
    text: widget.policies.maxCodOrder?.toStringAsFixed(3) ?? '',
  );
  late String _window = '${widget.policies.returnWindowDays} days';
  late String _condition = widget.policies.returnCondition;
  late String _shipping = widget.policies.returnShipping;
  late String _refund = widget.policies.refundMethod;
  bool _saving = false;

  @override
  void dispose() {
    _fee.dispose();
    _freeOver.dispose();
    _payMessage.dispose();
    _maxCod.dispose();
    super.dispose();
  }

  double? _amount(TextEditingController c) => Money.tryParse(c.text);

  String? _requiredAmount(String? text) =>
      Money.tryParse(text ?? '') == null ? 'Enter an amount like 7.000' : null;

  String? _optionalAmount(String? text) =>
      (text ?? '').trim().isEmpty || Money.tryParse(text!) != null
      ? null
      : 'Enter an amount like 150.000';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final p = widget.policies;
    final next = switch (widget.section) {
      StorePolicySection.delivery => p.copyWith(
        deliveryArea: _area,
        deliveryTime: _time,
        deliveryFee: _amount(_fee),
        freeDeliveryOver: () =>
            _freeOver.text.trim().isEmpty ? null : _amount(_freeOver),
      ),
      StorePolicySection.payment => p.copyWith(
        paymentMethod: _payMethod,
        paymentMessage: _payMessage.text.trim(),
        maxCodOrder: () =>
            _maxCod.text.trim().isEmpty ? null : _amount(_maxCod),
      ),
      StorePolicySection.returns => p.copyWith(
        returnWindowDays: int.parse(_window.split(' ').first),
        returnCondition: _condition,
        returnShipping: _shipping,
        refundMethod: _refund,
      ),
    };
    setState(() => _saving = true);
    try {
      await ref.read(saveStorePoliciesProvider)(next);
      router.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (heading, sub, fields, cta) = switch (widget.section) {
      StorePolicySection.delivery => (
        'Delivery',
        'Applies to every product without an exception.',
        <Widget>[
          _Dropdown(
            label: 'Delivery area',
            value: _area,
            options: _options([
              'Tunisia (all governorates)',
              'Greater Tunis',
              'Sousse and Monastir',
            ], _area),
            onChanged: (v) => setState(() => _area = v),
          ),
          _Dropdown(
            label: 'Delivery time',
            value: _time,
            options: _options([
              'Same day',
              '1–2 days',
              '3–5 days',
              '1 week',
            ], _time),
            onChanged: (v) => setState(() => _time = v),
          ),
          _AmountField(
            label: 'Fee (TND)',
            controller: _fee,
            validator: _requiredAmount,
          ),
          _AmountField(
            label: 'Free delivery over (TND, optional)',
            controller: _freeOver,
            validator: _optionalAmount,
            helper: 'Leave empty to always charge the delivery fee.',
          ),
        ],
        'Save delivery policy',
      ),
      StorePolicySection.payment => (
        'Payment',
        'How shoppers pay for your orders.',
        <Widget>[
          _Dropdown(
            label: 'Accepted method',
            value: _payMethod,
            options: _options(['Cash on delivery'], _payMethod),
            onChanged: (v) => setState(() => _payMethod = v),
          ),
          _AmountField(
            label: 'Max cash on delivery order (TND, optional)',
            controller: _maxCod,
            validator: _optionalAmount,
          ),
          _TextField(
            label: 'Message to shoppers',
            controller: _payMessage,
            helper: 'Shown on the product page and at checkout.',
          ),
        ],
        'Save payment policy',
      ),
      StorePolicySection.returns => (
        'Returns',
        'What shoppers can send back, and who pays.',
        <Widget>[
          _Dropdown(
            label: 'Return window',
            value: _window,
            options: _options(['7 days', '14 days', '30 days'], _window),
            onChanged: (v) => setState(() => _window = v),
          ),
          _Dropdown(
            label: 'Item condition',
            value: _condition,
            options: _options([
              'Unworn',
              'Unworn, with tags',
              'Any condition',
            ], _condition),
            onChanged: (v) => setState(() => _condition = v),
          ),
          _Dropdown(
            label: 'Return shipping',
            value: _shipping,
            options: _options(['Buyer pays', 'Seller pays'], _shipping),
            onChanged: (v) => setState(() => _shipping = v),
          ),
          _Dropdown(
            label: 'Refund method',
            value: _refund,
            options: _options([
              'Original payment method',
              'Store credit',
            ], _refund),
            onChanged: (v) => setState(() => _refund = v),
          ),
        ],
        'Save returns policy',
      ),
    };

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.base),
              children: [
                Text(
                  heading,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamilyDisplay,
                    fontSize: AppTypography.sizeXl,
                    height: AppTypography.lineHeightXl,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral1100,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: AppTypography.sizeSm,
                    height: AppTypography.lineHeightSm,
                    color: AppColors.neutral700,
                  ),
                ),
                for (final field in fields) ...[
                  const SizedBox(height: AppSpacing.base),
                  field,
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(100, 48),
                  ),
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : cta),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: AppTypography.sizeSm,
        fontWeight: FontWeight.w600,
        color: AppColors.neutral1100,
      ),
    ),
  );
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          items: [
            for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.label,
    required this.controller,
    required this.validator,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validator,
          decoration: InputDecoration(helperText: helper),
        ),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.controller,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        TextFormField(
          controller: controller,
          maxLength: 120,
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Enter a message' : null,
          decoration: InputDecoration(helperText: helper),
        ),
      ],
    );
  }
}
