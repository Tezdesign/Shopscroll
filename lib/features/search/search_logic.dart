import '../../data/models/product.dart';
import '../../data/models/user_profile.dart';

/// A phrase suggestion shown on the Items tab while typing (spec 0006,
/// AC-5): the phrase itself, plus the category of the first product that
/// produced it.
typedef Suggestion = ({String text, String category});

/// A category and how many of the loaded products belong to it. Backs both
/// the "Popular categories" row (AC-3) and the suggestion category chips
/// (AC-4).
typedef CategoryCount = ({String category, int count});

/// A product matches [phrase] when its title, store name or category
/// contains it, ignoring case and surrounding spaces (AC-7). A blank
/// phrase matches nothing — callers only call this once there is real
/// typed text.
bool matchesPhrase(Product product, String phrase) {
  final needle = phrase.trim().toLowerCase();
  if (needle.isEmpty) return false;
  return product.title.toLowerCase().contains(needle) ||
      product.storeName.toLowerCase().contains(needle) ||
      product.category.toLowerCase().contains(needle);
}

/// Categories present in [products], ordered by how many products each
/// has, then alphabetically (AC-3).
List<CategoryCount> popularCategories(List<Product> products) {
  final counts = <String, int>{};
  for (final product in products) {
    counts[product.category] = (counts[product.category] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return [for (final entry in entries) (category: entry.key, count: entry.value)];
}

/// The categories of the products that match [query] (AC-4's category
/// chips), same ordering as [popularCategories].
List<CategoryCount> categoriesMatching(List<Product> products, String query) {
  final matching = products.where((p) => matchesPhrase(p, query)).toList();
  return popularCategories(matching);
}

class _PhraseEntry {
  _PhraseEntry(this.text, this.category) : count = 1;
  final String text;
  final String category;
  int count;
}

/// Up to 8 suggestions for [query] (AC-5): for each matching product, the
/// first title word starting with [query] plus up to 2 following words,
/// deduplicated ignoring case and ranked by how many products produced
/// each one, then alphabetically. Falls back to up to 8 distinct matching
/// titles when no title word starts with [query] (a store name or
/// category only match).
List<Suggestion> suggestionsFor(List<Product> products, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];

  final matching = products.where((p) => matchesPhrase(p, needle)).toList();
  final phrases = <String, _PhraseEntry>{};

  for (final product in matching) {
    final words = product.title.split(RegExp(r'\s+'));
    final startIndex = words.indexWhere(
      (word) => word.toLowerCase().startsWith(needle),
    );
    if (startIndex == -1) continue;

    final phrase = words.skip(startIndex).take(3).join(' ');
    final key = phrase.toLowerCase();
    final existing = phrases[key];
    if (existing == null) {
      phrases[key] = _PhraseEntry(phrase, product.category);
    } else {
      existing.count++;
    }
  }

  if (phrases.isEmpty) {
    final seenTitles = <String>{};
    final fallback = <Suggestion>[];
    for (final product in matching) {
      if (!seenTitles.add(product.title.toLowerCase())) continue;
      fallback.add((text: product.title, category: product.category));
      if (fallback.length == 8) break;
    }
    return fallback;
  }

  final ranked = phrases.values.toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0
          ? byCount
          : a.text.toLowerCase().compareTo(b.text.toLowerCase());
    });

  return [
    for (final entry in ranked.take(8)) (text: entry.text, category: entry.category),
  ];
}

/// Sellers whose name contains [query], ignoring case (AC-9). Empty for a
/// blank query — the Stores tab isn't reachable with nothing typed.
List<UserProfile> storesMatching(List<UserProfile> sellers, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  return sellers.where((s) => s.name.toLowerCase().contains(needle)).toList();
}

/// The results view's product list (AC-7, AC-9): either every product from
/// [storeId] (the Stores tab path, ignoring [phrase]), or every product
/// matching [phrase], further narrowed to [category] and, when
/// [dealsOnly], to deals. Keeps the source list's own order.
List<Product> resultsFor(
  List<Product> products, {
  String? phrase,
  String? category,
  String? storeId,
  bool dealsOnly = false,
}) {
  return products.where((product) {
    if (storeId != null) {
      if (product.storeId != storeId) return false;
    } else if (phrase != null) {
      if (!matchesPhrase(product, phrase)) return false;
    }
    if (category != null && product.category != category) return false;
    if (dealsOnly && !product.isDeal) return false;
    return true;
  }).toList();
}
