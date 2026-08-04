-- Shopscroll: Supabase schema
-- Decision records: docs/specs/0003-supabase-backend/index.md,
-- docs/specs/0004-clerk-authentication/index.md
--
-- Run this once, in full, against a brand new Supabase project's SQL editor
-- (Database > SQL Editor > New query). It creates every table, the Row Level
-- Security policies that guard them, a like-count trigger, the anonymous to
-- real identity merge function, and seed data for the public catalog
-- (sellers, products, reels).
--
-- This is a hand run script, not a tracked migration (see spec 0003's
-- Follow-up). Re-running it on a project where these tables already exist
-- will error on the first `create table`; drop the tables first if you
-- really want to start over. An existing project that already ran the pre
-- spec-0004 version of this file should run
-- `supabase/migrations/0001_clerk_auth.sql` instead, which ALTERs it in
-- place rather than recreating it.
--
-- gen_random_uuid() ships in Postgres core (13+), so no extension is needed.
-- Ownership columns (user_profiles.id, products/reels.store_id, and every
-- owned table's user_id) are `text`, not `uuid`: Clerk's user ids (e.g.
-- user_2abc123) are strings, and Supabase's own anonymous sessions' `sub`
-- claim fits the same text column (spec 0004).

-- ============================================================
-- Tables
-- ============================================================

create table public.user_profiles (
  -- text, not uuid: a real account's id is Clerk's `sub` (e.g.
  -- user_2abc123), an anonymous session's id is Supabase's own `sub`. No
  -- default: every insert supplies its own id explicitly (spec 0004).
  id text primary key,
  name text not null,
  username text not null unique,
  avatar_url text,
  bio text,
  role text not null default 'seller' check (role in ('buyer', 'seller')),
  follower_count integer not null default 0,
  following_count integer not null default 0,
  product_count integer not null default 0,
  is_verified boolean not null default false,
  website_url text,
  location text,
  phone text,
  email text,
  created_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  price numeric(10, 2) not null,
  original_price numeric(10, 2),
  category text not null,
  store_id text not null references public.user_profiles (id) on delete cascade,
  store_name text not null,
  store_avatar_url text,
  image_url text,
  image_urls text[] not null default '{}',
  -- Color swatches as full ARGB values (Dart Color.value): bigint, not
  -- integer, because an opaque color's alpha byte (0xFF......) is bigger
  -- than Postgres' 32 bit int4 range.
  color_options bigint[] not null default '{}',
  sizes text[] not null default '{}',
  is_deal boolean not null default false,
  in_stock boolean not null default true,
  rating numeric(2, 1),
  review_count integer not null default 0,
  created_at timestamptz not null default now()
);
create index products_store_id_idx on public.products (store_id);
create index products_category_idx on public.products (category);

create table public.reels (
  id uuid primary key default gen_random_uuid(),
  video_url text not null,
  thumbnail_url text not null,
  store_id text not null references public.user_profiles (id) on delete cascade,
  store_name text not null,
  store_avatar_url text,
  caption text not null,
  like_count integer not null default 0,
  comment_count integer not null default 0,
  is_available boolean not null default true,
  created_at timestamptz not null default now()
);
create index reels_store_id_idx on public.reels (store_id);

-- Replaces Reel.productIds: the "shop the look" tagging, as a real join.
create table public.reel_products (
  reel_id uuid not null references public.reels (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  primary key (reel_id, product_id)
);
create index reel_products_product_id_idx on public.reel_products (product_id);

-- Per-user like state. reels.like_count is a cached counter kept in sync by
-- the trigger below, so a reel list read never needs to count these rows.
create table public.reel_likes (
  -- text, not a references auth.users FK: Clerk accounts never populate
  -- auth.users, and an anonymous session's own `sub` also fits text
  -- (spec 0004).
  user_id text not null,
  reel_id uuid not null references public.reels (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, reel_id)
);
create index reel_likes_reel_id_idx on public.reel_likes (reel_id);

-- Per-user save/bookmark state. Replaces the flat Reel.isSaved boolean,
-- which could never be correct once more than one person can save a reel.
create table public.reel_saves (
  user_id text not null,
  reel_id uuid not null references public.reels (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, reel_id)
);
create index reel_saves_reel_id_idx on public.reel_saves (reel_id);

create table public.cart_items (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  -- Cascades: a deleted product should not linger, un-shoppable, in
  -- someone's cart.
  product_id uuid not null references public.products (id) on delete cascade,
  quantity integer not null default 1 check (quantity > 0),
  selected_size text,
  selected_color bigint,
  added_at timestamptz not null default now()
);
create index cart_items_user_id_idx on public.cart_items (user_id);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  -- 'inProgress', not 'in_progress': matches Dart's OrderStatus.name exactly
  -- (the repository maps this column straight into OrderStatus.values.byName).
  status text not null default 'inProgress' check (status in ('delivered', 'inProgress', 'canceled')),
  total_amount numeric(10, 2) not null,
  delivery_fee numeric(10, 2),
  delivery_method text,
  shipping_address text,
  payment_method text,
  created_at timestamptz not null default now(),
  estimated_delivery timestamptz
);
create index orders_user_id_idx on public.orders (user_id);

-- Replaces Order.items's inline list. title/image_url/store_name/unit_price
-- are all snapshotted at purchase time, so a later product edit, rename, or
-- deletion never rewrites or breaks a past receipt; rendering order history
-- never needs a live join back to products. product_id is nullable with
-- ON DELETE SET NULL for exactly that reason: a deleted product must not
-- make an old order undeletable, and must not erase the receipt either.
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  product_id uuid references public.products (id) on delete set null,
  title text not null,
  image_url text,
  store_name text,
  unit_price numeric(10, 2) not null,
  quantity integer not null default 1 check (quantity > 0),
  selected_size text,
  selected_color bigint
);
create index order_items_order_id_idx on public.order_items (order_id);

