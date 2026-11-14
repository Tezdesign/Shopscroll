# 0020 verify: seller chat

Run `flutter analyze` at the root and `flutter test` in `apps/buyer`. Server checks reuse `supabase/checks/chat.sql` (store role, spec 0011 AC-14, AC-15).

| AC | Check | Where |
|---|---|---|
| AC-1 | The inbox lists mock threads newest first, shows the unread style, filters by name and preview | `apps/buyer/test/features/seller_chat/seller_inbox_screen_test.dart` |
| AC-2 | The dot shows on the tab and on both header chat icons while a thread is unread, and clears after opening it | `apps/buyer/test/features/seller_chat/` |
| AC-3 | A row opens `/store/messages/:id`, the header shows the customer's name with no link | `apps/buyer/test/features/seller_chat/` |
| AC-4 | A sent message shows as sending, then settles, and "Seen" appears after the customer reads | `apps/buyer/test/features/chat/chat_thread_screen_test.dart` (store role case) |
| AC-5 | "Message customer" opens the order's thread, or the "Say hello" empty state, and the first message creates it | `apps/buyer/test/features/seller_activity/` |
| AC-6 | A former seller cannot start a thread, an order of another store gives not found | `supabase/checks/chat.sql` and a widget test |
| AC-7 | Block and Unblock change the composer as 0011 AC-12 says | `apps/buyer/test/features/chat/` |
| AC-8 | No screen text or route contains a customer email, phone or id | review and a widget test |
| AC-9 | Loading, failure with Try again, and the empty state | `apps/buyer/test/features/seller_chat/` |
| AC-10 | Everything works with no Supabase configuration | the same tests, on mocks |
| AC-11 | Rows, the button and the composer say their name and are 44 by 44 or more | widget tests |
| AC-12 | `git diff` shows no change under `supabase/migrations/` and none to the buyer chat screens beyond the role parameter | review |
