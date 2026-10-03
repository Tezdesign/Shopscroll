# 0004. Adopt Clerk for real user authentication

**Date**: 2026-08-02
**Status**: In Progress

## Summary

The app currently has no real login: every install gets an anonymous Supabase identity so cart and
orders have an owner, but that identity is lost on uninstall and never follows a person across
devices. This decision adds Clerk (a dedicated login service) as the real sign in system, reachable
through Supabase's built in support for outside login providers ("Third Party Auth"), so the existing
Postgres database keeps its row level security approach, just checking a different kind of login token,
with one policy tightened so real people's contact details are never public. People can still browse
products and reels without signing in at all; a real account is offered once, the first time the app is
opened, and can be skipped.

Amended 2026-09-18: sign up is now a redesigned flow. A person enters a full name and username, then
either a phone number or an email address, then a one time code Clerk sends to it. There are no
passwords, no Google or Apple buttons, and Log in is still to be designed.

## Requirements

**User stories**:
- As an anonymous browser, I want to keep exploring products and reels without signing in, so I don't
  hit a login wall before I've decided to buy anything.
- As a first time visitor, I want to be offered the choice to sign up or just continue browsing, so I'm
  never forced into an account before I've explored.
- As a shopper, I want to create a real account with my phone number or my email address, confirmed by
  a one time code and with no password to remember, so my cart and orders are tied to me across devices
  and after a reinstall.
- As someone signing up, I want to switch between phone and email on the way, so I am never stuck if I
  would rather not give one of them.
- As a returning shopper, I want my anonymous cart to carry over automatically when I sign up, so I
  don't lose what I already added.
- As someone going through sign up, I want to see what went wrong when something is rejected (a taken
  username, a number Clerk refuses, a wrong code, and so on), so I'm not left guessing why nothing
  happened.
- As a signed in shopper, I want to sign out, and delete my account if I choose, so I control my own
  data.
- As the app, when Clerk reports an account was deleted, I want that person's data cleaned up
  automatically, so no orphaned rows are left behind.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1**: Catalog and reels browsing require no sign in, ever. The very first time the app is opened
  on a device, a welcome screen offers Sign up, Log in, or a Skip / continue browsing option; whichever
  is chosen, the welcome screen is remembered as seen and never appears again on that device. Someone
  who already has a real, signed in session skips the welcome screen automatically and goes straight to
  the home screen. The Profile tab in the bottom navigation is not part of this flow; it stays the same
  empty placeholder it was before this feature (a real Profile screen, and where sign in/out lives day
  to day, is a future decision, see Follow-up).
- **AC-2**: A person can sign up through the redesigned flow: full name and username, then either a
  phone number or an email address, then a one time code Clerk sends to it. Entering the right code
  creates the account and signs them in. There is no password step, and Google, Apple, and password
  sign in are not offered. Phone and email are equal choices, and each screen has a link to switch to
  the other. Signing back in to an existing account (Log in) is not part of this pass, see the note
  after the criteria.
- **AC-3**: On first successful real sign in, the prior anonymous session's cart items and orders are
  reassigned to the new real account; if the real account already has cart items, matching products'
  quantities are added together rather than overwritten, and non matching items are combined into one
  cart.
- **AC-4**: A `user_profiles` row (role `buyer`) is created for a real account on its first sign in if
  none exists yet, and its name/email stay in sync on every later sign in.
- **AC-5**: Every owned row (`cart_items`, `orders`, `reel_likes`, `reel_saves`) is only readable or
  writable by the session whose login token matches that row's owner, for both anonymous and real
  sessions alike.
- **AC-6**: Signing out returns the app to anonymous browsing (a fresh anonymous session), never a dead
  end screen. (The Account screen this happens on is currently not linked from anywhere in the
  navigation, since the Profile tab reverted to empty per AC-1; this criterion describes the behavior
  once that screen is reachable again.)
- **AC-7**: If a real session's login expires with nothing to silently refresh it, the app falls back to
  anonymous browsing with a brief message, rather than erroring or getting stuck.
- **AC-8**: Deleting an account (from the Account screen, or directly in Clerk) removes that person's
  cart, likes, saves, and profile, but keeps their order history. (Same note as AC-6: the Account screen
  is currently unreached from navigation.)
- **AC-9**: Leaving the sign up flow before the code is verified (the close button on the first screen,
  or the back arrow on later ones) goes back to the previous screen, creates no account, and shows no
  error.