-- ============================================================
-- Trigger: keep reels.like_count in sync with reel_likes
-- ============================================================
-- SECURITY DEFINER is required here: reels has no public UPDATE policy (see
-- RLS below), so a plain SECURITY INVOKER trigger would be blocked by RLS
-- the moment a regular user likes a reel. This is the legitimate case for
-- SECURITY DEFINER (an internal counter update, not a user facing RPC):
-- Postgres only ever invokes a trigger function from its trigger, never as
-- a directly callable function, so there is no separate grant to revoke.
-- search_path is pinned empty and every reference is schema qualified, so
-- the function cannot be tricked by a search_path change.
create or replace function public.sync_reel_like_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (tg_op = 'insert') then
    update public.reels set like_count = like_count + 1 where id = new.reel_id;
    return new;
  elsif (tg_op = 'delete') then
    update public.reels set like_count = greatest(like_count - 1, 0) where id = old.reel_id;
    return old;
  end if;
  return null;
end;
$$;

create trigger reel_likes_sync_count
after insert or delete on public.reel_likes
for each row execute function public.sync_reel_like_count();

-- ============================================================
-- Row Level Security
-- ============================================================

alter table public.user_profiles enable row level security;
alter table public.products enable row level security;
alter table public.reels enable row level security;
alter table public.reel_products enable row level security;
alter table public.reel_likes enable row level security;
alter table public.reel_saves enable row level security;
alter table public.cart_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Public catalog data: readable by anyone, anon or signed in. No insert,
-- update, or delete policy exists on these four tables at all, so those
-- are denied by default; there is no seller flow yet, so catalog changes
-- only happen through the Supabase dashboard or a service role key.
--
-- user_profiles is the one exception: since spec 0004, this table also
-- holds real buyers' name/email/phone (created lazily on first real sign
-- in), so it is only publicly readable for seller rows; a buyer can only
-- read their own.

create policy "sellers public, buyers own row only"
on public.user_profiles for select
to anon, authenticated
using (role = 'seller' or (select auth.jwt() ->> 'sub') = id);

