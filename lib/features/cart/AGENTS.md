# lib/features/cart

The buyer's cart: the screen at `/cart`, and the one helper every Add to cart button goes through.
Governing spec: `docs/specs/0007-cart-interface/index.md` (acceptance criteria AC-1 to AC-18).

## Files

- `cart_screen.dart` (`CartScreen`): header, the line list (one `ItemCard` per line, oldest first), the
  pinned footer with the total and "Proceed to checkout", and the empty, loading and error states.
  Figma node 369:362. Screen only widgets stay private in this file.
- `cart_logic.dart`: plain functions with no Flutter code (`cartTotal`, `cartTotalLabel`,
  `sortedByAddedAt`, `findLine`, `hasProduct`, `clampQuantity`, `firstSize`, `firstColor`, and
  `maxCartQuantity` = 99). Unit tested in `test/features/cart/cart_logic_test.dart`. The mock and Supabase
  repositories and the notifier all import it, so the merge and clamp rules live in one place. That makes
  `lib/data/` import from `lib/features/cart/`, which the spec chose on purpose.
- `add_to_cart.dart`: `addToCart(context, product, ...)` is the only way an Add to cart button should
  add (product detail, the Home and Discover product cards, search result rows). It refuses a product
  with `inStock` false ("This item is out of stock"), defaults size and colour to the product's first
  ones, and shows "Couldn't update your cart. Try again." when the write fails. `showCartSnackBar` and
  `guardCartWrite` are the shared message helpers. The Reels screens have no Add to cart and must not
  get one (AC-18).

## Conventions

- The cart state is `cartItemsProvider` (`lib/data/providers/cart_providers.dart`), an `AsyncNotifier`.
  Every write (`add`, `setQuantity`, `changeQuantity`, `remove`, `undoRemove`) changes the state at once,
  then saves through `CartRepository`, and puts the state back and rethrows if the save fails. Writes run
  one after another. From a button, prefer `changeQuantity(id, +1 or -1)` over `setQuantity`, because it
  reads the quantity when the call runs and so cannot use a stale number.
- A line added on screen has a `local-N` id until the save returns the real one. The notifier maps it, so
  never use a line's id as a stable key across a save.
- The provider has retry turned off on purpose: Riverpod 3 retries a failed load by default, which would
  keep the screen on a spinner and hide the error state with its "Try again" button.
- One line per product, size and colour. Adding the same variant raises the quantity (up to 99).
- Tests that read the cart through a mock repository must wait `mockNetworkDelay` twice for a first add
  (once to load the cart, once to save). Use `tester.runAsync` to read the mock repository directly, since
  its `Future.delayed` never completes inside fake async.
- Checkout (`/cart/checkout`) is a `ComingSoonScreen`. Nothing creates an order yet.

_Drafted by /sync from the introducing change, worth a quick human pass._
