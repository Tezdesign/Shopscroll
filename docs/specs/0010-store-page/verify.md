# Verify: Store Page · spec 0010 · updated 2026-10-01

_Steps derived from spec 0010 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._

## UI / manual

- [ ] Tap a store avatar in Home's "Most visited stores" row → opens `/store/:id` showing that seller → AC-1
- [ ] Tap a store avatar in Discover's store grid → opens `/store/:id` → AC-1
- [ ] Tap the store row on a product detail page → opens that seller's Store Page → AC-1
- [ ] Tap the store name/avatar on a reel's bottom overlay in the Reels player → opens that seller's Store Page → AC-1
- [ ] Store Page shows the seller's avatar, name, abbreviated follower count (e.g. "128K Followers"), a working back button, and a decorative report icon that does nothing when tapped → AC-2
- [ ] Follow and Message buttons render but do nothing when tapped → AC-3
- [ ] "Go to website" opens the seller's `websiteUrl` in an external browser when set; hidden when not set. Location row shows plain text when set; hidden when not set → AC-4
- [ ] Products/Reels `SegmentedTabs` switches between a 2 column product grid and a 3 column reel thumbnail grid, both scoped to the opened seller → AC-5
- [ ] Tapping a product in the Products grid opens product detail; "Add to cart" adds it to the cart → AC-6
- [ ] Tapping a reel thumbnail opens the full screen reel player, with the store's other reels as the swipe order → AC-7
- [ ] A seller with no products shows "<name> hasn't listed any products yet."; a seller with no reels shows "<name> hasn't posted any reels yet." → AC-8
- [ ] While a tab's data loads it shows a spinner; on a failed load it shows a message with "Try again" that reloads → AC-9
- [ ] Opening `/store/:id` with an id that matches no seller shows "Store not found" → AC-10
- [ ] The Store Page never renders the seller's email, phone, or bio → AC-11
- [ ] On Home, the "Tech Week Deals" banner (Apple) and "New Sneaker Drops" banner (Nike) open their seller's Store Page when tapped; the storewide "Fall Sale" banner stays non-interactive → AC-12
- [ ] The Store Page opens full screen, with no bottom tab bar → AC-13
- [ ] Every tappable element (back, Go to website, product cards, reel thumbnails) has a spoken accessibility label and at least a 44×44 point tap target → AC-14

## Commands

- [ ] `flutter test` → all tests pass (406+ at time of writing, including `test/features/store/store_page_screen_test.dart` and the `productsByStoreProvider`/`reelsByStoreProvider` cases in `test/data/providers_test.dart`) → AC-1 through AC-14
- [ ] `flutter analyze` → no issues found

## Acceptance-criteria coverage

- AC-1 covered by the four dead-tap wiring steps and the back-button test · AC-2 covered by the profile header UI step and widget test ("shows the seller avatar, name, follower count and products") · AC-3 covered by the Follow/Message UI step · AC-4 covered by the website/location UI step and widget test ("shows the website and location rows only when those fields are set") · AC-5 covered by the tab switcher UI step and the Products/Reels tab tests · AC-6 covered by the product tap-through/Add to cart UI step · AC-7 covered by the reel tap-through UI step and manual simulator check · AC-8 covered by the empty-tab UI steps and widget tests · AC-9 covered by the loading/error UI steps and the "a failed Products/Reels tab load" widget tests · AC-10 covered by the not-found UI step and widget test · AC-11 covered by the "never shows the bio, email or phone" widget test · AC-12 covered by the banner wiring UI step, verified live on the iOS Simulator · AC-13 covered by the route registration (`/store/:id` as a top-level route outside the shell) · AC-14 covered by the back button's 56×56 tap target and Semantics labels throughout the screen
