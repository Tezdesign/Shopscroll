# Verify: Clerk authentication · spec 0004 · updated 2026-08-04

_`/check verify` runs these against each acceptance criterion (AC-N) in `index.md`'s `## Requirements`;
`/test` locks the durable ones._

## Setup (one time, dashboards)

- [ ] Clerk dashboard: application created, email/password + Google + Apple sign in methods enabled,
  Phone number turned off (User & Authentication > Email, Phone, Username) → matches "Configuration
  required"
- [ ] Clerk dashboard: native Supabase integration activated (Integrations > Supabase) → matches
  "Configuration required"
- [ ] Supabase dashboard: Authentication > Sign In / Providers > Third Party Auth, Clerk added with its
  domain → matches "Configuration required"
- [ ] Clerk dashboard: webhook endpoint registered for `user.deleted`, pointing at the deployed
  `/functions/v1/clerk-webhook` URL, signing secret copied into `CLERK_WEBHOOK_SIGNING_SECRET` →
  matches "Configuration required"
- [ ] Decode a real (post sign in) session token in the Clerk dashboard's JWT inspector → carries
  `role: authenticated` → matches "Configuration required"

## Schema migration

- [ ] Run the `ALTER`-based migration against the project (not a fresh `schema.sql` create run) →
  `user_profiles.id`, `products.store_id`, `reels.store_id`, and every owned-table `user_id` are `text`,
  no `auth.users` foreign key remains on any of them, `user_profiles.id` has no `gen_random_uuid()`
  default → matches "Data model sketch"
- [ ] Every owned-table RLS policy reads `(select auth.jwt()->>'sub')`, not `auth.uid()`, including
  `order_items`'s indirect `exists (...)` check → matches "Security model"
- [ ] `user_profiles`'s select policy reads `role = 'seller' or (select auth.jwt()->>'sub') = id`, not
  bare `using (true)` → matches "Security model"
- [ ] `user_profiles` has an insert policy and an update policy, both `(select auth.jwt()->>'sub') =
  id`, `to authenticated` → matches "Security model"; without these a real sign in's own profile upsert
  fails with a row level security error (`42501`) → verifies **AC-4**
- [ ] As the anonymous/`anon` role, query another buyer's `user_profiles` row (a `role = 'buyer'` row,
  not a seed seller row) directly → rejected/empty, no email or phone visible → matches "Security model"
- [ ] `merge_anonymous_identity`'s definer: confirm `search_path = ''` is set and `execute` is revoked
  from `public`, granted only to `authenticated` → matches "Security model"

## Commands

- [ ] `flutter pub get` → resolves `clerk_flutter` cleanly
- [ ] `flutter analyze` → no issues
- [ ] `flutter test` → existing tests still pass unchanged

## UI / manual

- [ ] Open the app fresh (no prior session) → catalog and reels browse with no sign in prompt →
  verifies **AC-1**
- [ ] Open the app for the very first time on a fresh device/simulator (no prior install data) → the
  welcome screen appears (Shopscroll, Sign up, Log in, Skip for now) before the home screen → verifies
  **AC-1**
- [ ] On the welcome screen, tap Skip for now → lands on the home screen, browsing works with no
  account → verifies **AC-1**
- [ ] Force quit and reopen the app after skipping (or after signing in) once → the welcome screen does
  not appear again → verifies **AC-1**
- [ ] With a real signed in session already on the device, force quit and relaunch the app → goes
  straight to the home screen, the welcome screen never appears → verifies **AC-1**
- [ ] From the welcome screen, tap Sign up or Log in → Clerk's sign in/sign up card opens; tap the close
  (X) button before finishing → returns to browsing on the home screen, no account required → verifies
  **AC-1**
- [ ] Sign up with email + password → verification required before continuing; sign up with Google;
  sign up with Apple → verifies **AC-2**
- [ ] On the sign up screen, confirm there is no phone number field or phone sign in option anywhere →
  verifies **AC-2**
- [ ] While anonymous, add 2+ items to cart, then sign up with a new email → the same items appear in
  cart under the new real account → verifies **AC-3**
- [ ] Sign in on a second device/simulator with an anonymous cart containing a product already in the
  real account's cart elsewhere → quantities combine, no duplicate row → verifies **AC-3**
- [ ] After first real sign in, check `user_profiles` in the dashboard → a row exists with the Clerk
  id, correct name/email, `role = buyer` → verifies **AC-4**
- [ ] With two different signed in sessions (real or anonymous), confirm neither can read or write the
  other's `cart_items`/`orders`/`reel_likes`/`reel_saves` rows directly in the dashboard's SQL editor
  impersonation, or via a second app session → verifies **AC-5**
- [ ] Sign out from the Account screen → app returns to a working anonymous browsing session, not a
  blank/dead screen → verifies **AC-6**
- [ ] Force an expired/invalid session (e.g. revoke it in the Clerk dashboard) and reopen the app →
  falls back to anonymous browsing with a brief message, no crash → verifies **AC-7**
- [ ] Delete the account from the Account screen (or from the Clerk dashboard directly) → the webhook
  fires, and afterward `cart_items`/`reel_likes`/`reel_saves`/`user_profiles` for that id are gone but
  `orders` rows for that id remain → verifies **AC-8**
- [ ] Start a Google or Apple sign in and cancel partway → returns to the sign in screen with no error
  shown → verifies **AC-9**
- [ ] Simulate a network drop during the merge step (e.g. disable network right after a fresh sign up
  completes) → sign in still succeeds; on reconnect/retry the merge completes, or the account is left
  usable without the old anonymous data if it still fails → verifies **AC-10**
- [ ] Attempt several rapid failed sign ins → Clerk's own lockout/rate limit kicks in (no custom code to
  test on this app's side) → verifies **AC-11**
- [ ] On the sign up screen, submit a common/breached password (e.g. `password123`), or a username under
  4 characters → a visible message (a snack bar) appears naming the problem; nothing fails silently or
  only shows in the developer console → verifies **AC-12**

## Not yet coverable

- Any check needing two distinct *real* Clerk accounts (not just anonymous vs real) needs two actual
  Clerk test users; do this manually with two test accounts once Clerk is live, or defer to a future
  integration test suite.
- The `merge_anonymous_identity` residual risk (arbitrary `target_user_id`) is a design tradeoff, not a
  bug to verify away; nothing to check here beyond confirming the function still rejects non-anonymous
  callers.
