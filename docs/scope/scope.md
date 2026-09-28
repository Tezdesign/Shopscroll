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
| 6 | Log in | Unplanned | in-progress |
| 7 | Search flow | Unplanned | in-progress |
| 8 | Banner screens | Unplanned | planned |
| 9 | Cart interface | Unplanned | in-progress |
| 10 | Activity screens | Unplanned | in-progress |
| 11 | Order details | Unplanned | planned |
| 12 | Chat | Unplanned | planned |
| 13 | Purchasing flow | Unplanned | in-progress |
| 14 | Card payment | Unplanned | planned |
| 15 | Discount codes | Unplanned | planned |

## Features

### 1. Discover screen · in-progress

A search first browse screen (search field, category tabs, a store grid, a product feed with promo
banners), reachable from the bottom nav's Discover tab. Building it also introduces a persistent
navigation shell so tab switching preserves each tab's state.
**Done when:** Discover is reachable from the bottom nav, its search and category filters work
live, and switching tabs preserves state (see spec 0001 for the full acceptance criteria).
- [x] Design it (spec): `/architect discover screen`
- [x] Build it: `/develop discover screen`
   - [x] Navigation shell: `StatefulShellRoute` (Home/Discover branches + placeholder branches for
     Reels/Activity/Profile), bottom nav wiring (AC-1)
   - [x] Discover screen shell: search field + category tabs, rendering the product feed live from
     the existing providers (AC-1, AC-3)
   - [x] Live client side search filter (AC-2)
   - [x] Store grid section, reusing `MostVisitedItem` (AC-4)
   - [x] Promo banner tiles, per section loading/error/empty states, and product tap-through to
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
   - [x] Redesigned sign up screens (get started, phone number, email address, shared code entry),
     reachable from Welcome's Sign up, with their own field checks and tests; their send and verify
     actions do nothing yet (AC-2, AC-9, AC-13)
   - [x] Wire the sign up screens to Clerk's code sign up: start and verify with the phone or email code,
     carry the name and username, resend, and route Clerk errors to the error listener (AC-2, AC-9,
     AC-12, AC-13, AC-14)
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

### 6. Log in · in-progress · ⚠ spec pending

A way for people who already have an account to sign back in. The earlier Log in screen (Clerk's prebuilt
card) was deleted, so Welcome's Log in opens a coming soon placeholder today and returning people
cannot sign in. Probably reuses the same phone or email one time code as sign up, but its design and
behaviour are undecided.
**Done when:** Welcome's Log in lets a person with an existing account sign in with a one time code, and
their anonymous cart carries over as it does on sign up (see spec 0004, AC-3).
- [ ] Design it (spec): `/architect log in` — built ahead of its spec at the engineer's call, off the
  six Figma frames. Spec 0004 explicitly excludes Log in ("Not in this pass"), so this screen has no
  acceptance criteria of its own yet; backfill them.
- [x] Build it: `/develop log in`
   - [x] `LogInScreen`: two stages in place (identifier then one time code), the "Who are you"
     toggle, email and phone channel switch, footer links
   - [x] `SignInVerification`: Clerk `emailCode`/`phoneCode` sign in wired through the router at
     `/sign-in`, replacing the `ComingSoonScreen` placeholder
- [ ] Verify it: `/check verify log in`
- [ ] Test it: `/test log in`

From spec [0004](../specs/0004-clerk-authentication/index.md) · code:
`lib/features/onboarding/log_in_screen.dart`,
`lib/features/onboarding/sign_in_verification.dart`, `lib/core/router/app_router.dart`

### 7. Search flow · in-progress

A real search screen, opened by tapping the search field on Home or Discover, that walks a person from
nothing typed, to suggestions as they type, to a result list, with a Stores tab for finding a seller.
It searches on the device over the products and sellers the app already loads, and it replaces
Discover's live inline filter.
**Done when:** tapping the search field on Home or Discover opens the search screen, suggestions,
results and the Stores tab work, every state (nothing typed, loading, error, no results) is handled, and
Discover's own filter is gone (see spec 0006 for the full acceptance criteria).
- [x] Design it (spec): `/architect search flow`
- [ ] Build it: `/develop search flow`
   - [x] Entry points and routing: Home and Discover fields open the screen, Cancel and back, blank
     start, Discover's inline filter removed (AC-1, AC-2, AC-12)
   - [x] Search logic and the results thread: matching, suggestion phrases, the result list, opening a
     product (AC-5, AC-6, AC-7, AC-8, AC-13)
   - [x] Suggestions view, Items and Stores tabs, category chips and the nothing typed categories row,
     with plain tinted tiles rather than photos (AC-3, AC-4, AC-5, AC-11)
   - [x] Deals chip, the local add to cart toggle, and store tiles that open a store's results (AC-7,
     AC-8, AC-9)
   - [ ] Loading, error and no results states, accessibility, and widget tests are done; the keyboard
     and tab bar check on a real device is still outstanding (AC-1, AC-10, AC-14)
