# Verify: Clerk authentication · spec 0004 · updated 2026-09-18

_`/check verify` runs these against each acceptance criterion (AC-N) in `index.md`'s `## Requirements`;
`/test` locks the durable ones._

## Setup (one time, dashboards)

- [ ] Clerk dashboard: application created; Email address and Phone number on with the verification
  code method, Username on, Password off, Google and Apple off (User and Authentication) → matches
  "Configuration required"
- [ ] Clerk dashboard: SMS allowed to the countries sign ups are expected from; the phone screen's
  picker offers all of them, so anything not allowed here fails at send time → matches
  "Configuration required"
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
- [ ] From the welcome screen, tap Sign up → the Get started screen opens; tap the close (X) button →
  back on the welcome screen, and Skip for now still reaches browsing with no account → verifies
  **AC-1**, **AC-9**
- [ ] From the welcome screen, tap Log in → the real Log in screen opens (it replaced the coming soon
  placeholder on 2026-09-21); the steps for it are in `## Log in` below
- [ ] Sign up with an email address: Get started (name and username) → Email address → enter the code
  from the email → signed in → verifies **AC-2**
- [ ] Sign up with a phone number the same way → enter the code from the text → signed in → verifies
  **AC-2**
- [ ] On the phone screen tap "Use email instead", then "Use phone number instead" → each switches to
  the other → verifies **AC-2**
- [ ] Confirm there is no password field, and no Google or Apple button, anywhere in the flow → verifies
  **AC-2**
- [ ] After sending a code, Resend code shows a 30 second countdown, then becomes a link; tapping it
  sends a new code and restarts the countdown. On the phone screen the number is locked; on the email
  screen, editing the address returns to the first step → verifies **AC-13**
- [ ] After a successful sign up, check the new account in the Clerk dashboard and `user_profiles` → the
  full name and username from Get started are on both → verifies **AC-14**
- [ ] On the verify step, tap the back arrow → returns to the first step; on the first step, tap it →
  returns to the previous screen; no account exists in the Clerk dashboard → verifies **AC-9**
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
- [ ] Simulate a network drop during the merge step (e.g. disable network right after a fresh sign up
  completes) → sign in still succeeds; on reconnect/retry the merge completes, or the account is left
  usable without the old anonymous data if it still fails → verifies **AC-10**
- [ ] Attempt several rapid failed sign ins → Clerk's own lockout/rate limit kicks in (no custom code to
  test on this app's side) → verifies **AC-11**
- [ ] On Get started, leave a field blank or type a username with a space → the field shows a red
  message under it → verifies **AC-12**
- [ ] On the verify step, enter a wrong code, and an expired one → a visible message (a snack bar or
  the field message) names the problem; nothing fails silently or only shows in the developer console →
  verifies **AC-12**
- [ ] On the phone screen, tap the flag → a searchable country sheet opens; search by name or dial
  code, pick one → the prefix changes and the code is sent to that country's number → verifies **AC-2**
- [ ] Pick a country Clerk is not allowed to text, or a username Clerk rejects → a visible message
  appears → verifies **AC-12**

## Not yet coverable

- Log in's own acceptance criteria: the screen is now built (see `## Log in` below), but `index.md`
  still excludes Log in from its requirements ("Not in this pass"), so those steps hang off the
  criteria Log in touches rather than criteria of its own. Backfill real ones with
  `/architect log in`.
- The sign up screens' send and verify actions are not wired to Clerk yet (Build plan task 12), so
  every sign up check above needs that task first.
- Any check needing two distinct *real* Clerk accounts (not just anonymous vs real) needs two actual
  Clerk test users; do this manually with two test accounts once Clerk is live, or defer to a future
  integration test suite.
- The `merge_anonymous_identity` residual risk (arbitrary `target_user_id`) is a design tradeoff, not a
  bug to verify away; nothing to check here beyond confirming the function still rejects non-anonymous
  callers.

## Log in

_Added 2026-09-21 by `/develop log in`. The screen is `lib/features/onboarding/log_in_screen.dart`,
wired by `lib/features/onboarding/sign_in_verification.dart` at `/sign-in`. Figma frames 3001:11087,
5369:2154, 5368:7329, 5364:7369, 5369:2384, 5369:2267._

### UI / manual

- [ ] From Welcome, tap Log in → the real screen opens (not the coming soon placeholder), showing
  "Welcome back !", the Buyer / Store owner toggle with Buyer selected, one identifier field, and
  both footer lines → no AC yet, backfill with `/architect log in`
- [ ] Tap Store owner, then Buyer → the filled half moves between them and nothing else on the
  screen changes. The toggle is presentational: buyer and seller share one onboarding flow, and the
  seller only interfaces come later → no AC yet
- [ ] Type a malformed address (`nope`) and press Log in → a red message under the field, no code
  sent → verifies **AC-12** (mistakes the app catches itself)
- [ ] Type the address of an existing account and press Log in → the verification code field
  appears under it, with "Resend code in 0:30" counting down → verifies **AC-13**
- [ ] Wait for the countdown to reach zero → it becomes a tappable "Resend code"; tap it → a new
  code arrives and the countdown restarts at 0:30 → verifies **AC-13**
- [ ] With the code field showing, edit the address → the code field disappears and the screen
  returns to the first stage, since a code sent to the old address would not match the new one →
  no AC yet
- [ ] Confirm the first stage shows no "Use phone number instead" link; it appears only once the
  code field is showing → no AC yet
- [ ] On the verify stage, tap "Use phone number instead" → the screen returns to the first stage
  with a phone field and the country picker, the link will read "Use email instead" next time, and
  the pending code is dropped → no AC yet
- [ ] Enter a code that is not 6 digits and press Log in → a red message under the code field, no
  call made → verifies **AC-12**
- [ ] Enter a wrong or expired code → a visible snack bar message from `ClerkErrorListener`; nothing
  fails silently → verifies **AC-12**
- [ ] Enter an address or number with no Clerk account → a visible message, and the screen stays put
  (it does not route to sign up; that is an open decision) → verifies **AC-12**
- [ ] Enter the right code → the app goes straight to the home screen, not through the sign up tail
  of interests, notifications and setting up → no AC yet
- [ ] While the send or verify call is in flight → the Log in button renders inactive and a second
  press does nothing → no AC yet
- [ ] Add items to the cart while anonymous, then log in to an existing account → the anonymous cart
  items appear on that account, quantities added together for matching products → verifies **AC-3**
- [ ] Log in to an account, then query `user_profiles` → the row exists with role `buyer` and its
  name and email match Clerk → verifies **AC-4**
- [ ] Tap "Don't have an account ? Sign up" → `/sign-up` opens → no AC yet
- [ ] Tap the close cross from either stage → the screen closes and no account or session is
  created or changed → follows the spirit of **AC-9**

### Commands

- [ ] `flutter analyze` → no issues
- [ ] `flutter test` → all tests pass

### Acceptance-criteria coverage

- **AC-3** covered by the anonymous cart carry over step · **AC-4** by the `user_profiles` step ·
  **AC-12** by the malformed address, short code, wrong code and unknown account steps · **AC-13** by
  the countdown and resend steps.
- Log in has no acceptance criteria of its own: `index.md` excludes it. The steps marked "no AC yet"
  describe built behaviour with nothing to check it against until `/architect log in` writes the
  criteria.
