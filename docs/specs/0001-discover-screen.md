# 0001. Build the Discover screen

**Date**: 2026-07-14
**Status**: Proposed

## Summary

This decides how to build the app's Discover screen, the second tab in the bottom navigation, and
how tab switching works between screens in general. Discover is a search first browse surface: a
search field, category tabs, a grid of stores, and a product feed with a couple of promotional
banners mixed in, all reusing pieces already built for the Home screen. Because Discover cannot be
reached at all today (the bottom nav's tab switching is not wired up yet), this spec also covers
switching to a proper multi tab navigation setup (a persistent shell) so Cart, Profile, and Reels
can slot in the same way later.

## Context

The app (Shopscroll, a Flutter marketplace app) has one screen built so far, Home, plus a Product
detail screen. Both are reachable only because Home is the initial route; every other bottom nav
tab (Discover, Reels, Activity, Profile) is currently a dead tap, since `AppBottomNavBar`'s
`onItemSelected` callback on Home does nothing. `lib/features/discover/` does not exist yet.

Several pieces this feature needs are already built and unused, a strong signal of the intended
design: `SegmentedTabs`' own doc comment already names a Discover specific compact tab layout,
`CategoryChip` exists but has no caller yet, and `AppBottomNavBar` already defines a `discover` tab
item with a search style icon. The data layer already exposes what a browse screen needs:
`productsProvider`, `productsByCategoryProvider`, and `sellersProvider` (backing Home's own
category tabs and "Most visited stores" section).

The real Figma frame ("ShopScroll-UI", "The design - user" page, node 228:3114) shows: a search
field, a category tab row ("For you" active, then Sports, then "Makeup" repeated four times, a
known duplicate layer artifact already seen and worked around elsewhere in this codebase), a three
by four grid of generic store logos (Amazon, Apple, Plex, Yale, placeholder brands, not this app's
real sellers) ending in a "View all" tile, then a two column product grid with two promotional
banner tiles mixed in, then the bottom nav. Only five real sellers exist in this app's mock data,
so the store grid cannot be built to the letter; the fix decided below is to render exactly what
exists, not force twelve tiles.

Because nothing in the bottom nav currently navigates anywhere, building Discover forces a decision
about how tab switching works at all, not just for this one screen. That decision is made once
here (see Options considered) rather than being re-decided ad hoc when Cart, Profile, and Reels are
each built later.

## Requirements

**User stories**:
- As a shopper, I want a dedicated place to search and browse the whole catalog by category, so
  that I can find something specific faster than scrolling Home's algorithmic sections.
- As a shopper, I want tapping between bottom nav tabs to feel instant and keep my place, so that
  switching to check something on another tab doesn't lose my scroll position or filters.

**Acceptance criteria** (the contract, each independently checkable):
- **AC-1**: Tapping the bottom nav's Discover tab, from any screen that has it, opens the Discover
  screen; tapping Home again returns to Home with its previous scroll position and state intact
  (and vice versa), because each tab keeps its own navigation state.
- **AC-2**: Typing in the Discover search field filters the visible product feed, live as you type,
  by matching the product title or store name (case insensitive substring match), entirely client
  side.
- **AC-3**: The category tab row ("For you", Fashion, Tech, Sports, Makeup) filters the product
  feed to that category; "For you" shows the full catalog. Only one filter (search text or
  category) is expected active at a time is not required by this feature; combining both is out of
  scope for this build (search simply filters whatever the active category tab already shows).
- **AC-4**: A store grid section shows exactly the sellers that exist in mock data (5), with no
  placeholder or filler tiles, and no "View all" affordance (there is nothing further to view).
- **AC-5**: The product feed renders as a two column grid of `ProductCard` tiles, with two static
  promotional banner tiles mixed in at the same relative positions as the Figma design (after the
  first two products, and as a final pair at the end of the grid).
- **AC-6**: Each independently loading section (product feed, store grid) shows its own loading
  indicator while its provider resolves, its own error message if the provider fails, and an
  appropriate empty state message when a filter or search yields no results, matching the pattern
  already used on Home.
- **AC-7**: Tapping any product tile (feed or elsewhere on this screen) navigates to the existing
  product detail route (`/product/:id`).

## Options considered

### Option 1: Simple pushed routes, no shell

Each bottom nav tab is a plain `GoRoute`; tapping a tab calls `context.go('/discover')` or similar,
same as Home already does for product detail. No new go_router concepts.

**Pros**:
- Least code, nothing new to learn about go_router.
- Fastest to ship this one screen.

**Cons**:
- Switching tabs re-runs the destination screen from scratch every time: scroll position, the
  active category tab, and any typed search text are lost on every tab switch, which directly
  breaks part of AC-1.
- Doesn't scale: the same problem returns for every future tab (Cart, Profile, Reels), so it would
  likely need replacing with Option 2 later anyway, at that point as a larger, riskier refactor
  touching every existing screen.

### Option 2: Persistent shell (`StatefulShellRoute`)

go_router's purpose built pattern for bottom nav apps: each tab is its own branch with its own
navigation stack, and the framework preserves each branch's state (including scroll position) when
switching away and back.

**Pros**:
- Matches AC-1 exactly: switching tabs preserves state, because that's what the pattern is for.
- One time cost paid now, while there are only two real branches (Home, Discover) to wire, instead
  of a bigger refactor once Cart, Profile, and Reels exist too.
- The idiomatic, well documented go_router approach for exactly this shape of app; nothing custom
  to maintain.

**Cons**:
- More router setup than Option 1 for this feature alone: a shell scaffold, branch definitions, and
  a decision for what the three not yet built tabs (Reels, Activity, Profile) render meanwhile.
- Slightly less familiar than a flat route list to a developer new to go_router.

### Option 3: Hand rolled shell (Scaffold + IndexedStack)

Build a custom bottom nav shell manually: a `Scaffold` holding an `IndexedStack` of the five tab
screens, switched by local state instead of go_router's shell support.

**Pros**:
- Full control over exactly how state is kept per tab.

**Cons**:
- Reimplements, by hand, state preservation that `StatefulShellRoute` already provides and has
  tested; more code to write and maintain for no behavioral gain over Option 2.
- Loses go_router's URL based navigation and deep linking for each tab (each tab's location stops
  being a real route), a real regression against the rest of this app's routing conventions.

