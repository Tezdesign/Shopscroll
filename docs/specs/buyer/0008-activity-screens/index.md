# 0008. Build the Activity screens

**Date**: 2026-09-26
**Status**: In Progress

## Summary

This turns the Activity tab from a placeholder into three real tabs inside one screen: Purchases (the person's past orders), My collection (saved products and saved reels) and Messages (a list of store conversations). The bookmark buttons on product detail and in Reels start saving for real, so what a person saves shows up in My collection and survives a restart. Saved products get one new table, saved reels use the table that already exists, and Messages reads from mock data only for now, because no chat feature exists yet.

Reasoning and options: see [rationale.md](rationale.md).

## Requirements

**User stories**:
- As a shopper, I want to see my past orders with their status, so that I know what I bought and what is on its way.
- As a shopper, I want to save products and reels and find them again in one place, so that I can come back to what I liked.
- As a shopper, I want to remove something from my collection and undo it by mistake, so that the collection stays what I want.
- As a shopper, I want to find a purchase, saved item or conversation by typing part of its name, so that I do not have to scroll.
- As a shopper, I want to see my conversations with stores, so that I know which ones have news.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1**: The Activity item in the bottom tab bar opens `/activity`. The screen shows a search field, a tab row "Purchases", "My collection", "Messages" (opening on Purchases), and the body of the active tab. The bottom tab bar stays visible with Activity highlighted. Tapping a top tab swaps the body in place and does not change the route.
- **AC-2**: Typing in the search field narrows the active tab's list live, on the device, ignoring case and surrounding spaces. Purchases match on any item's title or store name. Saved products match on title or store name. Saved reels match on caption or store name. Conversations match on store name or last message. The typed text stays when the tab changes and applies to the new tab. When nothing matches, the tab shows "No results found for “<text>”".
- **AC-3**: Purchases lists one block per order, newest first. Each block shows the date (day and short month, like `27 Feb`, plus the year when it is not the current year) with a right chevron, thumbnails of the first two items (80 by 80), "+ N products" when the order has more than two items, the order total written like `$320`, and the status badge (Delivered, In progress or Canceled).
- **AC-4**: Tapping a Purchases block opens `/activity/orders/:id`, a "Order details coming soon" page inside the Activity tab (tab bar visible). Nothing is written.
- **AC-5**: My collection has two pills, "Products" and "Reels", opening on Products. Products lists one row per saved product, newest saved first, using the saved variant of the item card: image, store avatar and name, title (two lines at most), price, and a filled bookmark. Tapping the row body opens `/product/:id`.
- **AC-6**: Reels shows the saved reels in two columns, newest saved first: store avatar and name with a filled bookmark at the top right, the thumbnail, and the caption (two lines at most). Tapping an available reel opens the reel player at `/reels/:id`, paging through the saved available reels in that order. An unavailable reel shows dimmed with "No longer available", cannot be opened, and its bookmark still works so it can be cleared.
- **AC-7**: Tapping the bookmark on a collection card removes it at once with no confirmation and shows the snack bar "Removed from saved" with "Undo". The snack bar goes away by itself after about 4 seconds. Undo puts the item back in its old place in the list.
- **AC-8**: Saving is real. The bookmark on product detail saves or unsaves that product, and the bookmark in the Reels player saves or unsaves that reel. The bookmark shows filled whenever the item is saved, including after leaving and reopening the screen. Saving on one screen shows on every other screen at once. Product detail keeps its "Added to saved products" toast.
- **AC-9**: Saves are stored per person on Supabase (anonymous or signed in) in `product_saves` and `reel_saves`, and survive an app restart. Saves made before signing in are not merged into the real account (chosen on purpose, see Follow-up). On the mock backend saves live in memory for the app run. Both backends behave the same to the screens.
- **AC-10**: If a save or unsave write fails, the state goes back to what it was and a snack bar says "Couldn't update your saved items. Try again."
- **AC-11**: Messages lists conversations, newest first: a round store avatar, the store name, the last message, and the time on the right (like `4:25am` when sent today, like `27 Feb` otherwise). An unread conversation shows its name, message and time in the darker text colour, a read one shows the message and time in the lighter one. Tapping a row opens `/activity/chat/:id`, a "Chat coming soon" page inside the Activity tab.
- **AC-12**: Each list shows a loading indicator while it loads. If loading fails it shows "Couldn't load <purchases, your collection or your messages>." with a "Try again" button. An empty list shows "No purchases yet", "No saved products yet", "No saved reels yet" or "No messages yet".
- **AC-13**: On the Supabase backend Messages shows its empty state, because the Supabase conversation source returns an empty list until a chat feature designs a table. No conversations table is created in this spec.
- **AC-14**: The tab rows, search field, each bookmark, each row and each card have a spoken label and a tap area of at least 44 by 44 logical pixels.
- **AC-15**: Reels likes stay session only, the Reels grid screen is unchanged, and nothing on these screens creates an order or a message.

## Decision

**Chosen option**: Option 1: Repository backed saves with optimistic notifiers

Give saved products their own repository (mock and Supabase) over a new `product_saves` table, add save and unsave to the reel repository over the existing `reel_saves` table, run both through optimistic `AsyncNotifier` providers built like the cart, read Purchases from the existing orders provider, read Messages through a new mock only conversation repository, and build all of it as one `/activity` screen with tabs kept in widget state.

**Implementation skills**: `supabase` (`supabase/agent-skills`, `.agents/skills/supabase/`) · `supabase-postgres-best-practices` (`supabase/agent-skills`, `.agents/skills/supabase-postgres-best-practices/`)

## Feature design

**Design source**: Figma file `toOakybJ0DaJmU7vcEC0AW`, four frames the engineer gave: Purchases (node 291:2537), My collection products (292:8980), My collection reels (309:2196), Messages (826:4960). The frames also draw the tab bar with Activity highlighted.

**Data model sketch**:

New table `product_saves` (migration `0002`, modelled on `reel_saves`):

| Column | Type | Rules |
|---|---|---|
| `user_id` | text | part of the primary key, the Clerk id or the anonymous session `sub` |
| `product_id` | uuid | part of the primary key, foreign key to `products (id)`, on delete cascade |
| `created_at` | timestamptz | not null, default now(), the save time that orders the list |

Also: an index on `product_id`, row level security enabled, and the grant below. One row means one save, and the primary key makes a repeat save a no op.

Existing `reel_saves` (`user_id`, `reel_id`, `created_at`) is unchanged. The app starts writing to it.

App models (no table): `SavedProduct` (the `Product` plus `savedAt`), `SavedReel` (the `Reel` plus `savedAt`), `Conversation` (`id`, `storeId`, `storeName`, `storeAvatarUrl`, `lastMessage`, `sentAt`, `isUnread`). Orders and the `Order` model are read as they are.

Relationships: a person has many saved products and many saved reels (1 to N each); a product or reel can be saved by many people. Deleting a product or reel removes its saves (cascade).

**State transitions**:
- Saved item: not saved → saved (bookmark) → not saved (bookmark on the item or on the collection card) → saved again (Undo, keeping its old `savedAt`).

**API surface** (repository methods and the REST calls they stand in for, per the project convention):

| Function | Stands in for | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| `SavedProductRepository.getSavedProducts()` | `GET /saved-products` | none | `List<SavedProduct>`, newest saved first | signed in or anonymous session | empty list when no session |
| `SavedProductRepository.saveProduct(product, savedAt?)` | `PUT /saved-products/:productId` | product:Product (req), savedAt:DateTime (opt, used by Undo) | the `SavedProduct` | own rows only | write failure throws |
| `SavedProductRepository.unsaveProduct(productId)` | `DELETE /saved-products/:productId` | productId:String (req) | nothing | own rows only | write failure throws |
| `ReelRepository.getSavedReels()` | `GET /saved-reels` | none | `List<SavedReel>`, newest saved first, unavailable reels included | signed in or anonymous session | empty list when no session |
| `ReelRepository.saveReel(reel, savedAt?)` | `PUT /saved-reels/:reelId` | reel:Reel (req), savedAt:DateTime (opt) | the `SavedReel` | own rows only | write failure throws |
| `ReelRepository.unsaveReel(reelId)` | `DELETE /saved-reels/:reelId` | reelId:String (req) | nothing | own rows only | write failure throws |
| `ConversationRepository.getConversations()` | `GET /conversations` | none | `List<Conversation>`, newest first | signed in or anonymous session | Supabase version returns an empty list |
| `OrderRepository.getOrders()` (exists) | `GET /orders` | none | `List<Order>` | signed in or anonymous session | none new |

Saving is idempotent: the Supabase writes use an upsert (insert, do nothing on a repeat) and a delete of a missing row is not an error.

Providers (`lib/data/providers/`, each keeps the endpoint doc comment convention):
- `savedProductsProvider` and `savedReelsProvider`, `AsyncNotifierProvider`s. Each exposes `save(...)`, `unsave(id)` and `toggle(...)`. Each call updates the state first, then writes through the repository, and puts the state back and rethrows if the write fails. Calls run one after another. Retry is turned off so a failed load reaches the screen as an error (same as `cartItemsProvider`, spec 0007).
- `conversationsProvider`, a `FutureProvider` over `ConversationRepository`.
- `ordersProvider` (exists) feeds Purchases, sorted newest first on the screen.

Screens and files:

| Item | Where | Notes |
|---|---|---|
| Route `/activity` | `app_router.dart`, replaces the `ComingSoonScreen` in the Activity branch | builds `ActivityScreen` |
| Route `/activity/orders/:id` | child of `/activity` | `ComingSoonScreen(label: 'Order details', ...)` |
| Route `/activity/chat/:id` | child of `/activity` | `ComingSoonScreen(label: 'Chat', ...)` |
| `ActivityScreen` | `lib/features/activity/activity_screen.dart` | search field, top tab row (`SegmentedTabs`, space between variant), active tab body. The tab and the typed text are widget state. |
| Tab bodies | `lib/features/activity/purchases_tab.dart`, `collection_tab.dart`, `messages_tab.dart` | private widgets for their own rows and states |
| Activity helpers | `lib/features/activity/activity_logic.dart` | plain functions: filters for each tab, date and time labels, the "+ N products" count. Unit tested. |
| Save actions | `lib/features/activity/save_actions.dart` | one helper the bookmark on product detail, in the Reels player and on collection cards all call, with the failure snack bar and the Undo snack bar |
| Pill tabs | `lib/shared/widgets/pill_tabs.dart` | new: the Products and Reels pills (Figma 309:1985), active pill light blue with blue text |
| `ItemCard` | `lib/shared/widgets/item_card.dart` | the `saved` trailing gets an `onUnsave` callback, a spoken label and a 44 by 44 tap area |
| `ReelCard` | `lib/shared/widgets/reel_card.dart` | gains an optional bookmark in its store row (`saved`, `onSaveTap`), off by default so the Reels grid is unchanged |
| Purchase block, conversation row | private widgets in their tab files | Figma 322:2641 and 874:5784 |
| Product detail, Reels player | `product_detail_screen.dart`, `reel_player_screen.dart` | replace their local saved flags with the providers |
| Mock data | `lib/data/mock/mock_saved_products.dart`, `mock_conversations.dart` | seed 3 saved products and 3 conversations; the 2 reels already marked `isSaved` seed saved reels |
| Migration | `supabase/migrations/0002_product_saves.sql` | table, index, RLS, grant |
| Account deletion | `supabase/functions/_shared/delete_user_data.ts` | also deletes `product_saves` rows |

**Key invariants**:
- One save per person per product, and per person per reel (primary keys).
- The collection lists are read from the notifier state, never stored separately, so a save anywhere shows everywhere.
- The screen never shows a state the server refused: a failed write reverts the state before the message shows.
- Writes are serialized per app run, so quick taps apply in order.
- A collection list is ordered by save time, newest first, and Undo keeps the old save time.

**Security model**: `product_saves` follows the same owned table rules as `reel_saves`. Row level security is on, and three policies compare the row's `user_id` to `(select auth.jwt() ->> 'sub')`: select, insert and delete of own rows only, with no update policy. The grant is `select, insert, delete` to `authenticated` (anonymous sessions use that role with the anonymous claim, as everywhere else). The repository never sends a `user_id` it did not read from the current session. No payment or personal data is stored. Saves are not merged at sign in (see Follow-up), and account deletion removes them (`delete_user_data.ts`).

**Configuration required**: none. The migration `0002` must be run against the live Supabase project by hand, like `0001`.

**Deviations from the Figma frames** (each is a fix or a forced change):
- Totals read `$320` (app style, like spec 0007), not `320$`.
- The search hint reads "Search for anything" on all tabs (the frames show "Search" on two of them).
- The Reels grid uses the existing `ReelCard` width (172.5) so two columns fill the screen, not the frame's 160 wide cards with a 41 gap.
- The chevron beside a date is drawn with the app's `chevron_right` glyph.
- Sample text in the Messages frame is French placeholder text and the layer names come from a seller component ("Emily Richardson"). The mock conversations use English text and real store names.
- The unread look is read from the frame (the first row is darker than the second) and modelled as `isUnread`.
- The device status bar is not built.
- Loading, error, empty, Undo and failure states are not drawn in the frames and follow the app's existing patterns.

**Critical test scenarios** (each maps to an acceptance criterion in `## Requirements`):
- Happy path: tap Activity, see Purchases, switch to My collection, see saved products, tap a row and reach product detail, verifies **AC-1**, **AC-5**
- Save on detail: save a product on its page, open Activity then My collection, see it first in the list, verifies **AC-8**
- Remove and Undo: tap a bookmark on a collection card, see the snack bar, tap Undo, see the item in its old place, verifies **AC-7**
- Reels: save a reel in the player, see it in Reels pill, tap it and the player opens on it; an unavailable saved reel is dimmed and its bookmark clears it, verifies **AC-6**, **AC-8**
- Failure: make the repository throw on `unsaveProduct`, see the card come back and the message, verifies **AC-10**
- Search: type in the field on each tab, see the list narrow, switch tabs and keep the text, type nonsense and see the no results message, verifies **AC-2**
- Purchases: a 3 item order shows two thumbnails and "+ 1 products", the badge matches the status, tapping opens the coming soon page, verifies **AC-3**, **AC-4**
- Messages: unread row is darker, tap opens "Chat coming soon"; on the Supabase source the list is empty, verifies **AC-11**, **AC-13**
- Empty, loading and error states render on every list, verifies **AC-12**
- Persistence: save on Supabase, restart, the item is still there; a second person cannot read or delete the first person's row, verifies **AC-9**
- Accessibility: each bookmark, tab, row and card has a label and a 44 pixel tap area, verifies **AC-14**
- Unchanged: Reels grid and likes behave as before, no order or message is created, verifies **AC-15**

## Build plan

The project has no recorded build approach (the scope header says Tracer Bullet is assumed). The plan stands up one thin thread through every layer first (a real save on product detail shows up in the collection), then thickens it with the rest of the collection, then adds Purchases and Messages.

1. Write `supabase/migrations/0002_product_saves.sql` (table, index, RLS policies, grant), add `product_saves` to `delete_user_data.ts`, run the migration against the live project and confirm the table, policies and cascade exist, satisfies **AC-9**
2. Add the `SavedProduct` and `SavedReel` models, `SavedProductRepository` (mock with a seeded in memory copy, Supabase with upsert and delete), and `saveReel`, `unsaveReel` and `getSavedReels` on `ReelRepository` (mock and Supabase), wire the provider overrides in `repository_providers.dart` and `main.dart`, with unit tests on the mock, satisfies **AC-9**
3. Add `savedProductsProvider` and `savedReelsProvider` (serialized writes, update first, revert and rethrow on failure, retry off, Undo keeps `savedAt`), with unit tests, satisfies **AC-7**, **AC-8**, **AC-10**
4. Thin thread: replace the Activity placeholder with `/activity` and `ActivityScreen` (search field, top tab row, Purchases and Messages bodies as empty placeholders), the My collection tab with the Products pill listing saved products through the saved `ItemCard`, and wire product detail's bookmark to `savedProductsProvider`, satisfies **AC-1**, **AC-5**, **AC-8**
5. Add `PillTabs`, the Reels pill with the two column grid of saved reels, the `ReelCard` bookmark, the unavailable look, wire the Reels player's bookmark to `savedReelsProvider`, and open the player over the saved list, satisfies **AC-6**, **AC-8**
6. Bookmark on a collection card removes with the Undo snack bar, and the shared failure snack bar (`save_actions.dart`), satisfies **AC-7**, **AC-10**
7. Purchases tab: date, thumbnails, "+ N products", total and status badge from `ordersProvider`, and the `/activity/orders/:id` coming soon route, satisfies **AC-3**, **AC-4**
8. Add the `Conversation` model, `ConversationRepository` (mock with seeded rows, Supabase returning an empty list), `conversationsProvider`, the Messages tab and the `/activity/chat/:id` coming soon route, satisfies **AC-11**, **AC-13**
9. Search field filtering for every tab in `activity_logic.dart`, with unit tests, satisfies **AC-2**
10. Loading, error and empty states on every list, satisfies **AC-12**
11. Accessibility labels and tap areas, and widget tests that mirror `lib/` under `test/features/activity/` (including that the Reels grid and likes are unchanged), satisfies **AC-14**, **AC-15**

## Consequences

**Positive**:
- One save mechanism serves product detail, the Reels player and the collection, and it is stored, so it survives a restart.
- Products need one small new table that copies an existing, proven one, so the risk is low.
- Purchases needs no new data: orders, the badge and the item card already exist.
- The local "saved" flags on product detail and in the Reels player go away.

**Negative / tradeoffs**:
- A migration must be run by hand against the live Supabase project before the Supabase saves work.
- The screen shows changes before the server confirms them, so a failure means the shopper sees a change jump back.
- Saves made while anonymous are lost at sign in (no merge, chosen on purpose for now).
- Messages is empty on the real backend until a chat feature exists, so only the mock backend shows the list.
- The Undo of a removal is a new insert, so it briefly has no row on the server.
- Order details and chat open coming soon pages, so those two taps lead nowhere useful yet.

**Neutral**:
- A new `lib/features/activity/` code folder, and the root `AGENTS.md` context file list needs a line for it (`/sync` owns that).
- Spec 0002 (Reels) chose session only like and save on purpose. This spec replaces that choice for save only. Likes stay session only.
- `Reel.isSaved` stays on the model as what the list read returns, but screens read the saved state from the provider.

## Follow-up

- [ ] Update `docs/specs/buyer/0002-reels-screen.md`: its decision that save is session only is replaced for save by this spec (AC-8)
- [ ] Decide the anonymous save merge when the anonymous handling is redone (the engineer plans changes there): today `merge_anonymous_identity` folds cart and orders only, and saves are not carried over
- [ ] Design the order details screen, then replace the `/activity/orders/:id` coming soon page (`OrderRepository.getOrderById` already exists)
- [ ] Design chat (conversations table, messages, sending), then replace the mock only `ConversationRepository` on Supabase and the `/activity/chat/:id` coming soon page. Wire the inert "Chat now" button on product detail to it
- [ ] Add a count badge for unread conversations on the Activity tab once chat is real
- [ ] Give the coming soon pages a back arrow (the tab bar is the only way out today, same as checkout in spec 0007)
- [ ] Add pagination to the Purchases and collection lists if a person ever holds hundreds of items
