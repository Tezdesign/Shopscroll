# 0012. Use one Supabase project and one Clerk instance for both apps, with sellers as a role

**Date**: 2026-10-03
**Status**: In Progress

## Summary

The buyer app and the seller app will share one Supabase project (the database and server side functions) and one Clerk instance (sign in). A person has one account. They become a seller when a server side step sets `role = 'seller'` on their existing profile, and row level rules (database rules that decide who can read or write each row) then let sellers manage their own products and reels. This replaces the two backend, two Clerk and Edge Function sync decisions in spec 0011, so the sync work (scope feature 17) is no longer needed. The folder layout from spec 0011 stays as built.

## Requirements

**User stories**:
- As a person, I want one account for buying and selling so that I do not need two emails or two sign ins.
- As a buyer, I want to become a seller from my account so that my store shows up in the buyer app.
- As a seller, I want to add and edit my own products and reels so that buyers see them without any copy step.
- As the developer, I want one backend so that I own one schema, one set of rules and one migration history.

**Acceptance criteria** (the contract, each one independently checkable):
- **AC-1**: One `supabase/` folder at the repository root holds the schema, migrations and Edge Functions. Both apps read the same Supabase URL, key and Clerk publishable key. `apps/buyer/supabase` no longer exists.
- **AC-2**: A signed in client cannot write `role`, `is_verified`, `follower_count`, `following_count` or `product_count` on any profile row, by insert or by update. The write is refused. New profiles get `role = 'buyer'`.
- **AC-3**: The buyer app's sign in profile step never sends `role`, and never overwrites `name`, `username`, `email` or `phone` on a profile that already exists (it only creates the row when it is missing). A seller who signs in to the buyer app keeps `role = 'seller'` and their edited store details.
- **AC-4**: `become_seller()` sets `role = 'seller'` on the caller's own profile only, and clears the `email` and `phone` copied from the sign in account so they do not become public. It is safe to call twice. It refuses an anonymous session and refuses a caller with no profile row.
- **AC-5**: A user with `role = 'seller'` can insert, update and delete only their own `products`, `reels` and `reel_products` rows (`store_id` equals their Clerk `sub`). A user with `role = 'buyer'` cannot write those tables. One seller cannot change another seller's rows. A seller cannot write the cached or earned columns `rating`, `review_count`, `like_count` and `comment_count`. A seller can tag only their own products on their own reels.
- **AC-6**: Buyer behavior does not change. Catalog and seller profiles stay publicly readable, and the cart, order, like and save rules are untouched. All existing buyer tests and the shared tests still pass.
- **AC-7**: The seller app requires sign in. It never creates an anonymous Supabase session. Its bundle id and Android id are registered on the same Clerk instance. On first sign in it creates the profile row (without `role`) and then calls `become_seller()`.
- **AC-8**: No row that is already `role = 'seller'` in the live project gains write power unless it was checked first. Rows that became sellers only because clients could set `role` themselves are reviewed and fixed before the seller write rules are applied.

## Decision

**Chosen option**: Option 1: One Supabase project and one Clerk instance, sellers as a role

Both apps use the existing Supabase project and Clerk instance. A server side function `become_seller()` is the only way to set `role = 'seller'`, and row level rules let sellers write their own catalog rows.

## Feature design

