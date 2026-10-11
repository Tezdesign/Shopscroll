-- ============================================================
-- 0014: one order row per store, and the seller's order list (spec 0018, task 1)
-- ============================================================
-- Run against a TEST or BRANCH project first, after 0009. This changes
-- place_order, which is live, so check it before it goes to the live project.
-- The new place_order, the store_orders table and the backfill are in this one
-- file on purpose: no order can be placed between them.
--
-- What changes:
--   1. order_items.store_id says which store sold the line (null when the
--      product is gone). Old lines are filled from their product.
--   2. store_orders: one row per order and store, with its own status. Old
--      orders are filled from order_items, keeping their status. Closed to
--      every client: sellers read it only through the functions below.
--   3. place_order writes both in the same transaction as the order.
--   4. store_orders_list: the seller's Orders tab, filtered, searched and
--      paged by keyset.
--
-- Rollback: put the 0009 version of place_order back (the file is in this
-- folder). Orders placed after that have no store_orders row and stay
-- invisible to sellers until section 2's backfill is run again. The new
-- tables and columns can stay.

-- ------------------------------------------------------------
-- 1. order_items.store_id
-- ------------------------------------------------------------
alter table public.order_items
  add column if not exists store_id text;

update public.order_items as oi
set store_id = p.store_id
from public.products as p
where p.id = oi.product_id and oi.store_id is null;

create index if not exists order_items_store_idx
  on public.order_items (store_id, order_id);

-- Lets reports point at a line of one order and one store (spec 0018, 0017).
create unique index if not exists order_items_id_order_store_key
  on public.order_items (id, order_id, store_id);

-- ------------------------------------------------------------
-- 2. store_orders
-- ------------------------------------------------------------
create table if not exists public.store_orders (
  order_id uuid not null references public.orders (id) on delete cascade,
  -- The seller's Clerk id. No foreign key, same as orders.user_id.
  store_id text not null,
  status text not null default 'inProgress'
    check (status in ('inProgress', 'delivered', 'canceled', 'returned')),
  -- A copy of the order's date so one index serves the list and its paging.
  -- It never changes.
  created_at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (order_id, store_id)
);

create index if not exists store_orders_list_idx
  on public.store_orders (store_id, created_at desc, order_id desc);
create index if not exists store_orders_status_idx
  on public.store_orders (store_id, status);

drop trigger if exists store_orders_touch on public.store_orders;
create trigger store_orders_touch
before update on public.store_orders
for each row execute function public.touch_updated_at();

alter table public.store_orders enable row level security;
revoke all on public.store_orders from anon, authenticated;

-- Safe to run again: it only adds the rows that are missing. A line whose
-- product is gone has no store and gets no row.
insert into public.store_orders (order_id, store_id, status, created_at)
select distinct oi.order_id, oi.store_id, o.status, o.created_at
from public.order_items as oi
join public.orders as o on o.id = oi.order_id
where oi.store_id is not null
on conflict do nothing;

-- ------------------------------------------------------------
-- 3. place_order
-- ------------------------------------------------------------
-- The 0009 function with two additions, marked "0014": each line carries the
-- product's store_id, and one store_orders row is written per distinct store.
-- Same signature, same grants, same reasons.
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
  v_fee numeric(12, 3);
  v_days integer;
  v_lines integer;
  v_subtotal numeric;
  v_unavailable boolean;
  v_currencies integer;
  v_currency text;
  v_items jsonb;
  v_date date;
  v_left integer;
  v_need record;
