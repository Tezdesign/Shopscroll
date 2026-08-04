# 0003. Adopt Supabase as the backend

**Date**: 2026-07-31
**Status**: Accepted

## Summary

The app currently has no real backend; every screen reads mock data from `lib/data/mock/*`. This
decision introduces Supabase (a managed Postgres database with built in auth) as the real backend
for all five existing data models: products, reels, seller/user profiles, cart items, and orders.
Since the app has no login screen yet, people get access through Supabase's anonymous sign in
(a stable per install identity with no login form), so cart and order rows can already be owned by
someone. Real login is left for a later decision. This spec is the decision record; the SQL file
and the Flutter connection code are built next, by `/develop`.

## Decision

**Chosen option**: Option 1: Supabase (managed Postgres + Auth)

Supabase becomes the real backend, reachable from the Flutter app through the official
`supabase_flutter` SDK, with all five models re-modeled as relational Postgres tables and Row Level
Security (RLS) enforcing who can read or write each one.

**Implementation skills**: `supabase` (`supabase/agent-skills`, `.agents/skills/supabase/`) ·
`supabase-postgres-best-practices` (`supabase/agent-skills`,
`.agents/skills/supabase-postgres-best-practices/`)

## Proposed stack

| Layer | Choice | Reason |
|---|---|---|
| Backend platform | Supabase (managed Postgres + Auth) | A relational database fits this app's data (orders reference products reference stores, reels tag many products); Supabase's anonymous auth exactly covers "no login screen yet, but cart/order still need an owner" |
| Primary DB | Postgres, via Supabase | ACID, real foreign keys, mature tooling, the standard default for this data shape |
| Auth | Supabase Auth, anonymous sign in only for this pass | Gives every install a stable `auth.uid()` with zero login UI; upgrades to real auth later (`linkIdentity`) without a data migration |
| Flutter client | `supabase_flutter` (official SDK) | Handles session persistence, realtime, storage, and deep link auth callbacks; the lower level `supabase` package would mean rebuilding all of that by hand |
| File storage | None (URL columns only) | No upload flow exists yet; a Storage bucket would sit unused until a seller feature needs it |
| Config / secrets | `--dart-define` with a checked-in `.env.example` | No secret committed to the repo; works the same on every platform, including web |
| Data access layer | Repository interfaces behind the existing Riverpod providers | Keeps the mock implementations swappable back in for tests or offline use; matches the models' existing `fromJson`/`toJson`, already written "ready for a real API" |

## Data model

Entities, in the shape they will exist in Postgres (all primary keys are `uuid default gen_random_uuid()`
unless noted). This was assembled from the existing Dart models (`lib/data/models/*`) and confirmed
with the engineer.

| Table | Key fields | Notes |
|---|---|---|
| `user_profiles` | `id`, `name`, `username` (unique), `avatar_url`, `bio`, `role` (`buyer`\|`seller`), `follower_count`, `following_count`, `product_count`, `is_verified`, `website_url`, `location`, `phone`, `email` | Maps `UserProfile` one to one |
| `products` | `id`, `title`, `description`, `price`, `original_price`, `category`, `store_id` → `user_profiles.id`, `store_name`, `store_avatar_url`, `image_url`, `image_urls` (text array), `color_options` (int array), `sizes` (text array), `is_deal`, `in_stock`, `rating`, `review_count`, `created_at` | `store_name`/`store_avatar_url` are an intentional denormalization of `user_profiles` so a product list read needs no join; accepted as a tradeoff, see Consequences |
| `reels` | `id`, `video_url`, `thumbnail_url`, `store_id` → `user_profiles.id`, `store_name`, `store_avatar_url`, `caption`, `like_count` (cached counter), `comment_count` (static display, no comments feature exists), `is_available`, `created_at` | The old flat `isSaved` boolean is dropped, see `reel_saves` below |
| `reel_products` | `reel_id` → `reels.id`, `product_id` → `products.id`, primary key (both) | Replaces `Reel.productIds`; the "shop the look" tagging, now with real referential integrity |
| `reel_likes` | `user_id` → `auth.users.id`, `reel_id` → `reels.id`, `created_at`, primary key (both) | Per-user like state. A trigger keeps `reels.like_count` in sync on insert/delete, so reads stay a single cheap column. Rendering "did I like this" for a reel list is a join/`in` lookup against this table for the current `user_id`, not a column on `reels` |
| `reel_saves` | `user_id`, `reel_id`, `created_at`, primary key (both) | Per-user save/bookmark state; the flat `Reel.isSaved` boolean could never be correct once there is more than one real (even anonymous) user. Same per-user join needed at read time as `reel_likes` |
| `cart_items` | `id`, `user_id` → `auth.users.id`, `product_id` → `products.id` (`on delete cascade`), `quantity`, `selected_size`, `selected_color` (int), `added_at` | Owned by the signed in (possibly anonymous) session. Cascading the product FK is correct here: a deleted product cannot stay shoppable in anyone's cart |
| `orders` | `id`, `user_id` → `auth.users.id`, `status` (`delivered`\|`in_progress`\|`canceled`), `total_amount`, `delivery_fee`, `delivery_method`, `shipping_address`, `payment_method`, `created_at`, `estimated_delivery` | |
| `order_items` | `id`, `order_id` → `orders.id` (`on delete cascade`), `product_id` → `products.id`, nullable, `on delete set null`, `title`, `image_url`, `store_name`, `unit_price`, `quantity`, `selected_size`, `selected_color` | Replaces `Order.items`'s inline list. `title`/`image_url`/`store_name`/`unit_price` are all snapshotted at purchase time, so a later product edit, rename, or deletion never rewrites or breaks a past receipt; rendering order history never needs a live join back to `products` |

