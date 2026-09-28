# Verify: Purchasing flow · spec 0009 · updated 2026-09-28
_Steps derived from spec 0009 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._

## UI / manual
- [ ] Cart → tap "Proceed to checkout" → `/checkout` opens full screen with no tab bar, title "Checkout" and an X on the left   → AC-1
- [ ] Empty the cart, open `/checkout` → "Your cart is empty" with "Back to cart", no form; the button returns to the cart   → AC-1
- [ ] Sections run top to bottom: Shipping items (open, listing every line), Contact information, Delivery address, Delivery Method, Order Summary, Payment method; "Place order" stays pinned at the bottom and is light blue   → AC-2, AC-10
- [ ] Tap "+ Add your contact info" → the sheet shows a full name field, an email field, a phone field on +216 with a dial code picker, and Continue; no save toggle   → AC-3, AC-4
- [ ] In that sheet tap Continue with empty fields → a message under each field and the sheet stays open; fill valid values → Continue closes it and the section shows the name in bold with the email and phone in grey   → AC-3, AC-4
- [ ] Tap the pencil on the filled contact → the sheet reopens with the values; change the name and close with the round X → the old name is kept   → AC-3, AC-4
- [ ] With the keyboard open in either sheet, the fields and Continue stay above the keyboard   → AC-4, AC-6
- [ ] Signed in with a full profile → the contact section starts filled; with a profile missing a phone or email → it starts empty but the sheet fills what exists; signed out → empty. The address is empty in every case   → AC-5
- [ ] Tap "+ Add your address" → the sheet shows "Add current location" (looks disabled, tapping does nothing), city, address, zip code, an optional note, and Continue   → AC-6
- [ ] Continue with empty city, address or zip → messages and the sheet stays; a valid address fills the section with "Tunisia" in bold, `address, city, zip`, and the note   → AC-6
- [ ] Tap the Standard tile, then Exclusive → only one is selected (blue border, filled ring); Delivery shows `$10` then `$16` and Price to pay follows; before any choice Delivery shows "Not chosen" and Price to pay equals the subtotal   → AC-7, AC-8
- [ ] Type in the discount code field and tap Apply → nothing happens, no discount line appears, Apply looks disabled   → AC-8
- [ ] Payment shows "Pay by Credit Card" (lock icon and four card logos) and "Pay on delivery", neither chosen; choosing card opens no sheet   → AC-9, AC-24
- [ ] Fill contact, address, delivery type and choose Pay by Credit Card, tap Place order → "Card payment is coming soon", nothing is created, the cart is unchanged   → AC-10, AC-11
- [ ] Choose Pay on delivery, tap Place order (try several quick taps) → the button reads "Placing order", then the confirmation opens; exactly one order exists   → AC-12
- [ ] Force a failure (turn the network off on Supabase) → "Couldn't place your order. Try again.", the typed details and choices stay, the cart is unchanged, the button works again   → AC-13
- [ ] Change a product's price (or set `in_stock` false) in the database after Checkout opened, tap Place order → "Some items changed. Check your cart.", nothing is created, the cart reloads   → AC-13, AC-15
- [ ] With something typed or chosen, tap the X (and the system back gesture) → "Discard your details?" with "Keep editing" and "Discard"; Discard returns to the cart. With nothing typed the X leaves at once. A contact filled from a profile alone does not make it ask   → AC-14
- [ ] After the order, the Cart screen shows "Your cart is empty"; Activity → Purchases lists the new order first, "In progress", with the total; on Supabase it is still there after a full app restart, for a signed in buyer and an anonymous one   → AC-16
- [ ] The confirmation shows "Order Confirmation" with an X, "Order#00000N is confirmed", "Thank you for your order, {first name}!", the ready line, the summary card and "Go back to home page"   → AC-17
- [ ] Signed out: the "Be the first in line" text and a "Sign in" button show and open `/sign-in`; signed in: neither shows   → AC-17
- [ ] The summary card shows subtotal, Delivery, Total price, contact, "Tunisia" with the address line and note, the delivery method name with "Shipping price" and "Estimated arrival" (a date like `30 Sep` that skips weekends), and "Pay on delivery"   → AC-18
- [ ] "Go back to home page", the X and the system back on the confirmation all land on Home, never on Checkout   → AC-19
- [ ] Place an order signed out, then sign in → the order appears under the account   → AC-20
- [ ] Open the confirmation with a wrong order id → "Couldn't load your order." and "Go back to home page"; while loading a spinner shows   → AC-22
- [ ] With a screen reader on, the X buttons, the section links, the pencils, the delivery tiles and payment rows (with selected state), the sheet close buttons and the section headings are announced; tap areas are at least 44 by 44   → AC-23
- [ ] The Cart screen looks and works as before except where "Proceed to checkout" leads; Activity is unchanged except for the new orders   → AC-25

