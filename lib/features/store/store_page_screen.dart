import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/user_profile.dart';
import '../../data/providers/product_providers.dart';
import '../../data/providers/reel_providers.dart';
import '../../data/providers/user_profile_providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/segmented_tabs.dart';
import '../activity/list_states.dart';
import '../cart/add_to_cart.dart';

/// A seller's read only storefront, opened at `/store/:id`: the destination
/// for four pre-existing dead taps (Home/Discover's store rows, product
/// detail's store row, the Reels player's store name) plus a promo banner
/// slide with a `storeId`. Full build spec and acceptance criteria:
/// `docs/specs/0010-store-page/index.md`.
///
/// No single Figma frame covers this buyer facing page — the file's only
/// seller-profile-shaped frame (node 74:1498, "For sellers") is the
/// seller's own admin dashboard (revenue/report stat cards, an "edit
/// profile" button, the bottom tab bar kept). This reproduces that frame's
/// profile block layout (avatar, name, follower count, a button row, a
/// Products/Reels tab switcher) but swaps the seller-only pieces for the
/// buyer facing ones the spec asks for: a back + decorative report bar
/// above it (matching Order Receipt's header), Follow/Message in place of
/// "edit profile", and no revenue/report cards.
class StorePageScreen extends ConsumerStatefulWidget {
  const StorePageScreen({super.key, required this.storeId});

  final String storeId;

  @override
  ConsumerState<StorePageScreen> createState() => _StorePageScreenState();
}

class _StorePageScreenState extends ConsumerState<StorePageScreen> {
  int _activeTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final sellerAsync = ref.watch(userProfileByIdProvider(widget.storeId));

    return Scaffold(
      backgroundColor: AppColors.white100,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: sellerAsync.when(
                loading: () => const ListLoading(),
                error: (error, stackTrace) => ListMessage(
                  "Couldn't load this store.",
                  buttonLabel: 'Try again',
                  onPressed: () =>
                      ref.invalidate(userProfileByIdProvider(widget.storeId)),
                ),
                data: (seller) => seller == null
                    ? const ListMessage('Store not found')
                    : _Body(
                        seller: seller,
                        activeTabIndex: _activeTabIndex,
                        onTabChanged: (index) =>
                            setState(() => _activeTabIndex = index),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back + decorative report icon (AC-2), reproducing Order Receipt's header
/// (`order_receipt_screen.dart`'s `_Header`) exactly. No center title here —
/// the seller's name is shown in [_ProfileHeader] below instead of repeated.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Back',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => context.pop(),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: AppIcon(
                      AppIconGlyph.back,
                      color: AppColors.neutral1100,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.base),
              child: Semantics(
                button: true,
                enabled: false,
                label: 'Report this store',
                excludeSemantics: true,
                child: const AppIcon(
                  AppIconGlyph.report,
                  color: AppColors.neutral1100,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.seller,
    required this.activeTabIndex,
    required this.onTabChanged,
  });

  final UserProfile seller;
  final int activeTabIndex;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: _ProfileHeader(seller: seller),
        ),
        if (seller.websiteUrl != null || seller.location != null) ...[
          const SizedBox(height: AppSpacing.base),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: _LinksBlock(seller: seller),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: SegmentedTabs(
            labels: const ['Products', 'Reels'],
            activeIndex: activeTabIndex,
            onChanged: onTabChanged,
            distribution: SegmentedTabsDistribution.equal,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Expanded(
          child: activeTabIndex == 0
              ? _ProductsTab(storeId: seller.id, storeName: seller.name)
              : _ReelsTab(storeId: seller.id, storeName: seller.name),
        ),
      ],
    );
  }
}

/// Avatar, name, abbreviated follower count, and the decorative Follow /
/// Message buttons (AC-2, AC-3), in the layout of Figma node 74:1498's
/// profile block (see this file's class doc).
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.seller});

  final UserProfile seller;

  static const double _avatarSize = 72;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: SizedBox(
            width: _avatarSize,
            height: _avatarSize,
            child: seller.avatarUrl == null
                ? const ColoredBox(color: AppColors.neutral200)
                : CachedNetworkImage(
                    imageUrl: seller.avatarUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const ColoredBox(color: AppColors.neutral200),
                    errorWidget: (context, url, error) =>
                        const ColoredBox(color: AppColors.neutral200),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seller.name,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamilyDisplay,
                      fontSize: AppTypography.sizeLg,
                      height: AppTypography.lineHeightSm,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral1100,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${abbreviatedFollowerCount(seller.followerCount)} '
                    'Followers',
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamilyBody,
                      fontSize: AppTypography.sizeSm,
                      height: AppTypography.lineHeightSm,
                      fontWeight: FontWeight.w400,
                      color: AppColors.neutral700,
                    ),
                  ),
                ],
              ),
            ),
            // Decorative: no follow/social graph or buyer-to-seller chat
            // model exists yet (spec 0010 Follow-up), same "looks real, does
            // nothing" treatment as Reels' own Follow button and product
            // detail's "Chat now".
            AppButton(
              label: 'Follow',
              size: AppButtonSize.small,
              onPressed: () {},
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: 'Message',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}