- [ ] Verify it: `/check verify search flow`
- [ ] Test it: `/test search flow`

Spec [0006](../specs/0006-search-flow/index.md) · code: `lib/features/search/search_screen.dart`,
`lib/features/search/search_logic.dart`, `lib/shared/widgets/search_field.dart`,
`lib/core/router/app_router.dart`

### 8. Banner screens · planned · needs a decision

Make the promo banners tappable and design the screen a banner opens. The banners on Home and Discover
are static tiles today, and nothing happens when one is tapped. Split out of the search flow work, which
covers only search.
**Done when:** tapping a promo banner opens a screen for that campaign, with its states handled (see the
spec once it exists).
- [ ] Design it (spec): `/architect banner screens`
- [ ] Build it: `/develop banner screens`
- [ ] Verify it: `/check verify banner screens`
- [ ] Test it: `/test banner screens`

From spec [0006](../specs/0006-search-flow/index.md)

### 9. Cart interface · in-progress

A real cart screen opened from the cart icon on Home, inside the Home tab, that lists each item with a
quantity stepper and a trash icon (with Undo), shows the total, and leads to a coming soon checkout page.
It also makes every Add to cart button (product detail, product cards, search rows) really add to the
saved cart, on both the mock and Supabase backends.
**Done when:** the cart opens from Home, quantities change and items remove with Undo, the total is
right, every Add to cart button adds to the same saved cart, and the empty, loading, error and out of
stock states are handled (see spec 0007 for the full acceptance criteria).
- [x] Design it (spec): `/architect the cart interface`
- [x] Build it: `/develop cart interface`
   - [x] Cart data layer: repository write methods (mock and Supabase), cart helper functions, and the
     `CartNotifier` with optimistic updates (AC-4, AC-5, AC-6, AC-13, AC-15, AC-16)
   - [x] Cart screen thread: `/cart` route under Home, header cart icon, item list and total, product
     detail Add to cart wired (AC-1, AC-2, AC-3, AC-10)
   - [x] Steppers, trash with Undo, empty, loading and error states, checkout coming soon page (AC-4,
     AC-5, AC-6, AC-7, AC-8, AC-9)
   - [x] Product card and search row Add to cart wired, out of stock and failure messages, `ItemCard`
     size label and colour dot (AC-2, AC-11, AC-12, AC-14, AC-15)
   - [x] Accessibility and widget tests (AC-17, AC-18)
- [ ] Verify it: `/check verify cart interface`
- [ ] Test it: `/test cart interface`

Spec [0007](../specs/0007-cart-interface/index.md) · code: `lib/features/cart/`,
`lib/data/providers/cart_providers.dart`, `lib/data/repositories/cart_repository.dart` (mock and
Supabase), `lib/shared/widgets/item_card.dart`, `lib/core/router/app_router.dart`

### 10. Activity screens · in-progress

The Activity tab as one screen with three tabs: Purchases (past orders with their status), My collection
(saved products and saved reels) and Messages (a list of store conversations). It also makes the bookmark
on product detail and in the Reels player save for real, so the collection is stored per person.
**Done when:** the Activity tab opens the three tabs, saved products and reels list in My collection and
can be removed with Undo, Purchases shows the orders, Messages shows the mock conversations, and every
list handles its loading, error and empty states (see spec 0008 for the full acceptance criteria).
- [x] Design it (spec): `/architect activity screens`
- [x] Build it: `/develop activity screens`
   - [x] Saves data layer: `product_saves` migration applied, saved product and reel save repositories
     (mock and Supabase), the two optimistic saved notifiers (AC-7, AC-8, AC-9, AC-10)
   - [x] Activity screen thread: `/activity` route, search field and top tabs, saved products list,
     product detail bookmark wired (AC-1, AC-5, AC-8)
   - [x] Reels pill, `ReelCard` bookmark, Reels player bookmark wired, unsave with Undo (AC-6, AC-7, AC-8,
     AC-10)
   - [x] Purchases and Messages tabs with their coming soon routes, and the search filter for every tab
     (AC-2, AC-3, AC-4, AC-11, AC-13)
   - [x] Loading, error and empty states, accessibility and widget tests (AC-12, AC-14, AC-15)
- [ ] Verify it: `/check verify activity screens`
- [ ] Test it: `/test activity screens`

