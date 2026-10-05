import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/models/ids.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/models/product_draft.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';

import '../../core/area/app_area.dart';
import '../../data/providers/seller_product_providers.dart';
import '../../data/providers/user_profile_providers.dart';
import '../../data/repositories/repository_providers.dart';
import 'autofill_sheet.dart';
import 'basics_step.dart';
import 'flow_widgets.dart';
import 'photo_picker.dart';
import 'preview_step.dart';
import 'price_stock_step.dart';
import 'product_flow_controller.dart';
import 'product_messages.dart';

/// The route target for a brand new product. It makes the draft id once, when
/// the page opens, so a rebuild of the router never swaps the draft under the
/// seller's hands.
class NewProductFlowScreen extends StatefulWidget {
  const NewProductFlowScreen({super.key});

  @override
  State<NewProductFlowScreen> createState() => _NewProductFlowScreenState();
}

class _NewProductFlowScreenState extends State<NewProductFlowScreen> {
  final String _id = newUuid();

  @override
  Widget build(BuildContext context) =>
      ProductFlowScreen(draftId: _id, isNew: true);
}

/// Add or edit a product in three steps: Basics, Price & stock, Preview
/// (spec 0015). Figma frames: `product-creation-*` in file
/// toOakybJ0DaJmU7vcEC0AW (nodes 5523:27381, 5523:27585, 5523:27981 and the
/// states around them).
///
/// A new product opens with [isNew] and an id made on the phone. An existing
/// draft, or the working copy of a live product, opens by its id. The draft
/// saves itself as the seller types ([ProductFlowController]).
///
/// Deviations from the frames, all from the audit (spec 0015): three steps
/// instead of four with the details optional on the last one, no Store
/// dropdown, buttons that explain what is missing instead of being disabled,
/// the Draft saved and Publishing screens are a toast and an inline state, and
/// no "Create a reel" card on the success screen yet.
class ProductFlowScreen extends ConsumerStatefulWidget {
  const ProductFlowScreen({super.key, required this.draftId, this.isNew = false});

  final String draftId;
  final bool isNew;

  @override
  ConsumerState<ProductFlowScreen> createState() => _ProductFlowScreenState();
}

