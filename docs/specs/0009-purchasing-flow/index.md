# 0009. Build the purchasing flow (checkout and order confirmation)

**Date**: 2026-09-28
**Status**: In Progress

## Summary

This adds the whole purchasing flow in one spec: a full screen Checkout, two bottom sheets (contact and delivery address), and an Order confirmation screen. A buyer, signed in or not, picks a delivery type and pays on delivery, and a real order is created on the server from their cart. Card payment, discount codes and "use my location" are drawn but do nothing yet, and come in later specs. The order is created by one database function that takes prices from the products table, so the phone can never set its own total.

Reasoning and options: see [rationale.md](rationale.md).

## Requirements

**User stories**:
- As a shopper, I want to review what I am buying, give my contact details and address, and pick a delivery type, so that I know exactly what I will pay.
- As a shopper without an account, I want to place an order without signing in, so that I am not stopped at the last step.
- As a shopper, I want to see a confirmation with my order number, totals and delivery details, so that I know the order went through.
- As a shopper, I want the order to appear in my Purchases tab, so that I can find it later.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1**: "Proceed to checkout" on the cart opens `/checkout`, a full screen page with no bottom tab bar. This replaces the coming soon page of spec 0007 (AC-9). If the cart is empty when it opens, the page shows "Your cart is empty" with a "Back to cart" button and no form.
- **AC-2**: The Checkout page has a title "Checkout" with an X on the left, then these sections in order, in a scrolling body: Shipping items, Contact information, Delivery address, Delivery Method, Order Summary, Payment method. "Place order" is pinned at the bottom above the home indicator. Shipping items is the existing `ShippingItemsSection`, showing every cart line, and starts expanded.
- **AC-3**: The Contact information section shows "+ Add your contact info" when empty. Tapping it opens the contact sheet. When filled it shows the name (bold), then the email and the phone in grey, with a pencil that reopens the sheet holding the current values.
- **AC-4**: The contact sheet has the title "Contact information", a round close button, three fields (full name, email, phone with a dial code picker) and "Continue". There is no save toggle. If a field is invalid, "Continue" shows a message under that field and the sheet stays open. If all are valid, the sheet closes and the section fills. Closing the sheet another way keeps the old values.
- **AC-5**: A signed in buyer's name, email and phone from their profile fill the contact sheet, and when all three exist the section starts filled. If any is missing, the sheet fills what exists and the section stays empty until "Continue". A signed out buyer, or the mock backend with no sign in, starts empty. The address is never prefilled.
- **AC-6**: The Delivery address section shows "+ Add your address" when empty and opens the address sheet. The sheet has the title "Shipping address", a round close button, an "Add current location" link that looks disabled and does nothing, then city, address, zip code, an optional note ("Anything you want to add"), and "Continue". City, address and zip are required. When filled the section shows "Tunisia" (bold), then `address, city, zip` and the note in grey, with a pencil that reopens the sheet.
- **AC-7**: Delivery Method shows two tiles, "Standard Delivery (in 5 to 6 working days)" at `$10` and "Exclusive delivery (in 1 to 2 working days)" at `$16`. Tapping one selects it (a filled radio and a primary colour border) and unselects the other. Neither is selected at first.
- **AC-8**: Order Summary has a discount code field (typing is allowed and ignored) and an "Apply" button that looks disabled and does nothing, then three rows: "Order subtotal" (the sum of price times quantity), "Delivery" (the chosen fee, or "Not chosen" before one is chosen), and "Price to pay" in bold (subtotal plus the fee, or the subtotal alone before a choice). The rows update at once when the delivery type changes. There is no discount line or crossed out price.
- **AC-9**: Payment method shows two radio rows, "Pay by Credit Card" (with a lock icon and the Mastercard, Maestro, Visa and Discover logos) and "Pay on delivery". Neither is selected at first. Choosing card opens no sheet and collects no card data.
- **AC-10**: "Place order" is disabled (light blue) until the contact, the address, a delivery type and a payment method are all set. Then it turns primary blue.
- **AC-11**: With card chosen, tapping "Place order" shows a snack bar "Card payment is coming soon" and creates nothing.
- **AC-12**: With Pay on delivery chosen, tapping "Place order" shows a busy state on the button and creates exactly one order from the whole cart, even if the button is tapped several times or the same request is sent twice (the phone makes the order id once per checkout, and a repeat with that id returns the same order). It then opens `/order-confirmation/:id` in place of the Checkout page, so Back never returns to it.
- **AC-13**: If placing the order fails, a snack bar says "Couldn't place your order. Try again.", the typed details and choices stay, the cart is unchanged and the button works again. If a product in the cart is out of stock, was removed, or has a different price than the checkout showed, the snack bar says "Some items changed. Check your cart.", nothing is created, and the cart reloads.
- **AC-14**: The X asks "Discard your details?" with "Discard" and "Keep editing" when any detail was entered or any choice made. Discard goes back to the cart and forgets everything. With nothing entered, X goes back at once.
- **AC-15**: The order is priced on the server. Line prices come from the products table, the subtotal is their sum times quantity, the fee comes from the delivery type, and the total is the two added. Nothing the phone sends can change a price.
- **AC-16**: After a successful order the buyer's cart is empty (the Cart screen shows its empty state) and Activity → Purchases lists the new order first (newest first), with status "In progress" and the total, for a signed in buyer and for an anonymous one. On Supabase it is still there after an app restart.
- **AC-17**: The Order confirmation screen (Figma 3001:10433) has the title "Order Confirmation" with an X, then "Order#000001 is confirmed" (the number padded to 6 digits), the heading "Thank you for your order, {first name}!" (the first word of the contact name), "We'll send you an email and an sms when it's ready", and, for a signed out buyer only, "Be the first in line for exclusive offers." with its line and a "Sign in" button that opens `/sign-in`. Then a bordered summary card, and "Go back to home page".
- **AC-18**: The summary card shows Order Summary (subtotal, delivery, "Total price"), Contact Information, Shipping Address (country, address line, note), Delivery Method (its name, "Shipping price" with the fee that was charged, and "Estimated arrival" with the stored estimated delivery date, written like `28 May`) and Payment Method ("Pay on delivery").
- **AC-19**: "Go back to home page", the X and the system Back all go to Home and never back to the Checkout page.
- **AC-20**: A signed out buyer can place an order (their anonymous session owns it), and the order carries over on sign in through spec 0004's merge (AC-3). An order placed in the moment while a sign in is being processed can stay under the anonymous id (accepted edge, see Consequences).
- **AC-21**: Buyers cannot insert, edit or delete rows in `orders` or `order_items` directly (the policies and the table grants are both closed), and read only their own. `place_order` rejects a missing session, an empty cart, a blank or too long contact or address field, an unknown delivery or payment method, a product with `in_stock` false, and a subtotal that differs from the phone's expected one, and in every case changes nothing.
- **AC-22**: While the cart loads, Checkout shows a loading indicator. If it fails to load, it shows "Couldn't load your cart." with "Try again". The confirmation shows a loading indicator, and if the order cannot be loaded, "Couldn't load your order." with "Go back to home page".
- **AC-23**: Every tappable item on these screens (X, section links, pencils, tiles, radios, fields, buttons, the section header) has a spoken label, radios and tiles announce whether they are selected, and tap areas are at least 44 by 44 logical pixels.
- **AC-24**: No card number, expiry or CVV field exists anywhere in the app, and nothing about a card is stored, sent or logged.
- **AC-25**: Nothing else changes: the Cart screen looks and works as before except where "Proceed to checkout" leads, and the Activity screens are unchanged except that they now list the new orders.

