# 0006. Build the search flow

**Date**: 2026-09-21
**Status**: In Progress

## Summary

This adds a real search screen to the app. Tapping the search field on Home or Discover opens it, and it walks a person from nothing typed, to suggestions as they type, to a list of results, with a stores tab for finding a seller. It runs entirely on the phone against the products and sellers the app already loads, so it needs no database change. It replaces Discover's live filter (spec 0001, AC-2), and it does not cover the banner screens, which are a separate decision.

Decision history (context, options considered, rationale): [rationale.md](rationale.md). Verify steps: [verify.md](verify.md).

## Requirements

**User stories**:
- As a shopper, I want to tap the search field and get a screen made for searching, so that I can find a product or a store without scrolling through feeds.
- As a shopper, I want suggestions while I type, so that I can reach the right product in fewer taps.
- As a shopper, I want to look up a store by name, so that I can see what it sells.
- As a shopper, I want a clear message when nothing matches, so that I know the search worked and found nothing.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1**: Tapping the search field on Home opens the search screen at `/search`, and tapping it on Discover opens the same screen at `/discover/search`. The keyboard opens at once with an empty field. The bottom tab bar stays visible, with the tab you came from highlighted. The Reels search field is unchanged.
- **AC-2**: Cancel, and the system back gesture, close the screen and return to the tab it came from, with that tab's scroll position and state intact.
- **AC-3**: With nothing typed, or only spaces, the screen shows a "Popular categories" row with one tile per product category found in the loaded products (Fashion, Tech, Sports, Makeup today), ordered by how many products each has, then by name. Tapping a tile opens the results view for that category. A category with no photo shows a plain tinted tile.
- **AC-4**: As soon as one character other than a space is typed, the Items tab is selected and shows two things: category chips for the categories of the products that match, and a list of suggestions. An Items tab and a Stores tab are shown, labelled "Items" and "Stores".
- **AC-5**: Suggestions are built from product titles. For each matching product, find the first word of its title that starts with the typed text (ignoring case). The suggestion is that word and the words after it, up to 3 words in all. Duplicates are merged ignoring case. Each row shows the typed part in bold and the category of the first product that produced it on the right. Rows are ordered by how many products produced them, then alphabetically, and capped at 8. If no title word starts with the typed text but products still match by store name or category, the suggestions are the titles of up to 8 of those products instead.
- **AC-6**: Tapping a suggestion, tapping a category chip or a category tile, or pressing the keyboard Search key opens the results view. The field then shows the chosen phrase, and the heading reads "Results for “<phrase>”". The Search key uses the typed text as the phrase.
- **AC-7**: A product matches a phrase when its title, its store name or its category contains the phrase, ignoring case and surrounding spaces. Results keep the product list's own order. A "Deals" chip in the results view, when selected, keeps only products with `isDeal` true. A selected category chip or tile also limits results to that category.
- **AC-8**: Each result row shows the product image, the store avatar and name, the title and the price. Tapping the row opens `/product/:id`. Tapping the add to cart icon on a row flips it to its added state for the rest of the session. Nothing is saved, and it does not change the cart.
- **AC-9**: The Stores tab shows the sellers whose name contains the typed text, as store tiles in a four column grid. Tapping a tile opens the results view for that store, headed "Results for “<store name>”", listing that store's products by `storeId`. With no typed text the Stores tab is not reachable.
- **AC-10**: When a tab or the results view has nothing to show, it shows "No results found for “<text>”". While products or sellers are loading, the screen shows a loading indicator. If a provider fails, it shows an error message. This is the same pattern as spec 0001, AC-6.
- **AC-11**: Editing the text after the results view is showing returns to the suggestions view for the new text. Clearing the field returns to the nothing typed view. Nothing is remembered: closing and opening the screen again starts blank, and no recent searches are saved.
- **AC-12**: Discover's search field no longer filters its feed. It only opens the search screen. Discover's category tabs, store grid and product feed otherwise behave as before.
- **AC-13**: All searching runs on the device over `productsProvider` and `sellersProvider`. There is no new repository method and no database change, and the screen behaves the same on the mock and the Supabase backends.
- **AC-14**: Every tappable row, chip, tile and the Cancel button has a spoken label and a tap area of at least 44 by 44 logical pixels.

## Decision

**Chosen option**: Option 1: A dedicated search screen inside each tab, searching on the device

Build one `SearchScreen`, registered under both the Home and Discover branches, that finds products and stores in memory from the existing providers, and remove Discover's inline filter.

## Feature design

