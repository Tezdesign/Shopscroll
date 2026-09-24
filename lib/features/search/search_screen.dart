import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../data/models/user_profile.dart';
import '../../data/providers/product_providers.dart';
import '../../data/providers/user_profile_providers.dart';
import '../../shared/widgets/category_chip.dart';
import '../../shared/widgets/most_visited_item.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/segmented_tabs.dart';
import 'search_logic.dart';

/// Reproduces the Figma search flow ("ShopScroll-UI" file `toOakybJ0DaJmU7vcEC0AW`,
/// frames 968:8943 / 968:9652 / 968:9953 / 972:6472 / 972:6576): a full
/// build spec and its acceptance criteria live in
/// `docs/specs/0006-search-flow/index.md`. Registered under both the Home and
/// Discover branches ([AppRouter]'s `/search` and `/discover/search`), so
/// the bottom tab bar keeps whichever tab it was opened from highlighted.
///
/// Everything here runs in memory over [productsProvider] and
/// [sellersProvider] (AC-13) — no repository method exists for search.
/// State (typed text, phase, tab, filters, the local "added" set) lives
/// only in this widget and is never persisted (AC-11).
///
/// Deviations from the Figma frames (spec 0006's "Deviations" section):
/// tab labels are "Items"/"Stores" not "stores"; the field shows the
/// chosen phrase, not a shorter version than the heading; Popular
/// categories and the store grid use the app's real categories/sellers,
/// not Figma's placeholders; the results view's filter button isn't built
/// (no filter sheet is designed yet); the tab bar highlights the tab you
/// came from, not always Home. Popular category tiles are plain tinted
/// tiles (no exported photos — a deliberate scope cut, revisit per the
/// spec's Follow-up list).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

enum _Phase { empty, suggesting, results }

enum _Tab { items, stores }

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _addedProductIds = <String>{};

  _Phase _phase = _Phase.empty;
  _Tab _tab = _Tab.items;

  // The results view's own state: what to show it for, and its filters.
  String? _resultsPhrase;
  String? _resultsCategory;
  String? _resultsStoreId;
  String _resultsHeading = '';
  bool _dealsOnly = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Entering the results view sets the field's text to the chosen
    // phrase, which re-fires this callback (see class doc for why the
    // field and phase logic live in the same controller). Ignore that
    // self-triggered call so it isn't mistaken for an edit (AC-11).
    if (_phase == _Phase.results && value == _resultsPhrase) return;

    setState(() {
      _phase = value.trim().isEmpty ? _Phase.empty : _Phase.suggesting;
      if (_phase == _Phase.empty) _tab = _Tab.items;
    });
  }

  void _onSubmitted(String value) {
    final phrase = value.trim();
    if (phrase.isEmpty) return;
    _openResults(phrase: phrase, heading: phrase);
  }

  void _openResults({
    required String heading,
    String? phrase,
    String? category,
    String? storeId,
  }) {
    setState(() {
      _resultsPhrase = phrase;
      _resultsCategory = category;
      _resultsStoreId = storeId;
      _resultsHeading = heading;
      _dealsOnly = false;
      _phase = _Phase.results;
      _controller.text = heading;
      _controller.selection = TextSelection.collapsed(offset: heading.length);
    });
  }

  void _cancel() => context.pop();

  void _setTab(_Tab tab) => setState(() => _tab = tab);

  void _setDealsOnly(bool value) => setState(() => _dealsOnly = value);

  void _toggleAdded(String productId) => setState(() {
    if (!_addedProductIds.remove(productId)) _addedProductIds.add(productId);
  });

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
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
              child: Row(
                children: [
                  Expanded(
                    child: SearchField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onChanged,
                      onSubmitted: _onSubmitted,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _CancelButton(onTap: _cancel),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Expanded(
              child: productsAsync.isLoading || sellersAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : productsAsync.hasError || sellersAsync.hasError
                  ? const _Message("Couldn't load search results.")
                  : _phaseBody(productsAsync.requireValue, sellersAsync.requireValue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phaseBody(List<Product> products, List<UserProfile> sellers) {
    switch (_phase) {
      case _Phase.empty:
        return _EmptyView(
          products: products,
          onCategoryTap: (category) =>
              _openResults(heading: category, category: category),
        );
      case _Phase.suggesting:
        return _SuggestingView(
          query: _controller.text,
          tab: _tab,
          products: products,
          sellers: sellers,
          onTabChanged: _setTab,
          onSuggestionTap: (suggestion) => _openResults(
            heading: suggestion.text,
            phrase: suggestion.text,
          ),
          onCategoryChipTap: (category) => _openResults(
            heading: _controller.text.trim(),
            phrase: _controller.text.trim(),
            category: category,
          ),
          onStoreTap: (store) =>
              _openResults(heading: store.name, storeId: store.id),
        );
      case _Phase.results:
        return _ResultsView(
          heading: _resultsHeading,
          dealsOnly: _dealsOnly,
          onDealsToggled: _setDealsOnly,
          products: resultsFor(
            products,
            phrase: _resultsPhrase,
            category: _resultsCategory,
            storeId: _resultsStoreId,
            dealsOnly: _dealsOnly,
          ),
          addedProductIds: _addedProductIds,
          onAddToCartTap: _toggleAdded,
        );
    }
  }
}

/// Nothing typed yet (AC-3): one tile per category found in the loaded
/// products, ordered by how many products each has, then by name.
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.products, required this.onCategoryTap});

  final List<Product> products;
  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final categories = popularCategories(products);
    if (categories.isEmpty) {
      return const _Message('No categories to show yet.');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      children: [
        const Text(
          'Popular categories',
          style: TextStyle(
            fontFamily: AppTypography.fontFamilyDisplay,
            fontSize: AppTypography.sizeLg,
            height: AppTypography.lineHeightSm,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral1000,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Wrap(
          spacing: AppSpacing.base,
          runSpacing: AppSpacing.base,
          children: [
            for (final entry in categories)
              _CategoryTile(
                label: entry.category,
                onTap: () => onCategoryTap(entry.category),
              ),
          ],
        ),
      ],
    );
  }
}

/// Text typed, before the results view: the Items/Stores tabs (AC-4,
/// AC-9).
class _SuggestingView extends StatelessWidget {
  const _SuggestingView({
    required this.query,
    required this.tab,
    required this.products,
    required this.sellers,
    required this.onTabChanged,
    required this.onSuggestionTap,
    required this.onCategoryChipTap,
    required this.onStoreTap,
  });

  final String query;
  final _Tab tab;
  final List<Product> products;
  final List<UserProfile> sellers;
  final ValueChanged<_Tab> onTabChanged;
  final ValueChanged<Suggestion> onSuggestionTap;
  final ValueChanged<String> onCategoryChipTap;
  final ValueChanged<UserProfile> onStoreTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: SegmentedTabs(
            labels: const ['Items', 'Stores'],
            activeIndex: tab.index,
            onChanged: (index) => onTabChanged(_Tab.values[index]),
            distribution: SegmentedTabsDistribution.spaceBetween,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Expanded(
          child: tab == _Tab.items
              ? _ItemsTab(
                  query: query,
                  products: products,
                  onSuggestionTap: onSuggestionTap,
                  onCategoryChipTap: onCategoryChipTap,
                )
              : _StoresTab(
                  query: query,
                  sellers: sellers,
                  onStoreTap: onStoreTap,
                ),
        ),
      ],
    );
  }
}

