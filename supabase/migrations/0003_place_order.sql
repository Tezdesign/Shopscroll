-- ============================================================
-- 0003: place_order (spec 0009, the purchasing flow)
-- ============================================================
-- Run against the live project after 0001 and 0002 (supabase db push).
-- Never a rerun of schema.sql.
--
-- Three changes:
--   1. orders gets the columns a real order needs: an order number, a
--      subtotal, the buyer's contact details and the delivery address. The old
--      free text shipping_address column goes away.
--   2. Buyers can no longer insert, update or delete orders or order items
--      themselves. Row level security policies AND table grants are both
--      closed, so an order can only be made by place_order below.
--   3. place_order builds one order from the caller's own saved cart, prices
--      it from the products table (never from the phone), clears the cart and
--      returns the order id, all in one transaction.

-- ------------------------------------------------------------
-- 1. Columns on orders
-- ------------------------------------------------------------
-- Every new column allows empty values, so orders made before this change stay
-- valid. place_order always fills them for a new order.

alter table public.orders
  add column if not exists order_number bigint generated always as identity,
  add column if not exists subtotal numeric(10, 2),
  add column if not exists contact_name text,
  add column if not exists contact_email text,
  add column if not exists contact_phone text,
  add column if not exists ship_country text default 'Tunisia',
  add column if not exists ship_city text,
  add column if not exists ship_address text,
  add column if not exists ship_zip text,
  add column if not exists ship_note text;

alter table public.orders
  add constraint orders_order_number_key unique (order_number);

-- Older orders: the subtotal is the total without the delivery fee.
update public.orders
set subtotal = total_amount - coalesce(delivery_fee, 0)
where subtotal is null;

-- Replaced by ship_city, ship_address, ship_zip and ship_note.
alter table public.orders drop column if exists shipping_address;

-- ------------------------------------------------------------
-- 2. Close direct writes
-- ------------------------------------------------------------
-- The select policies ("read own orders", "read own order items") stay.

drop policy if exists "insert own orders" on public.orders;
drop policy if exists "update own orders" on public.orders;
drop policy if exists "delete own orders" on public.orders;

drop policy if exists "insert own order items" on public.order_items;
drop policy if exists "update own order items" on public.order_items;
drop policy if exists "delete own order items" on public.order_items;

-- Row level security is not the only barrier: the grants go too. The service
-- role (account deletion) and security definer functions (place_order and
-- merge_anonymous_identity) are not affected.
revoke insert, update, delete on public.orders from authenticated;
revoke insert, update, delete on public.order_items from authenticated;

-- ------------------------------------------------------------
-- 3. place_order
-- ------------------------------------------------------------
-- The convention for a security definer function here (supabase/AGENTS.md):
-- search_path is empty and every reference is schema qualified, execute is
-- revoked from public and granted back to authenticated only.
--
-- It reads the caller's rows only, by auth.jwt() ->> 'sub', and takes no user
-- id, price or total as an argument. The reasons it refuses are raised as the
-- whole error message, and the app reads them: no_session, cart_empty,
-- product_unavailable, price_changed, invalid_field, invalid_method.
--
-- Fees and delivery days are placeholders the owner will change. The same
-- numbers are in lib/data/models/place_order_request.dart (display only, this
-- function is the truth).
--   standard: 10 dollars, 6 working days
--   exclusive: 16 dollars, 2 working days
-- Working days skip Saturday and Sunday and are counted on the Tunis calendar.