**Data model changes** (two migrations, see the Migration plan):
- `0004_seller_role.sql` (safe to apply at any time): `user_profiles.role` default changes from `'seller'` to `'buyer'` (existing rows are left alone). New function `public.become_seller()`. New seller write policies and the column grants on the catalog tables below.
- `0005_lock_profile_columns.sql` (applied only after the buyer app without `role` has shipped): `revoke insert, update on public.user_profiles from anon, authenticated`, then grant insert and update back only on `id`, `name`, `username`, `avatar_url`, `bio`, `website_url`, `location`, `phone`, `email`. `role`, `is_verified`, `follower_count`, `following_count` and `product_count` stay unwritable by clients. The revoke comes first on purpose: Supabase gives `anon` and `authenticated` table level rights on new tables, and a column grant alone would not narrow them. `id` needs update rights too, because the buyer's upsert (insert with merge on conflict) sets every column in its payload. The existing row level policies stay.
- Seller write policies on `products`, `reels` and `reel_products` for insert, update and delete, `to authenticated`. For `products` and `reels`: `store_id` equals `(select auth.jwt() ->> 'sub')` and the caller is a seller (checked once per statement, through a stable `security definer` helper `public.is_seller()` or `(select exists(...))`). For `reel_products`: the parent reel's `store_id` equals the caller and the tagged product's `store_id` equals the caller.
- Same revoke then column grant pattern on `products` and `reels`: clients may write the descriptive columns only, never `rating`, `review_count`, `like_count` or `comment_count` (the existing `sync_reel_like_count` function keeps writing `like_count` as its owner).

**Key invariants**:
- `role` changes only inside `become_seller()` or with the service role key. Clients never write it.
- A seller owns a catalog row only when `store_id` equals their Clerk `sub`.
- The buyer app never sends `role` in a profile write.

**Security model**:
- `become_seller()` follows the existing pattern in this repo: `security definer`, `search_path = ''`, `execute` revoked from `public` then granted to `authenticated`. It reads the caller from `auth.jwt() ->> 'sub'`, rejects `is_anonymous = true` (the same check `merge_anonymous_identity` uses), and updates exactly that one row.
- Seller write rules use `(select auth.jwt() ->> 'sub')`, the convention in `supabase/AGENTS.md`, never `auth.uid()`.
- Seller profiles stay publicly readable, as today, and the public select shows every column of a seller row. So the private `email` and `phone` copied from a buyer's sign in account must not survive the switch: `become_seller()` clears them, and the sign in step no longer rewrites them (AC-3). A seller adds public store contact details later on purpose, through the profile edit screen.

