# 0007. Build the cart interface

**Date**: 2026-09-26
**Status**: In Progress

## Summary

This adds a real cart screen and makes every Add to cart button really add to it. The cart opens from the cart icon on Home, keeps the bottom tab bar, and lists each item with a quantity stepper and a trash icon, plus a total and a "Proceed to checkout" button that leads to a coming soon page. Carts are saved in the existing `cart_items` table (a real cart per person, anonymous or signed in), so no database change is needed, but the cart repository gains write methods on both the mock and Supabase backends.

Reasoning and options: see [rationale.md](rationale.md).

## Requirements

**User stories**:
- As a shopper, I want to add a product to my cart from where I find it, so that I can keep browsing.
- As a shopper, I want to open my cart and see every item, its price, and the total, so that I know what I am about to buy.
- As a shopper, I want to change a quantity or remove an item, and undo a removal by mistake, so that the cart matches what I want.
- As a shopper, I want my cart to still be there after I close the app or sign in, so that I do not lose it.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1**: Tapping the cart icon in the Home header opens the cart at `/cart`, inside the Home tab. The bottom tab bar stays visible with Home highlighted, and the back arrow returns to Home.
- **AC-2**: The cart lists one card per cart line, oldest added first. Each card shows the product image, the store avatar and name, the title (two lines at most), the price of one item, a size label and a colour dot when the line has them, a quantity stepper, and a trash icon. Tapping the card body opens `/product/:id`.
- **AC-3**: A footer pinned above the tab bar shows "Items price" with the total (the sum of price times quantity, written like `$170`) and a "Proceed to checkout" button. The list scrolls above the footer and the total updates at once when a quantity changes or a line is removed.
- **AC-4**: Plus raises a line's quantity by 1, up to 99. Five quick taps on plus raise it by exactly 5 (no tap is lost).
- **AC-5**: Minus lowers the quantity by 1 and is disabled at 1. Only the trash icon removes a line.
- **AC-6**: The trash icon removes the line at once, with no confirmation, and shows a snack bar with "Undo". Undo puts the line back with the same product, size, colour and quantity. The snack bar goes away by itself after about 4 seconds.
- **AC-7**: With no lines, the cart shows "Your cart is empty" and a "Start shopping" button that goes to Home. No footer is shown.
- **AC-8**: While the cart loads it shows a loading indicator. If loading fails it shows "Couldn't load your cart." with a "Try again" button.
- **AC-9**: "Proceed to checkout" opens `/cart/checkout`, a "Checkout coming soon" page, inside the Home tab. Nothing is written and no order is created.
- **AC-10**: On product detail, Add to cart adds the chosen quantity with the chosen size (if the product has sizes) and the first colour (if it has colours). The button shows its added state while the cart holds a line for that product, size and colour. Tapping it while added does nothing.
- **AC-11**: The Add to cart pill on product cards (Home and Discover) adds 1, with the first size and first colour when the product has them, and shows the snack bar "Added to cart".
- **AC-12**: The cart icon on each search result row adds 1, with the first size and first colour when the product has them. The icon shows its added state (the Figma icon from spec 0006) while the cart holds any line of that product.
- **AC-13**: Adding a product, size and colour already in the cart raises that line's quantity (up to 99) instead of adding a second line. A different size or colour makes a separate line.
- **AC-14**: A product with `inStock` false cannot be added. The tap shows "This item is out of stock" and writes nothing.
- **AC-15**: If a cart write fails, the cart goes back to the last saved state and a snack bar says "Couldn't update your cart. Try again."
- **AC-16**: Cart lines are saved per person on the `cart_items` rows on Supabase (anonymous or signed in), survive an app restart, and follow the sign in merge from spec 0004 (AC-3). On the mock backend the cart lives in memory for the app run. Both backends behave the same to the screens.
- **AC-17**: The header cart icon, the stepper buttons, the trash icon, the card, and the checkout button each have a spoken label and a tap area of at least 44 by 44 logical pixels.
- **AC-18**: The Reels screens are unchanged. The shop the look sheet has no Add to cart action and gets none.

## Decision

**Chosen option**: Option 1: A repository backed cart with an optimistic notifier

Give `CartRepository` write methods (add, set quantity, remove) on the mock and Supabase implementations, turn `cartItemsProvider` into an `AsyncNotifier` that updates the screen first and reverts on failure, and build the cart screen from the existing `ItemCard` inside the Home tab.

## Feature design

**Design source**: Figma file `toOakybJ0DaJmU7vcEC0AW`, frame Cart, node 369:362. The frame also draws the tab bar with Home highlighted, which is why the cart lives inside the Home tab.

