import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../data/providers/product_providers.dart';
import '../../shared/widgets/add_to_cart_toggle.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/info_row.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/size_selector.dart';
import '../../shared/widgets/spec_table.dart';

/// Reproduces the Figma "Product details" screen ("The design - user" page,
/// node 166:2686): hero image, price/stock, store row, title/description,
/// size picker, store commitments, a spec table with a "Product details"
/// row that opens a detail sheet (node 205:2431), a "Refund policy" row
/// that opens its own sheet (node 205:2487), recommended products, and a
/// fixed quantity/cart/buy footer.
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;
  String? _selectedSize;
  bool _addedToCart = false;
  bool _saved = false;

  void _showSavedToast() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.white100,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
        duration: const Duration(seconds: 2),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle, color: AppColors.success400, size: 20),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Added to saved products',
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeSm,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral1100,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productByIdProvider(widget.productId));

    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Text("Couldn't load this product."),
        ),
        data: (product) {
          if (product == null) {
            return const Center(child: Text('Product not found.'));
          }
          _selectedSize ??= product.sizes.isNotEmpty
              ? product.sizes.first
              : null;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _HeroImage(product: product)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PriceAndStockRow(product: product),
                          const SizedBox(height: AppSpacing.base),
                          _StoreRow(product: product),
                          const SizedBox(height: AppSpacing.sm),
                          _TitleAndDescription(product: product),
                          const SizedBox(height: AppSpacing.base),
                          if (product.sizes.isNotEmpty) ...[
                            _SizesSection(
                              sizes: product.sizes,
                              selected: _selectedSize,
                              onChanged: (size) =>
                                  setState(() => _selectedSize = size),
                            ),
                            const SizedBox(height: AppSpacing.base),
                          ],
                          const _StoreCommitmentsSection(),
                          const SizedBox(height: AppSpacing.base),
                          _SectionHeaderRow(
                            title: 'Product details',
                            onTap: () => showProductDetailsSheet(
                              context,
                              sizesLabel: product.sizes.join(','),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SpecTable(
                            rows: [
                              ('Material', '100% Cotton'),
                              ('Fit type', 'Loose Fit'),
                              ('Size', product.sizes.join(',')),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.base),
                          _SectionHeaderRow(
                            title: 'Refund policy',
                            onTap: () => showRefundPolicySheet(context),
                          ),
                          const SizedBox(height: AppSpacing.base),
                          _RecommendedSection(excludeProductId: product.id),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _TopBar(
                saved: _saved,
                onBack: () => context.pop(),
                onSaveToggle: () {
                  setState(() => _saved = !_saved);
                  if (_saved) _showSavedToast();
                },
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: productAsync.maybeWhen(
        data: (product) => product == null
            ? null
            : _BottomActionBar(
                quantity: _quantity,
                onDecrement: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                onIncrement: () => setState(() => _quantity++),
                addedToCart: _addedToCart,
                onAddToCart: () => setState(() => _addedToCart = true),
              ),
        orElse: () => null,
      ),
    );
  }
}

/// The full-bleed hero image (Figma "Media / Content", node 205:2290).
class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.product});

  final Product product;

  static const double _height = 378;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: product.imageUrl == null
          ? const ColoredBox(color: AppColors.blackAlpha10)
          : CachedNetworkImage(
              imageUrl: product.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const ColoredBox(color: AppColors.blackAlpha10),
              errorWidget: (context, url, error) =>
                  const ColoredBox(color: AppColors.blackAlpha10),
            ),
    );
  }
}

/// Back button + save/report icon overlaid on the hero image (Figma "Title
/// and Controls", node 173:3117).
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.saved,
    required this.onBack,
    required this.onSaveToggle,
  });

  final bool saved;
  final VoidCallback onBack;
  final VoidCallback onSaveToggle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _IconCircle(icon: Icons.chevron_left, onTap: onBack),
            _IconCircle(
              icon: saved ? Icons.bookmark : Icons.bookmark_border,
              onTap: onSaveToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white100,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Icon(icon, color: AppColors.neutral1100, size: 24),
        ),
      ),
    );
  }
}

