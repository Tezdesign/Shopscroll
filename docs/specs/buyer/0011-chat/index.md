# 0011. Chat between buyers and stores

**Date**: 2026-10-12
**Status**: In Progress

## Summary

Buyers and stores can write to each other in one thread per buyer and store pair. Messages are text, a photo, or a product card, and they arrive live on the other phone with a typing hint, a seen mark, and an unread count. Every write goes through a server function (never a direct table write), so the rules (who may start a chat, blocking, a 30 per minute limit, a 15 minute delete window) are enforced in one place. This spec builds the whole server side for both roles and the buyer screens. The seller screens are left to a follow up spec, because the Figma file has no seller chat frames yet.

Reasoning and options: see [rationale.md](rationale.md).

## Requirements

**User stories**:
- As a buyer, I want to message a store from a product or the store page, so that I can ask a question before I buy.
- As a buyer, I want to see my conversations and know which ones have a new message, so that I do not miss an answer.
- As a store, I want to answer a buyer and write to a buyer who ordered from me, so that I can handle delivery and problems in one place.
- As either person, I want to block the other side, so that I can stop unwanted messages.
- As either person, I want to delete a message I just sent by mistake, so that it does not stay in the thread.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1** (entry points): "Chat now" on product detail and "Message" on the Store Page open the thread screen for that store. A visitor who is not signed in with a real account sees a prompt with a Log in button instead, and returns to the same page after logging in. A person who opens their own store's chat sees "You can't message your own store". From "Chat now" the composer shows a removable "Asking about" product card for that product (AC-10).
- **AC-2** (inbox, buyer side): The Messages tab lists the threads where the person is the buyer, newest first, 20 at a time, loading the next 20 at the end of the list. A row shows the store avatar, store name, last message preview, time and an unread style, as the current row does (Figma `874:5784`). Tapping a row opens `/activity/chat/:id`. A new message or a read mark updates the row without a refresh. The existing search field still filters the loaded rows by store name or preview.
- **AC-3** (thread screen and empty state): The thread screen follows Figma `874:5806` and `874:5937`: a back arrow, the store avatar and name (tapping them opens the Store Page), the messages, and the composer. With no messages (including a chat not started yet) it shows the store avatar, name, the abbreviated follower count, and "Ask <name> about anything you want". It loads the 30 newest messages and 30 more each time the person scrolls to the top.
- **AC-4** (send text): The composer says "Type your message". The send button is on only when the trimmed text is not empty. Text is at most 2000 characters (the field stops at the limit). A tap on send adds a blue bubble on the right at once, shown as sending, and it settles when the server confirms. Received messages are grey bubbles on the left. Messages are ordered by `created_at`, then `id`.
- **AC-5** (thread creation): The first message sent creates the thread. Opening a chat and leaving without sending stores nothing. Two sends that race for the same buyer and store pair end with one thread. A retry of a send with the same message id returns the message already stored, before any other check, so a delivered message whose reply was lost never comes back as `blocked` or `rate_limited`. It never creates a second message and never moves the thread's preview or time again. The same id used for another thread or another sender gives `conflict`.
- **AC-6** (live): A message sent by the other side appears in an open thread within about 2 seconds, in order and never twice (messages merge by id). The inbox row and the unread count update the same way.
- **AC-7** (typing): While one person types, the other sees "Typing..." under the last message. It disappears 4 seconds after the last key press and as soon as a message arrives. Typing is never stored and only the other person in the thread receives it.
- **AC-8** (read, seen and unread): Opening a thread marks it read for the person. The last message a person sent shows "Seen" once the other side's read time is at or after that message's `created_at`. A thread is unread for a person when `last_sender_id` is the other side and `last_message_at` is later than the person's read time. Marking a thread read sets the read time to the thread's `last_message_at`, never to the clock, so a message that landed a moment earlier is never marked read unseen. The Messages tab shows the count of unread threads, and the Activity bottom tab shows a dot while any thread is unread.
- **AC-9** (photo): A photo button in the composer opens the picker (reusing `image_picker` and the photo helper from spec 0015). The photo becomes a JPEG under 1600 pixels and is refused if it is still over 5 MB. It uploads to the private `chat-images` bucket under the sender's own folder, then sends as a message (with optional text). The thread shows the photo through a link valid for one hour, and a tap opens it full size. One photo per message.
- **AC-10** (product card): A message can carry a product. The card shows the live photo, title and price, and a tap opens product detail. A removed product shows "Product unavailable". The "Asking about" card sits in the composer and goes out with the first message the person sends (text or photo). Leaving without sending drops it.
- **AC-11** (delete): Long pressing one's own message offers "Delete" for 15 minutes after it was sent. The server clears the text, the photo reference and the product, sets `deleted_at`, and returns the photo path it cleared, and the app then removes that file from the person's own folder (best effort). Both sides see "Message deleted" in place. After 15 minutes the option is not offered and the server refuses with `too_late`, which the screen treats as a normal answer because the phone clock may differ. The inbox preview becomes "Message deleted" when it was the last message. A delete never changes `last_message_at` or `last_sender_id`, so the thread does not jump to the top or turn unread.
- **AC-12** (block): The thread menu has Block and Unblock for either person. While a thread is blocked (by either person) nobody can send in it, old messages stay readable, the blocked person sees "You can't reply to this conversation", and the person who blocked sees "You blocked this person" with an Unblock button. Only the person who blocked can unblock.
- **AC-13** (limits): The server refuses text over 2000 characters (`too_long`), a message with no text, photo or product (`empty`), a photo path that is not exactly `<sender id>/<file>` (two parts, no `..`) for a file the sender uploaded (`bad_image`), more than 30 messages per minute from one sender across all threads, and more than 20 new threads per day from one sender (both `rate_limited`). The count is made under a lock per sender, so parallel sends cannot go over it. The screen says "Slow down" for a rate limit and keeps the text.
- **AC-14** (who may start, both roles): A buyer may start a thread with any person whose role is seller (otherwise `not_found`), never with themselves (`not_allowed`). A store starts a thread by naming an order (`p_order_id`): the order must have a line from that store (a `store_orders` row for the caller, any status), the buyer is taken from `orders.user_id` on the server, and the caller must still be a seller (`is_seller()`, otherwise `not_allowed`). A store never types or receives a buyer's account id. Replying in and reading an existing thread needs no order, and a person who stopped being a seller can still read and reply but cannot start new threads. Every store side call after the start uses the conversation id only. The sender states which role they act in (`buyer` or `store`), because one person can be both. The store role is checked by SQL checks, because its screens come later.
- **AC-15** (isolation and rights): A person reads only the conversations and messages where they are the buyer or the store. No client can insert, update or delete in `conversations` or `messages` directly. A caller with no session, or an anonymous session, gets `no_session` and nothing else, and a caller with no profile row gets `no_profile` (the same codes the existing functions use). A store sees a buyer's name and avatar only through the server functions, never the buyer's email, phone or account id. A store cannot look up the name or avatar of an arbitrary person: the functions answer only for a thread the caller is in, or for the order the caller names.
- **AC-16** (inbox function and unread): `chat_conversations_list` returns the caller's threads in one role with the other side's name, avatar, preview, time, unread flag and block flags, newest first, in pages by `last_message_at`. `chat_unread_count` returns the number of unread threads for a role.
- **AC-17** (account deletion): When a person deletes their account, their threads and messages are removed (the other side's inbox loses them) and their `chat-images` folder files are removed, by the same delete account path that removes their other data. A retry is safe.
- **AC-18** (reconnect and resume): When the live connection comes back, and when the app returns from the background, an open thread and the inbox load the newest messages again and merge them by id. If the new page shares no id with the messages already on screen (more than 30 were missed), the older local messages are dropped and the thread is paged again from the top, so there is never a gap in the middle. A thin "Reconnecting..." line shows only while the connection is down. Messages still waiting to be sent stay at the bottom in the order they were typed, not sorted by the phone's clock.
- **AC-19** (failed send): A message that cannot be sent keeps its bubble with "Not sent. Tap to retry". Tapping retries with the same message id. Long pressing the failed bubble offers Remove. The text and photo are never lost.
- **AC-20** (states): The inbox and the thread each show a loading indicator, a failure message with "Try again", and an empty state ("No messages yet" for the inbox, the AC-3 empty state for a thread).
- **AC-21** (mock backend): Without Supabase configuration the inbox and thread work in memory with the usual 300 ms delay. After the buyer's first message the mock store shows "Typing..." and answers once with a short canned text, so both bubble styles can be seen. Both backends behave the same to the screens.
- **AC-22** (accessibility): Bubbles are read as "You said <text>" or "<name> said <text>" with the time. Every control (send, photo, delete, block, retry, back) has a spoken label and a tap area of at least 44 by 44 logical pixels.
- **AC-23** (scope guard): This spec builds no seller chat screens (seller inbox, seller thread, "Message customer" on order detail, a badge on the store header chat icon). It adds no calls, voice notes, emoji picker, push notifications, emails, message editing, reporting a message, group chats, or search inside a thread. The frame's phone icon, mic and emoji icon are replaced as listed under Deviations.

## Decision

**Chosen option**: Option 1: two tables, writes only through server functions, live updates through Supabase Realtime

Add `conversations` and `messages`, close them to client writes, let every send, read mark, delete and block go through `security definer` functions that enforce the rules, and deliver new messages and typing over Supabase Realtime.

**Implementation skills**: `supabase` (`supabase/agent-skills`, `.agents/skills/supabase/`) · `supabase-postgres-best-practices` (`supabase/agent-skills`, `.agents/skills/supabase-postgres-best-practices/`)

## Rationale

Reasoning and options: see [rationale.md](rationale.md).

## Feature design

**Design source**: Figma file `toOakybJ0DaJmU7vcEC0AW`, page "The design - user", flow "Messages Flow" (flow header marked "Work in Progress", v0.0): `messages-inbox-default` (`826:4960`, row `874:5784`, already built in spec 0008), `messages-thread-empty` (`874:5806`), `messages-thread-typing` (`874:5937`). The page "The design - seller" has no chat frames.

**Deviations from the frames** (record each in the screen's doc comment):
- No phone icon in the thread header. There are no calls.
- The mic becomes a photo button. The emoji icon becomes the send button.
- The frames draw no photo bubble, product card, "Seen" mark, "Message deleted" bubble, blocked composer, "Asking about" chip or failed bubble. These reuse the bubble styles and the tokens, and are noted for a later Figma update.
- The empty state shows the follower count for a store. The frames show only the buyer side, so nothing is drawn for a store viewing a buyer.
- The seller inbox, seller thread and the "Message customer" button need new Figma frames before they are built (follow up spec).

**Data model sketch** (migrations `0018_chat.sql` to `0021_chat_delete_block.sql`, one per build slice, because an applied migration is never run again):

New table `conversations`, one row per buyer and store pair:

| Column | Type | Notes |
|---|---|---|
| `id` | uuid, primary key | default `gen_random_uuid()` |
| `buyer_id` | text, not null | foreign key to `user_profiles.id`, on delete cascade |
| `store_id` | text, not null | foreign key to `user_profiles.id`, on delete cascade |
| `created_at` | timestamptz, not null | default `now()` |
| `last_message_at` | timestamptz, not null | copied by `send_message` only, never moved by a delete |
| `last_sender_id` | text, not null | who sent the newest message, copied by `send_message`, so unread needs no query on `messages` |
| `last_message_preview` | text, not null | at most 120 characters, "Photo" or "Product" when there is no text, "Message deleted" when a delete hits the newest message |
| `buyer_read_at` | timestamptz, null | when the buyer last opened the thread |
| `store_read_at` | timestamptz, null | when the store last opened the thread |
| `buyer_blocked` | boolean, not null | default false. The buyer blocked the store. |
| `store_blocked` | boolean, not null | default false. The store blocked the buyer. |

- Unique `(buyer_id, store_id)`. Check `buyer_id <> store_id`.
- Indexes `(buyer_id, last_message_at desc, id desc)` and `(store_id, last_message_at desc, id desc)`.

New table `messages`:

| Column | Type | Notes |
|---|---|---|
| `id` | uuid, primary key | supplied by the client, so a retry is safe |
| `conversation_id` | uuid, not null | foreign key to `conversations.id`, on delete cascade |
| `sender_id` | text, not null | the thread's `buyer_id` or `store_id`, set by the function from the caller, never by the client |
| `body` | text, null | at most 2000 characters |
| `image_path` | text, null | path inside `chat-images`, always starts with the sender's own id |
| `product_id` | uuid, null | a plain reference with no foreign key, so a removed product reads "Product unavailable" |
| `created_at` | timestamptz, not null | set by `send_message` from `clock_timestamp()` while it holds the thread lock, so order follows commit order |
| `deleted_at` | timestamptz, null | set by `delete_message`, which also nulls `body`, `image_path` and `product_id` |

- Index `(conversation_id, created_at desc, id desc)` for the thread pages. Index `(sender_id, created_at desc)` for the rate limit. Index on `image_path` (where not null) for the storage read policy.
- Both tables are in the `supabase_realtime` publication. Row level security is on, with a select policy for the two people in the thread and no insert, update or delete policy for any client.

Relationships: `user_profiles` 1:N `conversations` (as buyer), `user_profiles` 1:N `conversations` (as store), `conversations` 1:N `messages`, `products` 0..1:N `messages` (soft reference only).

**State transitions**:
- Message: `sent` to `deleted` (one way, only by its sender within 15 minutes).
- Conversation: `open` (both flags false), `blocked by buyer`, `blocked by store`, `blocked by both`. Each flag is turned on and off only by its own person.

**API surface** (all functions are `security definer`, `set search_path = ''`, execute revoked from `public` and `anon`, and refuse a caller with no real account):

| Function or resource | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|
| `send_message` | `p_message_id` uuid (req), `p_as` text `buyer` or `store` (req), `p_conversation_id` uuid (an existing thread), `p_peer_id` text (buyer role, starting a thread, the store id), `p_order_id` uuid (store role, starting a thread), `p_body` text, `p_image_path` text, `p_product_id` uuid | the message row and the conversation id | signed in, not anonymous | `no_session`, `no_profile`, `not_found`, `not_allowed`, `blocked`, `too_long`, `empty`, `bad_image`, `rate_limited`, `conflict` |
| `mark_conversation_read` | `p_conversation_id` uuid (req) | none | a person in the thread | `not_found` |
| `delete_message` | `p_message_id` uuid (req) | the cleared photo path or null | the sender | `not_found`, `too_late` |
| `set_conversation_block` | `p_conversation_id` uuid (req), `p_blocked` boolean (req) | none | a person in the thread | `not_found` |
| `chat_conversations_list` | `p_as` text (req), `p_limit` int, `p_before_at` timestamptz, `p_before_id` uuid | threads with the other side's name, avatar, preview, time, unread flag, block flags (never the buyer's account id to a store) | signed in | `no_session`, `no_profile` |
| `chat_thread_info` | `p_as` text (req), and one of `p_conversation_id` uuid, `p_peer_id` text (buyer role only, must be a seller), or `p_order_id` uuid (store role only) | conversation id or null, the other side's name, avatar, follower count (a store's), read times, block flags | signed in | `no_session`, `no_profile`, `not_found` |
| `chat_unread_count` | `p_as` text (req) | integer | signed in | `no_session`, `no_profile` |
| `select` on `messages` (RLS) | `conversation_id`, keyset on `created_at`, `id` | the 30 newest, then older pages | a person in the thread | none |
| Realtime row changes on `messages` and `conversations` | the person's own threads | inserts and updates | RLS applies | none |
| Realtime private broadcast channel `chat:<conversation_id>` | `typing` event | nothing stored | a person in the thread, by a select and an insert policy on `realtime.messages` that compares the topic as text | none |
| Storage bucket `chat-images` (private, 5 MB, JPEG PNG WebP) | `<sender_id>/<uuid>.jpg` | signed link, 1 hour | write (no overwrite) and delete only in one's own folder and never for an anonymous session, read only for the two people in the message's thread | `bad_image` |

