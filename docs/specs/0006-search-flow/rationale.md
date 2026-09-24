# 0006. Build the search flow — rationale

Decision record for [index.md](index.md). Not needed to build against; kept here for the history behind the choice.

## Context

> ⚠️ Premise note: opening this screen from Discover takes away Discover's live inline filter, so spec 0001 AC-2 stops being true. The engineer chose this on purpose ("any search field"), and the recommendation was Home only. Spec 0001 needs a follow up edit (see Follow-up). Separately, the app has 18 mock products, so the search suggestions the engineer chose (phrases built from titles) will feel thin until the catalog grows.

Search today is a plain field. Home's field does nothing when typed in. Discover's field filters its product feed live, on the device, by title or store name (spec 0001, AC-2). No screen exists for searching, so there are no suggestions, no result list, no store search, and no empty state for "nothing found".

Figma now draws the whole flow in five frames (file `toOakybJ0DaJmU7vcEC0AW`): nothing typed (968:8943), typing (968:9652), the stores tab (968:9953), no results (972:6472) and a result list (972:6576). The frames disagree with the app in three ways that shape this build. The Popular categories are Men, Women, Accessories, Beauty and Tech, but the products only have Fashion, Tech, Sports and Makeup. The store grid shows brands (Amazon, Plex, Yale) that are not in the mock sellers (Bershka, Pull&Bear, Apple, Nike, Glossier). And every frame highlights the Home tab, although the screen is also opened from Discover.

The project constraints that apply: the mock and Supabase backends must behave the same, all data comes through the Riverpod providers in `lib/data/providers/`, and every colour and size comes from the tokens in `lib/core/theme/app_theme.dart`. `CartRepository` only reads, so there is no real add to cart yet.

## Options considered

### Option 1: A dedicated search screen inside each tab, searching on the device

Register the same screen under the Home branch and the Discover branch of the tab shell, so the tab bar stays and the highlighted tab follows where you came from. Search runs in memory over the lists the providers already hold.

**Pros**:
- Matches the Figma frames, which draw the tab bar.
- No new repository method, migration or Supabase index, and one code path for mock and Supabase.
- Each tab keeps its own search state, the way the shell already keeps scroll state.

**Cons**:
- Two route registrations for one screen, and the tab bar may ride above the keyboard and eat vertical space.
- Does not scale past a few hundred products, and has no typo tolerance.

### Option 2: One full screen route outside the tab shell, like product detail

A single `/search` route that hides the tab bar.

**Pros**:
- One route, one behaviour, and a tab bar never sits under the keyboard.
- Cancel is a plain pop, and there is no question of which tab is highlighted.

**Cons**:
- Drops the tab bar the frames draw.
- The person loses the tab bar for the whole search.

### Option 3: Keep the inline filter and add a suggestions overlay

Leave Discover's live filter as it is and float a suggestions panel over it.

**Pros**:
- Spec 0001 stays true, and Home is the only screen that changes.

**Cons**:
- Not what Figma draws, and it gives no stores tab, no result screen and no empty state.
- Two search behaviours to maintain side by side.

## Rationale

The tab bar and the search location were the engineer's calls, and both go against the first recommendation. I recommended Option 2 because a tab bar under an open keyboard wastes space and one route is simpler, and product detail already works that way. The engineer chose to keep the tab bar as drawn, and Option 1 delivers that. It is a fair choice, at the cost of two route registrations and a check that the tab bar behaves with the keyboard open.

Searching on the device follows spec 0001 AC-2 and the fact that the app holds 18 products. A server search would need a new repository method, a Supabase migration and a matching change to the mock repository, for a catalog that does not need it yet. The engineer chose it "for now", so the move to the server is a follow up, not a design goal.

The suggestions are phrases built from titles, which the engineer picked over listing whole titles. With 18 products that will produce short lists with little variety, so the extraction rule in AC-5 is written out exactly, and titles are the fallback when no phrase fits. It is not the recommended option, and it needs revisiting once the catalog grows.

The product detail screen already flips a local "added" state that is not saved, so the result rows reuse that pattern (AC-8) instead of inventing a cart write path that has no spec.
