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
| 3 | Supabase backend | Unplanned | in-progress |
| 4 | Auth (Clerk) | Unplanned | in-progress |
| 5 | Profile screen | Unplanned | in-progress |

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

### 3. Supabase backend · in-progress

Adopts Supabase (managed Postgres + Auth) as the real backend for all five existing data models
(products, reels, user profiles, cart items, orders), replacing the mock data layer, with anonymous
sign in giving cart/order rows a stable owner even though there is no login screen yet.
**Done when:** the schema exists in Supabase (tables, RLS, seed data) and the Flutter app reads and
writes through it instead of the mock providers, per the build plan `/develop` derives from the
decision (see spec 0003 for the full decision and data model).
- [x] Decide the stack (spec): `/architect supabase backend`
- [x] Scaffold from the decision: `/develop supabase backend`
- [ ] Verify it: `/check verify supabase backend`
- [ ] Test it: `/test supabase backend`

Spec [0003](../specs/0003-supabase-backend/index.md) · code: `supabase/schema.sql`,
`lib/data/repositories/`, `lib/data/providers/*.dart`, `lib/main.dart`,
`lib/core/config/supabase_config.dart`

### 4. Auth (Clerk) · in-progress

Adds Clerk as the real sign in system (email/password, Google, Apple), connected to the existing
Supabase Postgres backend through native Third Party Auth. Anonymous browsing stays fully open; a real
account is offered once, the first time the app opens, and can be skipped. An anonymous session's
cart/orders carry over automatically on first real sign in.
**Done when:** Clerk sign in/sign up work end to end, RLS is rewritten to the new text based ownership
model, the anonymous-to-real merge and account deletion cleanup both work, and sign up/sign in errors
show a visible message, per the full acceptance criteria in spec 0004.
- [x] Design it (spec): `/architect auth using clerk`
- [x] Build it: `/develop auth`
   - [x] Schema & security foundation: `ALTER`-based migration (`uuid`→`text`, RLS rewrite including
     `order_items` and the narrowed `user_profiles` policy), `merge_anonymous_identity` security
     definer function (AC-3, AC-5, AC-10) — migration file written, not yet run against the live project
   - [x] Clerk + Supabase Third Party Auth setup: dashboard configuration, `clerk_flutter` dependency
     (AC-2, AC-11)
   - [x] Dual Supabase client wiring: second client on Clerk's `accessToken`, provider level switch
     (AC-1, AC-2, AC-6, AC-7)
   - [x] First launch welcome screen (Figma node 561:5267), Skip / continue browsing, `shared_preferences`
     seen flag, Profile tab back to its original empty placeholder, error messages wired through
     `ClerkErrorListener` (AC-1, AC-2, AC-3, AC-4, AC-6, AC-7, AC-8, AC-9, AC-10, AC-12) — Account screen
     itself is already built (sign out, delete account), just not yet linked from navigation; phone
     number still needs to be turned off in the Clerk dashboard by hand (AC-2)
   - [x] Account deletion webhook (`clerk-webhook` Edge Function) (AC-8) — function written, not yet
     deployed or given its signing secret
- [ ] Verify it: `/check verify auth`
- [ ] Test it: `/test auth`

Spec [0004](../specs/0004-clerk-authentication/index.md) · code:
`supabase/migrations/0001_clerk_auth.sql`, `supabase/schema.sql`,
`supabase/functions/clerk-webhook/index.ts`, `lib/core/config/clerk_config.dart`,
`lib/core/auth/active_supabase_client.dart`, `lib/core/auth/auth_session_controller.dart`,
`lib/features/profile/`, `lib/core/router/app_router.dart`, `lib/main.dart`

### 5. Profile screen · in-progress

Replaces the empty Profile tab placeholder with the real page from the Figma design: a signed in
person's name, photo, and stores followed count, editing name/username/bio, sign out, and delete
account, plus a set of rows for features that don't exist yet in this buyer only app, shown as
visual placeholders for now. An anonymous browser sees a short sign in message instead.
**Done when:** the Profile tab shows the real signed in page or the anonymous message depending on
session state, editing a profile works end to end, sign out and delete account are reachable there,
and every not yet built row opens a coming soon placeholder instead of doing nothing (see spec 0005
for the full acceptance criteria).
- [x] Design it (spec): `/architect clone profile page`
- [x] Build it: `/develop profile screen`
   - [x] Data layer and the signed in Profile page: `UserProfileRepository.updateUserProfile`,
     header (avatar, name, stores following count, Become a seller, Edit profile), Generals and Help
     and Legal sections, Log out and Delete account rows, replacing `ComingSoonScreen` on `/profile`
     for a signed in session (AC-1, AC-3, AC-4, AC-8, AC-9)
   - [x] Anonymous view for the same `/profile` route: sign in message plus a button to the existing
     sign in screen (AC-2)
   - [x] Edit profile screen: name/username/bio form with inline validation for blank fields and a
     taken username (AC-5, AC-6)
   - [x] Wire every remaining row to the existing coming soon placeholder, and delete the old
     unlinked `account_screen.dart` (AC-7, AC-8)
- [ ] Verify it: `/check verify profile screen`
- [x] Test it: `/test profile screen`

Spec [0005](../specs/0005-profile-screen/index.md) · code: `lib/features/profile/profile_screen.dart`,
`lib/features/profile/profile_anonymous_view.dart`, `lib/features/profile/edit_profile_screen.dart`,
`lib/shared/widgets/settings_row.dart`, `lib/data/repositories/user_profile_repository.dart`,
`lib/core/router/app_router.dart`