## Security model

Row Level Security (RLS) is enabled on every table. Two access shapes:

**Public catalog data** (`user_profiles`, `products`, `reels`, `reel_products`): a single `select`
policy `to anon, authenticated using (true)`. No insert/update/delete policy exists at all, so those
are denied by default; content changes only through the Supabase dashboard or a service role key
until a real seller flow exists.

**Owned data** (`cart_items`, `orders`, `reel_likes`, `reel_saves`): full CRUD, but every policy is
scoped `to authenticated using ((select auth.uid()) = user_id)`, and every `update` policy repeats
the same check in `with check (...)` too (without it, a row's `user_id` could be reassigned to
someone else). `(select auth.uid())` (wrapped in a `select`, not called bare) so Postgres caches it
once per query instead of once per row (`supabase-postgres-best-practices` skill,
`security-rls-performance`). Every `user_id` column carries an index, since RLS filters on it on
every query.

`order_items` has no `user_id` of its own, so it cannot use that same direct check; its ownership is
indirect, through its parent `orders.user_id`. Every policy (`select`, `insert`, `update`, `delete`)
is scoped `using (exists (select 1 from orders o where o.id = order_id and o.user_id = (select
auth.uid())))`, and this same `exists` check is repeated in `with check (...)` on both `insert` and
`update` — the `insert` case matters just as much as `update` here: without a `with check`, a signed
in user could attach a line item to someone else's `order_id`. `order_items(order_id)` carries an
index for the same reason `user_id` columns do elsewhere: RLS runs this lookup on every query.

Anonymous sessions carry the same Postgres `authenticated` role as a real signed in user once
`signInAnonymously()` succeeds, so `to authenticated` alone does not distinguish "anonymous" from
"real" (a known Supabase trap, from the installed `supabase` skill). That is fine here because every
owned-data policy also checks `auth.uid() = user_id`, so it is correct regardless of which kind of
session that id belongs to.

## Configuration required

- `SUPABASE_URL`: the project's API URL, from the Supabase dashboard, passed via `--dart-define`
- `SUPABASE_PUBLISHABLE_KEY`: the project's publishable client key (what older Supabase docs call
  the "anon key"), safe to ship in the client, passed via `--dart-define`
- Dashboard setting: "Allow anonymous sign-ins" must be turned on under Authentication > Providers.
  This cannot be done from SQL or app code; it is a one time manual project setting.

## Consequences

**Positive**:
- The app has real, persisted data for the first time; cart and orders survive across app restarts
  within the same install
- RLS enforces ownership at the database level, not just in application code, for cart/order/like/save data
- The repository interface keeps the mock data path alive for tests and offline development

**Negative / tradeoffs**:
- An anonymous session lives in local device storage; uninstalling the app (or clearing app data)
  loses that identity, and with it the cart/order history tied to it, until real account linking exists
- Two more anonymous-session edge cases beyond uninstall, both for `/develop` to guard against: the app
  must check for and reuse a persisted session at startup, calling `signInAnonymously()` only when none
  exists (calling it unconditionally on every cold start would mint a fresh anonymous user, and orphan
  the previous session's cart/orders, every single launch); and a long-idle device's refresh token can
  expire with no credentials to sign back in, orphaning that data the same way an uninstall would
- The catalog (`products`, `reels`, `user_profiles`) is now read-only from the app; there is no
  seller UI, so all content changes go through the Supabase dashboard for now
- `products`/`reels` denormalize `store_name`/`store_avatar_url` for cheap reads; a store rename now
  needs an explicit update to every row that copied it, not just one row
- The project now has an external dependency (Supabase's uptime, quotas, pricing) where none existed before

**Neutral**:
- The SQL file is a single hand run script for the Supabase SQL editor, not a tracked Supabase CLI
  migration; formalizing that is a Follow-up, not done now
- Adds one new dependency, `supabase_flutter`
- Existing mock providers and mock data stay in the repo, now serving as the fallback/test implementation

## Follow-up

- [ ] Real auth (replacing anonymous only sign in) is its own future decision; needed before order
  history can be trusted to follow a person across devices or after a reinstall
- [ ] Turn on "Allow anonymous sign-ins" in the Supabase dashboard (Authentication > Providers);
  `signInAnonymously()` fails until this is set
- [ ] Adopt the Supabase CLI and tracked `supabase/migrations/`, instead of a hand run `schema.sql`,
  once the workflow is worth the setup
- [ ] A seller/product-management flow will eventually need write RLS policies on
  `products`/`reels`/`user_profiles`, which do not exist yet (catalog is read only for now)
- [ ] Connect the official `supabase-community/supabase-mcp` MCP server (needs a Service Role key in
  your MCP config) for live database access in future sessions; the engineer chose to be pointed at
  it rather than connect it now

## Rationale

Reasoning and options considered: see [rationale.md](rationale.md).