**Design source**: Figma file `toOakybJ0DaJmU7vcEC0AW`. Frames: 968:8943 (nothing typed), 968:9652 (typing), 968:9953 (stores tab), 972:6472 (no results), 972:6576 (results).

**Data model sketch**: no new tables, columns or models, so there is no migration. The screen reads `Product` (title, category, storeId, storeName, storeAvatarUrl, imageUrl, price, isDeal) and `UserProfile` sellers (id, name, avatarUrl). Screen state is held in memory only: the typed text, the phase, the selected tab, the selected category, the Deals switch, and the set of product ids marked added.

**State transitions**:
- `empty` (no text) → `suggesting` (text typed)
- `suggesting` → `results` (suggestion, chip, tile or Search key)
- `results` → `suggesting` (text edited), or `empty` (field cleared)
- `suggesting` → `results` for a store (store tile tapped on the Stores tab)

**Surface** (routes and files, there is no server API):

| Item | Where | Notes |
|---|---|---|
| Route `/search` | `app_router.dart`, child of the Home branch's `/` route | Builds `SearchScreen` |
| Route `/discover/search` | `app_router.dart`, child of the Discover branch's `/discover` route | Builds the same `SearchScreen` |
| `SearchScreen` | `lib/features/search/search_screen.dart` | Owns the field, tabs and phases |
| Search logic | `lib/features/search/search_logic.dart` | Plain functions: match, categories, phrases, store match. Unit tested. |
| Private widgets | `lib/features/search/` | Suggestion row, category tile, result row |
| `SearchField` | `lib/shared/widgets/search_field.dart` | Gains an `autofocus` option. Already has `readOnly` and `onTap`. |
| Reused | `SegmentedTabs`, `MostVisitedItem`, `CategoryChip` | Items and Stores tabs, store tiles, Deals chip |
| Category photos | `assets/search/` | Exported from Figma and downscaled. Tech, Makeup (from Beauty) and Fashion (from Women). Sports is a tinted tile. |

**Key invariants**:
- The same text and the same product list always give the same suggestions and results (no randomness, stable order).
- The screen never writes to any repository or provider that is shared with other screens.
- Old and new search do not coexist: Discover's `_applySearch`, `_searchQuery` and the `searchActive` flag are removed in the same change that makes its field open the screen.

**Security model**: read only over the public catalog, using the existing providers. Nothing here is per user, and no row level security rule changes.

**Configuration required**: none.

**Deviations from the Figma frames** (each is a fix or a forced change):
- The tab labels read "Items" and "Stores". Frame 2 has "stores" in lower case.
- The field shows the chosen phrase in the results view. Frame 5 shows "Iphone" in the field but "Iphone 12 midnight" in the heading.
- Popular categories use the real categories, not Men, Women, Accessories, Beauty and Tech. This build ships them as plain tinted tiles rather than the photos noted below, a build time scope cut (see `_CategoryTile` in `search_screen.dart`).
- The stores tab shows the real sellers, not Amazon, Plex and Yale, and not the repeated tiles.
- The duplicate stacked "Popular categories" layers in frame 1 (968:9488 and 972:6720) are treated as one.
- The filter button in frame 5 is not built (see Follow-up).
- The tab bar highlights the tab you came from, not always Home.

**Critical test scenarios** (each maps to an acceptance criterion in `## Requirements`):
- Happy path: on Home, tap the field, type "nik", tap a suggestion, see Nike products, tap one and reach product detail, verifies **AC-1**, **AC-4**, **AC-5**, **AC-6**, **AC-8**
- Happy path: open from Discover, tap Cancel, land back on Discover with its scroll position kept, verifies **AC-1**, **AC-2**
- Empty view: open the screen, see one tile per real category, tap Tech, see Tech results under "Results for “Tech”", verifies **AC-3**, **AC-6**
- Matching: "nike" (store name) and "tech" (category) both return products, verifies **AC-7**
- Suggestions: a store name only match falls back to product titles, verifies **AC-5**
- Deals: with Deals selected only `isDeal` products show, verifies **AC-7**
- Stores: type "app", open the Stores tab, tap Apple, see Apple's products only, verifies **AC-9**
- Failure and empty: type text that matches nothing on each tab, see "No results found for “<text>”", verifies **AC-10**
- Edit and clear: edit text in the results view, return to suggestions, clear it, return to categories, verifies **AC-11**
- Discover: typing is no longer possible in Discover's field, its feed is unchanged, verifies **AC-12**
- Backend parity: run the same search on mock and Supabase, verifies **AC-13**
- Accessibility: each row and control has a label and a 44 pixel tap area, verifies **AC-14**

