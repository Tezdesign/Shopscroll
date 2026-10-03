-- Decision record: docs/specs/_root/0012-one-backend-seller-role.md
--
-- Seller access rules, part one. Safe to apply at any time, with old and new
-- buyer builds: it locks nothing that an old build writes. Part two is
-- 0005_lock_profile_columns.sql, applied only once no build that sends `role`
-- is in use.
--
-- What this does:
--   1. New profile rows default to role 'buyer' (the old default was 'seller').
--      Existing rows are left alone.
--   2. public.is_seller() and public.become_seller().
--   3. Sellers may insert, update and delete their own products, reels and
--      reel_products. Buyers may not write those tables.
--
-- Apply by hand (`supabase db push`), then confirm in supabase/checks/.
--
-- Rollback: drop the policies and functions created below, restore the old
-- default (`set default 'seller'`), and re-grant what the revokes removed
-- (`grant insert, update, delete on public.products, public.reels,
-- public.reel_products to authenticated`). Rows written in the meantime stay,
-- review them by hand.

-- ------------------------------------------------------------
-- 1. Default role
-- ------------------------------------------------------------
alter table public.user_profiles alter column role set default 'buyer';

-- ------------------------------------------------------------
-- 2. is_seller() and become_seller()
-- ------------------------------------------------------------
-- Both follow the convention in supabase/AGENTS.md: security definer, empty
-- search_path with every reference schema qualified, execute revoked from
-- public AND anon (Supabase grants anon execute by default), then granted back
-- to authenticated.

-- Used by the write policies below. `stable` plus the `(select ...)` wrapper
-- in each policy lets Postgres evaluate it once per statement, not per row.
create or replace function public.is_seller()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_profiles
    where id = (select auth.jwt() ->> 'sub')
      and role = 'seller'
  );
$$;

revoke all on function public.is_seller() from public, anon;
grant execute on function public.is_seller() to authenticated;

-- The only way a client turns its own profile into a seller. Reads the caller
-- from the JWT and updates exactly that one row. It clears email and phone
-- because those were copied from the sign in account and a seller profile is
-- publicly readable; a seller adds public contact details on purpose later.
-- Calling it twice is a no op (the second call must not wipe contact details
-- the seller has added since). Refusals are raised as the whole error message,
-- like place_order: no_session, no_profile.
create or replace function public.become_seller()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user text := (select auth.jwt() ->> 'sub');
begin
  if v_user is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'no_session';
  end if;

  if not exists (select 1 from public.user_profiles where id = v_user) then
    raise exception 'no_profile';
  end if;

  update public.user_profiles
  set role = 'seller', email = null, phone = null
  where id = v_user and role <> 'seller';
end;
$$;

revoke all on function public.become_seller() from public, anon;
grant execute on function public.become_seller() to authenticated;

-- ------------------------------------------------------------
-- 3. Seller write access to the catalog
-- ------------------------------------------------------------
-- Rows are owned when store_id equals the caller's Clerk `sub`. Table grants
-- come first on purpose: Supabase hands anon and authenticated table level
-- rights on new tables, and a column grant alone would not narrow them. So
-- revoke, then grant back column by column. Clients never write rating,
-- review_count, like_count, comment_count or created_at. The security definer
-- trigger function sync_reel_like_count writes like_count as the table owner,
-- so it is not affected.

revoke insert, update, delete on public.products from anon, authenticated;
revoke insert, update, delete on public.reels from anon, authenticated;
revoke insert, update, delete on public.reel_products from anon, authenticated;

-- products. store_id is insert only: a row never moves to another store.
grant insert (
  id, title, description, price, original_price, category, store_id,
  store_name, store_avatar_url, image_url, image_urls, color_options, sizes,
  is_deal, in_stock
) on public.products to authenticated;
grant update (
  title, description, price, original_price, category, store_name,
  store_avatar_url, image_url, image_urls, color_options, sizes, is_deal,
  in_stock
) on public.products to authenticated;
grant delete on public.products to authenticated;

drop policy if exists "sellers insert own products" on public.products;
create policy "sellers insert own products"
on public.products for insert
to authenticated
with check (
  store_id = (select auth.jwt() ->> 'sub') and (select public.is_seller())
);

drop policy if exists "sellers update own products" on public.products;
create policy "sellers update own products"
on public.products for update
to authenticated
using (
  store_id = (select auth.jwt() ->> 'sub') and (select public.is_seller())
)
with check (
  store_id = (select auth.jwt() ->> 'sub') and (select public.is_seller())
);

drop policy if exists "sellers delete own products" on public.products;
create policy "sellers delete own products"
on public.products for delete
to authenticated
using (
  store_id = (select auth.jwt() ->> 'sub') and (select public.is_seller())
);

-- reels
grant insert (
  id, video_url, thumbnail_url, store_id, store_name, store_avatar_url,
  caption, is_available
) on public.reels to authenticated;
grant update (
  video_url, thumbnail_url, store_name, store_avatar_url, caption,
  is_available
) on public.reels to authenticated;
grant delete on public.reels to authenticated;

drop policy if exists "sellers insert own reels" on public.reels;
create policy "sellers insert own reels"
on public.reels for insert
to authenticated
with check (
  store_id = (select auth.jwt() ->> 'sub') and (select public.is_seller())
);

drop policy if exists "sellers update own reels" on public.reels;
create policy "sellers update own reels"
on public.reels for update
to authenticated
using (
  store_id = (select auth.jwt() ->> 'sub') and (select public.is_seller())
)
with check (
  store_id = (select auth.jwt() ->> 'sub') and (select public.is_seller())
);

drop policy if exists "sellers delete own reels" on public.reels;
create policy "sellers delete own reels"
on public.reels for delete
to authenticated
using (
  store_id = (select auth.jwt() ->> 'sub') and (select public.is_seller())
);

-- reel_products: the "shop the look" tags. A seller tags only their own
-- products on their own reels. No update: both columns are the key, so a tag
-- is added or removed, never edited.
grant insert, delete on public.reel_products to authenticated;

drop policy if exists "sellers insert own reel tags" on public.reel_products;
create policy "sellers insert own reel tags"
on public.reel_products for insert
to authenticated
with check (
  (select public.is_seller())
  and exists (
    select 1 from public.reels r
    where r.id = reel_id and r.store_id = (select auth.jwt() ->> 'sub')
  )
  and exists (
    select 1 from public.products p
    where p.id = product_id and p.store_id = (select auth.jwt() ->> 'sub')
  )
);

drop policy if exists "sellers delete own reel tags" on public.reel_products;
create policy "sellers delete own reel tags"
on public.reel_products for delete
to authenticated
using (
  (select public.is_seller())
  and exists (
    select 1 from public.reels r
    where r.id = reel_id and r.store_id = (select auth.jwt() ->> 'sub')
  )
);
