import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shopscroll_shared/theme/app_theme.dart';
import '../../data/providers/saved_providers.dart';
import 'package:shopscroll_shared/widgets/item_card.dart';
import 'package:shopscroll_shared/widgets/pill_tabs.dart';
import 'package:shopscroll_shared/widgets/reel_card.dart';
import 'activity_logic.dart';
import 'list_states.dart';
import 'save_actions.dart';

/// The My collection tab (spec 0008, AC-5, AC-6): a Products and a Reels
/// pill, each listing what the buyer saved, newest saved first. Both lists
/// read the saved notifiers, so a save made anywhere shows here at once.
class CollectionTab extends StatefulWidget {
  const CollectionTab({super.key, required this.query});

  final String query;

  @override
  State<CollectionTab> createState() => _CollectionTabState();
}

class _CollectionTabState extends State<CollectionTab> {
  int _pill = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: PillTabs(
            labels: const ['Products', 'Reels'],
            activeIndex: _pill,
            onChanged: (index) => setState(() => _pill = index),
          ),
        ),
        Expanded(
          child: _pill == 0
              ? _SavedProducts(query: widget.query)
              : _SavedReels(query: widget.query),
        ),
      ],
    );
  }
}

/// One row per saved product, using the saved variant of the item card.
class _SavedProducts extends ConsumerWidget {
  const _SavedProducts({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(savedProductsProvider)
        .when(
          loading: () => const ListLoading(),
          error: (error, stackTrace) => ListMessage(
            "Couldn't load your collection.",
            buttonLabel: 'Try again',
            onPressed: () => ref.invalidate(savedProductsProvider),
          ),
          data: (saved) {
            if (saved.isEmpty) {
              return const ListMessage('No saved products yet');
            }
            final shown = filterSavedProducts(saved, query);
            if (shown.isEmpty) return ListMessage.noResults(query);
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.base),
              itemCount: shown.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.xl),
              itemBuilder: (context, index) {
                final item = shown[index];
                final product = item.product;
                return ItemCard(
                  key: ValueKey(product.id),
                  title: product.title,
                  price: product.priceLabel,
                  storeName: product.storeName,
                  storeAvatarUrl: product.storeAvatarUrl,
                  imageUrl: product.imageUrl,
                  trailing: ItemCardTrailing.saved,
                  onUnsave: () => removeSavedProduct(context, item),
                  onTap: () => context.push('/product/${product.id}'),
                );
              },
            );
          },
        );
  }
}

/// The saved reels in two columns. [ReelCard] is 172.5 wide, so two of them
/// and the gap fill the screen width.
class _SavedReels extends ConsumerWidget {
  const _SavedReels({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(savedReelsProvider)
        .when(
          loading: () => const ListLoading(),
          error: (error, stackTrace) => ListMessage(
            "Couldn't load your collection.",
            buttonLabel: 'Try again',
            onPressed: () => ref.invalidate(savedReelsProvider),
          ),
          data: (saved) {
            if (saved.isEmpty) return const ListMessage('No saved reels yet');
            final shown = filterSavedReels(saved, query);
            if (shown.isEmpty) return ListMessage.noResults(query);
            // The player pages through the available saved reels in this
            // order (AC-6), so it never lands on one that cannot play.
            final playable = [
              for (final s in shown)
                if (s.reel.isAvailable) s.reel.id,
            ];
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: [
                  for (final item in shown)
                    ReelCard(
                      key: ValueKey(item.reel.id),
                      reel: item.reel,
                      saved: true,
                      onSaveTap: () => removeSavedReel(context, item),
                      onTap: () => context.push(
                        '/reels/${item.reel.id}',
                        extra: playable,
                      ),
                    ),
                ],
              ),
            );
          },
        );
  }
}