Notes on the functions:
- `send_message` order of work, all in one transaction: (1) read the caller from the token, refuse a missing or anonymous session (`no_session`) or a missing profile (`no_profile`); (2) look up `p_message_id` first, and when it exists for the same sender and thread return the stored row and stop (a repeat changes nothing), with another sender or thread raise `conflict` (the same pattern as `place_order` in `0014`); (3) take a transaction lock per sender (`pg_advisory_xact_lock` on a hash of the sender id) and enforce the 30 per minute and 20 new threads per day limits; (4) find the thread, or create it: as buyer, `p_peer_id` must be a seller and not the caller, as store the caller must be a seller and `p_order_id` must have a `store_orders` row for the caller, the buyer coming from `orders.user_id`; (5) `select ... for update` on the thread row, then reject when either block flag is true; (6) validate the body length, the photo path (exactly `<caller id>/<file>`, no `..`, and a `storage.objects` row for it owned by the caller) and that `p_product_id` is an existing product; (7) insert the message with `created_at = clock_timestamp()`, and set the thread's preview, `last_message_at` and `last_sender_id`.
- `mark_conversation_read` locks the thread row, then sets the caller's read time to the thread's `last_message_at`. `delete_message` locks the thread row, checks the 15 minutes against the server clock, clears the message, and changes the thread's preview only when that message is the newest, never `last_message_at` or `last_sender_id`.
- `chat_thread_info` and `chat_conversations_list` exist because `user_profiles` is readable only for sellers and one's own row, so a store cannot read a buyer's name or avatar by a normal select. They return only name, avatar and, for a store, the follower count, and only for a thread the caller is in or the order the caller names, so they cannot be used to look up a stranger.
- Opening the buyer's empty thread screen needs no thread. The typing channel can be joined only once a thread id exists, so a store that opens a first thread while the buyer sits on the empty screen reaches the buyer through the inbox row change, not the channel.

