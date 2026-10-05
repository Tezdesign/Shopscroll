# supabase

The real backend (managed Postgres + Auth via Supabase), replacing the mock data layer for
`apps/buyer/lib/data/repositories/`'s Supabase-backed implementations.

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
  `0004_seller_role.sql` and `0005_lock_profile_columns.sql` (spec 0012, one backend for both apps):
  new profiles default to `role = 'buyer'`; `become_seller()` and `is_seller()`; sellers may insert,
  update and delete their own `products`, `reels` and `reel_products` (`store_id` = the caller's Clerk
  `sub`); `0005` stops clients writing `role`, `is_verified` and the counters on `user_profiles`. Apply
  `0005` only once no buyer build that sends `role` is in use, or those sign ins fail.
  `0006_seller_applications.sql` (spec 0013): `seller_applications`, `submit_`, `approve_` and
  `reject_seller_application`, and the `store-logos` and `application-documents` buckets.
  `0007_visitor_applications.sql` (spec 0014): a person with no account applies through their anonymous
  session (`submit_visitor_application`, private `visitor-documents` bucket, 12 file cap per session folder);
  `merge_anonymous_identity` now also attaches those rows to the account that signs in on the same phone
  (`bound_account_id`); after an admin approves, `claim_seller_application` (service role only) copies the
  store details onto the profile and sets `role = 'seller'`. It also replaces `submit_seller_application` and
  `approve_seller_application`. Unverified until applied and checked on a test database.
- `checks/` — SQL you run by hand on a test or branch database: `seller_access.sql`,
  `seller_applications.sql` and `visitor_applications.sql` (each rolls back, one NOTICE per check) and
  `audit_seller_rows.sql` (read only, run before `0004`).
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
    0.0.18-beta — see `apps/buyer/lib/features/profile/AGENTS.md`. It also removes the account's visitor
    applications and their `visitor-documents` files first, and stops there if that fails so a retry still has
    the file paths (`_shared/delete_user_files.ts`, spec 0014).
  - `_shared/clerk_caller.ts` — the one Clerk session token check (pinned `CLERK_ISSUER`), used by
    `delete-account` and `claim-seller-application`.
  - `claim-seller-application` — the signed in app calls it after sign in, on resume and when the Seller
    application screen opens. It copies an approved visitor application's logo from `visitor-documents` to
    `store-logos`, then runs `claim_seller_application`. Logic is in `_shared/claim_seller_application.ts`.
    Needs `CLERK_ISSUER`; deploy with `--no-verify-jwt`. The Storage copy between buckets is not yet confirmed
    against the real project.
  - Tests for the shared modules run with `deno test supabase/functions/_shared/`. They use only `Deno.test`
    and `node:assert`, so Node 22 can run them too (`--experimental-strip-types` with a `Deno.test` shim).
## Conventions

- Every owned-table RLS policy compares to `(select auth.jwt()->>'sub')`, not `auth.uid()` — `uuid`
  casts reject Clerk's non-UUID ids. Follow this for any new owned table.
- A `security definer` function here sets `search_path = ''` and revokes `execute` from `public`
  before granting it back to `authenticated` (or narrower) — see `merge_anonymous_identity` for the
  pattern. Follow it for any new one.
- Clients never write `role`: it changes only inside `become_seller()` or with the service role key.
  To make a table client writable by one role only, `revoke` the table level insert/update/delete from
  `anon` and `authenticated` first, then `grant` back column by column, because Supabase grants table
  level rights on new tables and a column grant alone would not narrow them.
- New schema changes ship as a new `migrations/000N_<name>.sql`, never by editing `schema.sql` or an
  already-applied migration in place.

Governing specs: `docs/specs/buyer/0003-supabase-backend/index.md`, `docs/specs/buyer/0004-clerk-authentication/index.md`, `docs/specs/_root/0012-one-backend-seller-role/index.md`, `docs/specs/_root/0013-seller-application-request/index.md`, `docs/specs/_root/0014-shared-login-seller-area/index.md`.

_Drafted by /sync from the introducing change, worth a quick human pass._
