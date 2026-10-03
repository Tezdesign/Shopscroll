# Verify: Activity screens · spec 0008 · updated 2026-09-26
_Steps derived from spec 0008 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._

## UI / manual
- [ ] Tap Activity in the bottom bar → `/activity` opens on Purchases, with a search field, three tabs, and the tab bar visible with Activity highlighted; tap "My collection" then "Messages" → the body swaps and the route stays `/activity`   → AC-1
- [ ] Type "  nike " in the search field on each tab → the list narrows live, ignoring case and spaces; switch tabs → the text stays and applies; type "zzzz" → "No results found for “zzzz”"   → AC-2
- [ ] On Purchases → one block per order, newest first, with a date like `2 Jul` (plus the year if not this year), a chevron, two thumbnails, "+ N products" when there are more than two items, a total like `$150`, and the right status badge   → AC-3
- [ ] Tap a Purchases block → "Order details coming soon" opens with the tab bar visible   → AC-4
- [ ] My collection → Products pill is active first; saved products list newest saved first with a filled bookmark; tap a row body → product detail opens   → AC-5
- [ ] My collection → Reels pill → saved reels in two columns, newest first, bookmark at the top right; tap an available reel → the player opens on it and pages through the saved available reels only; an unavailable saved reel is dimmed with "No longer available", does not open, and its bookmark clears it   → AC-6
- [ ] Tap a bookmark on a collection card → it disappears at once, "Removed from saved" with "Undo" shows and goes away after about 4 seconds; tap Undo → the item is back in its old place   → AC-7
- [ ] Open a product, tap the bookmark → "Added to saved products" toast, bookmark fills; leave and reopen → still filled; open Activity → My collection → it is first in the list. Save a reel in the Reels player → it shows in the Reels pill   → AC-8
- [ ] Run on Supabase (`flutter run --dart-define-from-file=env.json`), save a product, fully restart the app → it is still saved   → AC-9
- [ ] Turn the network off (or make the write fail), tap a bookmark → the item goes back and "Couldn't update your saved items. Try again." shows   → AC-10
- [ ] Messages → newest first; each row has a round avatar, store name, last message, and a time like `4:25am` (today) or `27 Feb`; the unread row is in the darker text colour; tap a row → "Chat coming soon"   → AC-11
- [ ] Each list shows a spinner while loading; a failed load shows "Couldn't load purchases." / "Couldn't load your collection." / "Couldn't load your messages." with "Try again"; empty lists show "No purchases yet", "No saved products yet", "No saved reels yet", "No messages yet"   → AC-12
- [ ] On the Supabase backend open Messages → "No messages yet"   → AC-13
- [ ] With a screen reader on, each tab, the search field, each bookmark, row and card is announced with a label; tap areas are at least 44 by 44   → AC-14
- [ ] Open the Reels tab → the grid looks the same as before with no bookmarks, likes still reset on leaving; nothing on these screens creates an order or a message   → AC-15

## Commands
- [ ] `flutter analyze` → no issues   → all
- [ ] `flutter test` → all pass, including `test/features/activity/`, `test/data/saved_notifier_test.dart`   → AC-2, AC-3, AC-5, AC-6, AC-7, AC-8, AC-10, AC-11, AC-12, AC-14, AC-15
- [ ] `supabase db push` (linked project) → migration `0002_product_saves.sql` applies   → AC-9
- [ ] Query the live database: `product_saves` exists with primary key (`user_id`, `product_id`), index on `product_id`, RLS on, three policies (select, insert, delete), and deleting a product removes its saves   → AC-9
- [ ] As a second person, try to read or delete the first person's `product_saves` row → denied   → AC-9

## Acceptance-criteria coverage
- AC-1 … UI step 1, widget test · AC-2 … UI step 2, `activity_logic_test`, widget test · AC-3 … UI step 3, `activity_logic_test`, widget test · AC-4 … UI step 4, widget test · AC-5 … UI step 5, widget test · AC-6 … UI step 6, widget tests · AC-7 … UI step 7, `saved_notifier_test`, widget test · AC-8 … UI step 8, `saved_notifier_test`, product detail test · AC-9 … UI step 9, migration commands · AC-10 … UI step 10, `saved_notifier_test`, widget test · AC-11 … UI step 11, widget test · AC-12 … UI step 12, widget tests · AC-13 … UI step 13, widget test with an empty repository · AC-14 … UI step 14, widget tests · AC-15 … UI step 15, `reel_card_test`
