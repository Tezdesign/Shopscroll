# 0002. Build the Reels screen

**Date**: 2026-07-17
**Status**: In Progress

## Summary

This decides how to build the app's Reels tab: a browse grid of short seller videos (search field,
a "For you" tab row, a two column grid of reel cards), plus a full screen swipeable video player
that opens when a reel is tapped, with like, save, and "shop the look" actions. Most of the ground
work (the `Reel` model, ten mock reels with real playable video, and the data providers) was already
built ahead of this spec and has sat unused; this spec is what finally turns it into a real screen.

## Context

The app (Shopscroll, a Flutter marketplace app) has Home, Discover, and Product detail built. The
Reels tab in the bottom nav is currently a dead placeholder (`ComingSoonScreen`), one of three
branches stubbed out when the persistent navigation shell was built (see spec 0001).

Unusually for this project, the data side of this feature was built well ahead of the screen: the
`Reel` model (`lib/data/models/reel.dart`), ten mock reels with real playable sample video URLs and
picsum thumbnails (`lib/data/mock/mock_reels.dart`), and three Riverpod providers
(`lib/data/providers/reel_providers.dart`, covering the full list, a single reel by id, and reels by
store) all already exist and are referenced nowhere in the UI. `video_player` and `chewie` are
already project dependencies, added specifically for this feature per `AGENTS.md`. `lib/features/
reels/` exists only as an empty scaffold directory.

The real Figma frame ("ShopScroll-UI", node 234:646, named "Reels") shows only the browse grid: a
search field, a "For you" / "Following" tab row, and a two column grid of reel cards (avatar, store
name, thumbnail, caption). It does not show a full screen player; no Figma frame for that state
exists in this file. There is also no follow or social graph anywhere in the data model
(`UserProfile` has no notion of who a buyer follows), so the "Following" tab has no real data to
back it.

One mock reel (`reel-009`) is deliberately marked `isAvailable: false` with a caption explaining the
store closed its account, exercising a state the UI has to handle. Two mock reels are already marked
`isSaved: true`, and every reel carries `likeCount`/`commentCount`, matching what a like/save/comment
affordance needs to render, though nothing mutates them today.

## Requirements

**User stories**:
- As a shopper, I want to browse short seller videos in a familiar swipeable grid, so I can discover
  products in a more visual way than the static product feed.
- As a shopper, I want to tap into a reel and watch it full screen with a natural swipe to the next
  one, so browsing feels continuous rather than one video at a time.
- As a shopper, I want to see and reach the products tagged in a reel, so I can shop what I just
  watched without leaving the flow.

**Acceptance criteria** (the contract, each independently checkable):
- **AC-1**: Tapping the bottom nav's Reels tab opens the Reels grid screen (replacing today's
  `ComingSoonScreen` placeholder branch): a search field, a "For you" / "Following" tab row ("For
  you" active and functional, "Following" visually present but disabled, since no follow data
  exists), and a two column grid of reel cards (thumbnail, store avatar and name, caption preview)
  sourced from `reelsProvider`.
- **AC-2**: Typing in the search field filters the visible grid live, matching a reel's caption or
  store name (case insensitive substring), entirely client side, the same pattern already used on
  Discover.
- **AC-3**: A reel marked unavailable (`isAvailable: false`) still renders in the grid but visually
  dimmed and grayscale with a small "no longer available" label, and tapping it does nothing.
- **AC-4**: Tapping an available reel card opens a full screen vertical video player starting at
  that reel, within the same ordered list currently shown in the grid (respecting an active search
  filter), so swiping up or down moves to the next or previous available reel in that same order.
- **AC-5**: The full screen player shows: the video looping and autoplaying muted by default (a tap
  or an icon toggle unmutes), a right side action rail (like toggle with count, comment count as a
  static display, save and bookmark toggle, share), a bottom left overlay (store avatar, store name,
  a static, not yet wired "Follow" button, the caption, and a "shop the look" affordance when the
  reel has tagged products), and a thin per reel progress indicator. While an individual reel's
  video is still initializing or buffering after becoming the active page, that reel shows its own
  loading indicator over the frame, separate from the grid's list level loading state (AC-8).
