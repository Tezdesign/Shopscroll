# 0009. Rationale: the purchasing flow

The decision itself is in [index.md](index.md). This file keeps the reasoning.

## Context

The app has a cart that ends at a "Checkout coming soon" page, and an Activity tab whose Purchases list can only show orders that already exist. Nothing can create an order, so the buyer side of the marketplace stops one step short of buying. Figma already has a full set of purchasing frames: a Checkout page in five states, sheets for contact, address and card, and a confirmation page.

Three forces shaped the design. First, the engineer wants the screens now and the card payment later, with no card API yet, so the flow must be complete without it. Second, many buyers are anonymous (the app browses and fills carts before any sign in, spec 0004), so checkout cannot require an account. Third, this is the first feature that turns a cart into a record of money owed. Today the `orders` table lets any buyer insert or edit any row with any total, which was harmless while nothing wrote orders, and is not harmless now. Buyer contact details and a delivery address are also personal data that the orders table has never held.

The design file is also inconsistent in places (delivery is `10$` on one frame and `15$` on another, totals that do not add up, two headings for the address). The numbers are examples, so the rules had to come from the engineer rather than the frames.

## Options considered

### Option 1: One server function that builds the order from the buyer's saved cart

A Postgres function `place_order` takes only the contact, address, delivery type and payment type. It reads the caller's own cart rows, prices them from `products`, writes the order and items, and clears the cart, all in one transaction. The buyer's direct write policies on `orders` and `order_items` are dropped.

**Pros**:
- Prices and totals cannot be set by the phone.
- Order creation and cart clearing succeed or fail together.
- No new service to deploy, and it follows the pattern already used for `merge_anonymous_identity`.

**Cons**:
- Business rules (fees, arrival days, limits) live in SQL as well as in Dart, so they can drift.
- Harder to unit test than Dart code, needs checks against the live database.

### Option 2: The app inserts the order and items itself under row level security

The phone works out the totals, inserts the `orders` row and the `order_items` rows, then deletes the cart rows, each as its own call. The existing insert policies already allow it.

**Pros**:
- No SQL function to write, and all the logic is in Dart.
- Mock and Supabase repositories look almost the same.

**Cons**:
- The phone sets the price and the total, so a modified client could order anything for `$0`.
- Three separate calls can stop halfway and leave an order with no items, or a paid cart that was never cleared.

### Option 3: Screens only, no order is created

Place order opens the confirmation with the typed details and nothing is saved, as a pure interface prototype.

**Pros**:
- Smallest build, no migration, no risk to data.
- Fits "design the screens first" literally.

**Cons**:
- The Purchases tab stays empty and the confirmation shows made up data.
- The real work (order data, server pricing, guest ownership) is only postponed, and the screens would need reworking when it lands.

### Option 4: A Supabase Edge Function with the service role

The phone calls an Edge Function that does the same as Option 1 using the service role key.

**Pros**:
- Business rules in TypeScript, easier to test locally than SQL.
- A natural home for later payment provider calls and emails.

**Cons**:
- A new thing to deploy and secure, with its own secrets, for a job the database can do in one transaction.
- More moving parts on the buyer's most important path, and no need for them until card payment arrives.

## Rationale

Option 1 fits the forces. Because the app is the first thing that writes money related rows, the price must come from the server, and Option 2 fails that outright. Option 3 was the literal reading of "design first", but the engineer answered that Pay on delivery should make a real order, and the Facade build order in the plan still lets every screen be built and tested on mock data before the migration exists, which gets the benefit of Option 3 without its rework. Option 4 is the right home for the card spec, where an outside provider is called, but today it would add a deployed service and secrets for something one transaction covers.

Guests are supported without extra work because an anonymous session already has a stable `sub`, the function uses it as the owner, and spec 0004's merge moves orders when the buyer signs in. Closing the direct write policies is part of this decision because the new function only protects prices if nothing else can write orders.

Choices made without a question: fees and arrival days as constants (the engineer said the numbers are examples, and a table would be speculative), a fixed country of Tunisia (the design has no country field), fields checked both on the phone and in the function, and an order id made by the phone for safe retries (added after the cross check, since it costs a few lines and stops a lost reply from looking like a failure).