create policy "products are publicly readable"
on public.products for select
to anon, authenticated
using (true);

create policy "reels are publicly readable"
on public.reels for select
to anon, authenticated
using (true);

create policy "reel_products are publicly readable"
on public.reel_products for select
to anon, authenticated
using (true);

-- Owned data: cart_items, orders, reel_likes, reel_saves all carry a direct
-- user_id (text: a Clerk id or an anonymous session's own `sub`, spec 0004).
-- Anonymous sessions carry the same Postgres `authenticated` role as a real
-- signed in user, so `to authenticated` alone would not be enough to tell
-- them apart; every policy also checks (select auth.jwt() ->> 'sub') = user_id.
-- Wrapped in a select so Postgres caches it once per query instead of
-- calling it once per row. Every update policy repeats the same check in
-- `with check`, or a row's user_id could be reassigned to someone else
-- (the one deliberate, narrowly scoped exception is
-- merge_anonymous_identity below, a security definer function).

create policy "read own cart items"
on public.cart_items for select
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

create policy "insert own cart items"
on public.cart_items for insert
to authenticated
with check ((select auth.jwt() ->> 'sub') = user_id);

create policy "update own cart items"
on public.cart_items for update
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id)
with check ((select auth.jwt() ->> 'sub') = user_id);

create policy "delete own cart items"
on public.cart_items for delete
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

create policy "read own orders"
on public.orders for select
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

create policy "insert own orders"
on public.orders for insert
to authenticated
with check ((select auth.jwt() ->> 'sub') = user_id);

create policy "update own orders"
on public.orders for update
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id)
with check ((select auth.jwt() ->> 'sub') = user_id);

create policy "delete own orders"
on public.orders for delete
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

create policy "read own reel likes"
on public.reel_likes for select
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

create policy "insert own reel likes"
on public.reel_likes for insert
to authenticated
with check ((select auth.jwt() ->> 'sub') = user_id);

create policy "delete own reel likes"
on public.reel_likes for delete
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

create policy "read own reel saves"
on public.reel_saves for select
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

create policy "insert own reel saves"
on public.reel_saves for insert
to authenticated
with check ((select auth.jwt() ->> 'sub') = user_id);

create policy "delete own reel saves"
on public.reel_saves for delete
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

-- order_items has no user_id of its own; ownership is indirect, through its
-- parent orders.user_id. Every verb, INCLUDING insert, repeats the same
-- exists() check in with check: without it on insert, a signed in user
-- could attach a line item to someone else's order_id.

create policy "read own order items"
on public.order_items for select
to authenticated
using (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and o.user_id = (select auth.jwt() ->> 'sub')
  )
);

create policy "insert own order items"
on public.order_items for insert
to authenticated
with check (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and o.user_id = (select auth.jwt() ->> 'sub')
  )
);

create policy "update own order items"
on public.order_items for update
to authenticated
using (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and o.user_id = (select auth.jwt() ->> 'sub')
  )
)
with check (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and o.user_id = (select auth.jwt() ->> 'sub')
  )
);

create policy "delete own order items"
on public.order_items for delete
to authenticated
using (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and o.user_id = (select auth.jwt() ->> 'sub')
  )
);

-- ============================================================
-- Anonymous to real identity merge (spec 0004, AC-3, AC-10)
-- ============================================================
-- SECURITY DEFINER because RLS's `with check` can only ever validate the
-- caller's OWN session, so a plain client side UPDATE can never reassign a
-- row's user_id from an old anonymous identity to a new real one. Scoped to
-- anonymous-only callers (is_anonymous is read straight from the request's
-- own JWT, so it cannot be spoofed) and to additive-only writes into
-- target_user_id: it can fold quantities into, or add rows onto, the
-- target's data, but never delete or reduce anything the target already
-- owns. search_path is pinned empty and every reference is schema
-- qualified, same hardening as sync_reel_like_count above; execute is
-- revoked from public and granted only to authenticated.