- **AC-6**: Tapping the "shop the look" affordance opens a bottom sheet listing every product tagged
  on that reel (`productIds`), each tile tapping through to the existing `/product/:id` route.
- **AC-7**: Liking a reel fills its heart icon and increments or decrements the displayed like count
  optimistically; saving toggles the bookmark icon the same way. Both are local, session only state
  (not persisted anywhere), the same pattern `AddToCartToggle` already uses on Product detail. That
  state survives swiping to other reels and back within the same player session (it is not reset
  just because a reel's page scrolled offscreen); only leaving the player screen entirely and
  reopening it resets every reel back to the underlying mock data's original values.
- **AC-8**: The grid, and the player's initial load, each show their own loading indicator while
  `reelsProvider` resolves, an error message if it fails, and an empty state message if the
  (possibly search filtered) list is empty, matching the pattern already used on Home and Discover.

## Options considered

### Option 1: `PageView.builder` with a small active window of video controllers (recommended)

A vertical `PageView.builder` pages through the ordered reel list; only a three wide window around
the current index (the current reel plus the one immediately before and the one immediately after,
for smooth swiping in either direction) has a real `VideoPlayerController`/`ChewieController`
instantiated, disposed once a reel leaves that window.

**Pros**:
- Bounded memory and CPU no matter how many reels exist; the standard pattern behind every
  TikTok style feed, for exactly this reason.
- Reuses `video_player`/`chewie`, already a project dependency added specifically for this feature.
- Full control over autoplay, mute, and pause on page change via `PageView`'s `onPageChanged`.

**Cons**:
- The most lifecycle code of the three options to write and get right; a careless implementation
  can leak controllers, stutter on swipe, or dispose a controller mid initialize or before its
  Chewie widget has actually unmounted, a known `video_player` race that has to be guarded against
  explicitly (e.g. awaiting disposal, never disposing a controller still attached to the visible
  page).

### Option 2: Instantiate every reel's video controller up front

When the player opens, create a `VideoPlayerController` for all ten mock reels immediately.

**Pros**:
- Simplest code, no controller lifecycle bookkeeping.
- Instant swipe, nothing ever buffers, since every reel is already loaded.

**Cons**:
- Only "works" because the mock list happens to be fixed at ten; a real reel feed is effectively
  unbounded, so this shape would need a full rewrite the moment the data source stops being a small
  fixed list.
- Starts ten concurrent video downloads and decodes the moment the player opens, a real performance
  and battery cost even at this size, and not a pattern to build a habit around.

### Option 3: A prebuilt Flutter short video feed package

Add a third party package built for TikTok style feeds instead of hand rolling on `video_player`/
`chewie`.

**Pros**:
- Less custom code; lifecycle and gesture handling are already solved.

**Cons**:
- A new dependency in a project that has deliberately kept its surface small and already invested in
  `video_player`/`chewie` specifically for this screen.
- Ties the UI to a third party widget tree, making it harder to hit the Figma tokens
  (`AppColors`/`AppSpacing`/`AppTypography`) exactly the way every other screen in this app does.
- Unvetted: the engineer opted out of a web landscape check for this spec, so no current package was
  actually verified as trustworthy or maintained.

## Decision

**Chosen option**: Option 1: `PageView.builder` with a small active window of video controllers.

Build the Reels grid as its own screen replacing the placeholder shell branch, and the full screen
player as a second, top level screen it navigates to.

## Rationale

The deciding constraint is that this app's mock reel list is a stand in for a real, effectively
unbounded feed, not a fixed catalog; `video_player`/`chewie` were installed specifically to power
this feature, which is a strong signal the intended shape was always a real player, not a static
preview. Option 2 (load every controller) only looks simpler because the mock list happens to be
ten items; the moment reels comes off mock data, it stops working and needs a rewrite, which is
exactly the trap a bounded controller window avoids from day one. Option 3 (a third party package)
would save some lifecycle code, but trades away this project's tight, hand tuned match to its own
Figma tokens for a dependency nobody has evaluated in this session, in a codebase that has otherwise
kept its dependency surface intentionally small.

## Feature design

**Data model sketch**:
No new entities or fields. Reuses `Reel` exactly as it already exists (`id`, `videoUrl`,
`thumbnailUrl`, `storeId`/`storeName`, `storeAvatarUrl`, `caption`, `likeCount`, `commentCount`,
`productIds`, `isAvailable`, `isSaved`, `createdAt`). Like and save state render from those fields
but mutate only as local, session only widget state (no provider, no mock data mutation), matching
how `AddToCartToggle` already behaves on Product detail; this was confirmed directly with the
engineer rather than assumed.

**State transitions**: None. `Reel` has no lifecycle in this app; `isAvailable` and `isSaved` are
fixed mock flags, not state a user transitions.

**API surface** (all as-if endpoints, this app has no real backend, see `AGENTS.md`):

| Endpoint (as-if) | Method | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| `/reels` | GET | none | `List<Reel>` | none (public) | provider throws on the mocked failure path, surfaced as the grid's error state |
| `/reels/:id` | GET | `id: String` | `Reel?` | none (public) | returns `null` if not found (not expected in this build, every player entry comes from the already fetched list) |

Both already exist (`reelsProvider`, `reelByIdProvider` in `reel_providers.dart`); no new provider is
needed. `reelsByStoreProvider` also already exists but has no caller in this feature's scope.

**Key invariants**:
- The "Following" tab never changes the rendered grid; it is visually present but inert, since no
  data backs it.
- An `isAvailable: false` reel is never navigable into the player, from the grid or from swiping past
  it in the player's own list.
- A reel's like/save visual state always resets to `Reel.likeCount`/`Reel.isSaved` on rebuild; no
  toggle persists past the current widget lifetime. Concretely, that state is held once, in the
  player screen's own `State` (e.g. a set of liked reel ids and a set of saved reel ids), not inside
  each page's own per reel widget: a bare per page `StatefulWidget` gets disposed and its state lost
  the moment `PageView` scrolls it a couple of pages away, which would silently violate AC-7 well
  before the user ever leaves the player screen.
- The player's swipeable order always matches whatever ordered (and possibly search filtered) list
  was visible in the grid at the moment a card was tapped.

**Security model**:
None. This app has no authentication anywhere (see `AGENTS.md`, buyer side only, no real backend);
every reel and its store are public mock data, same as every existing screen.

**Configuration required**: None. `video_player` and `chewie` are already dependencies; no new
package, environment variable, or credential.

**Critical test scenarios**:
- Happy path: tap the Reels tab, the grid loads its ten reel cards, tap an available one, the full
  screen player opens on that reel and autoplays muted, verifies **AC-1**, **AC-4**, **AC-5**.
- Search filtering: type a store name into the search field, the grid narrows to matching reels, tap
  a result, the player's swipeable order matches that filtered list, verifies **AC-2**.
- Unavailable reel: `reel-009` renders dimmed with the "no longer available" label and is not
  tappable, verifies **AC-3**.
- Shop the look: tap the shop affordance on a reel with tagged products, a sheet lists them, tapping
  a tile navigates to `/product/:id`, verifies **AC-6**.
- Like and save: tap like, the icon fills and the count increments; navigate away and back, both
  reset to the original mock values, verifies **AC-7**.
- Empty and error: an empty or failed `reelsProvider` result shows the grid's own empty or error
  state instead of a blank screen, verifies **AC-8**.

## Build plan

Following this project's Tracer Bullet approach (thin, end to end slices, thickened after; no
project wide default is recorded yet in `AGENTS.md`, so this follows the same assumption spec 0001
made, noted there as an assumption):

