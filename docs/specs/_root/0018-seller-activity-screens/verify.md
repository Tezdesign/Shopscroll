# Verify: Seller Activity screens · spec 0018 · updated 2026-10-08
_Steps derived from spec 0018 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones. This file covers build plan tasks 1 to 4 (migrations `0014` and `0015`, data layer, Orders tab, order detail). Later slices append their own steps._

## UI / manual
- [ ] Sign in as a seller, open `/store`, tap "Activity" → `/store/activity` opens with the store logo and name, a chat icon, a bell icon, a search field, and the tabs Orders, Earnings, Reports, on Orders → AC-1
- [ ] Sign in as a buyer and open `/store/activity` directly → sent to the buyer area → AC-1
- [ ] Tap Earnings, then Reports, then Orders → the body swaps in place, the route stays `/store/activity` → AC-1
- [ ] Tap the "+" button → `/store/products/new` opens → AC-1
- [ ] Without Supabase config, Orders shows rows `Order#002545`, name, `Sousse, sahloul`, `Total : 450.000 TND`, and a status badge, 20 rows first → AC-2, AC-15
- [ ] Scroll to the end → a spinner shows and 10 more rows load, no row repeats → AC-2
- [ ] Pull down → the list reloads → AC-2
- [ ] An order with no contact name shows "Customer" and no address line → AC-2
- [ ] Tap Canceled → only canceled rows; tap Canceled again → all rows come back (Returned rows included) → AC-3
- [ ] Type `2545` then `002545` in the search → the same order is found; type `%` → "No results found for “%”" → AC-4
- [ ] Type a name, switch to Earnings and back → the text is still in the field → AC-4
- [ ] Turn off the network (or break the call) → "Couldn't load your orders." with a "Try again" button that reloads → AC-14
- [ ] Turn on VoiceOver → chips, tabs, rows and the "+" button read a clear label, and each tap target is at least 44 by 44 → AC-16

## Commands
- [ ] `docker exec -i supabase_db_localdb psql -U postgres -v ON_ERROR_STOP=1 < supabase/migrations/0014_store_orders.sql` (on a TEST or BRANCH database that is at migration `0013`) → no error → AC-13
- [ ] `docker exec -i supabase_db_localdb psql -U postgres -v ON_ERROR_STOP=1 < supabase/checks/store_activity.sql` → every check prints `ok`, ends with `ROLLBACK` → AC-2, AC-3, AC-4, AC-12, AC-13
- [ ] Run the same migration a second time on the same database → no error, no duplicate `store_orders` rows → AC-13
- [ ] `flutter analyze` (repo root) → no issues
- [ ] `cd apps/buyer && flutter test test/data/repositories/mock_store_activity_repository_test.dart test/features/seller_activity` → all pass → AC-2, AC-3, AC-4, AC-15
- [ ] Against a branch project: place an order with products of two stores as a buyer, then read `store_orders_list` as each seller → each sees only their own lines and total → AC-12, AC-13

## Acceptance-criteria coverage
- AC-1 … UI steps 1 to 4 (the route and button are built; the Earnings and Reports bodies are placeholders until slices 5 and 7) · AC-2 … UI steps 5 to 7, SQL checks · AC-3 … UI step 8, SQL checks · AC-4 … UI steps 9 and 10, SQL checks · AC-12 … SQL checks (for `store_orders_list` only; the other functions come with their slices) · AC-13 … migration steps, SQL checks · AC-14 … UI step 11 (Orders tab only) · AC-15 … mock steps (Orders tab only) · AC-16 … UI step 12 (Orders tab only)
- Not covered yet: AC-5 to AC-11 (later slices), AC-17 (closing pass)

