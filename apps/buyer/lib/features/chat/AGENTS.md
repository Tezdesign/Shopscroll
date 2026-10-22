# lib/features/chat

The buyer's chat with a store (spec 0011): one thread per buyer and store pair, opened from the Messages tab, "Chat now"
on product detail, and "Message" on the Store Page. Text only so far; the spec's later slices (live inbox, seen and
typing, photos and product cards, delete and block) are tracked in `docs/scope/buyer/scope.md`, feature 12.

## Files

- `chat_thread_screen.dart` — `ChatThreadScreen`, opened by `conversationId` (from the Messages tab) or by `storeId`
  (from "Chat now" and "Message", where no thread may exist yet). Exactly one is set (an assert enforces it). Nothing is
  stored until the first message is sent. Routes are in `lib/core/router/app_router.dart`: `chat/:id` under Activity
  and `/chat/store/:storeId` outside the tabs.
- `chat_composer.dart` — the message field and send button (Figma 874:5806 and 874:5937).
- `chat_bubble.dart` — the blue (own) and grey (store) bubbles and the sending and failed states.
- `chat_logic.dart` — plain Dart rules with no Flutter code (`canSendChat`, `mergeChatMessages`, `chatFailureText`,
  `maxChatBody`, `chatPageSize`), so they are easy to test.
- State and data live elsewhere: `lib/data/providers/chat_providers.dart` (`chatThreadProvider` keyed by `ChatTarget`,
  `chatVisitorProvider`), `lib/data/repositories/chat_repository.dart` plus its `mock/` and `supabase/` versions, the
  models `packages/shared/lib/models/chat_message.dart` and `chat_thread_info.dart`, and the server side in
  `supabase/migrations/0018_chat.sql` (checked by `supabase/checks/chat.sql`). Tests: `apps/buyer/test/features/chat/`.

## Conventions

- Every write goes through a server function (`send_message` and the others), never a direct table write. The client
  makes the message id (a uuid), so sending the same id again returns the stored message instead of a second one.
- Sending is optimistic: the bubble appears at once as sending and settles when the server confirms. Pending and failed
  messages stay at the bottom in typed order, whatever the phone clock says.
- Messages merge by id and sort by `createdAt`, then `id` (`mergeChatMessages`), so a live message never shows twice.
- Failures arrive as a `ChatException` with a `ChatFailure`. Add the wording in `chatFailureText`, not in the screen.
- A visitor with no real account sees a Log in prompt, and Log in returns to the same page through
  `loginReturnPathProvider` (see `lib/core/area/AGENTS.md`). `chatVisitorProvider` is false when Clerk is not
  configured, because the in memory mock has no accounts.
- Limits: 2000 characters per message, 30 messages per page.

Governing spec: `docs/specs/buyer/0011-chat/index.md`.

_Drafted by /sync from the introducing change, worth a quick human pass._