## Decision

**Chosen option**: Option 2: Persistent shell (`StatefulShellRoute`)

Build the Discover screen as the second branch of a `StatefulShellRoute`, alongside Home as the
first branch, and wire `AppBottomNavBar` on both screens to switch branches through it.

## Rationale

The deciding constraint is AC-1: tab switching has to preserve each tab's state, and that is
precisely the problem `StatefulShellRoute` exists to solve, not a side benefit. Option 1 (simple
pushed routes) fails AC-1 directly, since a freshly pushed screen has no memory of where it was.
Option 3 (a hand rolled shell) could satisfy AC-1 but only by re-implementing state preservation
that go_router's own pattern already provides, well tested, for more code and a real regression
(losing per tab URLs) with no corresponding benefit.

The cost of Option 2, more router setup now, is smallest right now: only two branches (Home,
Discover) need real screens, and three (Reels, Activity, Profile) need only a lightweight
placeholder to keep the shell structurally complete (see Consequences). Paying this setup cost
after those three tabs are fully built would touch far more code than paying it today.

## Feature design

**Data model sketch**:
No new entities. Reuses `Product` and `UserProfile` (`lib/data/models/`), both already built with
the fields this feature needs (`Product.category` for the tab filter, `Product.title` and
`Product.storeName` for the search filter). The store grid reuses the same `UserProfile` list
`sellersProvider` already exposes to Home's "Most visited stores" section, five sellers, no
filtering needed.

**State transitions**: None. No entity here has a lifecycle; this is a read only browse surface.

**API surface** (all as-if endpoints, this app has no real backend, see `AGENTS.md`):

| Endpoint (as-if) | Method | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| `/products` | GET | none | `List<Product>` | none (public) | provider throws on the mocked failure path, surfaced as the section's error state |
| `/products?category=:category` | GET | `category: String` | `List<Product>` | none (public) | same as above |
| `/sellers` | GET | none | `List<UserProfile>` | none (public) | same as above |

No new provider is needed; all three already exist (`product_providers.dart`,
`user_profile_providers.dart`). The search filter is local widget state applied over whichever list
is already fetched (matching category or "For you"), not a new provider, consistent with how Home
already manages its own local `_activeCategoryIndex` as plain widget state rather than Riverpod
state.

**Key invariants**:
- The category tab row's "For you" tab always shows the unfiltered product list; every other tab
  filters by exact `Product.category` match.
- The search filter is a pure client side substring match (case insensitive) over whatever category
  is currently active; it never issues a new request.
- The store grid always renders exactly `sellersProvider`'s current list, no more, no fewer, no
  static filler tiles.