class _ProductFlowScreenState extends ConsumerState<ProductFlowScreen> {
  ProductFlowController? _controller;
  Object? _loadError;
  String? _publishedId;
  bool _publishedEdit = false;
  List<DraftIssue> _serverIssues = const [];
  bool _filling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(sellerProductRepositoryProvider);
    try {
      ProductDraft? draft;
      if (widget.isNew) {
        draft = ProductDraft(
          id: widget.draftId,
          storeId: '',
          updatedAt: DateTime.now(),
        );
      } else {
        draft = await repo.getDraft(widget.draftId);
      }
      if (!mounted) return;
      if (draft == null) {
        setState(() => _loadError = 'not_found');
        return;
      }
      setState(() {
        _controller = ProductFlowController(
          repository: repo,
          draft: draft!,
          persisted: !widget.isNew,
        );
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String get _storeName {
    final id = ref.read(signedInUserIdProvider);
    final profile = id == null ? null : ref.read(userProfileByIdProvider(id)).value;
    return profile?.name ?? 'your store';
  }

  String get _currency {
    final id = ref.read(signedInUserIdProvider);
    final profile = id == null ? null : ref.read(userProfileByIdProvider(id)).value;
    return profile?.currency ?? 'TND';
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickPhotos(PhotoSourceChoice source) async {
    final c = _controller!;
    final room = ProductDraftData.maxPhotos - c.photos.length;
    if (room <= 0) return;
    try {
      final picked = await ref.read(photoPickerProvider)(source, max: room);
      if (!mounted || picked.isEmpty) return;
      final left = c.addPhotos(picked);
      if (left > 0) _say('Only 8 photos fit. $left left out.');
    } catch (_) {
      if (mounted) _say("Couldn't read that photo. Try another one.");
    }
  }

  String _fillMessage(String code) => switch (code) {
    'quota_exceeded' =>
      "You've used all of today's runs. Try again tomorrow, or type the details.",
    'no_photos' => 'Add a photo first.',
    'timeout' => 'That took too long. Try again, or type the details.',
    'not_seller' || 'no_session' => 'Sign in as a store owner to use this.',
    _ => "Couldn't read your photos. You can type the details yourself.",
  };

  /// "Fill from photos" (spec 0015, AC-13): saves the draft so the function can
  /// find its photos, asks for a suggestion, and lets the seller edit and
  /// accept it. A failure leaves the form as it was.
  Future<void> _fillFromPhotos() async {
    final c = _controller!;
    if (c.uploadingCount > 0) {
      _say('Wait for your photos to finish uploading.');
      return;
    }
    if (c.photos.where((p) => p.status == PhotoStatus.done).isEmpty) {
      _say('Add a photo first.');
      return;
    }
    setState(() => _filling = true);
    try {
      await c.ensureSaved();
      final repo = ref.read(sellerProductRepositoryProvider);
      final suggestion = await repo.autofill(c.draft.id);
      if (!mounted) return;
      final categories =
          ref.read(sellerCategoriesProvider).value ?? const <String>[];
      final choice = await showAutofillSheet(
        context,
        suggestion: suggestion,
        categories: categories,
      );
      if (choice != null) {
        c.applyAutofill(
          title: choice.title,
          description: choice.description,
          category: choice.category,
          material: choice.material,
          colors: choice.colors,
        );
      }
    } on SellerProductException catch (error) {
      if (mounted) _say(_fillMessage(error.code));
    } catch (_) {
      if (mounted) _say(_fillMessage('unknown'));
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  Future<void> _saveDraftAndLeave() async {
    final c = _controller!;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (c.persisted || c.data.photos.isNotEmpty || c.data.title.isNotEmpty) {
      await c.flush();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Saved as a draft')));
    }
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/store');
    }
  }

  void _continue() {
    final c = _controller!;
    final step = c.step;
    if (c.tryContinue(step)) {
      c.setStep(step + 1);
    } else {
      final count = c.issuesFor(step).length + (c.hasFailedPhoto ? 1 : 0);
      _say(
        count == 1 ? 'One thing is missing.' : '$count things are missing.',
      );
    }
  }

  Future<void> _publish() async {
    final c = _controller!;
    final isEdit = c.draft.isEdit;
    final result = await c.publish();
    if (!mounted) return;
    switch (result) {
      case Published(:final productId):
        setState(() {
          _publishedId = productId;
          _publishedEdit = isEdit;
          _serverIssues = const [];
        });
      case PublishRefused(:final issues):
        setState(() => _serverIssues = issues);
        _say(
          issues.length == 1
              ? issueMessage(issues.first)
              : '${issues.length} things need fixing.',
        );
      case PublishPhotoFailed():
        c.setStep(1);
        _say('A photo did not upload. Retry it or remove it.');
      case PublishNetworkFailed():
        _say("Couldn't reach the server. Your work is kept. Try again.");
      case PublishCancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.white100,
        appBar: AppBar(backgroundColor: AppColors.white100, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError == 'not_found'
                      ? 'This draft is no longer here.'
                      : "Couldn't open this product.",
                  style: flowSectionStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.base),
                AppButton(
                  label: 'Back to products',
                  size: AppButtonSize.small,
                  onPressed: () => context.go('/store/products'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (c == null) {
      return const Scaffold(
        backgroundColor: AppColors.white100,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_publishedId != null) {
      return _LiveView(
        controller: c,
        productId: _publishedId!,
        edit: _publishedEdit,
        currency: _currency,
        storeName: _storeName,
      );
    }
    final categories = ref.watch(sellerCategoriesProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => _buildFlow(context, c, categories.value),
    );
  }

  Widget _buildFlow(
    BuildContext context,
    ProductFlowController c,
    List<String>? categories,
  ) {
    final step = c.step.clamp(1, 3);
    final isEdit = c.draft.isEdit;
    final heading = switch (step) {
      1 => ('Start with the basics', 'Add the information shoppers see first.'),
      2 => ('Price & stock', 'Set the price and how many you have.'),
      _ => ('Review your product', 'See how it will look before going live.'),
    };
    final waiting = c.uploadingCount;
    final primaryLabel = step < 3
        ? 'Continue'
        : c.publishing
        ? (waiting > 0 ? 'Waiting for photos ($waiting)' : 'Publishing...')
        : (isEdit ? 'Save changes' : 'Publish product');
    return Scaffold(
      backgroundColor: AppColors.white100,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: FlowHeader(
                title: isEdit ? 'Edit product' : 'Add new product',
                onBack: _saveDraftAndLeave,
                onSaveDraft: _saveDraftAndLeave,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: StepProgress(
                step: step,
                labels: const ['Basics', 'Price & stock', 'Preview'],
                onTapStep: c.setStep,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.base),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Step $step of 3', style: flowHelperStyle),
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      header: true,
                      child: Text(heading.$1, style: flowTitleStyle),
                    ),
                    Text(heading.$2, style: flowBodyStyle),
                    const SizedBox(height: AppSpacing.base),
                    switch (step) {
                      1 => BasicsStep(
                        controller: c,
                        categories: categories,
                        onPickPhotos: _pickPhotos,
                        onFillFromPhotos: _fillFromPhotos,
                        filling: _filling,
                      ),
                      2 => PriceStockStep(controller: c, currency: _currency),
                      _ => PreviewStep(
                        controller: c,
                        currency: _currency,
                        storeName: _storeName,
                        onGoToStep: c.setStep,
                        extraIssues: _serverIssues,
                      ),
                    },
                  ],
                ),
              ),
            ),
            FlowBottomBar(
              backLabel: 'Back',
              onBack: step == 1 ? _saveDraftAndLeave : () => c.setStep(step - 1),
              primaryLabel: primaryLabel,
              onPrimary: c.publishing
                  ? null
                  : (step < 3 ? _continue : _publish),
            ),
          ],
        ),
      ),
    );
  }
}

/// The screen after Publish (Figma node 5523:29114 `product-creation-publish-success`).
/// Deviation: no "Create a reel for this product" card, because a seller
/// cannot make reels yet (spec 0015, AC-15).
class _LiveView extends StatelessWidget {
  const _LiveView({
    required this.controller,
    required this.productId,
    required this.edit,
    required this.currency,
    required this.storeName,
  });

  final ProductFlowController controller;
  final String productId;
  final bool edit;
  final String currency;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final data = controller.data;
    final cover = controller.photos.isEmpty ? null : controller.photos.first;
    final lowest = data.lowestPrice;
    return Scaffold(
      backgroundColor: AppColors.white100,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.successAlpha10,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: AppColors.success500),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        edit ? 'Changes saved' : 'Your product is live!',
                        style: flowTitleStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      edit
                          ? 'Shoppers see the new details now.'
                          : 'Shoppers can now find it in $storeName.',
                      style: flowBodyStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: cover == null
                            ? const ColoredBox(color: AppColors.neutral200)
                            : PhotoImage(bytes: cover.bytes, path: cover.path),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(data.title, style: flowLabelStyle, textAlign: TextAlign.center),
                    if (lowest != null)
                      Text(
                        Money.format(lowest, currency),
                        style: flowSectionStyle,
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Live · ${data.variants.length} ${data.variants.length == 1 ? 'variant' : 'variants'} · ${data.totalStock} units',
                      style: flowHelperStyle.copyWith(color: AppColors.success500),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                children: [
                  AppButton(
                    label: 'View product',
                    onPressed: () => context.push('/product/$productId'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Add another',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.pushReplacement('/store/products/new'),
                  ),
                  FlowLink(
                    'Back to products',
                    onTap: () => context.go('/store/products'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