- **AC-10**: If the anonymous-to-real merge (AC-3) fails partway (e.g. the network drops mid merge), sign
  in still succeeds, the merge is retried once automatically, and if it still fails the person keeps
  their new account without the unmigrated anonymous data — never a partial or duplicated row.
- **AC-11**: Sign in attempts are rate limited and lockable after repeated failures; this is Clerk's
  built in protection, not custom code in this app.
- **AC-12**: Any error Clerk reports while someone is signing up (a rejected username, a number or
  address Clerk refuses, a wrong or expired code, a server side rejection, and so on) is shown to them
  as a visible message; nothing fails silently or only shows up in developer logs. Mistakes the app can
  catch itself (a blank name, a username with spaces, a number or address that is not valid, a code
  that is not 6 digits) are shown by the field itself, in red under it.
- **AC-13**: After a code is sent, Resend code is unavailable for 30 seconds while a countdown shows the
  time left, then becomes a tappable link. Tapping it sends a new code and restarts the countdown. On
  the phone screen the number is locked once the code is sent; on the email screen, editing the
  address returns to the first step, since the old code would not match the new address.
- **AC-14**: The full name and username entered on the first screen are saved on the new account
  (Clerk's name and username, mirrored into `user_profiles` by AC-4's upsert), so the person never has
  to enter them a second time.

**Not in this pass**: Log in. The earlier Log in screen (Clerk's prebuilt card) was deleted. Until a new
one is designed, Welcome's Log in opens a coming soon placeholder, and a person who already has an
account has no way to sign back in. See Follow-up.

## Decision

**Chosen option**: Option 1: Clerk

Clerk becomes the real login system, connected to Supabase through native Third Party Auth, with the
existing Postgres schema updated so ownership columns hold Clerk's text style ids instead of Postgres
`uuid`s.

**Sign in methods (amended 2026-09-18)**: a one time code sent to a phone number, or to an email
address. No password, no Google, no Apple. Reasoning is in `rationale.md`.

**Implementation skills**: `supabase` (`supabase/agent-skills`, `.claude/skills/supabase/`) ·
`supabase-postgres-best-practices` (`supabase/agent-skills`,
`.claude/skills/supabase-postgres-best-practices/`)

## Feature design

**Data model sketch**:

Every id/ownership column that currently expects a Postgres `auth.users` `uuid` changes to `text`,
since Clerk's user ids (e.g. `user_2abc123`) are not UUIDs. The `auth.users` foreign key is dropped
from each (Clerk accounts have no row in `auth.users`); anonymous sessions still exist and still carry
a `sub` claim that fits the same `text` column.

| Table | Column | Before | After |
|---|---|---|---|
| `user_profiles` | `id` | `uuid default gen_random_uuid()` | `text` (Clerk id or anonymous `sub`) |
| `products` | `store_id` | `uuid references user_profiles(id)` | `text references user_profiles(id)` |
| `reels` | `store_id` | `uuid references user_profiles(id)` | `text references user_profiles(id)` |
| `reel_likes` | `user_id` | `uuid references auth.users(id)` | `text` (FK to `auth.users` dropped) |
| `reel_saves` | `user_id` | `uuid references auth.users(id)` | `text` (FK to `auth.users` dropped) |
| `cart_items` | `user_id` | `uuid references auth.users(id)` | `text` (FK to `auth.users` dropped) |
| `orders` | `user_id` | `uuid references auth.users(id)` | `text` (FK to `auth.users` dropped) |

No new tables. `user_profiles` gains no new columns; `name`/`email` already exist and are what gets
kept in sync from Clerk on each sign in (AC-4).

**Two Supabase clients, not one**: `supabase_flutter`'s `accessToken` callback (required to run Third
Party Auth against Clerk) and its own native `auth` namespace (`signInAnonymously`, session refresh)
are mutually exclusive on one client instance — configuring `accessToken` makes `supabase.auth` throw
outright. So the app runs two `SupabaseClient` instances side by side: the existing anonymous-capable
one (native auth, unchanged from spec 0003) and a second one constructed with an `accessToken` callback
that returns Clerk's current session token. Repository providers point at whichever client is active;
switching which one is active is the entire mechanism behind sign in, sign out, and session expiry
below — no single client ever holds both an anonymous and a Clerk session at once.

