import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/shipping_address.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/checkout_sheet.dart';
import 'checkout_logic.dart';

/// Opens the Shipping address sheet (Figma node 3001:10551, spec 0009, AC-6):
/// city, address, zip code and an optional note, then Continue. Resolves to
/// the checked address, or null when the sheet is closed any other way,
/// which keeps the old values.
///
/// "Add current location" is drawn as in the design but looks disabled and
/// does nothing: it needs a location plugin and a lookup service, which come
/// with their own spec. The country is fixed to Tunisia, the design has no
/// country field.
Future<ShippingAddress?> showAddressSheet(
  BuildContext context, {
  ShippingAddress? initial,
}) {
  return showCheckoutSheet<ShippingAddress>(
    context,
    title: 'Shipping address',
    child: _AddressForm(initial: initial),
  );
}

class _AddressForm extends StatefulWidget {
  const _AddressForm({this.initial});

  final ShippingAddress? initial;

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _zip;
  late final TextEditingController _note;

  String? _cityError;
  String? _addressError;
  String? _zipError;
  String? _noteError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _city = TextEditingController(text: initial?.city ?? '');
    _address = TextEditingController(text: initial?.address ?? '');
    _zip = TextEditingController(text: initial?.zip ?? '');
    _note = TextEditingController(text: initial?.note ?? '');
  }

  @override
  void dispose() {
    _city.dispose();
    _address.dispose();
    _zip.dispose();
    _note.dispose();
    super.dispose();
  }

  void _continue() {
    setState(() {
      _cityError = validateRequired(_city.text, 'city');
      _addressError = validateRequired(_address.text, 'address');
      _zipError = validateZip(_zip.text);
      _noteError = validateNote(_note.text);
    });
    if (_cityError != null ||
        _addressError != null ||
        _zipError != null ||
        _noteError != null) {
      return;
    }
    Navigator.of(context).pop(
      ShippingAddress(
        city: _city.text.trim(),
        address: _address.text.trim(),
        zip: _zip.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }

  static const TextStyle _locationStyle = TextStyle(
    fontFamily: AppTypography.fontFamilyDisplay,
    fontSize: AppTypography.sizeSm,
    height: AppTypography.lineHeightSm,
    fontWeight: FontWeight.w500,
    color: AppColors.primary200,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.base,
      children: [
        Semantics(
          button: true,
          enabled: false,
          label: 'Add current location',
          excludeSemantics: true,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(AppIconGlyph.location, color: AppColors.primary200),
              SizedBox(width: 2),
              Text('Add current location', style: _locationStyle),
            ],
          ),
        ),
        AppTextField(
          controller: _city,
          hintText: 'Enter your city',
          errorText: _cityError,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _cityError = null),
        ),
        AppTextField(
          controller: _address,
          hintText: 'Enter your address',
          errorText: _addressError,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _addressError = null),
        ),
        AppTextField(
          controller: _zip,
          hintText: 'Enter your Zip code',
          errorText: _zipError,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _zipError = null),
        ),
        AppTextField(
          controller: _note,
          hintText: 'Anything you want to add',
          errorText: _noteError,
          onChanged: (_) => setState(() => _noteError = null),
        ),
        AppButton(label: 'Continue', onPressed: _continue),
      ],
    );
  }
}