**Security model**:
None. This app has no authentication anywhere yet (see `AGENTS.md`, buyer side only, no real
backend); every product and seller shown here is public mock data, same as every existing screen.

**Configuration required**: None. No new environment variables, secrets, or third party
credentials; no new package dependency (`GridView`/`Wrap` are built into Flutter).

**Critical test scenarios**:
- Happy path: tap Discover from Home, the screen loads with "For you" active showing the full
  product feed and the 5 seller store grid, verifies **AC-1**, **AC-3**, **AC-4**.
- Search filtering: type a store name into the search field and the feed narrows to matching
  products only, then clearing the field restores the full (or category filtered) list, verifies
  **AC-2**.
- Tab state preservation: scroll the product feed, switch to Home, switch back to Discover, the
  scroll position and active category tab are unchanged, verifies **AC-1**.
- Empty state: search for text matching nothing, the feed shows an empty state message rather than
  a blank screen, verifies **AC-6**.
- Navigation: tap a product tile in the feed, lands on the existing product detail screen for that
  product's id, verifies **AC-7**.

## Build plan

Following a Tracer Bullet approach (thin, end to end slices, thickened after): no build approach is
recorded yet in `AGENTS.md` or a scope header (no `/scope` has run for this project), so this
defaults to end to end slices, matching how Home and Product detail were already built, data,
routing, and UI landed together per screen, and is noted here as an assumption.

1. Convert `app_router.dart` to a `StatefulShellRoute` with two real branches, Home (`/`) and
   Discover (`/discover`), plus lightweight placeholder branches for Reels, Activity, and Profile
   (a simple "Coming soon" screen each, so the shell is structurally complete for all 5 tabs without
   designing those features now). Satisfies **AC-1**.
2. Wire `AppBottomNavBar`'s `onItemSelected` on Home (replacing today's no-op) and on the new
   Discover screen to switch shell branches. Satisfies **AC-1**.
3. Scaffold `lib/features/discover/discover_screen.dart`: reuse `SearchField` and `SegmentedTabs`
   (categories: For you, Fashion, Tech, Sports, Makeup) wired to local widget state, rendering the
   product feed from `productsProvider` / `productsByCategoryProvider` in a 2 column grid of
   `ProductCard` tiles. This is the thin end to end slice: nav reaches a real screen showing real
   mocked data. Satisfies **AC-1**, **AC-3**.
4. Add the live client side search filter over the already fetched product list. Satisfies **AC-2**.
5. Add the store grid section: `sellersProvider`'s 5 sellers rendered via `MostVisitedItem` tiles in
   a grid (not Home's horizontal scroll, a deliberate difference matching Figma's own grid layout
   for this section), no "View all" tile. Satisfies **AC-4**.
6. Add two static promotional banner tiles (a new private, screen local widget, following
   `AGENTS.md`'s convention that one-off widgets stay private inside their screen file) interleaved
   into the product grid at the Figma-matched positions. Satisfies **AC-5**.
7. Add per section loading/error/empty states (`AsyncValue.when`), matching Home's existing
   per-section pattern. Satisfies **AC-6**.
8. Wire each `ProductCard` tap to `context.push('/product/:id')`, the existing route. Satisfies
   **AC-7**.

## Consequences

**Positive**:
- Discover becomes reachable and fully functional; the bottom nav stops being partly dead weight.
- The navigation shell now scales cleanly: Cart, Profile, and Reels slot in as new branches later
  without another routing refactor.
- Each tab keeps its own scroll position and filter state across switches.

**Negative / tradeoffs**:
- More router code lands now than a minimal "just add one screen" change would need, because the
  shell is being introduced for the whole app, not only Discover.
- Reels, Activity, and Profile each need a placeholder screen registered as their shell branch
  today, ahead of those features actually being designed.

**Neutral**:
- The "grid of stores" pattern now exists twice in the app (Home's horizontal scroll, Discover's
  grid), by deliberate choice: Figma draws them as genuinely different layouts, not a duplicate to
  consolidate.
- Home's `AppBottomNavBar` wiring changes from a no-op to a real navigation call, a behavior change
  to that existing screen, not just new code.

## Follow-up

- [ ] No scope entry exists yet for this feature (`docs/scope/` hasn't been created); consider
  running `/scope` so this feature is tracked and this spec's status can advance as it's built.
- [ ] Reels, Activity, and Profile's placeholder shell branches (build task 1) will need replacing
  with real screens and their own specs when those features are designed.