/// Price ("30$", one-off 28px size not on the shared scale — Figma's own
/// value, kept literal like other components' intrinsic one-offs) + color
/// swatches + "in stock" (Figma nodes 205:2448 / 177:2095).
class _PriceAndStockRow extends StatelessWidget {
  const _PriceAndStockRow({required this.product});

  final Product product;

  static const double _priceFontSize = 28;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.priceLabel,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: _priceFontSize,
            height: 20 / _priceFontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.neutral1000,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (product.colorOptions.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final color in product.colorOptions) ...[
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.neutral300),
                      ),
                    ),
                    if (color != product.colorOptions.last)
                      const SizedBox(width: AppSpacing.xs),
                  ],
                ],
              )
            else
              const SizedBox.shrink(),
            Text(
              product.inStock ? 'in stock' : 'out of stock',
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeXl,
                height: AppTypography.lineHeightBase,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.43,
                color: product.inStock
                    ? AppColors.success400
                    : AppColors.error400,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Store avatar + name row (Figma node 205:2282, annotated "will take you to
/// Store page" — not wired since this build is user-scope only, see
/// project scoping).
class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.product});

  final Product product;

  static const double _avatarSize = 24;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: SizedBox(
            width: _avatarSize,
            height: _avatarSize,
            child: product.storeAvatarUrl == null
                ? const ColoredBox(color: AppColors.neutral200)
                : CachedNetworkImage(
                    imageUrl: product.storeAvatarUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const ColoredBox(color: AppColors.neutral200),
                    errorWidget: (context, url, error) =>
                        const ColoredBox(color: AppColors.neutral200),
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          product.storeName,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeBase,
            height: AppTypography.lineHeightBase,
            fontWeight: FontWeight.w500,
            color: AppColors.neutral1000,
          ),
        ),
      ],
    );
  }
}

/// Title (Figma renders this in [AppColors.primary400], node 173:3173) +
/// description (node 177:2115).
class _TitleAndDescription extends StatelessWidget {
  const _TitleAndDescription({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.title,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeLg,
            height: AppTypography.lineHeightBase,
            fontWeight: FontWeight.w700,
            color: AppColors.primary400,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          product.description,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeBase,
            height: AppTypography.lineHeightBase,
            fontWeight: FontWeight.w500,
            color: AppColors.neutral1000,
          ),
        ),
      ],
    );
  }
}

/// "Sizes available" / "Pick the right one" + [SizeSelector] (Figma node
/// 187:2977).
class _SizesSection extends StatelessWidget {
  const _SizesSection({
    required this.sizes,
    required this.selected,
    required this.onChanged,
  });

  final List<String> sizes;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sizes available',
          style: TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeLg,
            height: AppTypography.lineHeightBase,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.43,
            color: AppColors.neutral1100,
          ),
        ),
        const Text(
          'Pick the right one',
          style: TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeSm,
            height: AppTypography.lineHeightXs,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizeSelector(sizes: sizes, selected: selected, onChanged: onChanged),
      ],
    );
  }
}

/// "Store commitments" (Figma node 199:169): 4 static [InfoRow]s. Figma's
/// glyphs (delivery truck, verified badge, u-turn/refund, coin-in-hand) are
/// mapped to the semantically-closest entries in the shared [AppIconGlyph]
/// registry, same reasoning already used elsewhere for icons the formal
/// icon set doesn't cover 1:1.
class _StoreCommitmentsSection extends StatelessWidget {
  const _StoreCommitmentsSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Store commitments',
          style: TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeLg,
            height: AppTypography.lineHeightBase,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.43,
            color: AppColors.neutral1000,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        InfoRow(icon: AppIconGlyph.delivery, text: 'Fast delivery in 1-2 days'),
        SizedBox(height: AppSpacing.sm),
        InfoRow(
          icon: AppIconGlyph.verifiedBadge,
          text: '100% authentic product',
        ),
        SizedBox(height: AppSpacing.sm),
        InfoRow(icon: AppIconGlyph.timer, text: 'Refund period 14 days'),
        SizedBox(height: AppSpacing.sm),
        InfoRow(icon: AppIconGlyph.cart, text: 'Hand to hand payment'),
      ],
    );
  }
}