create or replace function public.merge_anonymous_identity(target_user_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id text;
begin
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) is not true then
    return;
  end if;

  caller_id := auth.jwt() ->> 'sub';
  if caller_id is null or caller_id = target_user_id then
    return;
  end if;

  -- Cart: fold matching lines (same product + size + color) into the
  -- target's existing quantity.
  update public.cart_items as target
  set quantity = target.quantity + source.quantity
  from public.cart_items as source
  where source.user_id = caller_id
    and target.user_id = target_user_id
    and target.product_id = source.product_id
    and coalesce(target.selected_size, '') = coalesce(source.selected_size, '')
    and coalesce(target.selected_color, -1) = coalesce(source.selected_color, -1);

  -- The source rows just folded into an existing target row are now
  -- duplicates; remove them before reassigning whatever cart lines are
  -- left (no match in the target's cart) straight onto the target.
  delete from public.cart_items as source
  where source.user_id = caller_id
    and exists (
      select 1 from public.cart_items as target
      where target.user_id = target_user_id
        and target.product_id = source.product_id
        and coalesce(target.selected_size, '') = coalesce(source.selected_size, '')
        and coalesce(target.selected_color, -1) = coalesce(source.selected_color, -1)
    );

  update public.cart_items
  set user_id = target_user_id
  where user_id = caller_id;

  -- Orders: no merge concept between two independent orders, just
  -- reassign ownership; order_items follow automatically (keyed off
  -- order_id, not user_id).
  update public.orders
  set user_id = target_user_id
  where user_id = caller_id;
end;
$$;

revoke all on function public.merge_anonymous_identity(text) from public;
grant execute on function public.merge_anonymous_identity(text) to authenticated;

-- ============================================================
-- Grants (belt and braces alongside RLS: RLS controls which rows are
-- visible once a table is reachable at all; these grants control whether
-- it is reachable through the Data API in the first place)
-- ============================================================

grant usage on schema public to anon, authenticated;
grant select on public.user_profiles, public.products, public.reels, public.reel_products to anon, authenticated;
grant select, insert, update, delete on public.cart_items, public.orders, public.order_items, public.reel_likes, public.reel_saves to authenticated;

-- ============================================================
-- Seed data: the public catalog, from lib/data/mock/*.dart
-- ============================================================
-- Only the ownerless catalog (sellers, products, reels, reel_products) is
-- seeded here. cart_items, orders, reel_likes, and reel_saves are per-user
-- (owned) data: they need a real row in auth.users to point at, and that
-- only exists once someone actually opens the app and signs in (even
-- anonymously, via supabase.auth.signInAnonymously()). There is no such
-- user yet on a brand new project, so those tables intentionally start
-- empty; the app populates them itself once it is wired up.

insert into public.user_profiles (id, name, username, avatar_url, bio, role, follower_count, following_count, product_count, is_verified, website_url, location, phone, email) values
  ('11111111-1111-1111-1111-111111111001', 'Bershka', '@bershka', 'https://picsum.photos/seed/bershka-avatar/100/100', 'Trend-driven fashion for a young, bold crowd.', 'seller', 128400, 12, 6, true, 'https://www.bershka.com', 'Barcelona, Spain', null, 'contact@bershka.com'),
  ('11111111-1111-1111-1111-111111111002', 'Pull&Bear', '@pullandbear', 'https://picsum.photos/seed/pullandbear-avatar/100/100', 'Casual streetwear inspired by music and youth culture.', 'seller', 94200, 8, 3, false, 'https://www.pullandbear.com', 'Tunis, Tunisia', null, 'hello@pullandbear.com'),
  ('11111111-1111-1111-1111-111111111003', 'Apple', '@apple', 'https://picsum.photos/seed/apple-avatar/100/100', 'Official Apple accessories store.', 'seller', 512000, 1, 3, true, 'https://www.apple.com', 'Cupertino, USA', '+1 800 275 2273', 'support@apple.com'),
  ('11111111-1111-1111-1111-111111111004', 'Nike', '@nike', 'https://picsum.photos/seed/nike-avatar/100/100', 'Just Do It. Sportswear, sneakers and performance gear.', 'seller', 348900, 4, 3, true, 'https://www.nike.com', 'Beaverton, USA', null, 'care@nike.com'),
  ('11111111-1111-1111-1111-111111111005', 'Glossier', '@glossier', 'https://picsum.photos/seed/glossier-avatar/100/100', 'Skin first. Makeup second. Smile always.', 'seller', 76500, 20, 3, false, 'https://www.glossier.com', 'New York, USA', null, 'support@glossier.com');

insert into public.products (id, title, description, price, original_price, category, store_id, store_name, store_avatar_url, image_url, image_urls, color_options, sizes, is_deal, rating, review_count, created_at) values
  ('22222222-2222-2222-2222-222222222001', 'Oversized Blazer Dress', 'Bershka Menswear SS25: who''s slaying better. An oversized blazer dress with structured shoulders and a relaxed silhouette, perfect for layering into any season.', 65, null, 'Fashion', '11111111-1111-1111-1111-111111111001', 'Bershka', 'https://picsum.photos/seed/bershka-avatar/100/100', 'https://picsum.photos/seed/prod-001/400/500', ARRAY['https://picsum.photos/seed/prod-001-a/800/1000', 'https://picsum.photos/seed/prod-001-b/800/1000'], ARRAY[4294901502, 4278216447, 4294929152, 4281545523]::bigint[], ARRAY['XS', 'S', 'M', 'L', 'XL'], false, 4.5, 212, '2026-06-18'),
  ('22222222-2222-2222-2222-222222222002', 'Ribbed Knit Sweater', 'A soft ribbed-knit sweater with a relaxed crew neck, easy to dress up or down.', 35, null, 'Fashion', '11111111-1111-1111-1111-111111111001', 'Bershka', 'https://picsum.photos/seed/bershka-avatar/100/100', 'https://picsum.photos/seed/prod-002/400/500', ARRAY[]::text[], ARRAY[4281545523, 4292006610]::bigint[], ARRAY['S', 'M', 'L'], false, 4.2, 88, '2026-06-20'),
  ('22222222-2222-2222-2222-222222222003', 'Wide Leg Denim Jeans', 'High-rise wide-leg jeans in a mid-wash denim, built for all-day comfort.', 49, null, 'Fashion', '11111111-1111-1111-1111-111111111001', 'Bershka', 'https://picsum.photos/seed/bershka-avatar/100/100', 'https://picsum.photos/seed/prod-003/400/500', ARRAY[]::text[], ARRAY[]::bigint[], ARRAY['XS', 'S', 'M', 'L'], false, 4.6, 340, '2026-06-10'),
  ('22222222-2222-2222-2222-222222222016', 'Satin Slip Midi Dress', 'A bias-cut satin slip dress with adjustable straps, dresses up easily for evening wear.', 58, 82, 'Fashion', '11111111-1111-1111-1111-111111111001', 'Bershka', 'https://picsum.photos/seed/bershka-avatar/100/100', 'https://picsum.photos/seed/prod-016/400/500', ARRAY[]::text[], ARRAY[4278190080, 4294574080]::bigint[], ARRAY['XS', 'S', 'M', 'L'], true, 4.7, 156, '2026-06-28'),
  ('22222222-2222-2222-2222-222222222004', 'Graphic Print Hoodie', 'Heavyweight cotton hoodie with a bold graphic print across the chest.', 42, null, 'Fashion', '11111111-1111-1111-1111-111111111002', 'Pull&Bear', 'https://picsum.photos/seed/pullandbear-avatar/100/100', 'https://picsum.photos/seed/prod-004/400/500', ARRAY[]::text[], ARRAY[4278190080, 4287532686]::bigint[], ARRAY['S', 'M', 'L', 'XL'], false, 4.3, 121, '2026-06-15'),
  ('22222222-2222-2222-2222-222222222005', 'Cargo Utility Pants', 'Straight-fit cargo pants with multiple utility pockets and an adjustable waist.', 55, null, 'Fashion', '11111111-1111-1111-1111-111111111002', 'Pull&Bear', 'https://picsum.photos/seed/pullandbear-avatar/100/100', 'https://picsum.photos/seed/prod-005/400/500', ARRAY[]::text[], ARRAY[]::bigint[], ARRAY['S', 'M', 'L', 'XL'], false, 4.1, 64, '2026-06-22'),
  ('22222222-2222-2222-2222-222222222006', 'Cropped Denim Jacket', 'A classic cropped denim jacket with a slightly distressed wash and front button closure.', 60, null, 'Fashion', '11111111-1111-1111-1111-111111111002', 'Pull&Bear', 'https://picsum.photos/seed/pullandbear-avatar/100/100', 'https://picsum.photos/seed/prod-006/400/500', ARRAY[]::text[], ARRAY[]::bigint[], ARRAY['XS', 'S', 'M', 'L'], false, 4.4, 97, '2026-06-12'),
  ('22222222-2222-2222-2222-222222222007', 'iPhone 15 Pro Silicone Case', 'A soft-touch silicone case with a microfiber lining, precisely molded for iPhone 15 Pro.', 49, null, 'Tech', '11111111-1111-1111-1111-111111111003', 'Apple', 'https://picsum.photos/seed/apple-avatar/100/100', 'https://picsum.photos/seed/prod-007/400/500', ARRAY[]::text[], ARRAY[4278190080, 4294901502, 4278216447]::bigint[], ARRAY[]::text[], false, 4.8, 540, '2026-06-25'),
  ('22222222-2222-2222-2222-222222222008', 'AirPods Pro (2nd Gen)', 'Active Noise Cancellation, Adaptive Transparency, and Personalized Spatial Audio.', 249, null, 'Tech', '11111111-1111-1111-1111-111111111003', 'Apple', 'https://picsum.photos/seed/apple-avatar/100/100', 'https://picsum.photos/seed/prod-008/400/500', ARRAY[]::text[], ARRAY[]::bigint[], ARRAY[]::text[], false, 4.9, 1024, '2026-06-08'),
  ('22222222-2222-2222-2222-222222222009', 'MagSafe Charger', 'Snap-on wireless charging up to 15W, compatible with iPhone 12 and later.', 39, null, 'Tech', '11111111-1111-1111-1111-111111111003', 'Apple', 'https://picsum.photos/seed/apple-avatar/100/100', 'https://picsum.photos/seed/prod-009/400/500', ARRAY[]::text[], ARRAY[]::bigint[], ARRAY[]::text[], false, 4.6, 289, '2026-06-30'),
  ('22222222-2222-2222-2222-222222222018', 'USB-C to Lightning Cable', 'A 1m braided cable for fast charging and data transfer.', 19, 29, 'Tech', '11111111-1111-1111-1111-111111111003', 'Apple', 'https://picsum.photos/seed/apple-avatar/100/100', 'https://picsum.photos/seed/prod-018/400/500', ARRAY[]::text[], ARRAY[]::bigint[], ARRAY[]::text[], true, 4.4, 175, '2026-07-01'),
  ('22222222-2222-2222-2222-222222222010', 'Air Max 270 Sneakers', 'Nike''s biggest heel Air unit yet, for all-day comfort with a bold look.', 150, null, 'Sports', '11111111-1111-1111-1111-111111111004', 'Nike', 'https://picsum.photos/seed/nike-avatar/100/100', 'https://picsum.photos/seed/prod-010/400/500', ARRAY[]::text[], ARRAY[4278190080, 4294901502, 4294574080]::bigint[], ARRAY['38', '39', '40', '41', '42', '43'], false, 4.7, 892, '2026-06-05'),
  ('22222222-2222-2222-2222-222222222011', 'Dri-FIT Running Shorts', 'Lightweight, sweat-wicking shorts built for your daily run.', 35, null, 'Sports', '11111111-1111-1111-1111-111111111004', 'Nike', 'https://picsum.photos/seed/nike-avatar/100/100', 'https://picsum.photos/seed/prod-011/400/500', ARRAY[]::text[], ARRAY[]::bigint[], ARRAY['S', 'M', 'L', 'XL'], false, 4.3, 145, '2026-06-27'),
  ('22222222-2222-2222-2222-222222222012', 'Tech Fleece Joggers', 'Warm without the bulk, Nike Tech Fleece joggers with a tapered fit.', 110, null, 'Sports', '11111111-1111-1111-1111-111111111004', 'Nike', 'https://picsum.photos/seed/nike-avatar/100/100', 'https://picsum.photos/seed/prod-012/400/500', ARRAY[]::text[], ARRAY[]::bigint[], ARRAY['S', 'M', 'L', 'XL'], false, 4.5, 203, '2026-06-14'),
  ('22222222-2222-2222-2222-222222222017', 'Windrunner Jacket', 'The iconic Nike Windrunner with a water-repellent finish and signature chevron design.', 120, 160, 'Sports', '11111111-1111-1111-1111-111111111004', 'Nike', 'https://picsum.photos/seed/nike-avatar/100/100', 'https://picsum.photos/seed/prod-017/400/500', ARRAY[]::text[], ARRAY[4278216447, 4278190080]::bigint[], ARRAY['S', 'M', 'L', 'XL'], true, 4.6, 311, '2026-07-03'),
  ('22222222-2222-2222-2222-222222222013', 'Cloud Paint Blush', 'A buildable, gel-cream blush that blends like a second skin.', 22, null, 'Makeup', '11111111-1111-1111-1111-111111111005', 'Glossier', 'https://picsum.photos/seed/glossier-avatar/100/100', 'https://picsum.photos/seed/prod-013/400/500', ARRAY[]::text[], ARRAY[]::bigint[], ARRAY[]::text[], false, 4.7, 402, '2026-06-19'),
  ('22222222-2222-2222-2222-222222222014', 'Boy Brow Eyebrow Gel', 'A cult-favorite, all-in-one brow gel that shapes and tints.', 18, null, 'Makeup', '11111111-1111-1111-1111-111111111005', 'Glossier', 'https://picsum.photos/seed/glossier-avatar/100/100', 'https://picsum.photos/seed/prod-014/400/500', ARRAY[]::text[], ARRAY[]::bigint[], ARRAY[]::text[], false, 4.8, 615, '2026-06-24'),
  ('22222222-2222-2222-2222-222222222015', 'Lash Slick Mascara', 'A lengthening, curling mascara that keeps lashes soft, not stiff.', 20, null, 'Makeup', '11111111-1111-1111-1111-111111111005', 'Glossier', 'https://picsum.photos/seed/glossier-avatar/100/100', 'https://picsum.photos/seed/prod-015/400/500', ARRAY[]::text[], ARRAY[]::bigint[], ARRAY[]::text[], false, 4.5, 278, '2026-07-02');

insert into public.reels (id, video_url, thumbnail_url, store_id, store_name, store_avatar_url, caption, like_count, comment_count, is_available, created_at) values
  ('33333333-3333-3333-3333-333333333001', 'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 'https://picsum.photos/seed/reel-001/400/700', '11111111-1111-1111-1111-111111111001', 'Bershka', 'https://picsum.photos/seed/bershka-avatar/100/100', 'Layering the oversized blazer dress for a night out', 3420, 128, true, '2026-06-29'),
  ('33333333-3333-3333-3333-333333333002', 'https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 'https://picsum.photos/seed/reel-002/400/700', '11111111-1111-1111-1111-111111111002', 'Pull&Bear', 'https://picsum.photos/seed/pullandbear-avatar/100/100', 'Street style: graphic hoodie + cargo pants combo', 1876, 54, true, '2026-06-27'),
  ('33333333-3333-3333-3333-333333333003', 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4', 'https://picsum.photos/seed/reel-003/400/700', '11111111-1111-1111-1111-111111111003', 'Apple', 'https://picsum.photos/seed/apple-avatar/100/100', 'Unboxing AirPods Pro (2nd Gen)', 9820, 412, true, '2026-06-20'),
  ('33333333-3333-3333-3333-333333333004', 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4', 'https://picsum.photos/seed/reel-004/400/700', '11111111-1111-1111-1111-111111111004', 'Nike', 'https://picsum.photos/seed/nike-avatar/100/100', 'Morning run in the Air Max 270', 5230, 201, true, '2026-06-24'),
  ('33333333-3333-3333-3333-333333333005', 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4', 'https://picsum.photos/seed/reel-005/400/700', '11111111-1111-1111-1111-111111111005', 'Glossier', 'https://picsum.photos/seed/glossier-avatar/100/100', 'Get-ready-with-me using Cloud Paint + Boy Brow', 2740, 96, true, '2026-06-22'),
  ('33333333-3333-3333-3333-333333333006', 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4', 'https://picsum.photos/seed/reel-006/400/700', '11111111-1111-1111-1111-111111111001', 'Bershka', 'https://picsum.photos/seed/bershka-avatar/100/100', 'Denim on denim, always a good idea', 1543, 42, true, '2026-06-18'),
  ('33333333-3333-3333-3333-333333333007', 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4', 'https://picsum.photos/seed/reel-007/400/700', '11111111-1111-1111-1111-111111111004', 'Nike', 'https://picsum.photos/seed/nike-avatar/100/100', 'Windrunner jacket restock, almost gone again', 4102, 178, true, '2026-07-04'),
  ('33333333-3333-3333-3333-333333333008', 'https://storage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4', 'https://picsum.photos/seed/reel-008/400/700', '11111111-1111-1111-1111-111111111003', 'Apple', 'https://picsum.photos/seed/apple-avatar/100/100', 'MagSafe charger speed test', 987, 31, true, '2026-06-12'),
  ('33333333-3333-3333-3333-333333333009', 'https://storage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4', 'https://picsum.photos/seed/reel-009/400/700', '11111111-1111-1111-1111-111111111002', 'Pull&Bear', 'https://picsum.photos/seed/pullandbear-avatar/100/100', 'This store closed the account linked to this reel', 640, 12, false, '2026-05-30'),
  ('33333333-3333-3333-3333-333333333010', 'https://storage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4', 'https://picsum.photos/seed/reel-010/400/700', '11111111-1111-1111-1111-111111111005', 'Glossier', 'https://picsum.photos/seed/glossier-avatar/100/100', 'Lash Slick before/after, no clumps, just lift', 3187, 145, true, '2026-06-08');

insert into public.reel_products (reel_id, product_id) values
  ('33333333-3333-3333-3333-333333333001', '22222222-2222-2222-2222-222222222001'),
  ('33333333-3333-3333-3333-333333333002', '22222222-2222-2222-2222-222222222004'),
  ('33333333-3333-3333-3333-333333333002', '22222222-2222-2222-2222-222222222005'),
  ('33333333-3333-3333-3333-333333333003', '22222222-2222-2222-2222-222222222008'),
  ('33333333-3333-3333-3333-333333333004', '22222222-2222-2222-2222-222222222010'),
  ('33333333-3333-3333-3333-333333333004', '22222222-2222-2222-2222-222222222011'),
  ('33333333-3333-3333-3333-333333333005', '22222222-2222-2222-2222-222222222013'),
  ('33333333-3333-3333-3333-333333333005', '22222222-2222-2222-2222-222222222014'),
  ('33333333-3333-3333-3333-333333333006', '22222222-2222-2222-2222-222222222003'),
  ('33333333-3333-3333-3333-333333333007', '22222222-2222-2222-2222-222222222017'),
  ('33333333-3333-3333-3333-333333333008', '22222222-2222-2222-2222-222222222009'),
  ('33333333-3333-3333-3333-333333333009', '22222222-2222-2222-2222-222222222006'),
  ('33333333-3333-3333-3333-333333333010', '22222222-2222-2222-2222-222222222015');