## Commands
- [ ] `flutter analyze` → no issues   → all
- [ ] `flutter test` → all pass, including `test/features/checkout/`, `test/data/checkout_models_test.dart`, `test/data/checkout_providers_test.dart`, `test/data/repositories/mock/mock_order_repository_test.dart` and the new widget tests under `test/shared/widgets/`   → AC-1 to AC-25
- [ ] `supabase migration list --linked` → `0003` is on both sides   → AC-21
- [ ] Query the live database: `orders` has `order_number` (identity, unique), `subtotal`, `contact_*` and `ship_*` columns and no `shipping_address`; only the two select policies exist on `orders` and `order_items`; `authenticated` has no insert, update or delete on either   → AC-21
- [ ] Query the live database: `place_order` exists, is `security definer` with `search_path=""`, `authenticated` can execute it and `anon` cannot   → AC-21
- [ ] As a test buyer (set `request.jwt.claims` to a `sub`, inside a transaction you roll back): an empty cart, a bad field, a bad delivery or payment method, an out of stock product and a wrong expected subtotal each raise `cart_empty`, `invalid_field`, `invalid_method`, `product_unavailable`, `price_changed` and leave the cart and orders unchanged   → AC-13, AC-15, AC-21
- [ ] Same setup: a good call returns the order id, `total_amount = subtotal + delivery_fee`, `order_items` hold the server prices, the cart is empty, and a second call with the same id returns the same order with one row   → AC-12, AC-15, AC-16
- [ ] Same setup: as `authenticated` a direct insert, update or delete on `orders` or `order_items` is denied, and a second buyer reads none of the first buyer's orders or items   → AC-21
- [ ] Two parallel `place_order` calls on one cart → one order is made and the other raises `cart_empty`   → AC-12, AC-21
- [ ] Order as an anonymous session, then run `merge_anonymous_identity` for the real account → the order's `user_id` moves and its items follow   → AC-20
- [ ] Run the app against Supabase (`flutter run --dart-define-from-file=env.json`) as a Clerk signed in buyer → Activity → Purchases loads (no error) with the newest order first   → AC-16
- [ ] `grep -rniE "cvv|cvc|card number|expir" lib supabase` → no card number, expiry or CVV field anywhere; nothing about a card is stored, sent or logged   → AC-24

## Acceptance-criteria coverage
- AC-1 … UI steps 1 and 2, `checkout_screen_test` · AC-2 … UI step 3, `checkout_screen_test` · AC-3 … UI steps 4, 5, 6, `checkout_screen_test`, `checkout_section_test` · AC-4 … UI steps 4, 5, 6, 7, `checkout_screen_test`, `checkout_sheet_test`, `checkout_logic_test` · AC-5 … UI step 8, `checkout_screen_test`, `checkout_providers_test` · AC-6 … UI steps 7, 9, 10, `checkout_screen_test` · AC-7 … UI step 11, `delivery_method_tile_test`, `checkout_screen_test` · AC-8 … UI steps 11, 12, `summary_row_test`, `checkout_screen_test`, `checkout_logic_test` · AC-9 … UI step 13, `payment_option_row_test`, `checkout_screen_test` · AC-10 … UI steps 3, 14, `checkout_screen_test`, `checkout_providers_test` · AC-11 … UI step 14, `checkout_screen_test` · AC-12 … UI step 15, `checkout_screen_test`, `mock_order_repository_test`, live database steps · AC-13 … UI steps 16, 17, `checkout_screen_test`, `mock_order_repository_test`, live database steps · AC-14 … UI step 18, `checkout_screen_test` · AC-15 … UI step 17, `mock_order_repository_test`, live database steps · AC-16 … UI steps 19, `checkout_screen_test`, `mock_order_repository_test`, live database steps · AC-17 … UI steps 20, 21, `order_confirmation_screen_test` · AC-18 … UI step 22, `order_confirmation_screen_test` · AC-19 … UI step 23, `order_confirmation_screen_test` · AC-20 … UI step 24, live database step · AC-21 … command steps · AC-22 … UI step 25, `order_confirmation_screen_test`, `checkout_screen_test` · AC-23 … UI step 26, widget tests with semantics · AC-24 … UI step 13, the grep step, `checkout_screen_test` · AC-25 … UI step 27, `cart_screen_test`