**State transitions**:

Session identity: `anonymous` (native client active) → sign up/sign in via Clerk succeeds → **while
still on the anonymous client**, call `merge_anonymous_identity` → switch the active client to the
Clerk-backed one → upsert `user_profiles` → `real, merged`. The merge call has to happen before the
switch: it relies on the *caller's own* current session being the anonymous one (Postgres reads that
straight from the request's JWT, so it can't be spoofed), which is only true while the anonymous client
is still active. Signing out, or a real session's login expiring with nothing to refresh it, reverses
the switch: the active client goes back to the anonymous one, minting a fresh anonymous session via
`signInAnonymously()` if none is persisted (AC-6, AC-7). None of this is persisted app state beyond
whichever client instance is currently wired to the repositories, so an app restart mid merge simply
resumes as a fully signed in real account with whatever had already migrated.

**First launch welcome screen** (Figma node 561:5267, "ShopScroll UI" file): a full screen with the
Shopscroll wordmark, a one line tagline, a Sign up button, a Log in button, and a Skip / continue
browsing link. Shown before the main app shell, but only when both are true: the device has never seen
it before, and there is no already signed in real session. A small locally stored flag (through
`shared_preferences`, a new dependency this adds) records "seen", set the moment any of Sign up, Log in,
or Skip is chosen; once set, the app goes straight to the home screen on every later launch, signed in
or not. Skip goes straight to the home screen. Sign up opens the redesigned flow below. Log in opens a
coming soon placeholder for now (see Follow-up). This screen does not gate cart, checkout, or anything
else.

**Redesigned sign up flow** (Figma "Sign in" section, nodes 5284:7789, 5284:9148, 5284:9424, 5284:9570,
5284:9654, 5298:7977, 5298:8283): three steps, the last two advancing in place on one screen.
1. **Get started**: full name and username. Continue checks both are filled and the username has no
   spaces.
2. **Phone number or Email address**: equal choices. "Use email instead" and "Use phone number
   instead" switch between them. Continue checks the value, Clerk sends a code, and the same screen
   moves to a verify step: a "Verification code" field with a 30 second resend countdown (AC-13). The
   phone number locks at that point; the email address stays editable, and editing it returns to the
   first step.
3. **Verify**: the right code creates the account and signs the person in. That session change is what
   triggers the merge and profile upsert (Build plan task 8), so the screens need no wiring for it.

Sign up calls Clerk's headless sign up (`attemptSignUp`) with the code strategy for the chosen channel
(`emailCode` or `phoneCode`): one call starts it and Clerk sends the code, a second call submits the
code. It carries the full name and username from step 1 (AC-14) and no password. The exact parameters
are to be confirmed against `clerk_flutter` when building. The phone screen sends the number in E.164,
with the country taken from its own picker, so Clerk must allow SMS to every country that picker
offers, or refuse the ones it does not with a visible error (AC-12).

State of the build: the screens (`GetStartedScreen`, `PhoneNumberScreen`, `EmailAddressScreen`, and the
shared `VerificationCodeSection`, in `lib/features/onboarding/`) exist and are reachable from Welcome's
Sign up, but their send and verify actions do nothing yet because the Clerk calls are not wired (Build
plan task 12). The earlier hand built email and password form and Clerk's prebuilt Log in card were
deleted. `VerifyEmailScreen` is left over from that form and unused.

**Error surfacing**: Clerk reports errors (validation failures, server side rejections) onto an error
stream on the `ClerkAuthState`. Nothing listened to it at first, so those errors only reached the
developer console and never the person filling in the form (AC-12). The fix is `clerk_flutter`'s own
`ClerkErrorListener` widget, placed inside the `MaterialApp`'s widget tree (so it can find a
`ScaffoldMessenger`) and wrapping whatever the router builds; it turns every error on that stream into
a plain snack bar showing Clerk's own message, with no bespoke error UI to design. The sign up screens
must make their Clerk calls in a way that lands failures on that same stream (Build plan task 12).
Mistakes the screens can catch before calling Clerk are shown by the field itself instead.

**API surface**:

| Endpoint | Method | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| Clerk sign up, start (`attemptSignUp`, `emailCode` or `phoneCode`) | client call | email address or phone number, username, first and last name | Clerk sends a code, sign up is pending | public | already in use, unsupported phone country, username rejected |
| Clerk sign up, verify (the same call, with the code) | client call | the 6 digit code | a Clerk session | public | wrong code, expired code |
| Clerk sign in (Log in) | not designed yet | not decided | not decided | public | not decided |
| `merge_anonymous_identity(target_user_id text)` | Postgres RPC, called on the **anonymous** client | `target_user_id`: the new real account's id | void | caller's JWT must carry Supabase's `is_anonymous` claim | no-op if caller is not anonymous |
| `/functions/v1/clerk-webhook` | POST | Clerk `user.deleted` webhook payload + Svix signature headers | 200 | Svix signature verification (service role inside) | 400 invalid signature |

**Key invariants**:
- Every row in an owned table has a `user_id`/`store_id` matching exactly one session identity (real or
  anonymous); no row is ever unowned.
- `merge_anonymous_identity` only ever adds to or reassigns the calling anonymous session's own rows; it
  never deletes or reduces anything already owned by `target_user_id`.
- A `user_profiles` row's `id` always equals the `sub` claim of the session that created it.
- A buyer's `user_profiles` row (email, phone, name) is never publicly readable; only seller rows are.

**Security model**:

Row Level Security stays enabled on every table; every owned-table policy moves from
`(select auth.uid()) = user_id` to `(select auth.jwt()->>'sub') = user_id`, since `auth.uid()` casts to
`uuid` and would reject Clerk's non-UUID ids, while `->>'sub'` reads as text and is correct for both an
anonymous session's own `sub` and a Clerk session's `sub`, uniformly. `order_items` has no `user_id` of
its own (spec 0003), so its indirect `exists (select 1 from orders o where o.id = order_id and
o.user_id = ...)` check moves the same way, from comparing to `auth.uid()` to comparing to
`(select auth.jwt()->>'sub')`; left as `auth.uid()` it would raise a Postgres cast error (`text = uuid`)
on every real-account query, a 500 rather than a clean deny.

`user_profiles`'s public `select using (true)` policy from spec 0003 was written when the table only
ever held seller/store rows, safe to expose to anyone. AC-4 now also writes real buyers' name, email,
and phone into this same table, so that policy must narrow to
`using (role = 'seller' or (select auth.jwt()->>'sub') = id)`: seller rows stay publicly readable
everywhere product/reel cards render store info, buyer rows become owner-only. This is a required
amendment to spec 0003's policy, not an unchanged carryover.

`user_profiles` also needs an insert and an update policy it never had before, both
`(select auth.jwt()->>'sub') = id`: AC-4 has the app itself upsert a buyer's row on first real sign in
and keep it in sync on every later one, and with only the select policy above, RLS denies that write by
default (`insert`/`update` are separate privileges from `select`; nothing until now had granted them to
`authenticated`). Seed seller rows were never affected, since those are written once through the SQL
editor's own elevated connection, not through the app's `authenticated` role.

`merge_anonymous_identity` is `security definer` (bypasses RLS deliberately) because reassigning a row's
`user_id` is otherwise impossible under RLS: a `with check` clause can only validate against the
*caller's own* current session, so a plain client side `UPDATE` can never move a row from the old
anonymous identity to the new real one — neither identity's policy would permit writing rows under the
other's id. The function only runs for a caller whose token carries Supabase's `is_anonymous` claim
(present on Supabase-issued anonymous sessions, absent on Clerk sessions, so this fails closed for real
accounts), and it can only add to or merge into `target_user_id`'s data, never remove anything the
target already owns. Following this project's existing `security definer` hardening precedent
(`supabase/schema.sql`), the function sets `search_path = ''` (so it can't be tricked by a search path
substitution attack) and revokes default `execute` from `public`, granting it only to `authenticated`.
The accepted residual risk — an anonymous session can donate its own (typically small) cart into an
arbitrary real account's cart, or write an extra row into that account's `orders` history with
attacker-chosen `shipping_address`/`total_amount` — is covered in Consequences; it cannot read or remove
anything the target already has, and there is no real payment processing yet for a fake order to do
financial harm through.

Account deletion cleanup (AC-8) runs inside the `clerk-webhook` Edge Function using the Supabase service
role key (never shipped to the client), verifying the Clerk webhook's Svix signature before doing
anything.

**Configuration required**:
- `CLERK_PUBLISHABLE_KEY`: Clerk's client side publishable key, passed via `--dart-define` the same way
  `SUPABASE_PUBLISHABLE_KEY` is today
