# lib/core/auth

Drives the anonymous-to-real identity switch spec 0004 introduced (see that spec's "Two Supabase
clients, not one" and "State transitions" sections for the full reasoning).

## Files

- `active_supabase_client.dart` — `activeSupabaseClientProvider`, a `StateProvider<SupabaseClient>`
  every repository provider (`lib/data/repositories/`) reads through. Two real client instances
  exist because `supabase_flutter`'s `accessToken` callback (needed for Clerk) and its own native
  `auth` namespace (`signInAnonymously`, session refresh) are mutually exclusive on one instance.
  `buildClerkBackedClient` constructs the Clerk-backed one; `main.dart` builds the anonymous one and
  overrides the provider with it at startup.
- `auth_session_controller.dart` — `AuthSessionController` listens to `ClerkAuthState` for sign
  in/out transitions. On sign in: runs `merge_anonymous_identity` (Postgres RPC) on the **anonymous**
  client first (its anonymous-only check reads the caller's own session, so it only succeeds before
  the switch), then flips `activeSupabaseClientProvider` to the Clerk-backed client, then upserts the
  buyer's `user_profiles` row. On sign out (or an expired session Clerk can't refresh): flips back to
  the anonymous client, minting a fresh anonymous session if none is persisted. This listens to
  `ClerkAuthState` generically — any screen that changes sign-in state (Clerk's prebuilt card, or a
  hand-built flow) triggers it the same way, no per-screen wiring needed.

## Diagnosing Clerk calls

`clerk_auth` logs failed HTTP calls through `package:logging` and then swallows them: `Api._delete`
catches a non-200 or a thrown error, logs it, returns false, and every caller ignores that result.
Nothing reaches `errorStream`, so a failed sign out or account deletion is indistinguishable from a
successful one in the UI. `_printClerkLogs` in `main.dart` attaches a listener in debug builds so
those records reach the console; release builds stay quiet. When a Clerk action appears to do
nothing, run the app in debug and read the `[clerk]` lines.

## Configuration

`lib/core/config/clerk_config.dart` and `supabase_config.dart` read connection values via
`String.fromEnvironment` (`--dart-define`, never committed — see `.env.example`). Both expose an
`isConfigured` getter the app checks before wiring the real backend/auth in at all (falls back to
mock data / placeholder screens otherwise, see root `AGENTS.md`).

Governing spec: `docs/specs/0004-clerk-authentication/index.md`.

_Drafted by /sync from the introducing change, worth a quick human pass._