## Build plan

This project has no recorded build approach (the scope header says Tracer Bullet is assumed). The plan stands up one thin thread through every layer first (open, type, see results, open a product), then thickens it.

1. [x] Add an `autofocus` option to `SearchField`. Make Home's and Discover's fields read only and open the screen, and remove Discover's inline filter code in the same change, satisfies **AC-1**, **AC-12**
2. [x] Register `/search` and `/discover/search` and add a `SearchScreen` shell with Cancel and back, focus on open, and a blank start, satisfies **AC-1**, **AC-2**, **AC-11**
3. [x] Write `search_logic.dart` (match, category list, phrase extraction, store match) with unit tests, satisfies **AC-5**, **AC-7**, **AC-13**
4. [x] Results thread: pressing Search shows the heading and result rows, and a tap opens `/product/:id`, satisfies **AC-6**, **AC-7**, **AC-8**
5. [x] Suggestions view, the Items and Stores tabs, the category chips, and the edit and clear transitions between views, satisfies **AC-4**, **AC-5**, **AC-11**
6. [x] Nothing typed view: the Popular categories row. Built with plain tinted tiles, not the exported photos this task named (the engineer chose that cut for this build; see the class doc on `_CategoryTile`), satisfies **AC-3**
7. [x] The Deals chip and the local added toggle on result rows, satisfies **AC-7**, **AC-8**
8. [x] Stores tab tiles that open a store's results, satisfies **AC-9**
9. [x] Loading, error and "No results found" states on every tab and in the results view, satisfies **AC-10**
10. [ ] Check the tab bar with the keyboard open on a device. If it rides above the keyboard, hide it while the keyboard is up in `AppShell`, satisfies **AC-1** — not checked on a device this run; Flutter's default `Scaffold` behavior (the bottom nav rides up with the keyboard, staying visible) was left as is rather than guessed at
11. [x] Accessibility labels and tap areas, and widget tests that mirror `lib/` under `test/features/search/`, satisfies **AC-14**

## Consequences

**Positive**:
- One search screen serves Home and Discover, and it covers suggestions, stores, results and empty states, which the app had none of.
- No backend change, so it works the same with or without Supabase configured.
- The search rules live in plain functions that are easy to test.

**Negative / tradeoffs**:
- Spec 0001 AC-2 is no longer true, and Discover loses its live filter.
- Two routes for one screen, and a possible change to `AppShell` for the keyboard.
- On the device search will not scale, and the phrase suggestions are weak with 18 products.
- The add to cart icon looks like it adds to a cart but saves nothing, the same limit product detail has today.
- Frame 5's filter button is missing until a filter sheet is designed.

**Neutral**:
- A new `lib/features/search/` folder. The root `AGENTS.md` feature list will need a line for it (`/sync` owns that). No `assets/search/` folder was added this run (plain tinted tiles, no exported photos).
- The search screen keeps its state per tab while the app runs, so switching tabs and back can show the last search. Closing the screen always clears it.

## Follow-up

- [ ] Update spec 0001: AC-2 (Discover's live filter) no longer holds, and AC-6's wording about search results changes. Do this with `/architect` on 0001, or let `/sync` flag it
- [ ] Banner screens are a separate spec. Nothing here makes a banner tappable
- [ ] Design and add the filter sheet, then add the filter button back to the results view
- [ ] Add a real cart write path (`CartRepository` only reads today), then make the result rows' add to cart icon real
- [ ] Move search to the server (a new repository method on both backends, plus Supabase text search and an index) once the catalog is too large to load whole
- [ ] Revisit the phrase suggestions once the catalog grows, since the engineer chose them over plain titles and 18 products give thin results
- [ ] Give the app one category list. Figma uses Men, Women, Accessories, Beauty, Tech and Phones, Home's tabs use "Explore, Fashion, Tech, Sports, Makeup", Discover's use "For you, Fashion, Tech, Sports, Makeup", and the products use Fashion, Tech, Sports, Makeup
- [ ] Design a store screen. Tapping a store tile only shows its products here
- [ ] Supply category photos and a Sports photo if the tinted tile fallback is ever replaced, and fix the Figma frames (the mismatched field and heading, the "stores" label, the duplicate layer, the placeholder brands)
- [ ] Verify the tab bar with the keyboard open on a small phone (build plan task 10, still open)
- [ ] Enroll this as a feature in `docs/scope/scope.md` (already enrolled as feature 7 by the time of this build; this line predates that)
