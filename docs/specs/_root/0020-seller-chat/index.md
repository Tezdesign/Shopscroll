# 0020. Seller chat: the store's inbox, thread and "Message customer"

**Date**: 2026-11-06
**Status**: In Progress

## Summary

A seller reads and answers customer messages from the Messages tab of the seller shell (spec 0019). The tab lists the threads where the seller is the store, newest first, with an unread style per row and an unread dot on the tab and on the chat icon of the Home and Activity headers. Tapping a row opens the same thread screen the buyer uses, acting as the store. A seller can also start a thread from an order with "Message customer" on the order detail, which is the only way a store may begin a conversation. Everything the server needs already exists in spec 0011 (every chat function takes the role it acts in, `p_as`), so this spec adds screens and a role parameter to the app's chat code, and no tables. It depends on spec 0011's thread and inbox slices being built first.

Reasoning and options: see [rationale.md](rationale.md). Verification: see [verify.md](verify.md).

## Requirements

**User stories**:
- As a seller, I want one list of everyone who wrote to my store, with the unread ones first to notice, so that I answer customers quickly.
- As a seller, I want to answer in a thread that looks like the buyer's, so that I do not learn a second screen.
- As a seller, I want to message a customer from their order, so that I can ask about a delivery detail without waiting for them to write.
- As a seller, I want to know there is an unread message without opening the tab, so that I do not miss a customer.
- As a seller, I want to block someone who writes unwanted messages, so that I can stop them.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1** (inbox): The Messages tab (`/store/messages`) lists the threads where the signed in seller is the store, calling `chat_conversations_list` with `p_as = 'store'`. Newest first, 20 at a time, loading the next 20 at the end of the list. A row shows the customer's avatar (the first letter of their name when there is none), name, a preview of the last message, the time, and an unread style (bold name and preview, a `primary400` dot) when the last message is the customer's and later than the seller's read time. A search field above filters the loaded rows by customer name or preview. Pull down refreshes.
- **AC-2** (unread dot): While the seller has at least one unread thread (`chat_unread_count` with `p_as = 'store'` is above zero) the Messages tab shows a dot and the chat icon in the Home and Activity headers shows the same dot. The count updates when a message arrives and when a thread is opened, without a refresh.
- **AC-3** (open a thread): Tapping a row opens `/store/messages/:conversationId`. It is the buyer's thread screen (spec 0011) acting as the store: back arrow, the customer's avatar and name, the messages, the composer. The customer's name is not a link (a customer has no page). Opening the thread marks it read for the store.
- **AC-4** (send as the store): Text sending follows spec 0011 AC-4, AC-6 and AC-8 with the role `store`: the same optimistic bubble, the same live arrival within about 2 seconds, the same "Seen" mark. The seller's bubbles are the blue ones on the right, the customer's the grey ones on the left.
- **AC-5** (message customer): The order detail (`/store/activity/orders/:id`, spec 0018 AC-5) has a "Message customer" button under the customer block. It opens `/store/messages/order/:orderId`, which loads the thread for that order through `chat_thread_info` with `p_order_id`. If a thread already exists it is that thread. If none exists the screen shows the empty state "Say hello to <customer name>" and the first message creates the thread (`send_message` with `p_order_id`, spec 0011 AC-14). Nothing is stored until the first message is sent.
- **AC-6** (who may start): Only a current seller can start a thread, and only for an order that has a line from the seller's store. A seller who is no longer a seller can still read and reply in existing threads, and sees "You can't start new conversations" instead of an empty composer on a new one. An order of another store gives the not found screen, never the customer's name.
- **AC-7** (block): The thread menu has Block and Unblock (spec 0011 AC-12). While blocked, the seller sees "You blocked this customer" with an Unblock button, and a customer blocked this way cannot write. Built together with spec 0011's delete and block slice (its task 7), because the thread screen has no menu yet.
- **AC-8** (privacy): A seller sees a customer's name and avatar only through the chat functions and only for threads they are in. No screen shows the customer's email, phone or account id. "Message customer" never shows a customer id in the route, the route holds the order id.
- **AC-9** (empty and failure states): The inbox shows a loading indicator, a failure message with "Try again", and the empty state "No messages yet" with "When a customer writes to your store, it shows up here." The thread uses the failure messages of spec 0011 (`chatFailureText`).
- **AC-10** (mock backend): Without Supabase configuration the inbox, the thread and "Message customer" work in memory with the usual 300 ms delay, on seeded threads: three customers, one unread. After the seller's first message the mock customer shows "Typing..." and answers once, as in spec 0011 AC-21.
- **AC-11** (accessibility): Rows, the "Message customer" button, the composer and every menu action have a spoken label and a tap area of at least 44 by 44 logical pixels. An unread row says "unread" in its label.
- **AC-12** (scope guard): This spec adds no table, migration, push notification, email, template reply, broadcast to many customers, automatic reply, or change to the buyer's screens. The buyer's chat behavior stays as spec 0011 defines it.