- `CLERK_WEBHOOK_SIGNING_SECRET`: Clerk's webhook signing secret, set as a Supabase Edge Function
  secret (never sent to the client), used to verify the `user.deleted` webhook's Svix signature
- Supabase dashboard: Authentication > Sign In / Providers > Third Party Auth, add Clerk (needs Clerk's
  domain from the Clerk dashboard) — a one time manual project setting, same shape as the "Allow
  anonymous sign-ins" toggle in spec 0003
- Clerk dashboard: activate the native Supabase integration (Integrations > Supabase) — this is what
  makes Clerk add the `role: authenticated` claim its session tokens need for Supabase's `to
  authenticated` policies to apply; no custom JWT template needed
- Clerk dashboard: create the application, and add a webhook endpoint pointing at
  `/functions/v1/clerk-webhook` for the `user.deleted` event
- Clerk dashboard: under User and Authentication, turn Email address on with the verification code
  method, Phone number on with the verification code method, and Username on; turn Password off.
  Google and Apple stay off. The prebuilt card is gone, so the app itself offers only what the
  screens show, but Clerk still refuses a sign up whose method is not enabled here (AC-2)
- Clerk dashboard: allow SMS to the countries the phone screen supports. Its picker offers every ISO
  country, so this setting, not the app, is what decides which numbers actually work. An unsupported
  country is what made phone sign in get dropped the first time (see `rationale.md`)

**Critical test scenarios** (each maps to an acceptance criterion in ## Requirements):
- Happy path: browse anonymously, add to cart, sign up with an email code, cart carries over onto the
  new real account, verifies **AC-1**, **AC-2**, **AC-3**
- Failure case: network drops mid merge on first real sign in; sign in still succeeds, one retry is
  attempted, and the account is usable either way, verifies **AC-10**
- Auth/permission: one real account cannot read or write another real (or anonymous) account's cart or
  orders, verifies **AC-5**
- Failure case: a wrong or expired code shows a visible message, creates no account, and leaves the
  person on the verify step, where Resend code works after the countdown, verifies **AC-12**, **AC-13**

## Migration plan

**Strategy**: big bang for the schema, gradual per user for identities. `supabase/schema.sql` is a hand
run create script (spec 0003), and the project already has a live schema from it, so this migration is
a set of `ALTER TABLE`/`DROP POLICY`/`CREATE POLICY` statements run once against the live project (drop
the `auth.users` foreign keys and the `store_id`/`user_id`/`id` columns' old constraints, alter each
column's type to `text` via an explicit `::text` cast, drop `user_profiles.id`'s
`default gen_random_uuid()`, then replace every affected RLS policy), not a fresh rerun of the create
script. No real accounts exist yet (only anonymous test sessions, whose `sub` is already valid text), so
there is no data to backfill or transform beyond the column type itself. The actual anonymous-to-real
transition is inherently incremental after that: it happens one person at a time, at their own sign up
moment, via `merge_anonymous_identity`.

**Phases**:
1. Run the `ALTER`-based migration (column types, dropped FKs/defaults, rewritten RLS including
   `order_items`'s indirect check and `user_profiles`'s narrowed select policy) against the live
   Supabase project. Existing anonymous sessions keep working unchanged, since their `sub` is already
   valid text.
2. Ship the app build with Clerk wired in (dependency, sign in/sign up screens, Account screen, merge
   call on first real sign in).
3. Configure Clerk's webhook in the dashboard once the `clerk-webhook` Edge Function is deployed, so
   account deletion cleanup is live before any real account exists to delete.
4. From here, each person migrates individually and only when they choose to sign up; there is no bulk
   backfill step, since anonymous data has no real account to attach to until that moment.

**Rollback**: reverting the schema migration (back to `uuid`) is safe only *before* the first real
Clerk sign in; once even one real, non-UUID id (e.g. `user_2abc123`) has been written into a `text`
column, reverting the column type back to `uuid` fails outright with a cast error (a Clerk id cannot
cast to `uuid`), refusing to run rather than silently corrupting or orphaning anything. That is the
better failure mode, but it does mean rollback is only an option in that early window, not a safety net
available after Clerk has real users. Treat the rollback window as closed the moment Clerk goes live in
production, not just at first code deploy.

**Risks**:
- The rollback window above: coordinate the schema migration and the Clerk go live moment together,
  not as two independently timed deploys
- A misconfigured Supabase Third Party Auth setting (wrong Clerk issuer URL) would silently reject every
  real sign in's token while anonymous sessions kept working fine, since only real sessions exercise
  that path — verify a real sign in end to end before considering this shipped, not just that anonymous
  browsing still works
- The `merge_anonymous_identity` residual risk noted in Consequences (an anonymous session donating
  data into an arbitrary target account) is a property of the function itself, not of the rollout, so it
  does not change or worsen during migration

## Build plan

1. Write and run the `ALTER`-based schema migration: `user_profiles.id`, `products.store_id`,
   `reels.store_id`, and all owned-table `user_id` columns from `uuid` to `text`; drop the `auth.users`
   foreign keys and `user_profiles.id`'s `gen_random_uuid()` default; rewrite every owned-table RLS
   policy to `(select auth.jwt()->>'sub')`, including `order_items`'s indirect `exists (...)` check;
   narrow `user_profiles`'s public select policy to `role = 'seller' or (select auth.jwt()->>'sub') =
   id`; add its missing insert and update policies (`(select auth.jwt()->>'sub') = id`), without which
   the app's own upsert in task 8 is denied by RLS, satisfies **AC-4**, **AC-5**
2. Add the `merge_anonymous_identity(target_user_id text)` `security definer` Postgres function
   (anonymous-only via the `is_anonymous` claim, additive-only, `search_path = ''`, `execute` revoked
   from `public` and granted to `authenticated` only), satisfies **AC-3**, **AC-10**
3. Supabase dashboard: add Clerk as a Third Party Auth provider. Clerk dashboard: activate the native
   Supabase integration (adds the `role: authenticated` claim automatically), create the application,
   turn on email code, phone code, and username, turn password off, and allow SMS to the supported
   countries, satisfies **AC-2**, **AC-11**
4. Add the `clerk_flutter` dependency and `CLERK_PUBLISHABLE_KEY` `--dart-define` plumbing, satisfies
   **AC-2**
5. Stand up a second `SupabaseClient` instance configured with an `accessToken` callback that returns
   Clerk's current session token, alongside the existing anonymous-capable client from spec 0003; add
   the provider-level switch that points repositories at whichever client is currently active, satisfies
   **AC-1**, **AC-2**, **AC-6**, **AC-7**
6. Build the first launch welcome screen (Figma node 561:5267: Sign up, Log in, Skip / continue
   browsing) and the redesigned sign up screens behind Sign up (get started, phone number, email
   address, and the shared code entry); Log in opens a coming soon placeholder until it is designed.
   Add `shared_preferences` and a "seen" flag so the welcome screen only ever shows once per device,
   and is skipped outright for an already signed in returning user, satisfies **AC-1**, **AC-2**,
   **AC-9**, **AC-13**
7. Build the Account/Settings screen (sign out, delete account); not linked from navigation yet, see
   Follow-up, satisfies **AC-6**, **AC-8**
8. On successful Clerk sign in: while still on the anonymous client, call `merge_anonymous_identity`
   with the new Clerk id as `target_user_id`; then switch the active client to the Clerk-backed one and
   upsert the `user_profiles` row, satisfies **AC-3**, **AC-4**, **AC-10**
9. On sign out or an unrefreshable expired session, switch the active client back to the anonymous one
   (minting a fresh anonymous session if none is persisted) with a brief message on expiry, satisfies
   **AC-6**, **AC-7**
10. Build the `clerk-webhook` Supabase Edge Function (`user.deleted` handler, Svix signature
    verification, service role cleanup keeping order history) and register it in the Clerk dashboard,
    satisfies **AC-8**
11. Wrap the app in `clerk_flutter`'s `ClerkErrorListener` (inside `MaterialApp`'s `builder`, so it can
    reach a `ScaffoldMessenger`) so any sign in/up error shows as a visible message instead of failing
    silently, satisfies **AC-12**
12. Wire the sign up screens to Clerk: start sign up with the chosen channel's code strategy, carrying
    the name and username from the first screen; submit the code; send a new code on Resend and
    restart the countdown; make sure Clerk failures land on the error listener from task 11, satisfies
    **AC-2**, **AC-9**, **AC-12**, **AC-13**, **AC-14**

## Consequences

**Positive**:
- Cart and order history finally follow a real person across devices and reinstalls, closing the gap
  spec 0003 explicitly left open
- Sign in/sign up UI, session refresh, and rate limiting/lockout are Clerk's problem, not this app's
- RLS keeps working exactly as before, just checking a different token's `sub` claim; no application
  code needs to know whether a session is anonymous or real to read/write its own data correctly

**Negative / tradeoffs**:
- A second vendor (Clerk) now sits alongside Supabase, with its own uptime, pricing, and dashboard to
  manage
- The official `clerk_flutter` package is still beta (v0.0.18 at last check); its API may still change
- The app now runs two `SupabaseClient` instances instead of one (the existing anonymous-capable client,
  and a second one wired to Clerk's `accessToken`), because `supabase_flutter` does not allow one client
  to mix its own native auth with a third party `accessToken` callback. Repositories, and anything that
  reads the current session, must go through whichever client is currently active rather than a single
  fixed instance — a real increase in complexity over spec 0003's one-client design
- `merge_anonymous_identity` can, in principle, be called with an arbitrary `target_user_id` by anyone
  holding an anonymous session (see Security model for the exact scoping). Accepted given this app has
  no real payment processing yet for the residual risk to cause financial harm through
- Every owned-table id column silently loses the `uuid` type's format validation (Postgres no longer
  rejects a malformed id at the column level); Clerk's ids are trusted by construction (only ever
  written from a verified JWT `sub`), so this is a reasonable trade, not a new hole
- Once someone skips the first launch welcome screen, there is currently no other place in the app to
  sign in later: the Profile tab is an empty placeholder again, and cart/checkout don't exist yet. The
  only way back to Sign up/Log in right now is reinstalling, or clearing the app's local storage, which
  resets the "seen" flag
- Sign out and delete account are built and working (Account screen) but not reachable from anywhere in
  the navigation right now, for the same reason; a signed in person currently has no in app way to leave
  their account
- Until Log in is designed and built, a person who already has an account cannot sign back in. Sign up
  is effectively one way today
- Accounts have no password, so there is no fallback if someone loses the phone number or the email
  address. Recovery is not designed yet
- Phone codes cost money per SMS and are a known target for abuse (fake sign ups that trigger texts).
  Clerk's built in limits (AC-11) and the short list of supported countries keep that small, but it is
  a running cost the email only design did not have

**Neutral**:
- `user_profiles` rows for real accounts are now created lazily (on first real sign in) rather than
  never, but there is still no database trigger creating them: the app itself does the upsert, since
  Clerk accounts never appear in `auth.users` for a trigger to hook into
- Existing seed seller `user_profiles` rows (uuid-looking strings) keep working unchanged: they simply
  become `text` values that happen to look like UUIDs
- Which sign in methods are on (email code, phone code, and others) is a Clerk dashboard setting.
  Nothing about the schema, the merge function, or the webhook depends on it, so changing the set later
  is a dashboard change plus the matching screens, not a database change

## Follow-up

- [ ] Give the app a real, always available way to sign in, sign out, and delete an account once the
  Profile tab gets its own design and spec; right now that only happens once, on first launch, with no
  way back short of a reinstall (see Consequences)
- [ ] Multi factor authentication (Clerk supports it) is not in scope for this pass; revisit once real
  payment is added
- [ ] A seller sign in flow (this spec covers buyer/shopper accounts only, matching the app's buyer
  side only scope) is a future decision
- [ ] Design and build Log in. It probably reuses the same phone or email code step, but its screen and
  behaviour are the engineer's to design; until then Welcome's Log in is a coming soon placeholder and
  returning people cannot sign in (see Consequences)
- [ ] Delete `VerifyEmailScreen`, which nothing uses now that the email screen has its own verify step
- [x] Give the phone screen a real country picker (it was fixed to +1): `PhoneField`'s flag and prefix
  open a searchable sheet over `countryDialCodes`, and the screen sends the number in E.164. Which of
  those countries Clerk will actually text is still a dashboard setting, and a country it refuses
  surfaces as a Clerk error, not as a greyed out row
- [ ] Decide account recovery for code only accounts (what happens when the phone or email is lost)
- [ ] Confirm the exact `attemptSignUp` parameters for the phone and email code strategies, and that
  Clerk's username and name fields can be set in the same call, against `clerk_flutter` when building
  task 12

## Rationale

Reasoning and options considered: see [rationale.md](rationale.md).
