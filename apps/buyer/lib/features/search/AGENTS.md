# lib/features/search

The search flow (spec 0006): tapping the search field on Home or Discover opens a full search screen
that works from nothing typed, to suggestions, to a result list, with a Stores tab.

## Files

- `search_screen.dart` (`SearchScreen`): the field, Cancel, the three phases (`empty`, `suggesting`,
  `results`), the Items and Stores tabs, result rows. Screen only widgets stay private in this file.
  All state (typed text, phase, tab, category, Deals switch) is in memory and is
  never saved, so closing the screen always clears it.
- `search_logic.dart`: plain functions with no Flutter code (`matchesPhrase`, `popularCategories`,
  `categoriesMatching`, `suggestionsFor`, `storesMatching`, `resultsFor`). Unit tested in
  `test/features/search/search_logic_test.dart`. Change matching rules here, not in the screen.

## Conventions

- Search runs on the device over `productsProvider` and `sellersProvider`. There is no repository
  method for it, so it behaves the same on the mock and Supabase backends. Do not add one until the
  catalog is too big to load whole.
- One screen, two routes: `/search` is a child of the Home branch's `/` route and `/discover/search`
  a child of the Discover branch's `/discover` route in `app_router.dart`. Being inside the shell keeps
  the bottom tab bar and the highlighted tab; Cancel is a plain `context.pop()`.
- The Home and Discover search fields are read only and only open this screen. Reels keeps its own
  inline filter.
- A category chip in the suggestions view keeps the typed text and adds a category filter. A tile in
  the nothing typed view uses the category name as the phrase. A store tile filters by `storeId`
  instead of by phrase.
- `SearchField` gained `autofocus` for this screen. Entering the results view sets the field text,
  which fires `onChanged` again, so `_onChanged` ignores a value equal to the results phrase.
- The add to cart icon on a result row adds 1 to the saved cart through `addToCart` (see
  `lib/features/cart/AGENTS.md`, spec 0007 AC-12), and shows its added state while the cart holds any line
  of that product. The results view therefore watches `cartItemsProvider`. Its added state is the Figma icon `assets/icons/added_to_cart.svg` (node 976:6586), drawn with
  `flutter_svg`, because no Material glyph matches it.
- Category tiles are plain tinted tiles, not photos (deliberate cut, see spec 0006 Follow-up).

Governing spec: `docs/specs/buyer/0006-search-flow/index.md`.

_Drafted by /sync from the introducing change, worth a quick human pass._
