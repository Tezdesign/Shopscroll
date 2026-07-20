import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../data/models/user_profile.dart';
import '../../data/providers/product_providers.dart';
import '../../data/providers/user_profile_providers.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/most_visited_item.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/product_info_card.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/segmented_tabs.dart';

/// Reproduces the Figma "Home" screen ("The design - user" page, node
/// 791:7454): a dark header (logo/title, notification/cart icons, search),
/// a campaign banner carousel, a category filter, a trending product row,
/// "Most visited stores", "Big deals", and "You may also like" — each
/// section backed by its own Riverpod provider so it can load/error/render
/// independently.
///
/// Figma's category row reads "Explore, Tech, Outfits, Sports, Makeup,
/// Makeup, Makeup" — the trailing "Makeup" repeats are the same kind of
/// stray duplicate-layer artifact already seen elsewhere in this file (see
/// MostVisitedItem/CategoryChip), and "Outfits" is renamed to "Fashion"
/// here to match the mocked product taxonomy (see lib/data/mock).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _categories = ['Explore', 'Fashion', 'Tech', 'Sports', 'Makeup'];

  int _activeCategoryIndex = 0;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = _categories[_activeCategoryIndex];
    final productsAsync = category == 'Explore'
        ? ref.watch(productsProvider)
        : ref.watch(productsByCategoryProvider(category));

    return Scaffold(
      backgroundColor: AppColors.neutral100,
      body: Column(
        children: [
          _HomeHeader(searchController: _searchController),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: AppSpacing.base),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                  ),
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
                _TrendingRow(productsAsync: productsAsync),
                const SizedBox(height: AppSpacing.lg),
                const _MostVisitedSection(),
                const SizedBox(height: AppSpacing.lg),
                const _DealsSection(),
                const SizedBox(height: AppSpacing.lg),
                _RecommendedSection(productsAsync: productsAsync),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The dark header block (Figma "Navigation Bar - iPhone", node 126:13152):
/// logo/title row, search field, and campaign banner, all on the same
/// #222222 background — normalized to [AppColors.neutral1000], the nearest
/// existing token (Figma's own scale doesn't define this exact gray).
/// Extends behind the status bar like the source design, rather than being
/// inset by [SafeArea].
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.searchController});

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.neutral1000,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: _TopBar(),
            ),
            const SizedBox(height: AppSpacing.base),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
              ),
              child: SearchField(controller: searchController),
            ),
            const SizedBox(height: AppSpacing.base),
            const _CampaignBannerCarousel(),
            const SizedBox(height: AppSpacing.base),
          ],
        ),
      ),
    );
  }
}

/// Logo + "Shopscroll" title, a "Become a seller" call-to-action, and
/// notification/cart icons (Figma node 126:13166).
///
/// The logo mark and notification bell aren't part of the formal Icons
/// component set (node 443:2430), so they use the semantically-closest
/// Material icons directly, same reasoning already applied to the bottom
/// nav bar's icons. "Become a seller" doesn't lead anywhere in this
/// user-only build (see project scoping) — shown for fidelity, inert.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.shopping_bag,
          color: AppColors.primary400,
          size: 24,
        ),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(
          child: Text(
            'Shopscroll',
            style: TextStyle(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontSize: AppTypography.sizeLg,
              height: AppTypography.lineHeightSm,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.43,
              color: AppColors.white100,
            ),
          ),
        ),
        const _BecomeASellerButton(),
        const SizedBox(width: AppSpacing.sm),
        const Icon(
          Icons.notifications_outlined,
          color: AppColors.white100,
          size: 24,
        ),
        const SizedBox(width: AppSpacing.sm),
        const AppIcon(
          AppIconGlyph.cart,
          size: 24,
          color: AppColors.white100,
        ),
      ],
    );
  }
}

/// A small filled pill button (Figma node 126:13169) whose 8/8 padding
/// doesn't match any of [AppButton]'s 8 variants (which use 12+ vertical
/// padding), so it's a one-off here rather than forced into that widget.
class _BecomeASellerButton extends StatelessWidget {
  const _BecomeASellerButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primary400,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Text(
        'Become a seller',
        style: TextStyle(
          fontFamily: AppTypography.fontFamilyDisplay,
          fontSize: AppTypography.sizeSm,
          height: AppTypography.lineHeightSm,
          fontWeight: FontWeight.w600,
          color: AppColors.white100,
        ),
      ),
    );
  }
}

/// A promotional carousel (Figma node 130:1885). Not one of the 5 data
/// models this feature was scoped to mock, so its slides are simple static
/// content local to this screen rather than a provider-backed model.
class _CampaignBannerCarousel extends StatefulWidget {
  const _CampaignBannerCarousel();

  @override
  State<_CampaignBannerCarousel> createState() =>
      _CampaignBannerCarouselState();
}