## Decision

**Chosen option**: Option 1: reuse the buyer's thread code with a role

Add a `ChatRole` (`buyer` or `store`) to the app's chat code, pass it to every repository call (`p_as`), and reuse `ChatThreadScreen`, the composer, the bubbles and `chat_logic.dart` unchanged for the store. Add a seller inbox screen, a unread provider for the store, and the "Message customer" entry. The server needs nothing new.

**Implementation skills**: none expected. If the checks find a gap in a chat function for the store role, load `supabase` and `supabase-postgres-best-practices` before touching a migration.

## Feature design

**Design source**: Figma file `toOakybJ0DaJmU7vcEC0AW`, page "The design - seller", row at the bottom of the page (cloned from the buyer's frames on "The design - user", flow "Messages Flow": `messages-inbox-default` `826:4960`, `messages-thread-empty` `874:5806`, `messages-thread-typing` `874:5937`):
- `Messages-inbox-seller` (`5667:8915`): an unread row (bold, `primary400` dot) and a read row, the search field, the seller tab bar on Messages.
- `Messages-inbox-seller-empty` (`5667:8946`): "No messages yet".
- `Messages-thread-seller` (`5667:8977`): the thread acting as the store, the customer's name in the header, no phone icon.
- `Messages-thread-seller-new` (`5667:9026`): opened from an order, "Say hello to <name>" with the order number.
- `Order detail-seller (Message customer)` (`5667:10861`): the order detail with the "Message customer" button. The frame is a clone of the report details frame (`3001:11979`), because the order detail was built from the buyer receipt (spec 0018).
- The `tabbar-seller` component now reads Home, Products, Activity, Messages, Profile (spec 0019). Its icons are still the buyer ones (search, play) and should be swapped for the icons in spec 0019.

Deviations to record in each screen's doc comment: the seller bar labels differ from the Figma component (spec 0019), the customer's name is plain text instead of a link to a Store Page, and the buyer-side follower count in the empty state is left out, and the order number the frame shows under the name is not drawn either, because the thread information does not carry it.

**Routes** (declared inside the store area, spec 0019): `/store/messages` is the tab root. `/store/messages/:conversationId` and `/store/messages/order/:orderId` are top level, full screen over the tab bar. `order` is declared before `:conversationId` so it is never read as a conversation id.

**Data model sketch**: none. The tables, functions and checks of spec 0011 are used as they are: `chat_conversations_list`, `chat_unread_count`, `chat_thread_info` (with `p_order_id`), `send_message` (with `p_as = 'store'` and `p_order_id`), `mark_conversation_read`, and the delete and block functions.

**App changes**:
- `ChatRepository` gains a `ChatRole role` argument on the calls that need it, and `listConversations` and `unreadCount`, with mock and Supabase versions (these two are spec 0011's inbox slice and are built once, for both roles).
- `chatThreadProvider`'s key (`ChatTarget`) gains the role and an optional order id.
- A new `storeInboxProvider` and `storeUnreadProvider`, next to the buyer's.
- A feature folder `apps/buyer/lib/features/seller_chat/` with `seller_inbox_screen.dart` (the Messages tab body) and the route wiring. The thread, composer and bubbles stay in `features/chat/`.

## Consequences

- Built after spec 0011's thread slice and inbox slice (its tasks 1 to 3), because the role parameter and the inbox function are added there once for both roles. Until then the tab stays the Coming soon page.
- The five frames above exist, but the avatars in them are placeholder photos and the thread bubbles reuse the buyer's sample text.
- A customer who deletes their account removes their threads from the seller's inbox (spec 0011 AC-17), so a seller can see a thread vanish.
- The unread dot on the header chat icons makes the Home and Activity headers watch one more provider.
