import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';
import 'package:shopscroll_shared/widgets/app_icon.dart';
import 'package:shopscroll_shared/widgets/app_text_field.dart';
import 'package:shopscroll_shared/widgets/country_dial_code.dart';
import 'package:shopscroll_shared/widgets/phone_field.dart';

import '../../data/models/seller_application_request.dart';
import '../../data/providers/seller_application_providers.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/seller_application_repository.dart';
import '../checkout/checkout_header.dart';
import '../checkout/checkout_logic.dart' show newOrderId;
import 'seller_application_logic.dart';

/// One photo chosen on the phone, already resized by the picker.
class PickedPhoto {
  const PickedPhoto({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Asks the person for a photo from [source], or returns null when they
/// cancel. The default opens `image_picker` with the spec's resize (max width
/// 1600, quality 85, spec 0013 AC-9). Tests pass their own.
typedef PhotoPicker = Future<PickedPhoto?> Function(ImageSource source);

Future<PickedPhoto?> pickPhotoWithImagePicker(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (file == null) return null;
  return PickedPhoto(name: file.name, bytes: await file.readAsBytes());
}

/// The four step form that sends a seller application (spec 0013, AC-9):
/// store details, public contact and logo, documents, review and send. A
/// visitor with no account ([isVisitor], spec 0014, AC-7) gets one more step
/// before Review, "About you", with a name, an email and a phone number (the
/// phone chosen with the country picker so it is stored in international
/// format), and a confirmation after Send that says the team will reach them
/// there. A visitor's photos go to their own session folder. The
/// steps are not in Figma, so they are built from the onboarding screens'
/// parts ([CheckoutHeader], [AppTextField], [AppButton]) and should be
/// reviewed against a design once there is one.
///
/// Every controller and photo lives here, not in a step, so Back keeps what
/// was typed. Photos are uploaded only when the person sends, one by one, and
/// an upload that worked is not repeated on a retry. The application id is
/// made once, so a retry or a double tap sends one application (AC-1, AC-9).
class SellerApplicationWizardScreen extends ConsumerStatefulWidget {
  const SellerApplicationWizardScreen({
    super.key,
    this.photoPicker = pickPhotoWithImagePicker,
    this.isVisitor = false,
  });

  final PhotoPicker photoPicker;

  /// True for a person with no account, who applies from "Apply now".
  final bool isVisitor;

  @override
  ConsumerState<SellerApplicationWizardScreen> createState() =>
      _SellerApplicationWizardScreenState();
}

/// The steps of the form. A visitor has [about], a signed in person does not.
enum _Step { details, contact, documents, about, review }

/// What a visitor sees after Send (spec 0014, AC-7): the application is in, and
/// the team will contact them at the email and phone they gave.
class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({
    required this.email,
    required this.phone,
    required this.onDone,
  });

  final String email;
  final String phone;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            children: [
              const Spacer(),
              Semantics(
                header: true,
                child: Text(
                  'Application sent',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                'Our team will contact you at $email and $phone.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.neutral700,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: AppButton(label: 'Done', onPressed: onDone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A photo slot: what was picked, where it went once uploaded, and why it was
/// refused.
class _Slot {
  PickedPhoto? photo;
  String? uploadedPath;
  String? error;
}

class _SellerApplicationWizardScreenState
    extends ConsumerState<SellerApplicationWizardScreen> {
  static const _titles = {
    _Step.details: 'Store details',
    _Step.contact: 'Contact and logo',
    _Step.documents: 'Documents',
    _Step.about: 'About you',
    _Step.review: 'Review and send',
  };

  late final List<_Step> _steps = [
    _Step.details,
    _Step.contact,
    _Step.documents,
    if (widget.isVisitor) _Step.about,
    _Step.review,
  ];

  final _applicationId = newOrderId(); // a random v4 id, reused for any id
  final _detailsKey = GlobalKey<FormState>();
  final _contactKey = GlobalKey<FormState>();
  final _aboutKey = GlobalKey<FormState>();
  final _aboutName = TextEditingController();
  final _aboutEmail = TextEditingController();
  final _aboutPhone = TextEditingController();
  CountryDialCode _country = defaultCountryDialCode;
  String? _phoneError;
  bool _sent = false;
  final _storeName = TextEditingController();
  final _username = TextEditingController();
  final _location = TextEditingController();
  final _bio = TextEditingController();
  final _website = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _logo = _Slot();
  final _idDocument = _Slot();
  final _businessDocument = _Slot();

  int _step = 0;

  /// Set by the first failed Next on step 1. Until then the fields stay quiet,
  /// so touching one does not flag the empty ones (the form's own
  /// `onUserInteraction` mode validates every field when any one changes).
  bool _detailsTried = false;
  bool _submitting = false;
  String? _usernameError;
  String? _submitError;

  @override
  void dispose() {
    for (final c in [
      _storeName,
      _username,
      _location,
      _bio,
      _website,
      _phone,
      _email,
      _aboutName,
      _aboutEmail,
      _aboutPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _close() => context.canPop()
      ? context.pop()
      : context.go(widget.isVisitor ? '/' : '/profile');

  Future<void> _pick(_Slot slot) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from your library'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final PickedPhoto? picked;
    try {
      picked = await widget.photoPicker(source);
    } catch (_) {
      if (mounted) setState(() => slot.error = "Couldn't open the photo.");
      return;
    }
    if (picked == null || !mounted) return;

    final problem = checkPhoto(
      fileName: picked.name,
      bytes: picked.bytes.length,
    );
    setState(() {
      slot.error = problem;
      if (problem == null) {
        slot.photo = picked;
        slot.uploadedPath = null; // a replaced photo is uploaded again
      }
    });
  }

  void _remove(_Slot slot) => setState(() {
    slot.photo = null;
    slot.uploadedPath = null;
    slot.error = null;
  });

  void _next() {
    final step = _steps[_step];
    final valid = switch (step) {
      _Step.details => _detailsKey.currentState?.validate() ?? false,
      _Step.contact => _contactKey.currentState?.validate() ?? false,
      _Step.documents => _checkIdDocument(),
      _Step.about => _checkAbout(),
      _Step.review => true,
    };
    if (valid) {
      setState(() => _step++);
    } else if (step == _Step.details && !_detailsTried) {
      setState(() => _detailsTried = true);
    }
  }

  bool _checkAbout() {
    final fields = _aboutKey.currentState?.validate() ?? false;
    final phoneError = validateApplicantPhone(_country, _aboutPhone.text);
    setState(() => _phoneError = phoneError);
    return fields && phoneError == null;
  }

  bool _checkIdDocument() {
    if (_idDocument.photo != null) return true;
    setState(() => _idDocument.error = 'Add a photo of your ID.');
    return false;
  }

  /// Uploads a slot's photo unless it already went up, and returns its path.
  Future<String?> _upload(_Slot slot, SellerApplicationPhoto kind) async {
    final photo = slot.photo;
    if (photo == null) return null;
    return slot.uploadedPath ??= await ref
        .read(sellerApplicationRepositoryProvider)
        .uploadPhoto(
          applicationId: _applicationId,
          photo: kind,
          bytes: photo.bytes,
          extension: photoExtension(photo.name)!,
          asVisitor: widget.isVisitor,
        );
  }

  String? _orNull(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _submit() async {
    if (_submitting) return; // a double tap sends one application
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final repository = ref.read(sellerApplicationRepositoryProvider);
    try {
      // Submit is called only once every upload worked (AC-9).
      final idPath = await _upload(
        _idDocument,
        SellerApplicationPhoto.idDocument,
      );
      final businessPath = await _upload(
        _businessDocument,
        SellerApplicationPhoto.businessDocument,
      );
      final logoPath = await _upload(_logo, SellerApplicationPhoto.logo);

      await repository.submit(
        SellerApplicationRequest(
          id: _applicationId,
          storeName: _storeName.text.trim(),
          username: _username.text.trim(),
          location: _location.text.trim(),
          idDocumentPath: idPath!,
          bio: _orNull(_bio),
          websiteUrl: _orNull(_website),
          contactPhone: _orNull(_phone),
          contactEmail: _orNull(_email),
          logoPath: logoPath,
          businessDocumentPath: businessPath,
          applicant: widget.isVisitor
              ? ApplicantContact(
                  name: _aboutName.text.trim(),
                  email: _aboutEmail.text.trim(),
                  phone: internationalPhone(_country, _aboutPhone.text),
                )
              : null,
        ),
      );
    } on SellerApplicationException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        if (error.reason == SellerApplicationFailure.usernameTaken) {
          _step = 0;
          _usernameError = sellerApplicationFailureMessage(error.reason);
        } else {
          _submitError = sellerApplicationFailureMessage(error.reason);
        }
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = sellerApplicationFailureMessage(
          SellerApplicationFailure.failed,
        );
      });
      return;
    }

    if (widget.isVisitor) {
      // No list to refresh for a visitor: show the confirmation instead.
      if (mounted) setState(() => _sent = true);
      return;
    }
    ref.invalidate(sellerApplicationsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Application sent')));
    _close();
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return _SentConfirmation(
        email: _aboutEmail.text.trim(),
        phone: internationalPhone(_country, _aboutPhone.text),
        onDone: _close,
      );
    }
    final isLast = _step == _steps.length - 1;
    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: SafeArea(
        child: Column(
          children: [
            CheckoutHeader(title: 'Seller application', onClose: _close),
            _Progress(step: _step, total: _steps.length),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.base),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      _titles[_steps[_step]]!,
                      style: AppTypography.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  _stepBody(),
                ],
              ),
            ),
            if (_submitError != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                ),
                child: Text(
                  _submitError!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.error500,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: AppButton(
                        label: 'Back',
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        enabled: !_submitting,
                        onPressed: () => setState(() => _step--),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: !isLast
                          ? 'Next'
                          : _submitting
                          ? 'Sending...'
                          : _submitError != null
                          ? 'Try again'
                          : 'Send application',
                      size: AppButtonSize.small,
                      enabled: !_submitting,
                      onPressed: isLast ? _submit : _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody() => switch (_steps[_step]) {
    _Step.details => _detailsStep(),
    _Step.contact => _contactStep(),
    _Step.documents => _documentsStep(),
    _Step.about => _aboutStep(),
    _Step.review => _reviewStep(),
  };

  Widget _detailsStep() {
    return Form(
      key: _detailsKey,
      autovalidateMode: _detailsTried
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Store name'),
          AppTextField(
            controller: _storeName,
            hintText: 'Your store name',
            validator: validateStoreName,
          ),
          const SizedBox(height: AppSpacing.base),
          _label('Username'),
          AppTextField(
            controller: _username,
            hintText: 'your_store',
            helperText: 'Lowercase letters, numbers, _ and .',
            errorText: _usernameError,
            validator: validateUsername,
            onChanged: (_) {
              if (_usernameError != null) setState(() => _usernameError = null);
            },
          ),
          const SizedBox(height: AppSpacing.base),
          _label('Location'),
          AppTextField(
            controller: _location,
            hintText: 'City, country',
            validator: validateLocation,
          ),
          const SizedBox(height: AppSpacing.base),
          _label('About your store (optional)'),
          AppTextField(
            controller: _bio,
            hintText: 'Tell buyers what you sell',
            maxLines: 3,
            validator: validateBio,
          ),
        ],
      ),
    );
  }

  Widget _contactStep() {
    return Form(
      key: _contactKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buyers can see this on your store page. Leave it empty to keep '
            'it private.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.neutral700,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          _label('Website (optional)'),
          AppTextField(
            controller: _website,
            hintText: 'https://',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppSpacing.base),
          _label('Phone (optional)'),
          AppTextField(
            controller: _phone,
            hintText: 'Store phone number',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.base),
          _label('Email (optional)'),
          AppTextField(
            controller: _email,
            hintText: 'Store email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.base),
          _PhotoField(
            label: 'Store logo (optional)',
            slot: _logo,
            onPick: () => _pick(_logo),
            onRemove: () => _remove(_logo),
          ),
        ],
      ),
    );
  }

  Widget _documentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Our team checks these before your store opens. They are private '
          'and are never shown to other people.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral700),
        ),
        const SizedBox(height: AppSpacing.base),
        _PhotoField(
          label: 'Photo of your ID',
          slot: _idDocument,
          onPick: () => _pick(_idDocument),
          onRemove: () => _remove(_idDocument),
        ),
        const SizedBox(height: AppSpacing.base),
        _PhotoField(
          label: 'Business registration (optional)',
          slot: _businessDocument,
          onPick: () => _pick(_businessDocument),
          onRemove: () => _remove(_businessDocument),
        ),
      ],
    );
  }

  Widget _aboutStep() {
    return Form(
      key: _aboutKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Our team uses these to reach you about your application. They '
            'are private and are never shown to other people.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.neutral700,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          _label('Your name'),
          AppTextField(
            controller: _aboutName,
            hintText: 'Full name',
            validator: validateApplicantName,
          ),
          const SizedBox(height: AppSpacing.base),
          _label('Your email'),
          AppTextField(
            controller: _aboutEmail,
            hintText: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: validateApplicantEmail,
          ),
          const SizedBox(height: AppSpacing.base),
          _label('Your phone number'),
          PhoneField(
            controller: _aboutPhone,
            errorText: _phoneError,
            country: _country,
            onCountryChanged: (country) => setState(() => _country = country),
            onChanged: (_) {
              if (_phoneError != null) setState(() => _phoneError = null);
            },
          ),
        ],
      ),
    );
  }

  Widget _reviewStep() {
    String shown(String? value) =>
        (value == null || value.isEmpty) ? '-' : value;
    String yesNo(_Slot slot) => slot.photo == null ? 'Not added' : 'Added';
    return Column(
      children: [
        if (widget.isVisitor) ...[
          _ReviewRow('Your name', _aboutName.text.trim()),
          _ReviewRow('Your email', _aboutEmail.text.trim()),
          _ReviewRow(
            'Your phone',
            internationalPhone(_country, _aboutPhone.text),
          ),
        ],
        _ReviewRow('Store name', _storeName.text.trim()),
        _ReviewRow('Username', _username.text.trim()),
        _ReviewRow('Location', _location.text.trim()),
        _ReviewRow('About', shown(_orNull(_bio))),
        _ReviewRow('Website', shown(_orNull(_website))),
        _ReviewRow('Phone', shown(_orNull(_phone))),
        _ReviewRow('Email', shown(_orNull(_email))),
        _ReviewRow('Logo', yesNo(_logo)),
        _ReviewRow('ID photo', yesNo(_idDocument)),
        _ReviewRow('Business registration', yesNo(_businessDocument)),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(text, style: AppTypography.labelLarge),
  );
}

/// The bar under the title: how far through the four steps the person is.
class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});

  final int step;
  final int total;

  // Figma has no progress bar, 4 is a hairline that still reads as a bar.
  static const double _height = 4;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${step + 1} of $total',
      child: LinearProgressIndicator(
        value: (step + 1) / total,
        minHeight: _height,
        color: AppColors.primary400,
        backgroundColor: AppColors.neutral200,
      ),
    );
  }
}

/// A labelled photo slot: an "Add photo" box, or the chosen photo with
/// Replace and Remove. [slot]'s error shows under it.
class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.label,
    required this.slot,
    required this.onPick,
    required this.onRemove,
  });

  final String label;
  final _Slot slot;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  static const double _previewSize = 96;

  @override
  Widget build(BuildContext context) {
    final photo = slot.photo;
    final error = slot.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        if (photo == null)
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: _previewSize,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: error == null
                      ? AppColors.neutral500
                      : AppColors.error500,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppIcon(
                    AppIconGlyph.upload,
                    color: AppColors.neutral700,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Add photo',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.neutral700,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.memory(
                  photo.bytes,
                  width: _previewSize,
                  height: _previewSize,
                  fit: BoxFit.cover,
                  semanticLabel: label,
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              TextButton(onPressed: onPick, child: const Text('Replace')),
              TextButton(
                onPressed: onRemove,
                child: Text(
                  'Remove',
                  style: TextStyle(color: AppColors.error500),
                ),
              ),
            ],
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              error,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error500,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.neutral700,
              ),
            ),
          ),
          Expanded(flex: 3, child: Text(value, style: AppTypography.bodyLarge)),
        ],
      ),
    );
  }
}
