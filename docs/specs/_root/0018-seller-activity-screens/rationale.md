# 0018. Seller Activity screens: rationale

The decision record for [index.md](index.md). The build does not need this file.

## Context

The Figma page "The design - seller" draws an Activity area for a seller with an Orders list, an Earnings summary and a Reports list with a details page. Today the store area (`/store`) holds only two buttons for the product features, and the seller shell that should carry Activity has no spec.

The data does not match what the screens need. An order belongs to the buyer (`orders.user_id`), and a cart can hold products of several stores, so one order can concern three sellers. `order_items` keeps only `store_name` as text and a nullable `product_id`, no store id. There is one status for the whole order. Sellers have no read rule on `orders` at all. There is no report, return or dispute table, no buyer screen that creates a report, and no way to change an order status.

Nothing set a store on an order before, so the first real question is how a seller sees and tracks their share of a shared order without seeing the rest. Reports raise a second question: the seller screens come first, but the buyer who creates the data does not exist yet.

Facts the design rests on:
- `orders.status` allows `delivered`, `inProgress` and `canceled`. The buyer Purchases tab and the receipt read it.
- Spec 0015 gave each store a currency (`user_profiles.currency`, `TND` for all stores today) and stores money with 3 decimals.
- `place_order` is live, runs as one transaction, and already fixes the time zone to Africa/Tunis for delivery dates.
- Project rules: every owned table row level security compares to `(select auth.jwt() ->> 'sub')`, a `security definer` function sets `search_path = ''` and grants execute to `authenticated` only, and `require_seller()` already exists (migration `0008`).

## Options considered

### Option 1: A per store order table, read through filtering functions

Add `store_orders` (order, store, status) and `order_items.store_id`. Sellers never touch `orders` or `order_items`; functions return only their lines, their total and the contact data a delivery needs.

**Pros**:
- Matches how a marketplace really works: each store ships and tracks its own part.
- The buyer's order, receipt and status are untouched.
- Leaks nothing by default: other stores' lines and the whole order total stay inside the database.

**Cons**:
- More SQL (seven functions, a backfill, a `place_order` change) that the Dart tests cannot cover.
- Two statuses exist (`orders.status` and `store_orders.status`) until a later spec derives one from the other.

### Option 2: One order per store

`place_order` creates a separate `orders` row for every store in the cart. A seller then reads their orders with an ordinary row level rule.

**Pros**:
- No new table, and a seller policy on `orders` is one line.
- One status per order, nothing to derive.

**Cons**:
- Changes what the buyer sees: several receipts, several order numbers and several Purchases blocks for one checkout.
- Delivery fee and payment are per checkout, so they would have to be split or duplicated.
- Live orders cannot be split after the fact without a risky data migration.

### Option 3: Open the existing tables to sellers with row level security

Add a select policy on `orders` and `order_items` for a seller whose store appears in the order, and let the app compute totals and earnings.

**Pros**:
- Least SQL, no new tables.

**Cons**:
- A seller would see the order total, the delivery fee and the lines of other stores in a shared order, because row level security works on rows, not on which lines of an order are theirs.
- Earnings computed in the app fail as soon as the list is paged.
- Still needs a per store status, so the missing table comes back anyway.

## Rationale

Option 1 is the only one that fits the two facts that decide this: orders are shared between stores, and the buyer side is already live. Option 2 breaks the buyer's receipts and cannot be rolled out safely over existing orders. Option 3 leaks other sellers' sales, which is the first thing a seller of a marketplace would object to, and it needs the status table anyway.

The two statuses are an accepted cost, not a surprise. Nothing in this spec writes a store status, so they cannot disagree yet. The rule that derives the buyer's status belongs to the spec that lets a seller change it, where it can be designed with a real writer in front of it.

Smaller calls made here, each with the runner up:
- Reads go through functions that page with a keyset (created date and id), not offset paging, so a new order arriving while the seller scrolls never repeats a row. The id, not the order number, breaks ties because the index on `store_orders` can serve it. Runner up: offset, simpler, wrong under writes.
- A report has no type column. Returned Orders counts `store_orders.status = 'returned'`, which is the card definition the engineer chose, so a `kind` column would have no reader. A later buyer report spec can add one.
- The report to item link is enforced with composite foreign keys, so the database refuses an item from another order or store. Runner up: a SQL check only, which would let a bad row exist.
- One migration per build slice (`0014` to `0017`): an applied migration is never run again, so a slice that adds a function later needs its own file. Runner up: one large file, which breaks the Tracer Bullet order.
- Search runs on the server and uses `strpos(lower(...))` instead of `like`, so `%` and `_` typed by a seller are plain text. Runner up: `ilike` with escaping, more code for the same result.
- Earnings are one function returning one row, with the "recent" rows inside it. Runner up: a second list call, one more round trip for nothing.
- The week percent compares the week so far with the same span of last week. Comparing with the whole last week would show a large drop every Monday. Runner up: whole week, simpler but misleading.
- Returned orders are kept out of sales, even though the engineer chose "everything except canceled" before `returned` existed. A returned order means money went back. The difference is zero today because nothing sets `returned`, and it is listed in Follow-up for the engineer to confirm.
- Attachments live as a list of paths in the report row, not a table, because they are only shown and never queried one by one. Runner up: a table, a join for nothing.
- No `store_id` foreign key, like `orders.user_id`, so deleting a seller account keeps order history.
- The Earnings tab ignores the search text and the Orders and Reports tabs use it. Runner up: hide the field on Earnings, which departs from the frame.
- The seller screens ship before their writers (buyer reports, status changes). They are testable with seeded rows and mock data, and they fix the read contract those later specs write against.

## Inventory of the sources

**Figma** (file `toOakybJ0DaJmU7vcEC0AW`, page "The design - seller", `3001:8811`):

| Frame | Node | What it holds |
|---|---|---|
| Activity-orders-seller | `3001:11659` | Header (store logo and name, chat and bell icons), search, tabs Orders, Earnings, Reports, chips Delivered, In progress, Canceled, order rows (number, customer, city, total, badge), the "+" button |
| Activity-earnings-seller | `3001:11790` | Total Sales, Today's Sales with new orders, This Week's sales with percent, Customers with new today, Recent sales rows |
| Activity-reports-seller | `3001:11908` | Total Reports, Unresolved Reports, Returned Orders, report cards (number, date, badge, title, customer, product and order, description, View details, Resolve) |
| report details-seller | `3001:11979` | Customer Information, Products information, Problem details, Attachment, Mark as resolved |
| Alert | `860:5916` (user page) | "Are you sure you want to mark this report as resolved?" |

The flow header `3001:12043` reads "Activity-seller, Work in Progress". The frames link Orders, Earnings and Reports to each other, the report card to the details, and the chips to a category component. The buyer side draws "My reports" as an entry in the Profile frame (`322:2872`) and a "Report card" inside the messages frame; no screen creates a report. No seller order detail frame exists.

**Code and database** (checked 2026-10-08):
- `supabase/schema.sql`, `0003_place_order.sql`, `0009_place_order_variants.sql`: `orders` and `order_items` shape, `place_order`, closed direct writes.
- `0008_seller_products.sql`: `require_seller()`, `touch_updated_at()`, the function and grant pattern to copy.
- `apps/buyer/lib/features/store/store_area_screen.dart`: the placeholder `/store` page and the route order in `app_router.dart` (`/store/products` before `/store/:id`).
- `apps/buyer/lib/features/activity/`: the buyer Activity screens and `order_receipt_screen.dart`, the base for the seller order detail.
- Specs 0008 (buyer Activity), 0014 (store area), 0015 (currency, `Money`, seller functions).