/// "Go to website" (tappable, opens externally) and the plain-text location
/// row, each hidden when its field is unset (AC-4).
class _LinksBlock extends StatelessWidget {
  const _LinksBlock({required this.seller});

  final UserProfile seller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (seller.websiteUrl != null)
          Semantics(
            button: true,
            label: 'Go to website',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => _openWebsite(seller.websiteUrl!),
              behavior: HitTestBehavior.opaque,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.centerLeft,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      AppIconGlyph.web,
                      size: 18,
                      color: AppColors.primary400,
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      'Go to website',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamilyBody,
                        fontSize: AppTypography.sizeSm,
                        height: AppTypography.lineHeightSm,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (seller.location != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(
                AppIconGlyph.location,
                size: 18,
                color: AppColors.neutral600,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                seller.location!,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamilyBody,
                  fontSize: AppTypography.sizeSm,
                  height: AppTypography.lineHeightSm,
                  fontWeight: FontWeight.w400,
                  color: AppColors.neutral700,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

void _openWebsite(String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// "512K Followers" / "1.2M Followers" / "3 Followers" (AC-2). No existing
/// helper or `intl` dependency in this app to reuse (nothing else shows a
/// follower count), so this is a small local helper.
String abbreviatedFollowerCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).floor()}K';
  return '$count';
}

/// The Products tab (AC-5, AC-6, AC-8, AC-9): a 2 column grid of
/// [ProductCard] tiles scoped to this store, reusing the exact wrap/card
/// pattern `home_screen.dart` and `discover_screen.dart` already use.
class _ProductsTab extends ConsumerWidget {
  const _ProductsTab({required this.storeId, required this.storeName});

  final String storeId;
  final String storeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsByStoreProvider(storeId));

    return productsAsync.when(
      loading: () => const ListLoading(),
      error: (error, stackTrace) => ListMessage(
        "Couldn't load products.",
        buttonLabel: 'Try again',
        onPressed: () => ref.invalidate(productsByStoreProvider(storeId)),
      ),
      data: (products) {
        if (products.isEmpty) {
          return ListMessage("$storeName hasn't listed any products yet.");
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            0,
            AppSpacing.base,
            AppSpacing.xl,
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
                  size: ProductCardSize.medium,
                  colorOptions: product.colorOptions.map(Color.new).toList(),
                  onTap: () => context.push('/product/${product.id}'),
                  onAddToCart: () => addToCart(
                    context,
                    product,
                    successMessage: 'Added to cart',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The Reels tab (AC-5, AC-7, AC-8, AC-9): a 3 column grid of reel
/// thumbnails scoped to this store. No existing reel-grid widget to reuse
/// (the Reels tab elsewhere is a full screen swipeable player, not a grid),
/// so this is a plain [GridView.builder] of thumbnails.
class _ReelsTab extends ConsumerWidget {
  const _ReelsTab({required this.storeId, required this.storeName});

  final String storeId;
  final String storeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reelsAsync = ref.watch(reelsByStoreProvider(storeId));

    return reelsAsync.when(
      loading: () => const ListLoading(),
      error: (error, stackTrace) => ListMessage(
        "Couldn't load reels.",
        buttonLabel: 'Try again',
        onPressed: () => ref.invalidate(reelsByStoreProvider(storeId)),
      ),
      data: (reels) {
        if (reels.isEmpty) {
          return ListMessage("$storeName hasn't posted any reels yet.");
        }

        // The store's own reels, in load order, become the swipe order
        // inside the full screen player (AC-7), matching the
        // `orderedReelIds` already threaded through `/reels/:id`.
        final orderedIds = [for (final reel in reels) reel.id];

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            0,
            AppSpacing.base,
            AppSpacing.xl,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.xs,
            childAspectRatio: 9 / 16,
          ),
          itemCount: reels.length,
          itemBuilder: (context, index) {
            final reel = reels[index];
            return Semantics(
              button: true,
              label: 'Reel: ${reel.caption}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () =>
                    context.push('/reels/${reel.id}', extra: orderedIds),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: CachedNetworkImage(
                    imageUrl: reel.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const ColoredBox(color: AppColors.neutral200),
                    errorWidget: (context, url, error) =>
                        const ColoredBox(color: AppColors.neutral200),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