class _ItemsTab extends StatelessWidget {
  const _ItemsTab({
    required this.query,
    required this.products,
    required this.onSuggestionTap,
    required this.onCategoryChipTap,
  });

  final String query;
  final List<Product> products;
  final ValueChanged<Suggestion> onSuggestionTap;
  final ValueChanged<String> onCategoryChipTap;

  @override
  Widget build(BuildContext context) {
    final categories = categoriesMatching(products, query);
    final suggestions = suggestionsFor(products, query);

    if (suggestions.isEmpty) {
      return _Message('No results found for "$query"');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      children: [
        if (categories.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final entry in categories)
                CategoryChip(
                  label: entry.category,
                  onTap: () => onCategoryChipTap(entry.category),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
        ],
        for (final suggestion in suggestions)
          _SuggestionRow(
            suggestion: suggestion,
            boldPrefixLength: query.trim().length,
            onTap: () => onSuggestionTap(suggestion),
          ),
      ],
    );
  }
}

class _StoresTab extends StatelessWidget {
  const _StoresTab({
    required this.query,
    required this.sellers,
    required this.onStoreTap,
  });

  final String query;
  final List<UserProfile> sellers;
  final ValueChanged<UserProfile> onStoreTap;

  @override
  Widget build(BuildContext context) {
    final matches = storesMatching(sellers, query);
    if (matches.isEmpty) {
      return _Message('No results found for "$query"');
    }

    return GridView.count(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      crossAxisCount: 4,
      mainAxisSpacing: AppSpacing.base,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.75,
      children: [
        for (final store in matches)
          MostVisitedItem(
            storeName: store.name,
            iconUrl: store.avatarUrl,
            onTap: () => onStoreTap(store),
          ),
      ],
    );
  }
}