## Task 4: order detail (migration `0015`)
### UI / manual
- [ ] Without Supabase config, tap an order row on the Orders tab → `/store/activity/orders/:id` opens with the order number, purchase date, status badge, this store's lines (photo slot, title, size, color dot, unit price, line total), a Subtotal row, and Customer, Delivery address, Delivery method and Payment method blocks → AC-5
- [ ] The detail has no delivery fee row, no "Total price" row, no download button and no status control → AC-5, AC-17
- [ ] Open the order with no contact name (the last one, `Order#002516`) → the Customer block says "Customer" with no email, phone, address, delivery or payment block → AC-5
- [ ] Open `/store/activity/orders/unknown` → "Order not found" → AC-5, AC-14
- [ ] Break the call (Supabase config with the network off) → "Couldn't load this order." with "Try again" that reloads → AC-14
- [ ] As a buyer, open `/store/activity/orders/<any id>` → sent to the buyer area → AC-1
- [ ] The status bar clock and icons are light on the dark Activity header and dark on the light detail page, and light again after Back → AC-1
- [ ] VoiceOver reads each line as "N times title, size, total" and the Back button as "Back", and every row and the Back button are at least 44 by 44 → AC-16

### Commands
- [ ] `docker exec -i supabase_db_localdb psql -U postgres -v ON_ERROR_STOP=1 < supabase/migrations/0015_store_order_detail.sql` (on a TEST or BRANCH database at `0014`) → no error → AC-5
- [ ] `docker exec -i supabase_db_localdb psql -U postgres -v ON_ERROR_STOP=1 < supabase/checks/store_activity.sql` → the AC-5 and AC-12 detail checks print `ok`, ends with `ROLLBACK` → AC-5, AC-12
- [ ] `cd apps/buyer && flutter test test/features/seller_activity test/data/repositories/mock_store_activity_repository_test.dart` → all pass → AC-5, AC-15
- [ ] Against a branch project: as seller B call `store_order_detail` with an order id that only seller A sold → `not_found`, same as an unknown id → AC-12

### Acceptance-criteria coverage (task 4)
- AC-5 … UI steps 1 to 4, SQL checks · AC-12 … SQL checks, branch step · AC-14 … UI steps 4 and 5 · AC-15 … mock steps · AC-16 … UI step 8 · AC-17 … UI step 2 · AC-1 … UI steps 6 and 7


## Task 5: earnings (migration `0016`)
### UI / manual
- [ ] Without Supabase config, open `/store/activity` and tap Earnings → four cards: Total Sales `478458.000 TND`, Today's Sales `12426.000 TND` with "6 New orders today", This Week's sales `90458.000 TND` with "32% more than last week", Customers `125` with "5 new customers today"; no "+ 36%" text → AC-6, AC-15
- [ ] Below the cards, "Recent sales" lists 4 rows (`Order#002545`, `Moetez ben attia`, `Sousse, sahloul`, amount in green) → AC-7
- [ ] Tap the arrow beside "Recent sales" → the Orders tab opens, the route stays `/store/activity` → AC-7
- [ ] Type text in the search field, then open Earnings → the numbers do not change; go back to Orders → the text is still there → AC-4
- [ ] Pull down on Earnings → the numbers reload → AC-14
- [ ] Break the call (Supabase config with the network off) → "Couldn't load your earnings." with "Try again" that reloads → AC-14
- [ ] On a store with no orders (Supabase) → all four cards show zero, no percent line under This Week's sales, and "No sales yet" under "Recent sales" → AC-6, AC-14
- [ ] VoiceOver reads each card as "label, value, note" and the arrow as "See all orders", and the arrow is at least 44 by 44 → AC-16

## Commands
- [ ] `docker exec -i supabase_db_localdb psql -U postgres -v ON_ERROR_STOP=1 < supabase/migrations/0016_store_earnings.sql` (database at `0014` and `0015`) → no error → AC-6
- [ ] `docker exec -i supabase_db_localdb psql -U postgres -v ON_ERROR_STOP=1 < supabase/checks/store_activity.sql` → every check prints `ok` (including AC-6, AC-7, AC-14 earnings checks), ends with `ROLLBACK` → AC-6, AC-7, AC-12, AC-14
- [ ] `cd apps/buyer && flutter test test/features/seller_activity` → all pass → AC-6, AC-7, AC-14, AC-16
- [ ] Against a branch project: as a seller, place and cancel orders, then read `store_earnings` → canceled and returned orders are not counted, another store's lines never add to the amounts → AC-6, AC-12

## Acceptance-criteria coverage (task 5)
- AC-6 … UI steps 1 and 4, SQL checks · AC-7 … UI steps 2 and 3, SQL checks · AC-14 … UI steps 5 to 7, SQL checks · AC-15 … UI step 1 · AC-16 … UI step 8
- Not covered yet: AC-8 to AC-11 (task 7), AC-17 (closing pass)