/// A titled row with a trailing chevron that opens a detail sheet on tap
/// (Figma "Product details"/"Refund policy" rows, nodes 203:189 / 205:2450).
class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamilyBody,
              fontSize: AppTypography.sizeLg,
              height: AppTypography.lineHeightBase,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.43,
              color: AppColors.neutral1000,
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 16,
            color: AppColors.neutral1000,
          ),
        ],
      ),
    );
  }
}

/// Opens the "Product details" bottom sheet (Figma "Sheet - iPhone", node
/// 205:2431): same spec table shown inline on the screen, presented full
/// screen-width in a modal sheet. Figma repeats the "Size" row 5 times in
/// this sheet (a hand-duplicated artifact, same kind already seen elsewhere
/// in this file — e.g. Home's repeated "Makeup" category), so it's shown
/// once here like the inline table.
Future<void> showProductDetailsSheet(
  BuildContext context, {
  required String sizesLabel,
}) {
  return _showDetailSheet(
    context,
    title: 'Product details',
    child: SpecTable(
      rows: [
        ('Material', '100% Cotton'),
        ('Fit type', 'Loose Fit'),
        ('Size', sizesLabel),
      ],
    ),
  );
}

/// Opens the "Refund policy" bottom sheet (Figma "Sheet - iPhone", node
/// 205:2487): an intro line plus two return-method rows (in-store/home),
/// each with a "FREE" badge and a description.
Future<void> showRefundPolicySheet(BuildContext context) {
  return _showDetailSheet(
    context,
    title: 'Refund policy',
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You have 30 days from the date of shipment of the order.',
          style: TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeXs,
            height: AppTypography.lineHeightXs,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral1100,
          ),
        ),
        SizedBox(height: AppSpacing.base),
        _RefundMethodRow(
          label: 'In-store return',
          description:
              'You can return a product at one of our stores located in '
              'the country where you made your purchase.',
        ),
        SizedBox(height: AppSpacing.base),
        _RefundMethodRow(
          label: 'Home return',
          description:
              'You can request a product return via a carrier pickup by '
              'visiting the "My Account" section on our website and '
              'selecting "Home Return."',
        ),
      ],
    ),
  );
}

/// Shared "Sheet - iPhone" chrome (Figma nodes 205:2431 / 205:2487): a
/// rounded-top modal with a title row and an [AppIconGlyph.close] button.
/// The iOS home-indicator bar Figma bakes into the sheet frame is OS chrome,
/// not app UI — omitted here in favor of [SafeArea], same reasoning already
/// applied to [AppBottomNavBar].
Future<void> _showDetailSheet(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white100,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.base,
          AppSpacing.base,
          AppSpacing.base,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamilyBody,
                    fontSize: AppTypography.sizeXl,
                    height: AppTypography.lineHeightBase,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.45,
                    color: AppColors.neutral1100,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(sheetContext).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: const AppIcon(
                    AppIconGlyph.close,
                    size: 24,
                    color: AppColors.neutral1100,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    ),
  );
}

/// One "In-store return"/"Home return" row inside [showRefundPolicySheet]:
/// a label + green "FREE" badge, with a gray description underneath.
class _RefundMethodRow extends StatelessWidget {
  const _RefundMethodRow({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeXs,
                height: AppTypography.lineHeightXs,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral1100,
              ),
            ),
            const Text(
              'FREE',
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeXs,
                height: AppTypography.lineHeightXs,
                fontWeight: FontWeight.w600,
                color: AppColors.success400,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          description,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeXs,
            height: AppTypography.lineHeightXs,
            fontWeight: FontWeight.w400,
            color: AppColors.neutral500,
          ),
        ),
      ],
    );
  }
}