**Key invariants**:
- There is at most one thread per `(buyer_id, store_id)`, and `buyer_id <> store_id`.
- A message's `sender_id` is the thread's buyer or store, taken from the caller's token.
- A live message has text, a photo or a product. A deleted one has none of the three and has `deleted_at`.
- `last_message_at`, `last_sender_id` and `last_message_preview` always describe the newest message of the thread (kept by the functions in the same transaction, under a lock on the thread row, with times from `clock_timestamp()`).
- Nobody sends into a thread while `buyer_blocked` or `store_blocked` is true, and the block check runs under the same thread lock as the send.
- A store starts a thread only through an order of its own, and only while it is a seller. An existing thread has no such limit.
- A photo path is always exactly `<sender id>/<file>` and points to a file the sender uploaded.
- The sender limits (30 per minute, 20 new threads per day) are counted under one lock per sender, across all threads.

**Security model**:
- Reads: a person reads `conversations` and `messages` rows only where `buyer_id` or `store_id` equals their token `sub`. Realtime follows the same policy, so a person only receives their own threads. The typing channel is private and limited by a policy on `realtime.messages` to the two people in the thread.
- Writes: no client writes `conversations` or `messages`. Each write function takes the caller from `auth.jwt() ->> 'sub'`, refuses anonymous callers (the `is_anonymous` claim, as `0006` does), and never trusts a client supplied sender, role or time.
- Photos: the `chat-images` bucket is private. A person may upload (without overwriting) or delete only inside the folder named after their own id, and never as an anonymous session (otherwise the bucket would be free storage). A person reads a file only when a message in one of their threads points to it.
- Privacy: a store never receives a buyer's email or phone through chat. Messages are personal data. This feature adds no regulated data (no payment or health data), so no compliance scope applies.

