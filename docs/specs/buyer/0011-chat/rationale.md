# 0011. Chat between buyers and stores: rationale

Build spec: [index.md](index.md).

## Context

> ⚠️ Premise note: the request is a two way chat between buyers and sellers, but the Figma file only designs the buyer side (the inbox and the thread). Building both sets of screens now would mean inventing the seller layouts. This spec therefore builds the full server side for both roles and the buyer screens, and leaves the seller screens to a follow up spec after they are designed. The scope row (buyer scope, row 12) only says "buyer to store", so it needs widening once this ships.

The app is one Flutter app with a buyer area and a store area, on one Supabase project with Clerk sign in. A person can be a buyer and also own a store, so a thread is always between one buyer role and one store role. Today only stubs exist: a `Conversation` model, an inbox that shows mock rows, a Supabase repository that returns an empty list, and "Chat now" and "Message" buttons that do nothing. There is no table.

The forces that shape the design:
- Chat must feel live, because a back and forth conversation that needs a manual refresh feels broken.
- Either side may start a thread, which makes spam and abuse a real risk, so the server must decide who may start one, and a person must be able to block.
- Stores cannot read a buyer's profile (the profile table is readable only for sellers and one's own row), so names and avatars must be handed out through controlled functions.
- The identity is a Clerk token, not Supabase auth, so every rule must read the caller from the token, and anonymous sessions must be refused.
- Sellers already read their data only through server functions (spec 0018), so the pattern is known to the team.
- The team is small. A new vendor or a second backend is a real running cost.

Without a decision, the "Chat now" buttons stay dead and the Messages tab stays empty on the real backend.

## Options considered

### Option 1: Two tables, writes only through server functions, Supabase Realtime for live updates

`conversations` and `messages` tables closed to client writes. Functions do every send, read mark, delete and block, and enforce the rules. Realtime row changes deliver messages, and a private broadcast channel carries typing.

**Pros**:
- All rules live in one place and cannot be skipped by a client.
- No new vendor, package or bill. It uses the Supabase client and project the app already has.
- The same functions serve the buyer now and the seller screens later.
- Messages stay in the app's own database, next to orders, which the "who may start a chat" rule needs.

**Cons**:
- More SQL to write and check than plain inserts.
- Realtime with a Clerk token and a private channel policy is the least proven part and needs a spike.
- Copied inbox fields (`last_message_at`, preview) must be kept in step by the functions.

### Option 2: Direct inserts guarded by row level security, Realtime for live updates

The same two tables, but clients insert messages directly, with policies deciding who may.

**Pros**:
- Fewer functions, and the client code is a plain insert.
- Realtime works the same.

**Cons**:
- The 30 per minute limit, thread creation on first send, the order rule for stores and the inbox preview update are hard to do safely inside policies and triggers.
- Idempotent retries and error codes the screens can act on are harder to give.
- A policy mistake exposes data directly, with no function in between.

### Option 3: A third party chat service

Use a hosted chat product for threads, delivery, typing and read state.

**Pros**:
- Fastest way to a polished chat, with typing and read state built in.

**Cons**:
- A second user list and a second set of rules (block, who may start a chat from order history) that must be kept in step with Clerk and Supabase.
- Messages live outside the app's database, so the order rule and account deletion need extra integration.
- A monthly cost and a new vendor to operate for a small team.

### Option 5: Events sent from the write functions instead of row changes

The same tables and functions, but no Realtime publication. The write functions send a small event with `realtime.send()` into private topics (`chat:<id>` for a thread, `user:<sub>` for the inbox and unread count).

**Pros**:
- One mechanism and one authorization policy for messages and typing, so the spike has one thing to prove.
- No per subscriber row level security work on every insert.

**Cons**:
- The client treats an event as a hint and must still read the row, so there are two steps per message.
- A write that skips the functions would send no event (the tables are closed, so this cannot happen by accident).
- The engineer chose row changes for messages, so this stays the named fallback in the spike (build task 1), not the first pick.

### Option 4: Polling

The same server functions, but the app asks for new messages every few seconds.

**Pros**:
- No Realtime setup.

**Cons**:
- Slow and wasteful, and a typing hint is not practical.
- Does not meet the "live" requirement the engineer chose.

## Rationale

Option 1 fits the forces. The rules that matter most here (who may start a thread, blocking, the rate limit, the delete window, the thread creation race) are all things a function can check in one transaction and a policy cannot do cleanly. The app already uses this exact pattern for sellers (spec 0018), the Clerk token is already read in every function, and the profile table already forces profile reads through functions. Realtime keeps the stack at one backend, and the order rule only works because messages sit next to `store_orders` in the same database. A hosted chat service would trade that away for speed the team does not need, and polling would not meet the "live" answer.

Three choices go against the usual advice, each by the engineer's decision or for a stated reason:
- The inbox preview and time are copied onto the conversation. The usual advice is to compute derived values at read time. Here the inbox is the most opened screen and sorts by the last message, and a latest per thread query slows as threads grow. The functions keep the copy correct in the same transaction.
- A deleted message keeps a stub row with `deleted_at`. Soft deletes are usually wrong, but both people must see "Message deleted" in the same place, so the row stays while its content is cleared.
- The typing hint, the seen mark and a 15 minute delete are more than a first version needs. The engineer chose them, and they are cheap once the live channel and the read times exist.

The seller screens are left out on purpose: they have no design, and a layout invented here would be rebuilt when Figma arrives. Nothing in the server design waits on them.

## Notes from the design conversation

- Who starts: either side. A store may start only with a buyer who has an order with a line from that store (any status). A buyer may start with any seller.
- Thread shape: one per buyer and store pair, with the product attached to a message.
- Content: text, product card and a photo (one per message, 5 MB). Voice notes were not chosen.
- Live updates: yes. Notifications: unread count and dot in the app only. Seen, delete and typing are in.
- Limits: 2000 characters, 30 messages per minute, delete within 15 minutes.
- Blocking: flags on the conversation. A blocked person is told they can't reply.
- Account deletion removes the whole thread.
- A visitor is asked to sign in. Each area shows its own role's threads.
- Failed sends keep the bubble with "Not sent. Tap to retry". Mock mode gets one canned reply. Reconnect and resume refetch the newest messages.
- Design source: Figma, the "Messages Flow" frames on "The design - user". References: none.
