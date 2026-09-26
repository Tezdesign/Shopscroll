# Verify: cart interface · spec 0007 · updated 2026-09-26
_Steps derived from spec 0007 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._

## UI / manual
- [ ] On Home, tap the cart icon in the header → the cart opens, the tab bar stays with Home highlighted, the back arrow returns to Home → AC-1
- [ ] Open the cart with 3 or more lines → one card per line, oldest first, each with image, store, title, price, quantity stepper and trash; a size label and colour dot where the line has them → AC-2
- [ ] Tap a card body → product detail opens for that product → AC-2
- [ ] Look at the footer → "Items price" with a total that equals the sum of price times quantity, written like `$224`, and a "Proceed to checkout" button pinned above the tab bar while the list scrolls → AC-3
- [ ] Tap plus five times quickly on one line → quantity rises by exactly 5 and the total updates at once → AC-4
- [ ] Raise a line to 99, tap plus → it stays 99 → AC-4
- [ ] On a line with quantity 1, look at minus → it is dimmed and does nothing; only the trash icon removes a line → AC-5
- [ ] Tap trash → the line goes at once with no confirmation, a snack bar shows "Undo", and it goes away by itself after about 4 seconds → AC-6
- [ ] Tap trash, then Undo before it goes away → the line returns with the same product, size, colour and quantity → AC-6
- [ ] Remove every line → "Your cart is empty" and a "Start shopping" button that goes to Home, no footer → AC-7
- [ ] Open the cart with the backend unreachable → an error "Couldn't load your cart." with a "Try again" button that reloads it → AC-8
- [ ] Tap "Proceed to checkout" → "Checkout coming soon" opens inside the Home tab and no order is created → AC-9
- [ ] On product detail, choose a size and quantity 2, tap Add to cart → the button shows its added state, and the cart holds that product with that size, quantity 2 and the first colour → AC-10
- [ ] On the same page, tap the added button again → nothing changes → AC-10
- [ ] On a Home or Discover product card, tap the Add to cart pill → "Added to cart" shows and the cart gains 1 of the product with its first size and colour → AC-11
- [ ] In search results, tap a row's cart icon → the icon shows the added state (green cart with a check) and the cart gains 1 → AC-12
- [ ] Add the same product, size and colour twice → one line with quantity 2; add it in a second size → two lines → AC-13
- [ ] Try to add a product with `inStock` false from each entry point → "This item is out of stock" and no new line → AC-14
- [ ] With the network cut, tap plus in the cart → the quantity jumps back and "Couldn't update your cart. Try again." shows → AC-15
- [ ] With Supabase configured, add items, restart the app → the lines are still there → AC-16
- [ ] With Supabase configured, add items anonymously, then sign in → the lines follow the sign in merge → AC-16
- [ ] With a screen reader on, move over the header cart icon, back arrow, plus, minus, trash, card and checkout button → each is spoken with a label; each tap area is at least 44 by 44 → AC-17
- [ ] Open a reel and its shop the look sheet → no Add to cart control appears → AC-18

## Commands
- [ ] `flutter analyze` → no issues found → all
- [ ] `flutter test` → all tests pass (cart logic, mock repository, notifier, cart screen, product detail, item card, search, app boot) → AC-1 to AC-17
- [ ] `git diff --stat -- lib/features/reels` → empty, the Reels screens are unchanged → AC-18

## Acceptance-criteria coverage
- AC-1 … Home icon step, `test/widget_test.dart` · AC-2 … card and tap steps, `cart_screen_test.dart` · AC-3 … footer step · AC-4 … plus steps, `cart_notifier_test.dart` · AC-5 … minus step · AC-6 … trash and Undo steps · AC-7 … empty step · AC-8 … error step · AC-9 … checkout step · AC-10 … product detail steps, `product_detail_screen_test.dart` · AC-11 … card pill step · AC-12 … search step, `search_screen_test.dart` · AC-13 … add twice step, `mock_cart_repository_test.dart` · AC-14 … out of stock step · AC-15 … network cut step · AC-16 … Supabase steps (manual only, not covered by a test) · AC-17 … screen reader step, `item_card_test.dart` · AC-18 … reels step and command