**Configuration required**:
- No new environment variables or secrets.
- A project setting to check before the build: Realtime must be on for the project, and the Clerk token must be accepted by Realtime (see Build plan task 1, the spike).

**Client structure** (guide for `/develop`, matching the repository pattern in `apps/buyer/lib/data/repositories/AGENTS.md`):
- Shared model `ChatMessage` in `packages/shared/lib/models/` with `fromJson`, `toJson` and `copyWith`. `Conversation` keeps its buyer side fields and gains what the thread needs (the block flags and the other side's id).
- A new `ChatRepository` interface (send, page of messages, live stream, mark read, delete, block, typing) with a mock and a Supabase implementation, wired in `repository_providers.dart` and `main.dart`. `ConversationRepository` stays the inbox list and the Supabase one calls `chat_conversations_list`.
- A feature folder `apps/buyer/lib/features/chat/` with the thread screen, the composer, the bubbles and a plain `chat_logic.dart` for the testable rules. Sending is optimistic and follows the notifier rules in `apps/buyer/lib/features/cart/AGENTS.md`.
- Routes: the existing `/activity/chat/:id` becomes the thread screen, and a second route under `/activity/chat/` opens a chat with a store that has no thread yet.

**Critical test scenarios** (each maps to an acceptance criterion in ## Requirements):
- Happy path: a buyer taps Chat now, sees the empty state, sends text, a store replies from a second client, the buyer sees it live and "Seen" appears after the store opens it, verifies **AC-1**, **AC-3**, **AC-4**, **AC-6**, **AC-8**
- Happy path: send a photo and a product card, both show and open correctly, verifies **AC-9**, **AC-10**
- Retry: a send fails, the bubble shows "Not sent", a retry with the same id creates exactly one message, verifies **AC-5**, **AC-19**
- Race: two first sends for the same pair at once leave one thread, verifies **AC-5**
- Failure case: the 31st message in a minute is refused with `rate_limited`, the text stays in the field, verifies **AC-13**
- Failure case: a delete after 15 minutes is refused with `too_late`, verifies **AC-11**
- Block: while blocked, neither side can send and the composer text matches the person, verifies **AC-12**
- Auth and permission: a store tries to start a thread with a buyer who never ordered and gets `not_allowed`, a buyer reads another pair's thread and gets nothing, an anonymous caller gets `no_session`, a direct insert into `messages` is refused, verifies **AC-14**, **AC-15**
- Auth and permission: a photo path such as `user_abcd/x.jpg` sent by `user_abc`, or a path that points to someone else's file, gets `bad_image`, verifies **AC-13**
- Retry: a message that was stored but whose reply was lost is sent again after the sender was blocked, and returns the stored message, not `blocked`, verifies **AC-5**
- Store role: a store starts a thread with `p_order_id` of its own order, never sees the buyer's account id, a former seller cannot start but can reply, a store naming another store's order gets `not_allowed`, verifies **AC-14**, **AC-15**
- Concurrency: 40 parallel sends from one sender in one second leave at most 30 stored, two parallel sends in a thread keep the preview on the newest, verifies **AC-13**, **AC-5**
- Reconnect: drop the connection, send from the other side, restore it, the missed message appears once, and with more than 30 missed messages there is no gap, verifies **AC-18**
- Account deletion: deleting an account removes its threads and photos, verifies **AC-17**

## Build plan

Build approach: no approach is recorded for the project or this feature (the scope header says to run `/scope`). Assumption: Tracer Bullet, a thin working slice through every layer first (a text message sent from the buyer screen to a stored row and back live), then thicker slices.

1. Spike and first migration `0018_chat.sql`. Spike first: with a client holding a Clerk token, keep a row change subscription and a private broadcast channel open for more than 3 minutes, past at least two token refreshes (Clerk tokens last about a minute), and confirm both keep delivering. If row changes do not hold, the fallback is to drop the publication and let the three write functions push a small event with `realtime.send()` into private topics `chat:<id>` and `user:<sub>`, which also needs only one policy. Then create `conversations` and `messages`, the indexes, the select policies, the Realtime setup, `send_message` (text only, with every step listed under the function notes), `mark_conversation_read` and `chat_thread_info` (the thread screen needs it from the start). Add `supabase/checks/chat.sql` (one NOTICE per check, ends with rollback), satisfies **AC-5**, **AC-13**, **AC-14**, **AC-15**
2. Thread slice in the app: `ChatMessage` model, `ChatRepository` (mock and Supabase: send, page, live stream), providers, the thread screen with empty state, bubbles and text composer, optimistic send with the "Not sent" retry, the two routes, wire "Chat now" and "Message" and the visitor prompt, satisfies **AC-1**, **AC-3**, **AC-4**, **AC-6**, **AC-19**, **AC-20**, **AC-21**
3. Inbox slice, migration `0019_chat_inbox.sql`: `chat_conversations_list` and `chat_unread_count`. Replace `SupabaseConversationRepository`, make the Messages tab live and paged, add the unread count and the Activity dot, satisfies **AC-2**, **AC-8**, **AC-15**, **AC-16**
4. Live details: the "Seen" mark, typing over the private broadcast channel (with its `realtime.messages` policy, in a small migration if needed), and the reconnect and resume refetch, satisfies **AC-7**, **AC-8**, **AC-18**
5. Product card: the "Asking about" chip, the card in a bubble, `send_message` checks the product exists, satisfies **AC-10**
6. Photos, migration `0020_chat_images.sql`: the private `chat-images` bucket with its policies (own folder only, no overwrite, never anonymous, delete in own folder), the photo path check in `send_message`, the picker and compression, upload then send, signed links and the full size view, satisfies **AC-9**, **AC-13**
7. Delete and block, migration `0021_chat_delete_block.sql`: `delete_message`, `set_conversation_block`, the long press menu, the file removal after a delete, the thread menu and both composer states, satisfies **AC-11**, **AC-12**
8. Account deletion: extend `_shared/delete_user_data.ts` (and its Deno test) to remove the person's `chat-images` folder, confirm the foreign key cascade removes threads and messages, satisfies **AC-17**
9. Finish: loading, error and empty states everywhere, accessibility labels and tap areas, widget and logic tests, `apps/buyer/lib/features/chat/AGENTS.md`, the `supabase/AGENTS.md` lines, and the scope row update, satisfies **AC-20**, **AC-22**, **AC-23**

Migrations `0018` and `0019` change tables that nothing else reads, so they are safe to apply to the live project after the SQL checks pass on a test or branch project.

## Consequences

**Positive**:
- One set of rules, in the database, serves both roles, so the seller screens can be added later with no server change.
- Realtime comes with the Supabase client already in the app, so there is no new service, package or bill.
- Idempotent sends and reconnect refetch mean a flaky mobile connection does not lose or double messages.
- Private photos and function only profile reads keep a buyer's private details away from stores.

**Negative / tradeoffs**:
- The seller side has no screens until a follow up spec, so a store cannot answer from the app yet, and the server paths for the store role are tested only by SQL checks.
- Realtime with a Clerk token, and a private broadcast channel with a policy, are the least proven pieces. Task 1 is a spike for exactly this (long enough to cross token refreshes), with a named fallback that uses one mechanism (events sent from the write functions), and the last resort is refresh on open.
- Row changes under row level security cost work for every subscriber, and each send touches two tables. That is fine at the current size and is the first thing to revisit if chat grows.
- The typing hint, the seen mark and delete add realtime traffic, two more states per bubble and several error codes for modest value. The engineer chose them knowingly.
- `last_message_at` and the preview are copied data that the functions must keep in step. A write that skips the functions would break them, which is why the tables are closed to clients.
- A delete keeps a stub row (`deleted_at`), which is the one soft delete here. It is kept so both sides see "Message deleted" in place, and the content is gone.
- The thread screen reuses styles for states Figma does not draw, so it may need adjusting when Figma catches up.

**Neutral**:
- Four new migrations, run on a test or branch project first.
- Photos uploaded and never sent, a photo whose delete cleanup failed, and photos a surviving person sent to someone who later deleted their account, stay in the bucket until a cleanup exists (see Follow-up).
- Spec 0018 AC-17 said sellers cannot send a message to a buyer. That stays true for that spec's screens, and seller to buyer chat arrives only with the follow up spec below.

## Follow-up

- [ ] Design the seller side in Figma first (seller inbox, seller thread, a "Message customer" button on order detail, a badge on the store header chat icon), then write a follow up spec for those screens. The server already supports the store role.
- [ ] Add push notifications for new messages (needs device tokens and a sender function), a strong follow up once the screens exist.
- [ ] Add a cleanup for `chat-images` files that no message points to (uploads never sent, files of deleted messages, and photos left behind when the other person's account was deleted).
- [ ] Add "Report message" once an admin view exists.
- [ ] After the build, `/sync` should update `AGENTS.md` (the root feature list and the context files) and the buyer scope row 12, which still says "buyer to store chat" and should say both directions.
- [ ] Ask for the Figma frames of the new states (photo bubble, product card, seen, deleted, blocked, failed) so the screens match the design.
- [ ] The branch is 1 commit behind `origin/main`. Pull before building.