## Decision

**Chosen option**: Option 1: One server function that builds the order from the buyer's saved cart

Add a `place_order` Postgres function (security definer) that reads the caller's own `cart_items`, prices them from `products`, writes the order and its items, and clears the cart in one step. Build the screens on mock data first, then give `OrderRepository` a `placeOrder` method on the mock and Supabase backends.

**Implementation skills**: `supabase` (`supabase/agent-skills`, `.agents/skills/supabase/`) · `supabase-postgres-best-practices` (`supabase/agent-skills`, `.agents/skills/supabase-postgres-best-practices/`)

## Feature design

**Design source**: Figma file `toOakybJ0DaJmU7vcEC0AW`, page "The design - user":
- Checkout frames `purchasing-checkout-empty` (3001:9830), `-contact-filled` (3001:9956), `-details-filled` (3001:10085), `-discount-applied` (3001:10221), `-payment-added` (3001:10357).
- Sheets `purchasing-contact-default` (3001:10570), `purchasing-address-default` (3001:10551). The credit card sheets (3001:10507, 3001:10527) are out of scope.
- Confirmation `purchasing-confirmation-success` (3001:10433).
- The `ShippingItemsSection` component (455:3177) is already built.

**Deviations from the design, on purpose**:
- Prices read `$45`, like every other screen, where Figma writes `45$`.
- The frames use two headings for the address section. The screen says "Delivery address" (as the first frame), the confirmation says "Shipping Address" (as its frame).
- The sheets use a plain white surface with rounded top corners, not the translucent iOS blur material.
- The design's numbers (`10$` and `16$` against `15$` on the confirmation, totals that do not add up) are examples. The rules in AC-7 and AC-8 govern.
- The filled and selected states of the delivery tiles are not drawn. Selected uses a `primary400` border and a filled radio.
- The "discount applied", "card added" states, the discount code pop up note, and the "save for future" toggles are not built (see Follow-up).