**Data model sketch**: no new tables, columns or migration. The existing `cart_items` table (see `supabase/schema.sql`) and the `CartItem` model are used as they are:
- `cart_items`: `id` (uuid, primary key), `user_id` (text, the Clerk id or the anonymous session `sub`), `product_id` (uuid, foreign key to `products`, cascades on delete), `quantity` (integer, required, `check (quantity > 0)`), `selected_size` (text, nullable), `selected_color` (bigint ARGB, nullable), `added_at` (timestamp).
- No unique constraint exists. One line per user, product, size and colour is kept by the app (see invariants), and the sign in merge function already folds any duplicates.

**State transitions**:
- Line: absent → present with quantity n (add) → quantity n±1 (stepper, 1 to 99) → removed (trash) → present again (Undo, a new row with a new id).

**API surface** (repository methods and the REST calls they stand in for, per the project convention):

| Function | Stands in for | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| `getCartItems()` (exists) | `GET /cart` | none | `List<CartItem>` | signed in or anonymous session | empty list when no session |
| `addItem(product, quantity, size, color)` | `POST /cart/items` | product:Product (req), quantity:int (req, 1 to 99), size:String (opt), color:int (opt) | the resulting `CartItem` (merged if the same variant exists) | own rows only | write failure throws |
| `setQuantity(itemId, quantity)` | `PATCH /cart/items/:id` | itemId:String (req), quantity:int (req, 1 to 99) | the updated `CartItem` | own rows only | write failure throws, missing row throws |
| `removeItem(itemId)` | `DELETE /cart/items/:id` | itemId:String (req) | nothing | own rows only | write failure throws |

Provider: `cartItemsProvider` becomes an `AsyncNotifierProvider` (`CartNotifier`) in `lib/data/providers/cart_providers.dart`, keeping its name and its `GET /cart` doc comment. It exposes `add(...)`, `setQuantity(...)`, `remove(...)` and `undoRemove(...)`. Each call updates the state first, then writes through the repository, and reverts to the previous state and rethrows if the write fails. Calls run one after another in the order made.

Screens and files:

| Item | Where | Notes |
|---|---|---|
| Route `/cart` | `app_router.dart`, child of the Home branch's `/` route | Builds `CartScreen`, same pattern as `/search` |
| Route `/cart/checkout` | child of `/cart` | Builds `ComingSoonScreen(label: 'Checkout')` |
| `CartScreen` | `lib/features/cart/cart_screen.dart` | List, footer, empty, loading and error states. Private widgets stay in this file. |
| Cart helpers | `lib/features/cart/cart_logic.dart` | Plain functions: total, sort by `addedAt`, find a matching line, first size and colour. Unit tested. |
| `ItemCard` | `lib/shared/widgets/item_card.dart` | Gains an optional size label and colour dot |
| Header cart icon | `lib/features/catalog/home_screen.dart` | Becomes a button that pushes `/cart` |
| Add to cart wiring | product detail, `ProductCard` callers on Home and Discover, search result rows | All call the notifier, none keeps its own local flag |

**Key invariants**:
- From the app, one line exists per user, product, size and colour. `addItem` looks for a matching line first (size and colour compared as equal, including both empty) and raises it instead of inserting.
- Quantity is always 1 to 99. The notifier clamps, and the database check already rejects 0 or less.
- The total is computed from the lines when it is shown, never stored.
- The screen never shows a state the server refused: a failed write reverts the state before the message shows.
- Writes to the cart are serialized per app run, so quick taps apply in order and never overwrite each other.

**Security model**: no new rules. Row level security on `cart_items` already limits select, insert, update and delete to rows where `user_id` equals the caller's JWT `sub`, for both anonymous and Clerk sessions (see `supabase/schema.sql` and spec 0004). The repository never sends a `user_id` it did not read from the current session. The cart holds no payment or personal data.

**Configuration required**: none.

**Deviations from the Figma frame** (each is a fix or a forced change):
- The label reads "Items price" (the frame has lower case "items price") and the total reads `$170`, matching the app's `$40` style, not the frame's `170$`.
- The frame's total, 170, does not equal four rows of $40. It is placeholder data, so the total is computed.
- Each card gains an optional size label and colour dot, so two lines of the same product in different sizes can be told apart. The frame shows neither.
- The frame's device status bar and navigation chrome are not built. The app's own header (back arrow and centred "Cart" title) is used.
- Empty, loading, error and Undo states are not drawn in the frame and follow the app's existing patterns.

