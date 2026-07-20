import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../data/models/user_profile.dart';
import '../../data/providers/product_providers.dart';
import '../../data/providers/user_profile_providers.dart';
import '../../shared/widgets/most_visited_item.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/segmented_tabs.dart';

/// Reproduces the Figma "Discover" screen ("The design - user" page, node
/// 228:3114): a search field, a category tab row, a grid of stores, and a
/// product feed with promotional banners mixed in. Full build spec and
/// acceptance criteria: `docs/specs/0001-discover-screen.md`.
///
/// Deviations from the source design (each decided in spec 0001, not
/// improvised here):
/// - The category row reads "For you, Fashion, Tech, Sports, Makeup", the
///   same real categories [HomeScreen]'s tabs use, rather than Figma's
///   literal "For you, Sports, Makeup, Makeup, Makeup, Makeup" — the
///   repeated "Makeup" is the same stray duplicate layer artifact already
///   normalized on Home.
/// - The store grid shows exactly the 5 sellers this app mocks, laid out
///   as a grid (matching Figma's own layout for this section, a real
///   difference from Home's horizontal "Most visited stores" scroll), not
///   Figma's 12 generic placeholder brand logos plus a "View all" tile
///   that has nowhere real to go.
/// - The promotional banners get real copy in the same static,
///   non-provider-backed style as Home's campaign banner, rather than
///   Figma's literal placeholder text ("Insert Campaign Title", lorem
///   ipsum). Figma actually lays out 3 banner instances (one after the
///   first product row, two side by side at the end); this reproduces all
///   3 positions, correcting spec 0001's "two banners" count against the
///   real design.
/// - The search field live filters the product feed client side by title
///   or store name; Figma only shows its empty placeholder state.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  static const _categories = ['For you', 'Fashion', 'Tech', 'Sports', 'Makeup'];

  int _activeCategoryIndex = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _applySearch(List<Product> products) {
    if (_searchQuery.isEmpty) return products;
    return products
        .where(
          (p) =>
              p.title.toLowerCase().contains(_searchQuery) ||
              p.storeName.toLowerCase().contains(_searchQuery),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final category = _categories[_activeCategoryIndex];
    final productsAsync = category == 'For you'
        ? ref.watch(productsProvider)
        : ref.watch(productsByCategoryProvider(category));
    final sellersAsync = ref.watch(sellersProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: SearchField(
                controller: _searchController,
                onChanged: (value) => setState(
                  () => _searchQuery = value.trim().toLowerCase(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: SegmentedTabs(
                labels: _categories,
                activeIndex: _activeCategoryIndex,
                onChanged: (index) =>
                    setState(() => _activeCategoryIndex = index),
                fontSize: AppTypography.sizeSm,
                bottomPadding: AppSpacing.sm,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                children: [
                  _StoreGridSection(sellersAsync: sellersAsync),
                  const SizedBox(height: AppSpacing.lg),
                  _ProductFeed(
                    productsAsync: productsAsync,
                    applySearch: _applySearch,
                    searchActive: _searchQuery.isNotEmpty,
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

/// The store grid (Figma "Frame 231", node 228:3144): every mocked seller
/// (see this file's class doc for why this is a grid of the 5 real
/// sellers, not Figma's 12 placeholder logos).
class _StoreGridSection extends StatelessWidget {
  const _StoreGridSection({required this.sellersAsync});

  final AsyncValue<List<UserProfile>> sellersAsync;

  // Figma's horizontal gap here (32) doesn't land on a shared spacing
  // token (closest neighbors are base=16 and xl=24), so it's kept local,
  // consistent with other components' intrinsic one-off values. The
  // vertical gap (16) does land on a token (AppSpacing.base).
  static const double _tileGap = 32;

  @override
  Widget build(BuildContext context) {
    return sellersAsync.when(
      loading: () => const _SectionLoading(height: 178),
      error: (error, stackTrace) => const _SectionError(),
      data: (sellers) {
        if (sellers.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Wrap(
            spacing: _tileGap,
            runSpacing: AppSpacing.base,
            children: [
              for (final seller in sellers)
                SizedBox(
                  width: 56,
                  child: MostVisitedItem(
                    storeName: seller.name,
                    iconUrl: seller.avatarUrl,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The product feed (Figma "Frame 222", node 717:4056): a 2 column grid of
/// [ProductCard] tiles with 3 static promotional banners mixed in, matching
/// Figma's real layout (see this file's class doc).
class _ProductFeed extends StatelessWidget {
  const _ProductFeed({
    required this.productsAsync,
    required this.applySearch,
    required this.searchActive,
  });

  final AsyncValue<List<Product>> productsAsync;
  final List<Product> Function(List<Product>) applySearch;
  final bool searchActive;

  static const List<_BannerSlide> _banners = [
    (
      dateRange: '1 - 31 Oct 2023',
      title: 'Travel Ready',
      subtitle: 'Pack smarter with weekend luggage and travel essentials.',
      imageUrl: 'https://picsum.photos/seed/discover-travel/800/400',
    ),
    (
      dateRange: '1 - 15 Nov 2023',
      title: 'Weekend Flash Deals',
      subtitle: 'Limited time drops across Fashion, Tech and Sports.',
      imageUrl: 'https://picsum.photos/seed/discover-flash/800/400',
    ),
    (
      dateRange: '20 Nov - 5 Dec 2023',
      title: 'New Arrivals',
      subtitle: "Fresh drops from this week's favorite stores.",
      imageUrl: 'https://picsum.photos/seed/discover-new/800/400',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return productsAsync.when(
      loading: () => const _SectionLoading(height: 480),
      error: (error, stackTrace) => const _SectionError(),
      data: (allProducts) {
        final products = applySearch(allProducts);

        if (products.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.xl,
            ),
            child: Text(
              searchActive
                  ? 'No products match your search.'
                  : 'No products in this category yet.',
              style: const TextStyle(
                fontFamily: AppTypography.fontFamilyBody,
                fontSize: AppTypography.sizeSm,
                color: AppColors.neutral600,
              ),
            ),
          );
        }

        final firstRow = products.take(2).toList();
        final rest = products.skip(2).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProductWrap(products: firstRow),
              const SizedBox(height: AppSpacing.base),
              _PromoBannerTile(slide: _banners[0], height: 96),
              const SizedBox(height: AppSpacing.base),
              if (rest.isNotEmpty) ...[
                _ProductWrap(products: rest),
                const SizedBox(height: AppSpacing.base),
              ],
              Row(
                children: [
                  Expanded(
                    child: _PromoBannerTile(slide: _banners[1], height: 158.56),
                  ),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(
                    child: _PromoBannerTile(slide: _banners[2], height: 158.56),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductWrap extends StatelessWidget {
  const _ProductWrap({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.base,
      children: [
        for (final product in products)
          ProductCard(
            title: product.title,
            price: product.priceLabel,
            storeName: product.storeName,
            storeAvatarUrl: product.storeAvatarUrl,
            imageUrl: product.imageUrl,
            colorOptions: product.colorOptions.map(Color.new).toList(),
            onTap: () => context.push('/product/${product.id}'),
          ),
      ],
    );
  }
}

/// A static promotional slide, same shape as HomeScreen's private
/// campaign banner content, not backed by any provider (see this file's
/// class doc: neither this app nor Home models a "campaigns" entity).
typedef _BannerSlide = ({
  String dateRange,
  String title,
  String subtitle,
  String imageUrl,
});

class _PromoBannerTile extends StatelessWidget {
  const _PromoBannerTile({required this.slide, required this.height});

  final _BannerSlide slide;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: slide.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const ColoredBox(color: AppColors.neutral1000),
              errorWidget: (context, url, error) =>
                  const ColoredBox(color: AppColors.neutral1000),
            ),
            Container(
              color: AppColors.neutral1100.withValues(alpha: 0.45),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white100.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      slide.dateRange.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamilyBody,
                        fontSize: AppTypography.sizeXs,
                        height: AppTypography.lineHeightXs,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white100,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamilyBody,
                      fontSize: AppTypography.sizeBase,
                      height: AppTypography.lineHeightSm,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white100,
                    ),
                  ),
                  Text(
                    slide.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamilyBody,
                      fontSize: AppTypography.sizeXs,
                      height: AppTypography.lineHeightXs,
                      fontWeight: FontWeight.w400,
                      color: AppColors.white100,
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
}

/// Loading placeholder for a section on this screen — same reasoning as
/// Home's own loading rows: Figma's mockup is static and doesn't define
/// skeleton art, so this uses a centered spinner sized to roughly match
/// the section's real content height, to minimize layout shift.
class _SectionLoading extends StatelessWidget {
  const _SectionLoading({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: AppSpacing.xl,
          height: AppSpacing.xl,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.lg,
      ),
      child: Text(
        "Couldn't load this section.",
        style: TextStyle(
          fontFamily: AppTypography.fontFamilyBody,
          fontSize: AppTypography.sizeSm,
          color: AppColors.neutral600,
        ),
      ),
    );
  }
}