**Component inventory**:
- Existing, reused: `ShippingItemsSection`, `AppTextField`, `PhoneField`, `AppButton`, `AppIcon`, `ItemMedia`, `ComingSoonScreen` (not used), `showCartSnackBar`.
- New shared widgets in `lib/shared/widgets/`: `CheckoutSection` (title, body, bottom border), `AddInfoRow` (the blue "+ Add ..." link), `InfoSummaryRow` (bold line, grey lines, pencil), `AppRadio` (16 point radio with the `primary100` outline), `DeliveryMethodTile`, `PaymentOptionRow`, `SummaryRow`, `SheetHeader` (title and round close button).
- New screen files in `lib/features/checkout/`: `checkout_screen.dart`, `contact_sheet.dart`, `address_sheet.dart`, `order_confirmation_screen.dart`, `checkout_logic.dart` (plain functions: fees, totals, validators, arrival date).
- Assets: the four card logos are real brand marks, so they are downloaded from Figma and committed under `assets/icons/` (per `AGENTS.md`). Their names are decided at build time.

**Data model sketch** (confirmed). No new tables, one migration `supabase/migrations/0003_place_order.sql`.

`orders` (existing, changed):

| Column | Type | Notes |
|---|---|---|
| `id` | uuid, primary key | unchanged |
| `user_id` | text | unchanged, Clerk id or anonymous `sub` |
| `status` | text | unchanged. New orders are `inProgress` |
| `created_at`, `estimated_delivery` | timestamptz | unchanged |
| `order_number` | bigint, generated always as identity, unique | new. Shown as `Order#000001` |
| `subtotal` | numeric(10,2) | new. Backfilled as `total_amount - coalesce(delivery_fee, 0)` |
| `delivery_fee`, `total_amount` | numeric(10,2) | unchanged. Total is subtotal plus fee |
| `delivery_method` | text | unchanged column. New orders hold `standard` or `exclusive` |
| `payment_method` | text | unchanged column. New orders hold `cashOnDelivery` (`card` is for a later spec) |
| `contact_name`, `contact_email`, `contact_phone` | text | new, empty allowed so old rows stay valid |
| `ship_country` (default `Tunisia`), `ship_city`, `ship_address`, `ship_zip`, `ship_note` | text | new, empty allowed. The note is optional for new orders |
| `shipping_address` | text | dropped, replaced by the ship columns |

`order_items` and `cart_items` are unchanged. One order has many order items (cascade delete). An order belongs to one buyer through `user_id` (plain text, no foreign key).

**State transitions**:
- Order: created as `inProgress` by `place_order` → `delivered` or `canceled` later, by a seller side flow that does not exist yet (nothing in the app changes an order after creation).
- Checkout draft (in memory only): empty → contact set, address set, delivery chosen, payment chosen (any order) → placing → the confirmation, or back to editable on failure.

**API surface**:

| Function | Stands in for | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| `OrderRepository.placeOrder(PlaceOrderRequest)` | `POST /orders` | orderId (uuid made by the phone once per checkout), contact (name, email, phone), address (city, address, zip, note), deliveryMethod, paymentMethod, expectedSubtotal | the new `Order` | the buyer's session | empty cart, unavailable product, price changed, invalid field, network failure |
| `OrderRepository.getOrderById(id)` (exists) | `GET /orders/:id` | id | `Order` with the new fields, or null | the buyer's session | not found |
| Postgres `place_order(p_order_id, p_contact_name, p_contact_email, p_contact_phone, p_ship_city, p_ship_address, p_ship_zip, p_ship_note, p_delivery_method, p_payment_method, p_expected_subtotal)` | the same | the same fields (`p_order_id` uuid, `p_expected_subtotal` numeric, the rest text) | the order id (uuid). If `p_order_id` already exists for the caller, it is returned and nothing new is made | `authenticated` (anonymous sessions included), owner is `auth.jwt() ->> 'sub'`, raises if that is null | `no_session`, `cart_empty`, `product_unavailable`, `price_changed`, `invalid_field`, `invalid_method` |

The Dart `Order` model gains `orderNumber`, `subtotal`, `contact` (name, email, phone) and `shippingAddress` as a structured object (country, city, address, zip, note), replacing the old `String shippingAddress`. Both repositories map the new columns. The checkout draft lives in an auto disposed `NotifierProvider` (`lib/data/providers/checkout_providers.dart`), so leaving the flow forgets it.

**Key invariants**:
- `total_amount = subtotal + delivery_fee`, and `subtotal` is the sum of `unit_price * quantity` over the order's items.
- `unit_price` on every item is the product's price at the moment of purchase, read on the server.
- An order exists if and only if the cart lines it holds were removed by the same call. The function takes the lines with one `delete from cart_items where user_id = sub returning ...` statement and builds the order from the returned rows, so a line added by another device meanwhile is never lost, and two parallel calls cannot both order the same lines (the second finds nothing and raises `cart_empty`).
- "Unavailable" means `products.in_stock = false`. There is no stock count. Lines whose product was deleted are already gone from the cart (cascade), so the expected subtotal check is what catches them.
- The phone sends `p_expected_subtotal` (what Checkout showed). If the server's sum differs, the function raises `price_changed` and rolls back.
- A repeated `p_order_id` for the same buyer returns that order (safe retry after a lost reply).
- Size and colour on each line are copied as they are (null allowed) and not checked against the product's options. Quantity is capped at 99 by the cart already.
- `ship_country` is `Tunisia` for every new order.
- Fees are constants in code and in the function (`standard` `$10`, `exclusive` `$16`), arrival is 6 and 2 working days (Saturday and Sunday skipped, counted in the Africa/Tunis time zone) from the order date. They are placeholders the owner will change, kept in one place (`checkout_logic.dart` and the function).
- Field limits on the server: name, city and address 1 to 120 characters, email 3 to 254 and containing `@`, phone 6 to 20 characters, zip 3 to 12, note 0 to 300.

**Security model**:
- `orders` and `order_items`: buyers keep only the select policies (own rows). The insert, update and delete policies are dropped, and `insert, update, delete` is also revoked from `authenticated` on both tables (`schema.sql` grants it today), so row level security is not the only barrier. An order can only be created by `place_order`.
- `place_order` is `security definer`, sets `search_path = ''`, revokes `execute` from `public` and grants it to `authenticated` (the pattern in `supabase/AGENTS.md`). It reads the caller's rows only, by `auth.jwt() ->> 'sub'`, and never takes a user id, price or total as an argument.
- Compliance scope: buyer contact details and delivery address are personal data now stored on orders. Card data (PCI DSS scope) is deliberately not collected: no card fields, and the later card spec must use a provider hosted form so card numbers never touch this app or database.
- Audit trail: the order row is the record. With update and delete closed to buyers, it cannot be rewritten by them.

**Configuration required**: none. No new plugin, no new environment variable.