/// The results view (AC-7, AC-8, AC-9): a heading, a Deals filter chip,
/// and the matching product rows.
class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.heading,
    required this.dealsOnly,
    required this.onDealsToggled,
    required this.products,
    required this.addedProductIds,
    required this.onAddToCartTap,
  });

  final String heading;
  final bool dealsOnly;
  final ValueChanged<bool> onDealsToggled;
  final List<Product> products;
  final Set<String> addedProductIds;
  final ValueChanged<String> onAddToCartTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Text(
            'Results for "$heading"',
            style: const TextStyle(
              fontFamily: AppTypography.fontFamilyDisplay,
              fontSize: AppTypography.sizeLg,
              height: AppTypography.lineHeightSm,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral1000,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: CategoryChip(
            label: 'Deals',
            icon: Icons.local_offer_outlined,
            selected: dealsOnly,
            onTap: () => onDealsToggled(!dealsOnly),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Expanded(
          child: products.isEmpty
              ? _Message('No results found for "$heading"')
              : ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                  ),
                  children: [
                    for (final product in products)
                      _ResultRow(
                        product: product,
                        added: addedProductIds.contains(product.id),
                        onTap: () => context.push('/product/${product.id}'),
                        onAddToCartTap: () => onAddToCartTap(product.id),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// One tile in the "Popular categories" row. Always a plain tinted tile —
/// this build ships without exported category photos (spec 0006's "no
/// photo" fallback, used unconditionally rather than adding an
/// `assets/search/` image set).
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const double _size = 76;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: _size,
          height: _size,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamilyBody,
              fontSize: AppTypography.sizeSm,
              height: AppTypography.lineHeightSm,
              fontWeight: FontWeight.w600,
              color: AppColors.primary600,
            ),
          ),
        ),
      ),
    );
  }
}

/// One suggestion row (AC-5): the typed prefix in bold, the rest regular,
/// the producing category on the right.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.suggestion,
    required this.boldPrefixLength,
    required this.onTap,
  });

  final Suggestion suggestion;
  final int boldPrefixLength;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = suggestion.text;
    final prefixLength = boldPrefixLength.clamp(0, text.length);

    return Semantics(
      button: true,
      label: '${suggestion.text}, ${suggestion.category}',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: AppColors.neutral500),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamilyBody,
                        fontSize: AppTypography.sizeSm,
                        height: AppTypography.lineHeightSm,
                        color: AppColors.neutral1100,
                      ),
                      children: [
                        TextSpan(
                          text: text.substring(0, prefixLength),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: text.substring(prefixLength),
                          style: const TextStyle(fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  suggestion.category,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamilyBody,
                    fontSize: AppTypography.sizeXs,
                    color: AppColors.neutral600,
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

/// One result row (AC-8): image, store avatar + name, title, price, and a
/// local add-to-cart toggle (nothing is saved — same limit
/// [AddToCartToggle]'s other use on product detail already has).
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.product,
    required this.added,
    required this.onTap,
    required this.onAddToCartTap,
  });

  final Product product;
  final bool added;
  final VoidCallback onTap;
  final VoidCallback onAddToCartTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${product.title}, ${product.storeName}, ${product.priceLabel}',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: product.imageUrl == null
                        ? const ColoredBox(color: AppColors.neutral200)
                        : CachedNetworkImage(
                            imageUrl: product.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const ColoredBox(color: AppColors.neutral200),
                            errorWidget: (context, url, error) =>
                                const ColoredBox(color: AppColors.neutral200),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (product.storeAvatarUrl != null)
                            ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: product.storeAvatarUrl!,
                                width: 14,
                                height: 14,
                                fit: BoxFit.cover,
                              ),
                            ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            product.storeName,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamilyBody,
                              fontSize: AppTypography.sizeXs,
                              color: AppColors.neutral600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamilyBody,
                          fontSize: AppTypography.sizeSm,
                          fontWeight: FontWeight.w500,
                          color: AppColors.neutral1100,
                        ),
                      ),
                      Text(
                        product.priceLabel,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamilyBody,
                          fontSize: AppTypography.sizeSm,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral1100,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: added ? 'Added to cart' : 'Add to cart',
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      onPressed: onAddToCartTap,
                      icon: Icon(
                        added ? Icons.check_circle : Icons.add_shopping_cart,
                        color: added
                            ? AppColors.success400
                            : AppColors.neutral1000,
                      ),
                    ),
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

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cancel',
      child: SizedBox(
        height: 44,
        child: TextButton(
          onPressed: onTap,
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontFamily: AppTypography.fontFamilyBody,
              fontSize: AppTypography.sizeSm,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral1100,
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamilyBody,
            fontSize: AppTypography.sizeSm,
            color: AppColors.neutral600,
          ),
        ),
      ),
    );
  }
}
