# supabase

The real backend (managed Postgres + Auth via Supabase), replacing the mock data layer for
`lib/data/repositories/`'s Supabase-backed implementations.

## Files

- `schema.sql` — the hand-run create script (spec 0003): `user_profiles`, `products`, `reels`,
  `reel_products`, `reel_likes`, `reel_saves`, `cart_items`, `orders`, `order_items`, plus RLS
  policies, seed data, and `security definer` functions (`sync_reel_like_count`,
  `merge_anonymous_identity`). Run once against a fresh Supabase project; not re-run after that (see
  Migration strategy below).
- `migrations/000N_<name>.sql` — incremental `ALTER`-based changes applied against the **live**
  project after the initial `schema.sql` run, never a rerun of the create script. `0001_clerk_auth.sql`
  (spec 0004): every ownership column `uuid`→`text` (Clerk's ids aren't UUIDs), drops the `auth.users`
  foreign keys, rewrites every RLS policy from `auth.uid()` to `(select auth.jwt()->>'sub')`, and
  redefines `merge_anonymous_identity` for the new text-based ids.
- `functions/<name>/index.ts` — Supabase Edge Functions (Deno). Deploys and `supabase secrets set`
  are manual steps, not run by this repo's tooling.
  - `_shared/delete_user_data.ts` — removes one identity's cart, likes, saves and profile with the
    service role key (bypasses RLS by design; this is the one place allowed to), keeping order
    history. Idempotent. Both deletion paths below share it so they cannot drift.
  - `clerk-webhook` — Clerk's `user.deleted` event, Svix signature verified before anything else.
    Covers deletions started outside the app (the Clerk dashboard, the Backend API).
    Needs `CLERK_WEBHOOK_SIGNING_SECRET`.
  - `delete-account` — the buyer deleting their own account from the Profile tab. Verifies the
    caller's Clerk session token against the instance's JWKS itself (pinned `CLERK_ISSUER`, never the
    token's own `iss`), deletes the Clerk user through the Backend API, then the rows. Needs
    `CLERK_SECRET_KEY` and `CLERK_ISSUER`. Deploy it with `--no-verify-jwt`: it does its own
    verification and fails closed, so it must not also depend on the platform gateway accepting a
    third-party token. This exists because `ClerkAuthState.deleteUser()` is broken in `clerk_auth`
    0.0.18-beta — see `lib/features/profile/AGENTS.md`.

## Conventions

- Every owned-table RLS policy compares to `(select auth.jwt()->>'sub')`, not `auth.uid()` — `uuid`
  casts reject Clerk's non-UUID ids. Follow this for any new owned table.
- A `security definer` function here sets `search_path = ''` and revokes `execute` from `public`
  before granting it back to `authenticated` (or narrower) — see `merge_anonymous_identity` for the
  pattern. Follow it for any new one.
- New schema changes ship as a new `migrations/000N_<name>.sql`, never by editing `schema.sql` or an
  already-applied migration in place.

Governing specs: `docs/specs/0003-supabase-backend/index.md`, `docs/specs/0004-clerk-authentication/index.md`.

_Drafted by /sync from the introducing change, worth a quick human pass._