Spec [0008](../specs/0008-activity-screens/index.md) · code: `lib/features/activity/`,
`lib/data/providers/saved_providers.dart`, `lib/data/repositories/saved_product_repository.dart`,
`lib/data/repositories/conversation_repository.dart` (mock and Supabase), `lib/shared/widgets/pill_tabs.dart`,
`supabase/migrations/0002_product_saves.sql` (applied), `lib/core/router/app_router.dart`

### 11. Order details · planned · needs a decision

Design and build the screen a Purchases block opens: the items, delivery and payment details and the
status of one order. The Activity screens only open a "coming soon" page today.
**Done when:** tapping a purchase opens a real order detail screen with its states handled (see the spec
once it exists).
- [ ] Design it (spec): `/architect order details`
- [ ] Build it: `/develop order details`
- [ ] Verify it: `/check verify order details`
- [ ] Test it: `/test order details`

From spec [0008](../specs/0008-activity-screens/index.md)

### 12. Chat · planned · needs a decision

Design and build buyer to store chat: conversations, messages and sending, a table behind them, and the
Chat now button on product detail. The Messages tab lists mock conversations only until this exists.
**Done when:** a buyer can open a conversation from the Messages tab or product detail and exchange
messages with a store, with its states handled (see the spec once it exists).
- [ ] Design it (spec): `/architect chat`
- [ ] Build it: `/develop chat`
- [ ] Verify it: `/check verify chat`
- [ ] Test it: `/test chat`

From spec [0008](../specs/0008-activity-screens/index.md)

### 13. Purchasing flow · in-progress

A full screen Checkout (shipping items, contact, delivery address, delivery type, order summary, payment
method), two bottom sheets for contact and address, and an Order confirmation screen. A buyer, signed in or
not, pays on delivery and a real order is made on the server from their cart. Card payment, discount codes
and "use my location" are drawn but do nothing yet.
**Done when:** "Proceed to checkout" opens Checkout, a completed Pay on delivery order creates one priced
order, empties the cart, shows the confirmation and appears in Purchases, and buyers can no longer write
orders directly (see spec 0009 for the full acceptance criteria).
- [x] Design it (spec): `/architect purchasing flow`
- [x] Build it: `/develop purchasing flow`
   - [x] Models, checkout logic and the shared checkout widgets (AC-4, AC-6, AC-7, AC-8, AC-9, AC-15, AC-23)
   - [x] Contact and address sheets, the Checkout screen and Place order on the mock backend (AC-1, AC-2,
     AC-3, AC-5, AC-10, AC-11, AC-12, AC-13, AC-16)
   - [x] Order confirmation screen, routes, discard dialog (AC-14, AC-17, AC-18, AC-19, AC-22)
   - [x] Migration `0003_place_order.sql` and the Supabase `placeOrder`, plus the Purchases fix for signed in
     buyers (AC-12, AC-15, AC-16, AC-20, AC-21)
   - [x] Accessibility, states and widget tests (AC-22, AC-23, AC-24, AC-25)
- [ ] Verify it: `/check verify purchasing flow`
- [ ] Test it: `/test purchasing flow`

Spec [0009](../specs/0009-purchasing-flow/index.md) · code: `lib/features/checkout/`,
`lib/data/providers/checkout_providers.dart`, `lib/data/models/place_order_request.dart`,
`lib/data/repositories/order_repository.dart` (mock and Supabase), `lib/shared/widgets/checkout_section.dart`,
`lib/shared/widgets/shipping_items_section.dart`, `supabase/migrations/0003_place_order.sql` (applied),
`lib/core/router/app_router.dart`

### 14. Card payment · planned · needs a decision

Make "Pay by Credit Card" real: the card sheet (Figma 3001:10507 and 3001:10527), the "card added" state, and
a payment provider with a hosted card form so card numbers never touch this app or database.
**Done when:** a buyer can pay by card at checkout and the order records it as paid (see the spec once it
exists).
- [ ] Design it (spec): `/architect card payment`
- [ ] Build it: `/develop card payment`
- [ ] Verify it: `/check verify card payment`
- [ ] Test it: `/test card payment`

From spec [0009](../specs/0009-purchasing-flow/index.md)

### 15. Discount codes · planned · needs a decision

Make the discount code field at checkout real: a codes table, a percent per store, the "Discount from a store"
line and the crossed out price (Figma 3001:10221 and 3001:10085).
**Done when:** a valid code lowers the price to pay, checked on the server, and an invalid one shows a message
(see the spec once it exists).
- [ ] Design it (spec): `/architect discount codes`
- [ ] Build it: `/develop discount codes`
- [ ] Verify it: `/check verify discount codes`
- [ ] Test it: `/test discount codes`

From spec [0009](../specs/0009-purchasing-flow/index.md)
