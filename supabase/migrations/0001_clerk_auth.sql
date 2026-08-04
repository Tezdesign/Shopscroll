-- Shopscroll: migrate ownership columns from uuid to text for Clerk auth
-- Decision record: docs/specs/0004-clerk-authentication/index.md
--
-- Run this once, in full, against the SAME Supabase project that already
-- has spec 0003's schema.sql applied (Database > SQL Editor > New query).
-- Unlike schema.sql this is NOT for a brand new project: it ALTERs the
-- live tables in place. A fresh project should use the updated
-- schema.sql instead, which already has this migration folded in.
--
-- Order matters: FKs into user_profiles.id must be dropped before that
-- column (or the columns referencing it) can change type, and recreated
-- only after every column involved is text.

-- ============================================================
-- 1. Drop the foreign keys this migration touches
-- ============================================================

alter table public.products drop constraint products_store_id_fkey;
alter table public.reels drop constraint reels_store_id_fkey;
alter table public.reel_likes drop constraint reel_likes_user_id_fkey;
alter table public.reel_saves drop constraint reel_saves_user_id_fkey;
alter table public.cart_items drop constraint cart_items_user_id_fkey;
alter table public.orders drop constraint orders_user_id_fkey;

-- ============================================================
-- 2. user_profiles.id: drop the uuid default, real ids come from Clerk's
--    `sub` claim (or an anonymous session's `sub`) from here on
-- ============================================================

alter table public.user_profiles alter column id drop default;

-- ============================================================
-- 3. Change every ownership column from uuid to text. Clerk's user ids
--    (e.g. user_2abc123) are strings, not UUIDs; anonymous sessions'
--    `sub` claims are UUID shaped strings, so the cast is lossless for
--    every row that exists today.
-- ============================================================

alter table public.user_profiles alter column id type text using id::text;
alter table public.products alter column store_id type text using store_id::text;
alter table public.reels alter column store_id type text using store_id::text;
alter table public.reel_likes alter column user_id type text using user_id::text;
alter table public.reel_saves alter column user_id type text using user_id::text;
alter table public.cart_items alter column user_id type text using user_id::text;
alter table public.orders alter column user_id type text using user_id::text;

-- ============================================================
-- 4. Recreate the store_id foreign keys (user_profiles.id is text now).
--    reel_likes/reel_saves/cart_items/orders.user_id do NOT get a foreign
--    key back: Clerk accounts never populate auth.users, and a real
--    account's user_profiles row is created lazily by the app on first
--    real sign in, not guaranteed to exist before these tables are
--    written to (spec 0004, Consequences).
-- ============================================================

alter table public.products
  add constraint products_store_id_fkey
  foreign key (store_id) references public.user_profiles (id) on delete cascade;

alter table public.reels
  add constraint reels_store_id_fkey
  foreign key (store_id) references public.user_profiles (id) on delete cascade;

-- ============================================================
-- 5. RLS: replace auth.uid() with auth.jwt()->>'sub' everywhere it is
--    used for ownership, and narrow user_profiles' public select policy
--    now that it also holds real buyers' contact details (spec 0004,
--    Security model).
-- ============================================================

drop policy "user_profiles are publicly readable" on public.user_profiles;
create policy "sellers public, buyers own row only"
on public.user_profiles for select
to anon, authenticated
using (role = 'seller' or (select auth.jwt() ->> 'sub') = id);

drop policy "read own cart items" on public.cart_items;
create policy "read own cart items"
on public.cart_items for select
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

drop policy "insert own cart items" on public.cart_items;
create policy "insert own cart items"
on public.cart_items for insert
to authenticated
with check ((select auth.jwt() ->> 'sub') = user_id);

drop policy "update own cart items" on public.cart_items;
create policy "update own cart items"
on public.cart_items for update
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id)
with check ((select auth.jwt() ->> 'sub') = user_id);

drop policy "delete own cart items" on public.cart_items;
create policy "delete own cart items"
on public.cart_items for delete
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

drop policy "read own orders" on public.orders;
create policy "read own orders"
on public.orders for select
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

drop policy "insert own orders" on public.orders;
create policy "insert own orders"
on public.orders for insert
to authenticated
with check ((select auth.jwt() ->> 'sub') = user_id);

drop policy "update own orders" on public.orders;
create policy "update own orders"
on public.orders for update
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id)
with check ((select auth.jwt() ->> 'sub') = user_id);

drop policy "delete own orders" on public.orders;
create policy "delete own orders"
on public.orders for delete
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

drop policy "read own reel likes" on public.reel_likes;
create policy "read own reel likes"
on public.reel_likes for select
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

drop policy "insert own reel likes" on public.reel_likes;
create policy "insert own reel likes"
on public.reel_likes for insert
to authenticated
with check ((select auth.jwt() ->> 'sub') = user_id);

drop policy "delete own reel likes" on public.reel_likes;
create policy "delete own reel likes"
on public.reel_likes for delete
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

drop policy "read own reel saves" on public.reel_saves;
create policy "read own reel saves"
on public.reel_saves for select
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

drop policy "insert own reel saves" on public.reel_saves;
create policy "insert own reel saves"
on public.reel_saves for insert
to authenticated
with check ((select auth.jwt() ->> 'sub') = user_id);

drop policy "delete own reel saves" on public.reel_saves;
create policy "delete own reel saves"
on public.reel_saves for delete
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

-- order_items has no user_id of its own; its indirect exists() check
-- moves the same way, or a real account's query would hit a text = uuid
-- cast error instead of a clean RLS deny (spec 0004, Security model).

drop policy "read own order items" on public.order_items;
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

drop policy "insert own order items" on public.order_items;
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

drop policy "update own order items" on public.order_items;
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

drop policy "delete own order items" on public.order_items;
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
-- 6. merge_anonymous_identity: the anonymous-to-real cart/order merge
--    (spec 0004, AC-3, AC-10). SECURITY DEFINER because RLS's `with
--    check` can only ever validate the caller's OWN session, so a plain
--    UPDATE can never reassign a row's user_id across identities. Scoped
--    to anonymous-only callers (the is_anonymous claim is read straight
--    from the request's own JWT, so it cannot be spoofed) and to
--    additive-only writes into target_user_id: it can fold quantities
--    into or add rows onto the target's data, but never delete or reduce
--    anything the target already has.
-- ============================================================

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