class _CampaignBannerCarouselState extends State<_CampaignBannerCarousel> {
  static const _slides = [
    (
      dateRange: '1 - 31 Oct 2023',
      title: 'Fall Sale Is Here',
      subtitle: 'Up to 40% off on new-season arrivals, storewide.',
      imageUrl: 'https://picsum.photos/seed/banner-fall/800/400',
    ),
    (
      dateRange: '1 - 15 Nov 2023',
      title: 'Tech Week Deals',
      subtitle: 'Save on AirPods, chargers, and more from Apple.',
      imageUrl: 'https://picsum.photos/seed/banner-tech/800/400',
    ),
    (
      dateRange: '20 Nov - 5 Dec 2023',
      title: 'New Sneaker Drops',
      subtitle: 'Fresh Nike arrivals, just in time for winter.',
      imageUrl: 'https://picsum.photos/seed/banner-sneakers/800/400',
    ),
  ];

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const double _height = 96;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: _height,
          child: PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white100.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
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
                              maxLines: 1,
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
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _slides.length; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page
                      ? AppColors.white100
                      : AppColors.white100.withValues(alpha: 0.4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The unlabeled 4-up product row directly under the category tabs (Figma
/// node 130:2141, confusingly named "Product Card" though it's built from
/// [ProductInfoCard] tiles, not [ProductCard]).
class _TrendingRow extends StatelessWidget {
  const _TrendingRow({required this.productsAsync});

  final AsyncValue<List<Product>> productsAsync;

  @override
  Widget build(BuildContext context) {
    return productsAsync.when(
      loading: () => const _HorizontalLoadingRow(height: 265),
      error: (error, stackTrace) => const _SectionError(),
      data: (products) {
        final trending = products.take(4).toList();
        if (trending.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 265,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            itemCount: trending.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.base),
            itemBuilder: (context, index) {
              final product = trending[index];
              return ProductInfoCard(
                storeName: product.storeName,
                description: product.title,
                storeAvatarUrl: product.storeAvatarUrl,
                imageUrl: product.imageUrl,
                onTap: () => context.push('/product/${product.id}'),
              );
            },
          ),
        );
      },
    );
  }
}

/// "Most visited stores" (Figma node 141:2983), backed by [sellersProvider].
class _MostVisitedSection extends ConsumerWidget {
  const _MostVisitedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellersAsync = ref.watch(sellersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: _TwoToneSectionTitle(
            leading: 'Most visited ',
            trailing: 'stores',
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        sellersAsync.when(
          loading: () => const _HorizontalLoadingRow(height: 94),
          error: (error, stackTrace) => const _SectionError(),
          data: (sellers) {
            if (sellers.isEmpty) return const SizedBox.shrink();

            return SizedBox(
              height: 94,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                ),
                itemCount: sellers.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSpacing.lg),
                itemBuilder: (context, index) {
                  final UserProfile seller = sellers[index];
                  return SizedBox(
                    width: 56,
                    child: MostVisitedItem(
                      storeName: seller.name,
                      iconUrl: seller.avatarUrl,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// "Big deals" (Figma node 141:2552), backed by [dealsProductsProvider].
class _DealsSection extends ConsumerWidget {
  const _DealsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealsAsync = ref.watch(dealsProductsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TwoToneSectionTitle(leading: 'Big ', trailing: 'deals'),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.neutral1000,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        dealsAsync.when(
          loading: () => const _HorizontalLoadingRow(height: 274.5),
          error: (error, stackTrace) => const _SectionError(),
          data: (deals) {
            if (deals.isEmpty) return const SizedBox.shrink();

            return SizedBox(
              height: 274.5,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                ),
                itemCount: deals.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSpacing.base),
                itemBuilder: (context, index) {
                  final product = deals[index];
                  return ProductCard(
                    title: product.title,
                    price: product.priceLabel,
                    storeName: product.storeName,
                    storeAvatarUrl: product.storeAvatarUrl,
                    imageUrl: product.imageUrl,
                    size: ProductCardSize.medium,
                    colorOptions: product.colorOptions.map(Color.new).toList(),
                    onTap: () => context.push('/product/${product.id}'),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// "You may also like" (Figma node 141:2690): a 2-column grid fed by the
/// screen's active category selection.
class _RecommendedSection extends StatelessWidget {
  const _RecommendedSection({required this.productsAsync});

  final AsyncValue<List<Product>> productsAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Text(
            'You may also like',
            style: TextStyle(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontSize: AppTypography.sizeLg,
              height: AppTypography.lineHeightSm,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.36,
              color: AppColors.neutral1000,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        productsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => const _SectionError(),
          data: (products) {
            if (products.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                  vertical: AppSpacing.xl,
                ),
                child: Text(
                  'No products in this category yet.',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamilyBody,
                    fontSize: AppTypography.sizeSm,
                    color: AppColors.neutral600,
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
              ),
              child: Wrap(
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
                      colorOptions: product.colorOptions
                          .map(Color.new)
                          .toList(),
                      onTap: () => context.push('/product/${product.id}'),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A two-color section title matching Figma's "Big deals" / "Most visited
/// stores" headers (first phrase in [AppColors.neutral1000], second in
/// [AppColors.primary400]) — a one-off text treatment, not a shared design
/// token, so it's local to this screen.
class _TwoToneSectionTitle extends StatelessWidget {
  const _TwoToneSectionTitle({required this.leading, required this.trailing});

  final String leading;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: AppTypography.fontFamilyDisplay,
          fontSize: AppTypography.sizeLg,
          height: AppTypography.lineHeightSm,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.36,
        ),
        children: [
          TextSpan(text: leading, style: const TextStyle(color: AppColors.neutral1000)),
          TextSpan(text: trailing, style: const TextStyle(color: AppColors.primary400)),
        ],
      ),
    );
  }
}

/// Loading placeholder for a horizontal-scroll section — Figma's mockup is
/// static and doesn't define skeleton art, so this uses a plain centered
/// spinner sized to roughly match the section's real content height, to
/// minimize layout shift once data arrives.
class _HorizontalLoadingRow extends StatelessWidget {
  const _HorizontalLoadingRow({required this.height});

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