1. Wire the Reels shell branch: replace the `ComingSoonScreen` placeholder in `app_router.dart`'s
   Reels branch with a real `ReelsScreen` at `/reels`, and add a new top level route `/reels/:id` for
   the full screen player, outside the shell (matching `ProductDetailScreen`'s existing convention so
   it opens without the bottom nav). Satisfies **AC-1**, **AC-4**.
2. Build `ReelCard` (`lib/shared/widgets/reel_card.dart`): thumbnail via `CachedNetworkImage`, avatar
   and store name overlay, caption, and the dimmed and disabled unavailable treatment. Satisfies
   **AC-3**.
3. Scaffold `lib/features/reels/reels_screen.dart`: reuse `SearchField` and `SegmentedTabs` ("For
   you" active and functional, "Following" visually present but disabled), a two column grid of
   `ReelCard` sourced from `reelsProvider`, wired so tapping an available card pushes `/reels/:id`.
   This is the thin end to end slice: nav reaches a real screen showing real mocked data. Satisfies
   **AC-1**.
4. Add the live client side search filter over the already fetched reel list. Satisfies **AC-2**.
5. Build `lib/features/reels/reel_player_screen.dart`: a vertical `PageView.builder` over the ordered
   reel list, always excluding `isAvailable: false` reels from that pageable list (never just the
   grid's dimmed display, the underlying page order itself), and respecting the search filtered
   subset if the tap came from a filtered grid. `video_player`/`chewie` controllers are instantiated
   for a three wide window (current index plus one before and one after), disposed once a reel
   leaves that window, guarding against disposing a controller mid initialize or before its Chewie
   widget has unmounted. Muted autoplay with a tap or icon based unmute toggle, and the per reel
   progress and per reel buffering indicators. Satisfies **AC-4**, the video portion of **AC-5**.
6. Add the action rail (like and save toggles, static comment count, share) and the bottom overlay
   (avatar, store name, a static "Follow" button, caption). Like/save state is held once, in the
   player screen's own `State` (liked and saved reel id sets), not per page, so it survives swiping
   away and back within the session; it resets only when the whole player screen is left and
   reopened. Satisfies the chrome portion of **AC-5**, and **AC-7**.
7. Add the "shop the look" bottom sheet, reusing the modal sheet chrome pattern already built for
   Product detail's sheets (`showModalBottomSheet`, rounded top, close button), listing every tagged
   product and tapping through to `/product/:id`. Satisfies **AC-6**.
8. Add per section loading, error, and empty states (`AsyncValue.when`) on both the grid and the
   player's initial load, matching the existing pattern. Satisfies **AC-8**.

## Consequences

**Positive**:
- Reels stops being a dead placeholder tab; the model, mock data, providers, and video packages that
  have sat unused finally get used.
- Establishes this app's first video playback pattern, and reuses the modal sheet chrome pattern a
  second time (after Product detail), both now reusable for later features.

**Negative / tradeoffs**:
- The full screen player is the most complex UI this app has built so far (manual video controller
  lifecycle, gesture driven paging); more surface area to get wrong than any screen shipped to date.
- "Following" ships as a visibly inert tab, and the player's "Follow" button as a visibly inert
  affordance, until a real follow model exists.
- Comments stay display only; the UI shows a count that implies an interaction the app cannot
  actually perform yet.

**Neutral**:
- The player route sits outside the shell, like Product detail, a deliberate consistency choice
  (opens without the bottom nav).
- Like and save are session only by deliberate choice, matching `AddToCartToggle`'s existing pattern
  rather than introducing this feature's own persistence model.

## Follow-up

- [ ] No scope entry exists yet for this feature (`docs/scope/scope.md` has no Reels row); consider
  running `/scope` so it's tracked and this spec's status can advance as it's built.
- [ ] "Following" is visually present but non functional; it needs its own follow or social graph
  data model (e.g. `UserProfile.isFollowed` or a followed seller list) and its own spec before it can
  filter reels for real.
- [ ] The player overlay's static "Follow" button has no real backing action; wire it once the follow
  model above exists.
- [ ] Comments are display only in this build; a real comments feature (data model plus UI) is out of
  scope here and would need its own spec.
- [ ] The project's task list marks "Build Follow-Button widget" as already completed, but no such
  widget exists anywhere in the codebase (verified by search); likely a stale record worth
  correcting in the tracker. It is not deferred work: Build plan task 6 already creates it now, as
  part of this spec, for the player overlay's static Follow button.