/// "Recommended store products" (Figma node 205:2588): a 3-column preview
/// grid, then "More to see" + a wrap of full [ProductCard]s.
class _RecommendedSection extends ConsumerWidget {
  const _RecommendedSection({required this.excludeProductId});

  final String excludeProductId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (products) {
        final recommended = products
            .where((p) => p.id != excludeProductId)
            .toList();
        if (recommended.isEmpty) return const SizedBox.shrink();

        final preview = recommended.take(6).toList();
        final more = recommended.skip(6).take(8).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommended store products',
              style: TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeLg,
                height: AppTypography.lineHeightBase,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.43,
                color: AppColors.neutral1000,
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Wrap(
              spacing: AppSpacing.base,
              runSpacing: AppSpacing.base,
              children: [
                for (final product in preview)
                  _MiniProductTile(product: product),
              ],
            ),
            if (more.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.base),
              const SizedBox(
                width: double.infinity,
                child: Text(
                  'More to see',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamilyBody,
                    fontSize: AppTypography.sizeSm,
                    height: AppTypography.lineHeightXs,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.43,
                    color: AppColors.neutral500,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              // 2-up grid: [ProductCardSize.big]'s fixed 172.5 width times 2
              // plus the AppSpacing.base gap exactly fills this screen's
              // content width (393 - 2*16 padding = 361), so a plain [Wrap]
              // lays them out edge-to-edge with no leftover side margins.
              Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: [
                  for (final product in more)
                    ProductCard(
                      title: product.title,
                      price: product.priceLabel,
                      storeName: product.storeName,
                      storeAvatarUrl: product.storeAvatarUrl,
                      imageUrl: product.imageUrl,
                      colorOptions: product.colorOptions
                          .map(Color.new)
                          .toList(),
                      onTap: () => context.push('/product/${product.id}'),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A bare image+price tile (Figma node 214:562 etc) — not a formally
/// published Figma component (just a hand-duplicated frame), so it's kept
/// private to this screen rather than promoted to a shared widget.
class _MiniProductTile extends StatelessWidget {
  const _MiniProductTile({required this.product});

  final Product product;

  static const double _size = 99;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/product/${product.id}'),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: _size,
                height: 95,
                child: product.imageUrl == null
                    ? const ColoredBox(color: AppColors.blackAlpha10)
                    : CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const ColoredBox(color: AppColors.blackAlpha10),
                        errorWidget: (context, url, error) =>
                            const ColoredBox(color: AppColors.blackAlpha10),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              product.priceLabel,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeBase,
                height: AppTypography.lineHeightBase,
                fontWeight: FontWeight.w500,
                color: AppColors.neutral1100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed footer (Figma node 205:2579): quantity stepper, [AddToCartToggle],
/// and Chat now / Buy now [AppButton]s. "Chat now" isn't wired to a real
/// destination — this build is user-scope only (no seller-side messaging
/// screen exists yet), shown for fidelity but inert, same reasoning already
/// applied to Home's "Become a seller" button.
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    required this.addedToCart,
    required this.onAddToCart,
  });

  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;
  final bool addedToCart;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white100,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.sm,
          ),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.neutral200),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Quantity',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamilyDisplay,
                      fontSize: AppTypography.sizeBase,
                      height: AppTypography.lineHeightBase,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.43,
                      color: AppColors.neutral1100,
                    ),
                  ),
                  Row(
                    children: [
                      _QuantityButton(label: '-', onTap: onDecrement),
                      const SizedBox(width: AppSpacing.base),
                      Text(
                        '$quantity',
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamilyBody,
                          fontSize: AppTypography.sizeXl,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral1100,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.base),
                      _QuantityButton(label: '+', onTap: onIncrement),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AddToCartToggle(added: addedToCart, onTap: onAddToCart),
                  Row(
                    children: [
                      AppButton(
                        label: 'Chat now',
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: () {},
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppButton(
                        label: 'Buy now',
                        size: AppButtonSize.small,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeXl,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral1100,
          ),
        ),
      ),
    );
  }
}
