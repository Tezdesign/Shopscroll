# 0008. Build the Activity screens: rationale

Decision record for [index.md](index.md). Not needed to build against; kept for the history behind the choice.

## Context

> ⚠️ Premise note: this topic covers three tabs (Purchases, My collection, Messages) and one data decision (real saving), which are separable pieces of work. They are kept in one spec because they share one screen, one search field and one tab bar, and the build plan is ordered so the collection ships first and Purchases and Messages follow. Two of the pieces depend on features that have no spec yet: order details and chat. Those are handled as coming soon pages, and the missing specs are listed in Follow-up.

The Activity item in the bottom tab bar exists, but its screen is a placeholder that says "Activity coming soon". The project already has most of the parts an Activity screen needs. It has an `Order` model with a status, an orders provider with mock and Supabase versions, an `OrderStatusBadge`, an item card with a saved variant, a reel card, a `SegmentedTabs` widget that was built for the Purchases, My collection and Messages row, and a search field.

What is missing is the meaning of "My collection". Today the bookmark on product detail and the bookmark in the Reels player are session only flags in the screen's own state, so nothing is stored and nothing could be listed. A `reel_saves` table exists in Supabase and the reel repository reads it, but no code writes to it. There is no table for saved products. There is also no model, table or repository for messages, and the Chat now button on product detail does nothing.

The Figma file has four frames for this: Purchases (orders grouped by date with thumbnails, a total and a status badge), My collection with a Products pill (item cards with a filled bookmark) and a Reels pill (a two column grid of reel cards with a bookmark), and Messages (a list of avatar, name, last message and time). None of them draws an order detail, a chat, or any empty, loading or error state.

Project constraints that apply: the mock and Supabase backends must behave the same to the screens, all data goes through repository interfaces and Riverpod providers, every colour and size comes from the design tokens, and per person tables compare `user_id` to the JWT `sub` because Clerk ids are not uuids (spec 0004). The engineer chose real saving for both products and reels, no merge of anonymous saves at sign in, and a mock only Messages list.

## Options considered

### Option 1: Repository backed saves with optimistic notifiers

A new `product_saves` table modelled on `reel_saves`, a saved product repository and save methods on the reel repository (mock and Supabase), and two optimistic notifiers built like the cart notifier. Purchases reads the existing orders provider, and Messages reads a new mock only conversation repository.

**Pros**:
- Saves survive a restart and every bookmark in the app shares one state.
- Reuses the proven cart pattern and the existing `reel_saves` table, so the new work is small and familiar.
- Taps feel instant, and a failed write is undone in one place.

**Cons**:
- Needs one migration run by hand against the live project.
- Anonymous saves are lost at sign in until a merge is added.
- Messages shows nothing on the real backend for now.

### Option 2: Session only saves in memory

Keep the bookmark flags but move them into one provider held in memory, so the collection fills from what was tapped this run.

**Pros**:
- No migration and no repository work.
- Fastest to build.

**Cons**:
- The collection empties on every restart, which defeats the point of a collection.
- Bookmarks that look permanent but are not would mislead shoppers.
- The work is thrown away once real saving is wanted.

### Option 3: One polymorphic `saved_items` table for products and reels

A single table with an item type and an item id, replacing `reel_saves`.

**Pros**:
- One table and one repository for every kind of save.
- Adding a third saveable type later needs no migration.

**Cons**:
- Loses the foreign keys, so a deleted product or reel leaves a dead row behind.
- Means migrating away from `reel_saves`, which already exists and has policies.
- Joining to the right table depends on the type column, which is easy to get wrong.

## Rationale

Option 1 fits the forces in Context. The engineer wants a real collection, so Option 2 is out. `reel_saves` already exists with correct row level security, so Option 3 would mean replacing a working table to gain flexibility nobody has asked for, and it gives up the foreign keys that keep the data clean. Copying `reel_saves` for products keeps one pattern for both, and the cart notifier from spec 0007 already solved the hard part, which is instant updates that revert when a write fails. Purchases needs nothing new because the orders data, the badge and the card exist.

Three smaller calls were made along the way. The tabs and the typed search text are widget state on one `/activity` route, because these tabs have no reason to be linked to on their own and the shell already keeps the Activity tab's state while the person visits other tabs. Messages is mock only on the real backend, because a conversations table with no way to write to it would be a table designed without its feature. Undo keeps the old save time, so a restored item returns to its place and not to the top.

The engineer chose not to merge anonymous saves at sign in because the anonymous handling is due to change. That is recorded as a follow up and a consequence, so it is a known gap and not a surprise.
