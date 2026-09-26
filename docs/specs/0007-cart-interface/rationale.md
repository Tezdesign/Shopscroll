# 0007. Build the cart interface: rationale

Decision record for [index.md](index.md). Not needed to build against; kept for the history behind the choice.

## Context

> ⚠️ Premise note: the cart is reachable only from the cart icon in the Home header, so shoppers on Discover, Reels or Profile have no way in. The engineer chose this on purpose (the icon already exists on Home and the Figma frame draws no other entry). It is fine for a first pass, but a cart that hides on one tab will feel lost once Add to cart buttons work everywhere. A badge and other entry points are listed in Follow-up.

The app has a cart data model (`CartItem`), a `cart_items` table with row level security for select, insert, update and delete (spec 0003 and 0004), a sign in merge function that folds an anonymous cart into a real account, and an `ItemCard` widget built from the same Figma component the cart frame uses. What it does not have is a cart screen or any way to write to the cart. `CartRepository` only has `getCartItems()`, and every Add to cart control is fake: product detail flips a local flag, the `ProductCard` pill has no handler, and search result rows flip a local set (spec 0006).

The Figma cart frame draws a title with a back arrow, four item cards (image, store, title, price, a "- 1 +" stepper and a red trash icon), a total labelled "items price", and a "Proceed to checkout" button, with the bottom tab bar visible and Home highlighted. No payment, delivery or order design exists yet.

The project constraints that apply: the mock and Supabase backends must behave the same, all data goes through the repository interface and Riverpod providers, every colour and size comes from the design tokens, and a shopper can be anonymous, so the cart must belong to whoever the current session is.

## Options considered

### Option 1: A repository backed cart with an optimistic notifier

Add write methods to `CartRepository` (mock and Supabase), turn `cartItemsProvider` into an `AsyncNotifier` that updates the state first and reverts on failure, and build the screen from `ItemCard`. Merging a duplicate is done in the repository by finding the matching line first.

**Pros**:
- Reuses the existing table, row level security and sign in merge, so no migration.
- Taps feel instant, and the same notifier serves the cart screen and every Add to cart button.
- Follows the project's repository and provider pattern exactly.

**Cons**:
- The merge is not atomic in the database, so two devices adding at the same moment could make a duplicate line.
- Optimistic updates need revert logic and tests.

### Option 2: An in memory cart only

Hold the cart in a Riverpod notifier with no repository writes and sync to the backend later.

**Pros**:
- The least code, and no backend work.

**Cons**:
- The cart is lost when the app closes, and it ignores the `cart_items` table that already exists.
- The sign in merge would have nothing to merge, and the mock and Supabase backends would stop behaving the same.

### Option 3: A server side add function with a unique index

Add a migration with a unique index on user, product, size and colour and an `add_to_cart` database function that inserts or raises the quantity atomically.

**Pros**:
- Correct under any concurrency, and duplicates become impossible.

**Cons**:
- Needs a migration applied to the live project (a manual step in this project) and a mock version of the same function.
- More moving parts than a cart of a few lines needs today.

## Rationale

Option 1 gives a real, saved cart with the least new machinery. The forces that decide it: the table and its rules already exist, the sign in merge already handles carts, and the app runs on two backends that must agree. Option 2 would throw that work away, and Option 3 solves a two device race that a person adding to a cart almost never causes. Because writes from one device are queued and applied in order, the only remaining duplicate risk is two devices at once, and the merge function already tidies that. If duplicates ever appear, Option 3 becomes a small follow up (listed).

The updates show first because cart taps are frequent and small, and a wait on every plus tap would feel broken. The revert on failure keeps the screen honest.

The smaller calls, made here so the build does not stall:
- **Quantity cap of 99**: a stepper with no upper bound invites a runaway tap, and 99 is far above any real order. Runner up: no cap.
- **Added state comes from the cart**, not from a local flag: it then survives leaving the page and reflects a removal. Runner up: keep a local flag (what exists today).
- **Quick add uses the first size and colour**, as decided with the engineer, because product cards and search rows have no picker. Runner up: open product detail when a product has options.
- **A snack bar on the product card pill only**: the pill has no added state of its own, while the detail button and the search icon already change to show it.
- **No "View cart" action on that snack bar**: `/cart` lives in the Home tab, and pushing it from another tab would switch branches in a surprising way. A real entry from other tabs is a follow up.
- **Oldest added first**: matches how lines were added and keeps a line from jumping when its quantity changes.
- **Size label and colour dot on the card**: without them, two sizes of one product look like a duplicated line.