begin
  if v_user is null then
    raise exception 'no_session';
  end if;

  -- A repeat of a request that already worked (a lost reply, a retry) returns
  -- that order and makes nothing new, so stock is not taken twice.
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

  -- Take the caller's cart lines and price them in ONE statement (see 0003).
  -- Each line is matched to its variant by product, color and size, where a
  -- missing choice matches a missing option. A line with no variant, or whose
  -- product is not live, is unavailable.
  with taken as (
    delete from public.cart_items
    where user_id = v_user
    returning product_id, quantity, selected_size, selected_color
  ),
  priced as (
    select
      t.quantity,
      t.selected_size,
      t.selected_color,
      p.id as product_id,
      p.store_id,
      p.title,
      p.image_url,
      p.store_name,
      p.status,
      p.currency,
      v.id as variant_id,
      v.price as unit_price
    from taken as t
    join public.products as p on p.id = t.product_id
    left join public.product_variants as v
      on v.product_id = p.id
      and v.color_value is not distinct from t.selected_color
      and v.size is not distinct from t.selected_size
  )
  select
    count(*),
    coalesce(sum(unit_price * quantity), 0),
    coalesce(bool_or(status <> 'live' or variant_id is null), false),
    count(distinct currency),
    min(currency),
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'product_id', product_id,
          'variant_id', variant_id,
          'store_id', store_id,
          'title', title,
          'image_url', image_url,
          'store_name', store_name,
          'unit_price', unit_price,
          'quantity', quantity,
          'selected_size', selected_size,
          'selected_color', selected_color
        )
      ),
      '[]'::jsonb
    )
  into v_lines, v_subtotal, v_unavailable, v_currencies, v_currency, v_items
  from priced;

  if v_lines = 0 then
    raise exception 'cart_empty';
  end if;
  if v_unavailable then
    raise exception 'product_unavailable';
  end if;
  if v_currencies > 1 then
    raise exception 'mixed_currency';
  end if;
  -- A product repriced since Checkout showed its total.
  if v_subtotal is distinct from p_expected_subtotal then
    raise exception 'price_changed';
  end if;
  -- Far beyond any real order, and past what numeric(12, 3) can hold.
  if v_subtotal > 99999999 then
    raise exception 'invalid_field';
  end if;

  -- Take the stock off, one variant at a time in a fixed order (so two orders
  -- cannot wait on each other), adding up lines that point at the same
  -- variant. The guarded update only succeeds while enough stock is left, so
  -- two orders for the last unit cannot both pass. Any refusal rolls the
  -- whole function back: stock, cart and order stay as they were.
  for v_need in
    select
      (i ->> 'variant_id')::uuid as variant_id,
      min(i ->> 'product_id') as product_id,
      sum((i ->> 'quantity')::integer) as quantity
    from jsonb_array_elements(v_items) as i
    group by (i ->> 'variant_id')::uuid
    order by (i ->> 'variant_id')::uuid
  loop
    update public.product_variants
    set stock = stock - v_need.quantity
    where id = v_need.variant_id and stock >= v_need.quantity;
    if not found then
      raise exception 'out_of_stock:%', v_need.product_id;
    end if;
  end loop;

  v_date := (now() at time zone 'Africa/Tunis')::date;
  v_left := v_days;
  while v_left > 0 loop
    v_date := v_date + 1;
    if extract(isodow from v_date) < 6 then
      v_left := v_left - 1;
    end if;
  end loop;

  insert into public.orders (
    id, user_id, status, subtotal, delivery_fee, total_amount, currency,
    delivery_method, payment_method,
    contact_name, contact_email, contact_phone,
    ship_country, ship_city, ship_address, ship_zip, ship_note,
    estimated_delivery
  )
  values (
    p_order_id, v_user, 'inProgress', v_subtotal, v_fee, v_subtotal + v_fee,
    v_currency,
    p_delivery_method, p_payment_method,
    p_contact_name, p_contact_email, p_contact_phone,
    'Tunisia', p_ship_city, p_ship_address, p_ship_zip, p_ship_note,
    (v_date::timestamp + interval '12 hours') at time zone 'UTC'
  );

  insert into public.order_items (
    order_id, product_id, store_id, title, image_url, store_name,
    unit_price, quantity, selected_size, selected_color
  )
  select
    p_order_id,
    (i ->> 'product_id')::uuid,
    i ->> 'store_id',
    i ->> 'title',
    i ->> 'image_url',
    i ->> 'store_name',
    (i ->> 'unit_price')::numeric,
    (i ->> 'quantity')::integer,
    i ->> 'selected_size',
    (i ->> 'selected_color')::bigint
  from jsonb_array_elements(v_items) as i;

  -- 0014: one row per store in this order, with the order's own date.
  insert into public.store_orders (order_id, store_id, status, created_at)
  select distinct p_order_id, i ->> 'store_id', 'inProgress', o.created_at
  from jsonb_array_elements(v_items) as i
  cross join (
    select created_at from public.orders where id = p_order_id
  ) as o
  where i ->> 'store_id' is not null;

  return p_order_id;
end;
$$;

revoke all on function public.place_order(
  uuid, text, text, text, text, text, text, text, text, text, numeric
) from public, anon;
grant execute on function public.place_order(
  uuid, text, text, text, text, text, text, text, text, text, numeric
) to authenticated;

-- ------------------------------------------------------------
-- 4. store_orders_list
-- ------------------------------------------------------------
-- Same convention as supabase/AGENTS.md: security definer, empty search_path,
-- execute revoked from public and anon and granted to authenticated only.
-- Refusals are raised as the whole error message: no_session, not_seller,
-- bad_status, bad_cursor.
--
-- One row per store order of the caller, newest first, ordered by
-- (created_at, order_id) so the keyset below never repeats or skips a row.
-- total is this store's lines only. No column returns the buyer's account id,
-- the whole order total, the delivery fee or another store's lines.
--
-- Search: strpos on lower case text, not like, so % and _ are plain
-- characters. A number search drops the leading zeros the seller typed, and a
-- name search never matches an order with no contact name.
create or replace function public.store_orders_list(
  p_status text default null,
  p_search text default null,
  p_limit integer default 20,
  p_cursor_created_at timestamptz default null,
  p_cursor_order_id uuid default null
)
returns table (
  order_id uuid,
  order_number bigint,
  status text,
  customer_name text,
  city text,
  address text,
  total numeric,
  currency text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_store text := public.require_seller();
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_text text := lower(btrim(coalesce(p_search, '')));
  v_digits text := ltrim(lower(btrim(coalesce(p_search, ''))), '0');
begin
  if p_status is not null
     and p_status not in ('inProgress', 'delivered', 'canceled', 'returned') then
    raise exception 'bad_status';
  end if;
  if (p_cursor_created_at is null) <> (p_cursor_order_id is null) then
    raise exception 'bad_cursor';
  end if;

  return query
  select
    so.order_id,
    o.order_number,
    so.status,
    o.contact_name,
    o.ship_city,
    o.ship_address,
    (
      select coalesce(sum(oi.unit_price * oi.quantity), 0)
      from public.order_items as oi
      where oi.order_id = so.order_id and oi.store_id = so.store_id
    ),
    o.currency,
    so.created_at
  from public.store_orders as so
  join public.orders as o on o.id = so.order_id
  where so.store_id = v_store
    and (p_status is null or so.status = p_status)
    and (
      v_text = ''
      or (v_digits <> '' and strpos(o.order_number::text, v_digits) > 0)
      or (
        o.contact_name is not null
        and strpos(lower(o.contact_name), v_text) > 0
      )
    )
    and (
      p_cursor_created_at is null
      or (so.created_at, so.order_id) < (p_cursor_created_at, p_cursor_order_id)
    )
  order by so.created_at desc, so.order_id desc
  limit v_limit;
end;
$$;

revoke all on function public.store_orders_list(
  text, text, integer, timestamptz, uuid
) from public, anon;
grant execute on function public.store_orders_list(
  text, text, integer, timestamptz, uuid
) to authenticated;