**Critical test scenarios** (each maps to an acceptance criterion in `## Requirements`):
- Happy path: on Home tap the cart icon, see the lines and the total, tap plus twice, see quantity and total change, verifies **AC-1**, **AC-2**, **AC-3**, **AC-4**
- Remove and Undo: tap trash, see the snack bar, tap Undo, see the same line back, verifies **AC-6**
- Minus at 1 is disabled, verifies **AC-5**
- Add twice: add the same product, size and colour twice, see one line with quantity 2; add a second size, see two lines, verifies **AC-13**
- Out of stock: try to add a product with `inStock` false, see the message and no new line, verifies **AC-14**
- Failure: make the repository throw on `setQuantity`, see the quantity revert and the message, verifies **AC-15**
- Empty and error states render, verifies **AC-7**, **AC-8**
- Checkout opens the coming soon page and creates no order, verifies **AC-9**
- Product detail, product card and search row adds all reach the cart, verifies **AC-10**, **AC-11**, **AC-12**
- Persistence: add on Supabase, restart, the line is still there; sign in, the line follows the merge, verifies **AC-16**
- Accessibility: each control has a label and a 44 pixel tap area, verifies **AC-17**
- Reels: no new Add to cart control appears, verifies **AC-18**

## Build plan

This project has no recorded build approach (the scope header says Tracer Bullet is assumed). The plan stands up one thin thread through every layer first (add to cart, open the cart, see it), then thickens it.

1. Add `addItem`, `setQuantity` and `removeItem` to `CartRepository`, with a mock version that keeps its own in memory copy of `mockCartItems` and a Supabase version (find the matching line, then update or insert; update; delete), with unit tests on the mock, satisfies **AC-13**, **AC-16**
2. Write `cart_logic.dart` (total, sort, match, first size and colour) with unit tests, satisfies **AC-2**, **AC-3**, **AC-13**
3. Turn `cartItemsProvider` into the `CartNotifier` (serialized writes, update first, revert and rethrow on failure, clamp 1 to 99, merge, undo) and update the existing provider test, with unit tests, satisfies **AC-4**, **AC-5**, **AC-6**, **AC-13**, **AC-15**
4. Thin thread: the `/cart` route under Home, the header cart icon, and a `CartScreen` that lists the lines with `ItemCard` and the total, satisfies **AC-1**, **AC-2**, **AC-3**
5. Wire product detail's Add to cart to the notifier (real quantity, selected size, first colour, added state from the cart), satisfies **AC-10**, **AC-14**
6. Steppers and the trash icon with the Undo snack bar, satisfies **AC-4**, **AC-5**, **AC-6**
7. Empty, loading and error states, satisfies **AC-7**, **AC-8**
8. The `/cart/checkout` route and the "Proceed to checkout" button, satisfies **AC-9**
9. Wire the `ProductCard` Add to cart pill on Home and Discover with the "Added to cart" snack bar, satisfies **AC-11**, **AC-14**
10. Wire the search result rows to the notifier, remove their local "added" set, and update the search screen test, satisfies **AC-12**, **AC-14**
11. `ItemCard` size label and colour dot, satisfies **AC-2**
12. The out of stock guard and the failure snack bar as one shared helper the three add entry points use, satisfies **AC-14**, **AC-15**
13. Accessibility labels and tap areas, and widget tests that mirror `lib/` under `test/features/cart/`, satisfies **AC-17**, **AC-18**

## Consequences

**Positive**:
- One cart serves every entry point, and it is saved, so it survives a restart and follows the sign in merge.
- No database change, so nothing has to be run against the live Supabase project.
- The cart rules (total, merge, clamp) live in plain functions that are easy to test.
- The search screen's fake "added" flag goes away.

**Negative / tradeoffs**:
- Two quick taps on different devices at once could still make a duplicate line (the merge is not enforced in the database). The sign in merge and the next add tidy it up.
- The screen shows changes before the server confirms them, so a failure means the shopper sees a change jump back.
- Quick add picks the first size and colour, which may not be what the shopper wants. They can change it in the cart only by removing and adding again from product detail.
- The cart is reachable only from the Home header icon for now.
- Checkout is a placeholder, so the cart cannot be turned into an order yet.

**Neutral**:
- A new `lib/features/cart/` code folder (the empty directory in `AGENTS.md` becomes real), and the root `AGENTS.md` feature list needs a line for it (`/sync` owns that).
- The Add to cart button on product detail now reads from the cart, so its added state survives leaving the page.
- The product detail page still has no colour picker, so it adds the first colour.

## Rationale

Reasoning and options: see [rationale.md](rationale.md).

## Follow-up

- [ ] Add a count badge on the Home cart icon, and a way into the cart from the other tabs (today only the Home header opens it)
- [ ] Add a colour picker to product detail, so the colour is a choice and not always the first one
- [ ] Design checkout (address, payment, order creation), then replace the coming soon page and use the existing `OrderRepository`
- [ ] Add a database unique index on user, product, size and colour with an atomic add function, if duplicates from two devices ever show up
- [ ] Update `docs/specs/buyer/0006-search-flow/index.md`: its AC-8 says the result row's add to cart is local only and changes no cart, which this spec replaces
- [ ] Decide whether the deal price (`originalPrice`) should show struck through on cart cards
- [ ] Give the Checkout coming soon page a back arrow (it has none, the tab bar is the only way out today)
