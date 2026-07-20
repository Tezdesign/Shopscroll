# Scope: Shopscroll

A Flutter mobile marketplace app (buyer side only, mock data, no real backend yet). See `AGENTS.md`
for the stack.

**Build approach:** Not yet set for the whole product; run `/scope` to decide one. This feature's
build plan assumed Tracer Bullet (thin, end to end slices) as a default in the meantime, see spec
0001.

## At a glance

| # | Feature | Phase | Status |
|---|---------|-------|--------|
| 1 | Discover screen | Unplanned | in-progress |
| 2 | Reels screen | Unplanned | in-progress |

## Features

### 1. Discover screen · in-progress

A search first browse screen (search field, category tabs, a store grid, a product feed with promo
banners), reachable from the bottom nav's Discover tab. Building it also introduces a persistent
navigation shell so tab switching preserves each tab's state.
**Done when:** Discover is reachable from the bottom nav, its search and category filters work
live, and switching tabs preserves state (see spec 0001 for the full acceptance criteria).
- [x] Design it (spec): `/architect discover screen`
- [ ] Build it: `/develop discover screen`
   - [ ] Navigation shell: `StatefulShellRoute` (Home/Discover branches + placeholder branches for
     Reels/Activity/Profile), bottom nav wiring (AC-1)
   - [ ] Discover screen shell: search field + category tabs, rendering the product feed live from
     the existing providers (AC-1, AC-3)
   - [ ] Live client side search filter (AC-2)
   - [ ] Store grid section, reusing `MostVisitedItem` (AC-4)
   - [ ] Promo banner tiles, per section loading/error/empty states, and product tap-through to
     product detail (AC-5, AC-6, AC-7)
- [ ] Verify it: `/check verify discover screen`
- [ ] Test it: `/test discover screen`

Spec [0001](../specs/0001-discover-screen.md) · code (filled by `/develop`)

### 2. Reels screen · in-progress

A browse grid of short seller videos (search field, a For you tab row, a two column reel card grid)
reachable from the bottom nav's Reels tab, plus a full screen swipeable video player opened by
tapping a reel, with like, save, and shop the tagged products actions.
**Done when:** Reels is reachable from the bottom nav showing real reel data, tapping an available
reel opens the full screen player with working like/save and a "shop the look" sheet, and unavailable
reels are dimmed and non navigable (see spec 0002 for the full acceptance criteria).
- [x] Design it (spec): `/architect reels screen`
- [x] Build it: `/develop reels screen`
   - [x] Reels grid screen: shell route wiring (real screen replacing the placeholder branch),
     `ReelCard` widget, search field + tab row, live client side search filter (AC-1, AC-2, AC-3)
   - [x] Full screen video player core: `PageView.builder`, bounded video controller window, muted
     autoplay with unmute toggle, progress/buffering indicators (AC-4, AC-5)
   - [x] Player interactions: action rail (like/save/comment count/share), overlay (avatar, store
     name, static Follow button, caption), "shop the look" bottom sheet (AC-5, AC-6, AC-7)
   - [x] Per section loading/error/empty states, grid and player (AC-8)
- [ ] Verify it: `/check verify reels screen`
- [ ] Test it: `/test reels screen`

Spec [0002](../specs/0002-reels-screen.md) · code: `lib/features/reels/reels_screen.dart`,
`lib/features/reels/reel_player_screen.dart`, `lib/shared/widgets/reel_card.dart`,
`lib/core/router/app_router.dart`
