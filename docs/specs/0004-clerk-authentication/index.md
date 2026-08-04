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
products and reels without signing in; a real account is only asked for at cart, checkout, or profile.

## Requirements

**User stories**:
- As an anonymous browser, I want to keep exploring products and reels without signing in, so I don't
  hit a login wall before I've decided to buy anything.
- As a shopper, I want to create a real account (email, Google, Apple, or phone) so my cart and orders
  are tied to me across devices and after a reinstall.
- As a returning shopper, I want my anonymous cart to carry over automatically when I sign up, so I
  don't lose what I already added.
- As a signed in shopper, I want to sign out, and delete my account if I choose, so I control my own
  data.
- As the app, when Clerk reports an account was deleted, I want that person's data cleaned up
  automatically, so no orphaned rows are left behind.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1**: Catalog and reels browsing require no sign in; a sign in prompt only appears when opening
  cart, checkout, or the account/profile screen.
- **AC-2**: A person can sign up or sign in via Clerk using email + password (with email verification),
  Google, Apple, or phone number with SMS one time code.
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
  end screen.
- **AC-7**: If a real session's login expires with nothing to silently refresh it, the app falls back to
  anonymous browsing with a brief message, rather than erroring or getting stuck.
- **AC-8**: Deleting an account (from the Account screen, or directly in Clerk) removes that person's
  cart, likes, saves, and profile, but keeps their order history.
- **AC-9**: Cancelling an OAuth (Google/Apple) sign in returns silently to the sign in screen; no error
  is shown.
- **AC-10**: If the anonymous-to-real merge (AC-3) fails partway (e.g. the network drops mid merge), sign
  in still succeeds, the merge is retried once automatically, and if it still fails the person keeps
  their new account without the unmigrated anonymous data — never a partial or duplicated row.
- **AC-11**: Sign in attempts are rate limited and lockable after repeated failures; this is Clerk's
  built in protection, not custom code in this app.

## Decision

**Chosen option**: Option 1: Clerk

Clerk becomes the real login system, connected to Supabase through native Third Party Auth, with the
existing Postgres schema updated so ownership columns hold Clerk's text style ids instead of Postgres
`uuid`s.

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

**API surface**:

| Endpoint | Method | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| Clerk Sign In component | (Clerk prebuilt UI) | email/password, Google, Apple, or phone+OTP | a Clerk session | public | invalid credentials, OTP mismatch |
| Clerk Sign Up component | (Clerk prebuilt UI) | email/password, Google, Apple, or phone+OTP | a Clerk session, verification prompt | public | email/phone already in use |
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
- Clerk dashboard: create the application, enable email/password + Google + Apple + phone/SMS sign in
  methods, and add a webhook endpoint pointing at `/functions/v1/clerk-webhook` for the `user.deleted`
  event

**Critical test scenarios** (each maps to an acceptance criterion in ## Requirements):
- Happy path: browse anonymously, add to cart, sign up with email, cart carries over onto the new real
  account, verifies **AC-1**, **AC-2**, **AC-3**
- Failure case: network drops mid merge on first real sign in; sign in still succeeds, one retry is
  attempted, and the account is usable either way, verifies **AC-10**
- Auth/permission: one real account cannot read or write another real (or anonymous) account's cart or
  orders, verifies **AC-5**

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
   id`, satisfies **AC-5**
2. Add the `merge_anonymous_identity(target_user_id text)` `security definer` Postgres function
   (anonymous-only via the `is_anonymous` claim, additive-only, `search_path = ''`, `execute` revoked
   from `public` and granted to `authenticated` only), satisfies **AC-3**, **AC-10**
3. Supabase dashboard: add Clerk as a Third Party Auth provider. Clerk dashboard: activate the native
   Supabase integration (adds the `role: authenticated` claim automatically), create the application,
   enable email/password + Google + Apple + phone/SMS sign in methods, satisfies **AC-2**, **AC-11**
4. Add the `clerk_flutter` dependency and `CLERK_PUBLISHABLE_KEY` `--dart-define` plumbing, satisfies
   **AC-2**
5. Stand up a second `SupabaseClient` instance configured with an `accessToken` callback that returns
   Clerk's current session token, alongside the existing anonymous-capable client from spec 0003; add
   the provider-level switch that points repositories at whichever client is currently active, satisfies
   **AC-1**, **AC-2**, **AC-6**, **AC-7**
6. Wire Clerk's prebuilt Sign In / Sign Up screens into `app_router.dart`, gated only at cart,
   checkout, and account entry points, satisfies **AC-1**, **AC-2**, **AC-9**
7. Build the Account/Settings screen (sign out, delete account), satisfies **AC-6**, **AC-8**
8. On successful Clerk sign in: while still on the anonymous client, call `merge_anonymous_identity`
   with the new Clerk id as `target_user_id`; then switch the active client to the Clerk-backed one and
   upsert the `user_profiles` row, satisfies **AC-3**, **AC-4**, **AC-10**
9. On sign out or an unrefreshable expired session, switch the active client back to the anonymous one
   (minting a fresh anonymous session if none is persisted) with a brief message on expiry, satisfies
   **AC-6**, **AC-7**
10. Build the `clerk-webhook` Supabase Edge Function (`user.deleted` handler, Svix signature
    verification, service role cleanup keeping order history) and register it in the Clerk dashboard,
    satisfies **AC-8**

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

**Neutral**:
- `user_profiles` rows for real accounts are now created lazily (on first real sign in) rather than
  never, but there is still no database trigger creating them: the app itself does the upsert, since
  Clerk accounts never appear in `auth.users` for a trigger to hook into
- Existing seed seller `user_profiles` rows (uuid-looking strings) keep working unchanged: they simply
  become `text` values that happen to look like UUIDs

## Follow-up

- [ ] No `docs/scope/` feature row currently links this decision; enroll one (e.g. via `/scope`) once
  this spec is confirmed, so `/develop` has a tracked build plan to check off
- [ ] Multi factor authentication (Clerk supports it) is not in scope for this pass; revisit once real
  payment is added
- [ ] A seller sign in flow (this spec covers buyer/shopper accounts only, matching the app's buyer
  side only scope) is a future decision

## Rationale

Reasoning and options considered: see [rationale.md](rationale.md).
