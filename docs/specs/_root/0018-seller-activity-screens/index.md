# 0018. Seller Activity screens: orders, earnings and reports

**Date**: 2026-10-08
**Status**: In Progress

## Summary

A seller gets an Activity area at `/store/activity` with three tabs: Orders (a filterable list, with an order detail page), Earnings (sales and customer numbers) and Reports (problems raised on their orders, with a Resolve action). To make this possible, each order is split on the server into one row per store (`store_orders`, with its own status), and every order line now says which store sold it. The seller reads everything through server functions that return only their own part of an order, never the whole order. The seller cannot change an order status, and buyers cannot create reports yet, so the Reports tab starts empty. Design source: the four `Activity` frames of the Figma page "The design - seller", with deviations listed below.

Reasoning and options: see [rationale.md](rationale.md).

## Requirements

**User stories**:
- As a seller, I want to see the orders that contain my products, filtered by status and searched by order number or customer, so that I know what to prepare and send.
- As a seller, I want to open an order and see my products, the customer and the delivery address, so that I can fulfil it.
- As a seller, I want to see my sales today, this week and in total, and how many customers I have, so that I know how the store is doing.
- As a seller, I want to see the problems customers reported and mark one resolved, so that I can keep my support work in one list.
- As a seller whose order mixes products from other stores, I want to see only my own lines and my own total, so that I never see what other sellers sold.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1** (entry and shell): A seller opens `/store/activity` from a new "Activity" button on the `/store` page. A non seller is sent away by `SellerGate`, on `/store/activity` and on both detail routes (`/store/activity/orders/:id`, `/store/activity/reports/:id`). The screen shows the store header (logo and store name from the profile, a chat icon and a bell icon that do nothing yet), a search field, and the tabs Orders, Earnings and Reports, opening on Orders. Tapping a tab swaps the body in place and keeps the route. The "+" floating button opens `/store/products/new`.
- **AC-2** (orders list): The Orders tab lists one row per store order, newest first: `Order#` and the order number with 6 digits, the customer name, the delivery `city, address` on one line, `Total :` and this store's total in the order's currency with 3 decimals (like `450.000 TND`), and a status badge (Delivered, In progress, Canceled or Returned). It loads 20 rows at a time, loads the next 20 on reaching the end, and refreshes by pulling down. Orders placed before migration `0003` have no contact or address: the name shows "Customer" and the address line is left out.
- **AC-3** (status filter): The three chips Delivered, In progress and Canceled filter the list. Only one chip is active at a time, and tapping the active chip clears the filter. With no chip active every order shows, including Returned ones.
- **AC-4** (search): Typing in the search field narrows the Orders list on the server by order number (digits, typed with or without the leading zeros, so `123` and `000123` both find order 123) or customer name, ignoring case and surrounding spaces, and treating `%` and `_` as plain characters. The typed text stays when the tab changes and applies to the Reports tab too (report number, customer name or title). The Earnings tab ignores it. When nothing matches, the tab shows "No results found for “<text>”".
- **AC-5** (order detail): Tapping an order opens `/store/activity/orders/:id`. It shows the order number, date and status badge, only this store's lines (photo, title, size, color, unit price, quantity), this store's subtotal (no delivery fee, no other store's lines), the customer name, email and phone, the delivery city, address, zip and note, and the delivery and payment methods. It is read only. An order that has no line from this store shows "Order not found", the same as an unknown id.
- **AC-6** (earnings numbers): The Earnings tab shows four cards: Total Sales, Today's Sales with "N New orders today", This Week's sales with "X% more than last week" or "X% less than last week", and Customers with "N new customers today". A sale counts every store order that is not Canceled and not Returned. Amounts use the store currency. "Today" and "this week" use the Africa/Tunis day, and the week starts on Monday. The percent compares the week so far with the same span of the week before, rounds to a whole number, and is hidden when the week before had no sales. Customers counts distinct buyers with at least one counted order, and "new today" counts those whose first counted order is today.
- **AC-7** (recent sales): Below the cards, "Recent sales" lists the 4 latest counted store orders (order number, customer name, `city, address`, amount in green). The arrow beside the title switches to the Orders tab.
- **AC-8** (reports summary): The Reports tab shows Total Reports with "N new reports today", Unresolved Reports (red) and Returned Orders (the number of this store's orders with status Returned, which is 0 until a later spec sets that status).
- **AC-9** (reports list): Below the summary, report cards are listed newest first, 20 at a time like AC-2: `#R-` and the report number with 4 digits, the date (like `May 15, 2025`), a badge Unsolved or Resolved, the title, the customer name, the first product title with its `Order #` and number ("and N more" when several), the description (3 lines at most), a "View details" button and a "Resolve" button. A resolved card has no Resolve button.
- **AC-10** (report details): "View details" opens `/store/activity/reports/:id`: the report number, date, badge and title, Customer Information (name, email and phone from the order contact), Products information (stacked photos, titles, order number, purchase date), Problem details (the description), and Attachment (N) as thumbnails loaded through signed links valid for one hour. A "Mark as resolved" button shows while the report is Unsolved.
- **AC-11** (resolve): Resolve and Mark as resolved open the Figma alert "Are you sure you want to mark this report as resolved?". Confirming calls `resolve_report`, sets `status = 'resolved'` and `resolved_at = now()`, and the card, the details page and the Unresolved Reports card show Resolved at once. Cancelling changes nothing. Resolving twice is a no op that succeeds. If the call fails the state goes back and a snack bar says "Couldn't resolve this report. Try again."
- **AC-12** (isolation and rights): A seller reads only rows of their own store. An order id or report id of another store gives `not_found`. A buyer calling any of the functions gets `not_seller`, an anonymous session gets `no_session`, and a caller with no session at all is refused by Postgres (execute is revoked from `public` and `anon`). No client can read or write `store_orders`, `reports` or `report_items` directly, and no function returns the buyer's account id, the whole order total, the delivery fee or another store's lines.
- **AC-13** (orders get a store): After the migration, `place_order` writes `order_items.store_id` from the product, and one `store_orders` row per distinct store of the cart with status `inProgress` and the order's `created_at`, in the same transaction as the order. A cart with two stores gives two rows. Orders placed before the migration are filled from `order_items.product_id`, keeping their status, by a backfill that can be run again safely (`on conflict do nothing`). A line whose product no longer exists keeps no store and shows to no seller.
- **AC-14** (states): Each tab and each detail page shows a loading indicator, a failure message with a "Try again" button, and an empty message ("No orders yet", "No sales yet", "No reports yet"). The Earnings numbers show zero for a store with no orders.
- **AC-15** (mock backend): Without Supabase configuration the three tabs and both detail pages work on mock data (the values drawn in Figma) with the usual 300 ms delay, and resolving works in memory. Both backends behave the same to the screens.
- **AC-16** (accessibility): Tabs, chips, rows, cards, the floating button and every action have a spoken label and a tap area of at least 44 by 44 logical pixels.
- **AC-17** (scope guard): Nothing in this spec lets a seller change a store order status, creates a report, writes `orders.status`, or sends a message or notification to a buyer.

## Decision

**Chosen option**: Option 1: a per store order table, read through filtering functions

Add `store_orders` (one row per order and store, with its own status) and `order_items.store_id`, keep `orders` and `order_items` closed to sellers (they already are), and give the app seven `security definer` functions plus a private storage bucket, so each seller reads only their own slice of an order.

**Implementation skills**: `supabase` (`supabase/agent-skills`, `.agents/skills/supabase/`) · `supabase-postgres-best-practices` (`supabase/agent-skills`, `.agents/skills/supabase-postgres-best-practices/`)

## Feature design

**Design source**: Figma file `toOakybJ0DaJmU7vcEC0AW`, page "The design - seller": Activity-orders-seller (`3001:11659`), Activity-earnings-seller (`3001:11790`), Activity-reports-seller (`3001:11908`), report details-seller (`3001:11979`), and the Alert "mark as resolved" on the user page (`860:5916`). The flow header marks the frames "Work in Progress". Deviations from the frames, to record in each screen's doc comment:
- No order detail frame exists. The order detail copies the buyer receipt layout ("order receipt-user", `3001:9058`, code in `apps/buyer/lib/features/activity/order_receipt_screen.dart`) with this store's lines only (AC-5).
- The Figma money shows `$`. The app shows the store currency with 3 decimals (spec 0015 AC-9), through the shared `Money` type.
- The "+ 36%" text on Total Sales is hidden in the frame and is left out.
- The bottom tab bar and status bar in the frames belong to the seller shell, which has no spec yet. The chat and bell icons are drawn but inert.
- "Sousse,sahloul" is shown as the order's `ship_city, ship_address`.
- Returned is a fourth badge that Figma does not draw. It reuses the three badge styles and adds one neutral style from the tokens.

**Data model sketch** (migrations `0014_store_orders.sql`, `0015_store_order_detail.sql`, `0016_store_earnings.sql` and `0017_reports.sql`, one per build slice because an applied migration is never run again):

New table `store_orders`, one row per store inside an order:

| Column | Type | Rules |
|---|---|---|
| `order_id` | uuid | part of the primary key, foreign key to `orders (id)`, on delete cascade |
| `store_id` | text | part of the primary key, the Clerk id of the seller, no foreign key (same as `orders.user_id`) |
| `status` | text | not null, default `inProgress`, check in (`inProgress`, `delivered`, `canceled`, `returned`) |
| `created_at` | timestamptz | not null, copied from the order, never changes, orders the list |
| `updated_at` | timestamptz | not null, default now(), kept by a `touch_updated_at` trigger created on this table (the function exists from `0008`) |

Indexes: `(store_id, created_at desc, order_id desc)` (serves the list and its paging) and `(store_id, status)`.

Changed table `order_items`: add `store_id text` (null for lines whose product is gone), index on `(store_id, order_id)`, and a unique index on `(id, order_id, store_id)` for the report foreign key below.

New table `reports`:

| Column | Type | Rules |
|---|---|---|
| `id` | uuid | primary key, default `gen_random_uuid()` |
| `report_number` | bigint | `generated always as identity`, unique, shown as `#R-0001` |
| `order_id` | uuid | not null |
| `store_id` | text | not null |
| `reporter_id` | text | not null, the buyer's Clerk id (private, never returned) |
| `title` | text | not null, 1 to 120 characters |
| `description` | text | not null, 1 to 2000 characters |
| `attachment_paths` | text[] | not null, default `{}`, at most 6 storage paths |
| `status` | text | not null, default `unsolved`, check in (`unsolved`, `resolved`) |
| `created_at` | timestamptz | not null, default now() |
| `resolved_at` | timestamptz | null until resolved, set together with `status` (check) |

Foreign key `(order_id, store_id)` to `store_orders (order_id, store_id)` with `on delete cascade`, so a report only points at a store that sold in that order and goes away with the order. Unique `(id, order_id, store_id)` for the foreign key below. Indexes: `(store_id, created_at desc, id desc)` and `(store_id, status)`. There is no report type column: the Returned Orders card counts store orders with status `returned`, not reports.

New table `report_items`: `report_id`, `order_item_id`, `order_id` and `store_id`, primary key on `(report_id, order_item_id)`. Foreign key `(report_id, order_id, store_id)` to `reports (id, order_id, store_id)` and foreign key `(order_item_id, order_id, store_id)` to `order_items (id, order_id, store_id)`, both `on delete cascade`, so the database itself guarantees that each item belongs to the report's order and store.

Storage: private bucket `report-attachments`, object path `<store_id>/<report_id>/<file>`.

**State transitions**:
- `store_orders.status`: `inProgress` to `delivered`, `canceled` or `returned` (`delivered` to `returned`). Nothing in this spec writes it after `place_order`.
- `reports.status`: `unsolved` to `resolved` only, through `resolve_report`. No way back.

**API surface** (every function is `security definer`, `search_path = ''`, first line `require_seller()`, execute granted to `authenticated` only):

| Function | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|
| `store_orders_list` | `p_status` text (opt), `p_search` text (opt), `p_limit` int (default 20, max 50), `p_cursor_created_at` timestamptz and `p_cursor_order_id` uuid (opt, both or neither) | rows of `order_id`, `order_number`, `status`, `customer_name`, `city`, `address`, `total`, `currency` (the order's), `created_at` | seller | `no_session`, `not_seller`, `bad_status`, `bad_cursor` |
| `store_order_detail` | `p_order_id` uuid (req) | order header, customer contact, delivery fields, this store's `lines`, `subtotal`, `currency` | seller | `not_found` |
| `store_earnings` | none | `total_sales`, `today_sales`, `today_orders`, `week_sales`, `prev_week_same_span_sales` (last week up to the same weekday and time), `customers`, `new_customers_today`, `currency` (the store profile's, `TND` if empty), `recent` (4 rows of `order_id`, `order_number`, `customer_name`, `city`, `address`, `amount`) | seller | |
| `store_reports_summary` | none | `total`, `new_today`, `unresolved`, `returned_orders` | seller | |
| `store_reports_list` | `p_status` (`unsolved` or `resolved`, opt), `p_search` (opt), `p_limit`, `p_cursor_created_at`, `p_cursor_id` uuid | rows of `id`, `report_number`, `created_at`, `status`, `title`, `customer_name`, `first_item_title`, `item_count`, `order_number`, `description` | seller | `bad_status`, `bad_cursor` |
| `store_report_detail` | `p_report_id` uuid (req) | report fields, customer contact, `items` (title, photo, order number, purchase date), `attachment_paths` | seller | `not_found` |
| `resolve_report` | `p_report_id` uuid (req) | `status`, `resolved_at` | seller | `not_found` |
| Storage `createSignedUrls` | paths from `attachment_paths`, 3600 seconds | signed links | seller (select policy on the store's own folder) | missing object |
| `place_order` (changed) | same signature | same | signed in | no new reasons |

Rules shared by the list functions: sort by `created_at desc` then the id desc, and page with a keyset on those two (a new order arriving during paging never repeats a row; an order whose transaction commits late can show only after a refresh). The app sends the cursor timestamp back as the raw string the function returned, never through a Dart `DateTime`, which would lose microseconds. A cursor with only one part is refused with `bad_cursor`. The search uses `strpos(lower(...))`, not `like`, so `%` and `_` are plain text, and compares an order or report number as text after stripping the leading zeros of the input. A null contact name (orders before `0003`) shows as "Customer" and never matches a name search. `total` and `subtotal` are the sum of `unit_price * quantity` over this store's lines. A row's currency is the order's `orders.currency`. "Today" and "week" are computed in Africa/Tunis, week from Monday (the same zone `place_order` already uses for delivery dates). Every function revokes execute from `public` and `anon` explicitly (Supabase grants it by default) before granting it to `authenticated`.

**Key invariants**:
- A `store_orders` row exists for an order and a store if and only if the order has at least one line with that `store_id` (kept by `place_order` and the backfill).
- A report's `(order_id, store_id)` exists in `store_orders`, and each of its `report_items` is a line of that order and that store (both enforced by foreign keys, and tested in `supabase/checks/store_activity.sql`).
- `reports.resolved_at is not null` exactly when `status = 'resolved'` (check constraint).
- No function returns `orders.user_id`, `orders.total_amount`, `orders.delivery_fee`, `reports.reporter_id` or another store's lines.
- The Earnings sum, the order list totals and the order detail subtotal come from the same line sum, so they always agree.

**Security model**:
- `store_orders`, `reports` and `report_items`: row level security on, no policy, and `revoke all` from `anon` and `authenticated`. The `orders` and `order_items` policies are not widened; sellers reach them only inside the functions.
- Every function calls `require_seller()` first (anonymous sessions and non sellers are refused) and then filters on `store_id = (select auth.jwt() ->> 'sub')`.
- `report-attachments` is private. The select policy allows the folder `<caller id>/` to a seller only. No client insert policy exists in this spec, because only a later buyer feature uploads.
- Personal data: the seller sees a customer's name, email, phone and address for orders that contain their products, which fulfilment needs. No payment data and no buyer account id is exposed. No named regulation is claimed, but the data minimum above is enforced in the functions.
- Resolving is the only write, and it is limited to the seller's own report. It is idempotent, and it is written to the row (`resolved_at`) as its own record.

**Configuration required**: none. The bucket and its policy are created by migration `0017`.

**Migration safety** (`0014` changes the live `place_order`, so treat it like `0009`): the new `place_order`, the `store_orders` table and the backfill are in one migration, so no order is placed between them. `place_order` adds `store_id` (from `products.store_id`) to the `jsonb_build_object` that builds each `order_items` line, then inserts the `store_orders` rows. The backfill uses `on conflict do nothing`, so it can be run again as a repair. Rollback: put the `0009` version of `place_order` back; orders placed after that have no `store_orders` row and are invisible to sellers until the backfill is run again. The new tables and columns can stay. Run it on a test or branch project first.

**Critical test scenarios** (each maps to an acceptance criterion):
- Happy path: a buyer cart with products of two stores places one order, each seller sees only their lines and total in Orders, opens the detail, and sees the sales on Earnings, verifies **AC-2**, **AC-5**, **AC-6**, **AC-13**.
- Happy path: a seeded report shows in Reports, opens in details with its signed attachments, and Resolve with confirmation turns it Resolved everywhere, verifies **AC-9**, **AC-10**, **AC-11**.
- Failure case: `resolve_report` twice and from a second device gives the same result, and a failed call restores the card, verifies **AC-11**.
- Failure case: filter and search together, a `%` in the search, and a page boundary with a new order arriving during paging show no repeat and no gap, verifies **AC-3**, **AC-4**, **AC-2**.
- Auth/permission: seller B calls `store_order_detail` and `store_report_detail` with seller A's ids and gets `not_found`. A buyer gets `not_seller`, an anonymous session gets `no_session`, and the `anon` role is refused by Postgres. A direct `select` on `store_orders` and `reports` returns nothing or an error, verifies **AC-12**.
- Backfill: an old order whose product was deleted gets no store row and shows to nobody, an old delivered order keeps `delivered`, verifies **AC-13**.

## Build plan

No build approach is recorded for this feature (the project scope says "not yet set"), so the plan assumes Tracer Bullet: each slice goes through the database, the data layer and the screen before the next one starts. The seller shell does not exist, so the screen lives behind a button on `/store`.

1. Migration `0014_store_orders.sql` and checks: `order_items.store_id` with backfill, `store_orders` with backfill and closed rights, `place_order` writing both (see Migration safety), `store_orders_list`; add `supabase/checks/store_activity.sql` (each check rolls back), satisfies **AC-2**, **AC-3**, **AC-4**, **AC-12**, **AC-13**
2. Data layer slice: `StoreOrder` model, a `StoreActivityRepository` with a Supabase version and a mock version, Riverpod providers with the 300 ms delay and the endpoint doc comments, the keyset paging notifier, satisfies **AC-2**, **AC-15**
3. Orders tab slice: `/store/activity` route (declared before `/store/:id`), the "Activity" button on `/store`, the header, search field and tab row, the Orders tab with chips, rows, paging, refresh and states, the "+" button, satisfies **AC-1**, **AC-2**, **AC-3**, **AC-4**, **AC-14**, **AC-16**
4. Order detail slice: migration `0015_store_order_detail.sql` with `store_order_detail` and its checks, the model, repository methods and the `/store/activity/orders/:id` screen inside `SellerGate`, satisfies **AC-1**, **AC-5**, **AC-12**, **AC-14**
5. Earnings slice: migration `0016_store_earnings.sql` with `store_earnings` and its checks, the model, repository methods and the Earnings tab, satisfies **AC-6**, **AC-7**, **AC-14**, **AC-15**
6. Migration `0017_reports.sql` and checks: `reports`, `report_items` with their foreign keys, the `report-attachments` bucket and select policy, `store_reports_summary`, `store_reports_list`, `store_report_detail` and `resolve_report`; extend the checks file with a two session resolve test, a cross store test and a wrong store report item test, satisfies **AC-8**, **AC-9**, **AC-10**, **AC-11**, **AC-12**
7. Reports slice: `StoreReport` models, repository methods (Supabase and mock with seeded reports), the Reports tab with the summary cards and list, the `/store/activity/reports/:id` details screen inside `SellerGate` with signed attachment links, and the resolve alert with its optimistic update, satisfies **AC-1**, **AC-8**, **AC-9**, **AC-10**, **AC-11**, **AC-14**, **AC-15**, **AC-16**
8. Closing pass: the Returned badge style, the `AGENTS.md` notes for the new feature folder and `supabase/`, and the full test run for buyer, shared and the Deno shared modules, satisfies **AC-16**, **AC-17**

## Consequences

**Positive**:
- A seller never sees the whole order, other stores' lines or the buyer's account, by construction (functions, not table access).
- The buyer's order screens, receipt and `orders.status` are untouched.
- Earnings are computed in one query, so they stay correct at any order count.
- A later "seller changes status" spec only has to write `store_orders.status` and derive the buyer status.

**Negative / tradeoffs**:
- `place_order` is live and changes again; it needs the same careful check as migration `0009`.
- `store_orders.created_at` is a copy of the order's date (kept so one index serves the list and its paging), so it must never be edited.
- Old orders whose product was deleted are invisible to sellers for good, and orders from products with no `store_id` (seed data) show to nobody.
- `orders.status` stays `inProgress` for everything new while store statuses can later differ, until the derivation rule exists.
- The Reports tab and the Returned Orders card show zero in production until later specs add report creation and a way to set `returned`.
- Seven functions and a bucket policy are SQL that the client tests cannot exercise, so the SQL checks must carry the permission cases.

**Neutral**:
- The seller shell, the chat icon and the bell stay unbuilt.
- A new feature folder `apps/buyer/lib/features/seller_activity/` and a new `lib/data` model, repository and provider set follow the existing mock and Supabase pattern.

## Follow-up

- [ ] Design "seller changes an order status" (a control in the order detail, the rule that derives the buyer's `orders.status`, how `returned` is set), with a Figma frame
- [ ] Design the buyer side of reports: "Report a problem" with attachments (insert policy for the bucket and the creating function that writes `reports` and `report_items`, which also needs a report type if the Returned Orders card should later count requests), and the "My reports" screen already drawn in the Profile frame
- [ ] Draw the seller order detail in Figma so the code can cite a frame instead of the buyer receipt
- [ ] Decide what the chat icon and the bell open, and whether a resolved report notifies the buyer (this spec sends nothing, AC-17)
- [ ] Decide whether Returned orders belong in Total Sales. This spec leaves them out (the money went back), which differs from "everything except canceled" only once `returned` can be set
- [ ] Add a seller shell spec (header, tab bar, Home, Activity, Profile) and then move the Activity entry from the `/store` button into it
- [ ] Add a row for this feature to `docs/scope/_root/scope.md`, linking this spec
- [ ] Decide what the "+ 36%" figure on Total Sales means, or remove it from the Figma frame

## Rationale

Reasoning, options and the Figma and code inventory: see [rationale.md](rationale.md).