**Critical test scenarios** (each maps to an acceptance criterion in ## Requirements):
- Happy path: fill contact and address, choose Standard and Pay on delivery, tap Place order, see the confirmation with `Order#` and the right totals, the cart is empty and Purchases lists the order, verifies **AC-12**, **AC-16**, **AC-17**, **AC-18**.
- Totals: subtotal, delivery and price to pay recompute when the delivery type changes, verifies **AC-7**, **AC-8**.
- Gate: Place order stays disabled until all four parts are set, verifies **AC-10**.
- Card path: card chosen then Place order shows "Card payment is coming soon" and creates nothing, verifies **AC-11**.
- Failure: the repository throws on `placeOrder`, the snack bar shows and the form and cart are unchanged, verifies **AC-13**.
- Double tap: five quick taps on Place order create one order, verifies **AC-12**.
- Retry: `place_order` called twice with the same `p_order_id` returns the same order and makes one, verifies **AC-12**.
- Discard: X with typed details asks first, X with nothing typed does not, verifies **AC-14**.
- Empty cart: opening `/checkout` with no lines shows "Your cart is empty" and "Back to cart", and the confirmation's load error shows "Couldn't load your order.", verifies **AC-1**, **AC-22**.
- Navigation: after the confirmation, "Go back to home page", X and system Back all land on Home and never on Checkout, verifies **AC-19**.
- Guest and prefill: signed out starts empty and shows the Sign in button on the confirmation, signed in shows prefilled contact and no Sign in button, verifies **AC-5**, **AC-17**.
- Carry over: on the live database, an order made by an anonymous session moves to the real account after `merge_anonymous_identity`, verifies **AC-20**.
- Signed in Purchases: with a Clerk backed session, Purchases loads and lists the new order first, verifies **AC-16**.
- Permission: a second buyer cannot read the first buyer's order, and a direct insert, update or delete on `orders` or `order_items` is denied (policy and grant), verifies **AC-21**.
- Server rules: `place_order` with no session, an empty cart, a blank field, a bad method, an out of stock product or a wrong expected subtotal raises and changes nothing, verifies **AC-13**, **AC-15**, **AC-21**.
- Concurrency: two parallel `place_order` calls on one cart make one order and the other raises `cart_empty`, verifies **AC-12**, **AC-21**.
- No card data: a search of `lib/` and `supabase/` finds no card number, expiry or CVV field, and no log line prints card values, verifies **AC-24**.

## Build plan

Build approach: none is recorded for the project (the scope header says to run `/scope`). This plan follows a Facade order (screens first on mock data, backend after), because the engineer asked to design the screens first and add card payment later. The mock backend is a full working path, so every screen is testable before the migration is applied.

1. [x] Add the models and the pure logic: `ContactInfo`, `ShippingAddress`, `PlaceOrderRequest`, the changed `Order`, and `checkout_logic.dart` (fees, totals, delivery labels, arrival date, field validators) with unit tests, satisfies **AC-4**, **AC-6**, **AC-7**, **AC-8**, **AC-15**
2. [x] Build the shared widgets (`CheckoutSection`, `AddInfoRow`, `InfoSummaryRow`, `AppRadio`, `DeliveryMethodTile`, `PaymentOptionRow`, `SummaryRow`, `SheetHeader`) and download the four card logos, each with a widget test, satisfies **AC-2**, **AC-7**, **AC-9**, **AC-23**
3. [x] Build the contact and address sheets with inline validation and the disabled "Add current location" link, satisfies **AC-3**, **AC-4**, **AC-6**
4. [x] Build the Checkout screen from the sections, the checkout draft provider, the totals, the Place order gate and the card message, on the mock backend, satisfies **AC-1**, **AC-2**, **AC-5**, **AC-8**, **AC-10**, **AC-11**
5. [x] Add `OrderRepository.placeOrder` to the mock repository (builds the order from the mock cart, adds it first to the orders list, clears the cart, numbers it, returns the same order for a repeated id, checks the expected subtotal and stock), and wire Place order with the once per checkout order id, busy state, double tap guard, failure messages and the provider refreshes, satisfies **AC-12**, **AC-13**, **AC-16**
6. [x] Build the Order confirmation screen and its route, with the guest only Sign in block, satisfies **AC-17**, **AC-18**, **AC-19**, **AC-22**
7. [x] Wire routing: `/checkout` and `/order-confirmation/:id` as top level routes, the cart's button, the empty cart page, and the discard dialog on X, satisfies **AC-1**, **AC-14**, **AC-19**
8. [x] Write `supabase/migrations/0003_place_order.sql` (columns, backfill, drop `shipping_address`, drop the write policies and revoke the write grants, `place_order` with the single statement cart take, idempotent order id, expected subtotal check and a null session check, grants) for the engineer to apply, satisfies **AC-12**, **AC-13**, **AC-15**, **AC-21**
9. [x] Add the Supabase `placeOrder` (RPC call and error mapping) and the new order column mapping. Fix `SupabaseOrderRepository.getOrders` (it filters on `client.auth.currentUser`, which fails on the Clerk backed client, so drop that filter since row level security already scopes it, and order by `created_at` descending). Then check on the live database (second buyer denied, direct writes denied, bad inputs rejected, retry and concurrency, anonymous to real carry over), satisfies **AC-12**, **AC-15**, **AC-16**, **AC-20**, **AC-21**. Built and applied. Checked live inside a rolled back transaction: every refusal, the priced order, the retry, direct writes and the second buyer. Left for `/check verify`: two parallel calls, the anonymous to real carry over, and a run of the app on the Supabase backend.
10. [x] Accessibility labels, tap areas, loading and error states, and the remaining widget tests, satisfies **AC-22**, **AC-23**, **AC-24**, **AC-25**

## Consequences

**Positive**:
- Guests and signed in buyers use one path, and the Purchases tab fills with real orders.
- The server sets every price and the total, and buyers can no longer write orders directly, which also closes a hole that exists today.
- No new plugin or secret. The card part, discount codes and location later slot into fields that already exist.

**Negative / tradeoffs**:
- Fees and arrival days live in two places (the Dart constants for display, the function for the truth). They can drift until a table replaces them.
- An order placed in the short moment while a sign in is being handled (the anonymous to real switch in `auth_session_controller.dart`) can stay under the anonymous id and not show for the signed in account. Accepted: the window is short and Place order is a deliberate last step.
- The confirmation promises an email and an SMS that nothing sends yet.
- Contact and address details are now kept on orders, and account deletion keeps order history (spec 0003), so that personal data outlives the account until a rule says otherwise.
- The mock and Supabase repositories must both implement the same cart clearing and numbering, or the two backends will behave differently.

**Neutral**:
- Migration `0003` changes a live table and closes the write policies, so it is applied by the engineer after review, like `0002`.
- `order.dart`'s `shippingAddress` string is replaced by an object, so its mock data and mapping change.
- Spec 0007's AC-9 (the coming soon checkout page) is replaced by AC-1 here.

## Rationale

Reasoning and options: see [rationale.md](rationale.md).

## Follow-up

- [ ] Card payment: the credit card sheet (3001:10507, 3001:10527), the "card added" state (3001:10357), the card row's real behaviour, and a provider hosted card form (never raw card fields). Needs its own spec. The order id already makes `place_order` safe to retry.
- [ ] Discount codes: a codes table, per store percent, the "Discount from {store}" line and the crossed out price (frames 3001:10221 and 3001:10085), and the field's real Apply. The design note asks for a pop up, which was set aside for now.
- [ ] "Add current location" on the address sheet: a location plugin, a permission prompt and a lookup service.
- [ ] The two "save for future" toggles (contact "to be discussed", card) were removed. Revisit saving contact details to the profile.
- [ ] The confirmation says "We'll send you an email and an sms when it's ready". Nothing sends either. Decide to build it or change the copy before release.
- [ ] Decide what happens to contact and address details on orders when an account is deleted (`supabase/functions/_shared/delete_user_data.ts` keeps order history today).
- [ ] Fees and arrival days are placeholders. Replace with real values, and move them to a table if they will change.
- [ ] Update spec 0007's AC-9 note and `lib/features/cart/AGENTS.md` (which says checkout is a coming soon page) when this ships. `/sync` owns those files.
- [ ] Supabase's default grants leave `anon` with broad table privileges on `orders` and `order_items` (and on every other public table), and `authenticated` with `TRUNCATE`, `TRIGGER` and `REFERENCES`. Row level security blocks all of it through the API, but a new migration should revoke them for the money tables, and ideally for every table.
- [ ] Order details (scope feature 11) stays a separate spec. The confirmation card is a summary, not that screen.
