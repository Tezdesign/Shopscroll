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
- `functions/<name>/index.ts` — Supabase Edge Functions (Deno). `clerk-webhook`: handles Clerk's
  `user.deleted` event (Svix signature verified before anything else), deletes that identity's cart/
  likes/saves/profile via the service role key (bypasses RLS by design — the one place allowed to),
  keeps order history. Deploy + `supabase secrets set CLERK_WEBHOOK_SIGNING_SECRET=...` are manual
  steps, not run by this repo's tooling.

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