## Tasks 6 and 7: reports (migration `0017`)
### UI / manual
- [ ] Without Supabase config, tap Reports → three cards (Total Reports 25 with "N new reports today", Unresolved Reports in red, Returned Orders), then report cards starting with `#R-2589`, `May 15, 2025` style date, an Unsolved badge, title, customer, product with `Order #002545`, the description (3 lines at most), "View details" and "Resolve" → AC-8, AC-9, AC-15
- [ ] A report with several products shows "<first> and N more" → AC-9
- [ ] A resolved card (the fourth) shows Resolved and has no Resolve button → AC-9
- [ ] Scroll to the end → a spinner shows and 5 more reports load, no repeat; pull down → the list and the cards reload → AC-9
- [ ] Type `2589`, then `002589`, then `quality` in the search → matching cards; type `zzz` → "No results found for “zzz”" and the cards stay on top; switch to Earnings and back → the text is still there → AC-4
- [ ] Tap Resolve → the alert "Confirm resolution / Are you sure you want to mark this report as resolved?" shows; Cancel → nothing changes → AC-11
- [ ] Tap Resolve, then Confirm → the card shows Resolved at once and the Unresolved Reports card goes down by 1 → AC-11
- [ ] Tap View details (or the card body) → `/store/activity/reports/:id` opens with number, date, badge, title, Customer Information (name, email, phone), Products information (overlapping photos, titles, order number, purchase date), Problem details and `Attachment (2)` thumbnails → AC-10
- [ ] On the details page tap Mark as resolved, then Confirm → the badge shows Resolved and the button goes away; Back → the card and the Unresolved Reports card agree → AC-11
- [ ] Open `/store/activity/reports/unknown` → "Report not found"; break the call → "Couldn't load this report." with "Try again" → AC-14
- [ ] With the call failing (Supabase config, network off after the page loads), confirm Resolve → the card goes back to Unsolved and a snack bar says "Couldn't resolve this report. Try again." → AC-11
- [ ] As a buyer, open `/store/activity/reports/<any id>` → sent to the buyer area → AC-1
- [ ] Reports empty on Supabase (nothing creates reports yet) → "No reports yet", the cards show 0, Returned Orders shows 0 → AC-8, AC-14
- [ ] VoiceOver reads each card, the three number cards, both buttons and the Back button with a clear label, each at least 44 by 44 → AC-16
- [ ] No screen has a control that changes an order status or creates a report → AC-17

### Commands
- [ ] `docker exec -i supabase_db_localdb psql -U postgres -v ON_ERROR_STOP=1 < supabase/migrations/0017_reports.sql` (on a database already at `0014`) → no error; run it a second time → no error → AC-12
- [ ] `docker exec -i supabase_db_localdb psql -U postgres -v ON_ERROR_STOP=1 < supabase/checks/store_activity.sql` → every check prints `ok` (the new section starts at "AC-12 an item of another store cannot join a report"), ends with `ROLLBACK` → AC-4, AC-8 to AC-12, AC-17
- [ ] `flutter analyze` (repo root) → no issues
- [ ] `cd apps/buyer && flutter test test/data/repositories/mock_store_reports_test.dart test/features/seller_activity` → all pass → AC-8 to AC-11, AC-14, AC-15
- [ ] Against a branch project: insert a report as the table owner, open it as its seller (details and signed attachment links load, valid one hour), resolve it from two devices → the same `resolved_at` on both → AC-10, AC-11
- [ ] Against a branch project: seller B calls `store_report_detail` and `resolve_report` with seller A's report id → `not_found` → AC-12

### Acceptance-criteria coverage (tasks 6 and 7)
- AC-8 … UI steps 1 and 13, SQL checks · AC-9 … UI steps 1 to 4, SQL checks · AC-10 … UI step 8, SQL checks (contact, products, attachment folder) · AC-11 … UI steps 6, 7, 9 and 11, SQL checks (twice, constraint) · AC-12 … SQL checks (not_found, not_seller, no_session, anon role, direct tables, foreign keys) · AC-14 … UI steps 10 and 13 · AC-15 … UI steps 1 to 9 · AC-16 … UI step 14 · AC-17 … UI step 15, SQL checks