**Configuration required**:
- Same `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and `CLERK_PUBLISHABLE_KEY` in each app's own `env.json`. No new variables.
- Clerk dashboard: add the seller app's iOS bundle id, Android application id and redirect URLs to the existing instance (and Google or Apple sign in if used).
- Supabase CLI: one `supabase link` at the repo root, replacing the buyer folder's link.

**Critical test scenarios**:
- Happy path: a buyer calls `become_seller()`, then inserts a product with their own `store_id` and reads it back, verifies **AC-4**, **AC-5**.
- Failure case: a client update that includes `role = 'seller'` or `is_verified = true` is refused, verifies **AC-2**.
- Failure case: an anonymous session calls `become_seller()` and is refused, verifies **AC-4**.
- Auth/permission: a buyer and a different seller each try to write someone else's product and are refused, verifies **AC-5**.
- Regression: a seller signs in to the buyer app and the profile upsert leaves `role` as `seller`, verifies **AC-3**.
- Regression: the full buyer and shared test suites pass, verifies **AC-6**.

## Build plan

1. Audit the live project: list `user_profiles` rows with `role = 'seller'` that are not the seeded demo sellers (`id not like '11111111-%'`), and fix or approve each one, satisfies **AC-8**
2. Move `apps/buyer/supabase` to `supabase/` at the repo root with `git mv`, fix the path comments inside it, relink the CLI once, satisfies **AC-1**
3. Buyer app: change `_upsertBuyerProfile` in `apps/buyer/lib/core/auth/auth_session_controller.dart` so it never sends `role` and only creates the row when it is missing (insert, ignore duplicates). Update its test, satisfies **AC-3**
4. Write and apply `supabase/migrations/0004_seller_role.sql` (default `'buyer'`, `become_seller()`, `is_seller()`, seller write policies, catalog column grants). Confirm in the database that the function, policies and grants exist, satisfies **AC-4**, **AC-5**
5. Seller app: sign in required, no anonymous client. On first sign in it creates the profile row and calls `become_seller()`. Add the seller bundle ids to the Clerk instance. This wires sign in only, not seller screens, satisfies **AC-7**
6. After the buyer build from task 3 is the only build in use, write and apply `supabase/migrations/0005_lock_profile_columns.sql`. Test the buyer's real sign in upsert against it on a branch or test database first, satisfies **AC-2**
7. Add SQL level checks for the test scenarios above (a script on a test or branch database, or a walkthrough in `verify.md`), satisfies **AC-2**, **AC-4**, **AC-5**
8. Run `flutter analyze` and all three test suites, satisfies **AC-6**

## Migration plan

**Strategy**: staged, two migrations, no data copy. The existing project and its rows stay in place.
**Phases**:
1. Apply `0004` (default `'buyer'`, `become_seller()`, seller write rules). It is safe with old and new buyer builds, because it locks nothing the old build writes. It also fixes the old default that made new rows sellers.
2. Ship the buyer build from task 3 (no `role` in the upsert).
3. When no older buyer build is in use (immediately if the app is not released yet, otherwise after adoption or a forced update), apply `0005` to lock the profile columns. Applying it earlier would make old builds fail on sign in with an uncaught permission error, and those users would never get a profile row.
**Rollback**: for `0005`, re-grant table level insert and update on `user_profiles` to `authenticated` (and `anon` if it had them). For `0004`, drop the new policies and functions and restore the old default. Rows created in the meantime stay, so review them by hand.
**Risks**: a client write that still sends a locked column fails with a permission error, so search the buyer app for every write to `user_profiles` before `0005` (today only the sign in upsert and the profile edit, which sends `name`, `username` and `bio`). PostgREST upserts set every payload column on conflict, so test the real upsert, not just a plain insert.

## Consequences

**Positive**:
- No sync layer to build, monitor or debug, so scope feature 17 is dropped.
- One account can buy and sell. A seller's store row is the exact row buyers already read.
- Closes an existing gap: clients can no longer verify themselves or edit counters.

**Negative / tradeoffs**:
- One backend means one blast radius. A wrong rule or a bad migration can break both apps, so both suites and the SQL checks must run before a change ships.
- Both apps depend on one Clerk configuration and one set of beta package versions.
- The buyer app's profile code must ship before the column lock (`0005`), so the rollout takes two steps.
- The buyer sign in step stops refreshing `name`, `username`, `email` and `phone` from Clerk on later sign ins. Spec 0004 AC-4 asked for that sync, so this partly changes it. Profile edits inside the app are the way to change them.

**Neutral**:
- Spec 0011 stays `Accepted` for the folder layout. Its two backend, two Clerk and Edge Function sync decisions are replaced by this spec, and it gets a one line pointer here.
- Each app still keeps its own `env.json` and `.env.example`, with the same values.
- Repositories and row mappers for tables both apps use stay in each app for now. Move one into `packages/shared` when the seller app first needs it, not before.

## Follow-up

- [ ] Add a one line note to spec 0011 that its backend, Clerk and sync rows are partly superseded by 0012.
- [ ] Spec 0004 AC-4 (keep the profile in sync on every sign in) is narrowed by AC-3 here. Add a note there.
- [ ] Update the scope: mark feature 17 `dropped` and enroll a feature for this spec ("Seller access rules").
- [ ] `order_items` has no `store_id`, only a nullable `product_id`. Seller order visibility and delivery tracking need a `store_id` snapshot on order items and their own rules. Design that in the seller orders spec.
- [ ] `products.store_name` and `store_avatar_url` are copied from the profile by the client. Once sellers write products, fill them from the profile with a trigger so a seller cannot show another store's name.
- [ ] Deleting a seller account cascades to their products and reels. Decide what should happen to a seller with live orders before the seller app ships account deletion.
- [ ] `/sync` should update `supabase/AGENTS.md` and the root `AGENTS.md` paths after the folder move.
- [ ] Seller features (delivery tracking, messages, posts) still need their own scope rows and specs. The buyer to store chat decision can now use one `conversations` table for both sides.

Decision history (context, options, rationale): [rationale.md](./rationale.md)
