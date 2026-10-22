# Verify: chat · spec 0011 · updated 2026-10-12
_Steps derived from spec 0011 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones. Covers build tasks 1 and 2 only (server text slice and the thread screen)._

## UI / manual (mock backend, `flutter run` without `--dart-define`)
- [ ] Open a product, tap Chat now → the thread screen opens with the store avatar, name, follower count and "Ask <name> about anything you want"   → AC-1, AC-3
- [ ] Open a Store Page, tap Message → the same screen for that store   → AC-1
- [ ] Type text, tap send → a blue bubble appears on the right at once; send is off while the field is empty or only spaces   → AC-4
- [ ] After the first send, wait about 2 seconds → a grey bubble with a canned answer appears on the left, once   → AC-6, AC-21
- [ ] Leave a new chat without sending, open it again → still the empty state   → AC-5
- [ ] Open a Messages tab row → the thread shows the stored message and the back arrow returns to the tab   → AC-3
- [ ] Tap the store avatar or name in the header → the Store Page opens   → AC-3
- [ ] Type 2000 characters → the field stops at the limit   → AC-4

## UI / manual (real backend, after migration 0018 is applied, with `--dart-define-from-file=env.json`)
- [ ] Signed out, tap Chat now → "Log in to message this store" with a Log in button; log in → you come back to the same chat page   → AC-1
- [ ] Open the chat of your own store → "You can't message your own store"   → AC-1
- [ ] Send a message, then read `messages` and `conversations` in the dashboard → one thread, one message, preview and sender copied   → AC-5
- [ ] Insert a message for the other side from the SQL editor or a second client → it appears in the open thread within about 2 seconds, once   → AC-6
- [ ] Turn off the network, send → the bubble shows "Not sent. Tap to retry"; turn it on, tap the bubble → one message is stored   → AC-5, AC-19
- [ ] Realtime spike: keep a thread open for more than 3 minutes, past two token refreshes, then send from the other side → it still arrives   → build plan task 1

## Commands
- [ ] Run `supabase/checks/chat.sql` on a test or branch database after migrations 0014 and 0018 → every check prints `ok`, none prints FAIL, ends with rollback   → AC-5, AC-13, AC-14, AC-15
- [ ] `cd apps/buyer && flutter test test/features/chat` → all pass   → AC-1, AC-3, AC-4, AC-6, AC-13, AC-19
- [ ] `flutter analyze` (repo root) → no issues   → all

## Acceptance-criteria coverage
- AC-1 … visitor prompt, own store, entry buttons · AC-3 … empty state, thread, header · AC-4 … send, limit · AC-5 … thread creation, retry, conflict · AC-6 … live message · AC-13 … limits, Slow down · AC-14 … who may start (SQL checks) · AC-15 … isolation (SQL checks) · AC-19 … failed send
- Not covered yet (later tasks): AC-2, AC-7 to AC-12, AC-16 to AC-18, AC-20 (inbox paging and empty inbox), AC-22, AC-23. AC-21 is covered for the thread, not the inbox.