create or replace function public.place_order(
  p_order_id uuid,
  p_contact_name text,
  p_contact_email text,
  p_contact_phone text,
  p_ship_city text,
  p_ship_address text,
  p_ship_zip text,
  p_ship_note text,
  p_delivery_method text,
  p_payment_method text,
  p_expected_subtotal numeric
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user text := (select auth.jwt() ->> 'sub');
  v_fee numeric(10, 2);
  v_days integer;
  v_lines integer;
  v_subtotal numeric;
  v_unavailable boolean;
  v_items jsonb;
  v_date date;
  v_left integer;
begin
  if v_user is null then
    raise exception 'no_session';
  end if;

  -- A repeat of a request that already worked (a lost reply, a retry) returns
  -- that order and makes nothing new.
  if exists (
    select 1 from public.orders
    where id = p_order_id and user_id = v_user
  ) then
    return p_order_id;
  end if;

  p_contact_name := btrim(coalesce(p_contact_name, ''));
  p_contact_email := btrim(coalesce(p_contact_email, ''));
  p_contact_phone := btrim(coalesce(p_contact_phone, ''));
  p_ship_city := btrim(coalesce(p_ship_city, ''));
  p_ship_address := btrim(coalesce(p_ship_address, ''));
  p_ship_zip := btrim(coalesce(p_ship_zip, ''));
  p_ship_note := btrim(coalesce(p_ship_note, ''));

  if char_length(p_contact_name) not between 2 and 120
    or char_length(p_contact_email) not between 3 and 254
    or p_contact_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
    or char_length(p_contact_phone) not between 6 and 20
    or char_length(p_ship_city) not between 1 and 120
    or char_length(p_ship_address) not between 1 and 120
    or char_length(p_ship_zip) not between 3 and 12
    or char_length(p_ship_note) > 300
  then
    raise exception 'invalid_field';
  end if;

  -- Only Standard and Exclusive delivery exist, and only pay on delivery can
  -- place an order for now (card payment has its own spec).
  if p_delivery_method = 'standard' then
    v_fee := 10;
    v_days := 6;
  elsif p_delivery_method = 'exclusive' then
    v_fee := 16;
    v_days := 2;
  else
    raise exception 'invalid_method';
  end if;
  if p_payment_method is distinct from 'cashOnDelivery' then
    raise exception 'invalid_method';
  end if;

  -- Take the caller's cart lines and price them in ONE statement. The delete
  -- returns exactly the rows it removed, so a line added from another device
  -- a moment later is never lost, and two parallel calls cannot both order the
  -- same lines (the second finds nothing and raises cart_empty). If anything
  -- below raises, the whole function rolls back and the cart is untouched.
  with taken as (
    delete from public.cart_items
    where user_id = v_user
    returning product_id, quantity, selected_size, selected_color
  )
  select
    count(*),
    coalesce(sum(p.price * t.quantity), 0),
    coalesce(bool_or(not p.in_stock), false),
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'product_id', p.id,
          'title', p.title,
          'image_url', p.image_url,
          'store_name', p.store_name,
          'unit_price', p.price,
          'quantity', t.quantity,
          'selected_size', t.selected_size,
          'selected_color', t.selected_color
        )
      ),
      '[]'::jsonb
    )
  into v_lines, v_subtotal, v_unavailable, v_items
  from taken as t
  join public.products as p on p.id = t.product_id;

  if v_lines = 0 then
    raise exception 'cart_empty';
  end if;
  if v_unavailable then
    raise exception 'product_unavailable';
  end if;
  -- A product removed or repriced since Checkout showed its total.
  if v_subtotal is distinct from p_expected_subtotal then
    raise exception 'price_changed';
  end if;
  -- Far beyond any real order, and past what numeric(10, 2) can hold.
  if v_subtotal > 99999999 then
    raise exception 'invalid_field';
  end if;

  v_date := (now() at time zone 'Africa/Tunis')::date;
  v_left := v_days;
  while v_left > 0 loop
    v_date := v_date + 1;
    if extract(isodow from v_date) < 6 then
      v_left := v_left - 1;
    end if;
  end loop;

  insert into public.orders (
    id, user_id, status, subtotal, delivery_fee, total_amount,
    delivery_method, payment_method,
    contact_name, contact_email, contact_phone,
    ship_country, ship_city, ship_address, ship_zip, ship_note,
    estimated_delivery
  )
  values (
    p_order_id, v_user, 'inProgress', v_subtotal, v_fee, v_subtotal + v_fee,
    p_delivery_method, p_payment_method,
    p_contact_name, p_contact_email, p_contact_phone,
    'Tunisia', p_ship_city, p_ship_address, p_ship_zip, p_ship_note,
    -- Noon UTC of that date, so no time zone moves it to a neighbouring day.
    (v_date::timestamp + interval '12 hours') at time zone 'UTC'
  );

  insert into public.order_items (
    order_id, product_id, title, image_url, store_name,
    unit_price, quantity, selected_size, selected_color
  )
  select
    p_order_id,
    (i ->> 'product_id')::uuid,
    i ->> 'title',
    i ->> 'image_url',
    i ->> 'store_name',
    (i ->> 'unit_price')::numeric,
    (i ->> 'quantity')::integer,
    i ->> 'selected_size',
    (i ->> 'selected_color')::bigint
  from jsonb_array_elements(v_items) as i;

  return p_order_id;
end;
$$;

-- Supabase also grants execute to anon by default, so revoking from public is
-- not enough: anon (a caller with no session at all) is revoked by name.
revoke all on function public.place_order(
  uuid, text, text, text, text, text, text, text, text, text, numeric
) from public, anon;
grant execute on function public.place_order(
  uuid, text, text, text, text, text, text, text, text, text, numeric
) to authenticated;
