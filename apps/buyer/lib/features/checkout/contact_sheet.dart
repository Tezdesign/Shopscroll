import 'package:flutter/material.dart';

import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/models/contact_info.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';
import 'package:shopscroll_shared/widgets/app_text_field.dart';
import '../../shared/widgets/checkout_sheet.dart';
import 'package:shopscroll_shared/widgets/country_dial_code.dart';
import 'package:shopscroll_shared/widgets/phone_field.dart';
import 'checkout_logic.dart';

/// Opens the Contact information sheet (Figma node 3001:10570, spec 0009,
/// AC-4): full name, email and a phone number with its dial code, then
/// Continue. Resolves to the checked details, or null when the sheet is
/// closed any other way, which keeps the old values.
///
/// Deviations from the design: the phone is the app's own [PhoneField] with a
/// dial code picker (starting on Tunisia), and the "Save these informations
/// for future usages" toggle is left out (spec 0009: nothing is saved beyond
/// the order). The sheet is a plain white surface, see [showCheckoutSheet].
Future<ContactInfo?> showContactSheet(
  BuildContext context, {
  ContactInfo? initial,
}) {
  return showCheckoutSheet<ContactInfo>(
    context,
    title: 'Contact information',
    child: _ContactForm(initial: initial),
  );
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({this.initial});

  final ContactInfo? initial;

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late CountryDialCode _country;

  String? _nameError;
  String? _emailError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _email = TextEditingController(text: initial?.email ?? '');
    final phone = splitPhone(initial?.phone ?? '');
    _country = phone.country;
    _phone = TextEditingController(text: phone.national);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _continue() {
    setState(() {
      _nameError = validateFullName(_name.text);
      _emailError = validateEmail(_email.text);
      _phoneError = validatePhone(_country, _phone.text);
    });
    if (_nameError != null || _emailError != null || _phoneError != null) {
      return;
    }
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    Navigator.of(context).pop(
      ContactInfo(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: '${_country.dialCode}$digits',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.base,
      children: [
        AppTextField(
          controller: _name,
          hintText: 'Enter your full name',
          errorText: _nameError,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _nameError = null),
        ),
        AppTextField(
          controller: _email,
          hintText: 'Enter your email',
          errorText: _emailError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _emailError = null),
        ),
        PhoneField(
          controller: _phone,
          hintText: 'Enter your phone number',
          errorText: _phoneError,
          country: _country,
          onCountryChanged: (country) => setState(() => _country = country),
          onChanged: (_) => setState(() => _phoneError = null),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: 'Continue', onPressed: _continue),
      ],
    );
  }
}
