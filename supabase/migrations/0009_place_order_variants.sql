-- ============================================================
-- 0009: orders use the variant's price and stock (spec 0015, task 9)
-- ============================================================
-- Run against a TEST or BRANCH project first, after 0008. This changes
-- place_order, which is live, so check it before it goes to the live project.
--
-- What changes:
--   1. Order money columns hold 3 decimals (a dinar has three), and orders
--      get a currency.
--   2. place_order finds the variant of each cart line (same product, color
--      and size), prices the line from that variant, refuses a product that is
--      not live or a line with no matching variant (product_unavailable),
--      refuses a cart with two currencies (mixed_currency), and takes the
--      stock off each variant in the same transaction. A variant with less
--      stock than asked refuses the whole order with out_of_stock:<product id>
--      and nothing changes, the cart included.
--
-- Rollback: put the 0003 version of place_order back (the file is in this
-- folder). The widened columns and the currency column can stay.

-- ------------------------------------------------------------
-- 1. Money columns and currency
-- ------------------------------------------------------------
alter table public.orders
  alter column total_amount type numeric(12, 3),
  alter column subtotal type numeric(12, 3),
  alter column delivery_fee type numeric(12, 3);

alter table public.order_items
  alter column unit_price type numeric(12, 3);

alter table public.orders
  add column if not exists currency text not null default 'TND';

alter table public.orders
  drop constraint if exists orders_currency_check;
alter table public.orders
  add constraint orders_currency_check check (currency ~ '^[A-Z]{3}$');

-- ------------------------------------------------------------
-- 2. place_order
-- ------------------------------------------------------------
-- Same signature, same grants, same reasons as 0003 plus out_of_stock and
-- mixed_currency. Reasons are raised as the whole error message:
-- no_session, cart_empty, product_unavailable, price_changed, invalid_field,
-- invalid_method, out_of_stock:<product id>, mixed_currency.
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

revoke all on function public.place_order(
  uuid, text, text, text, text, text, text, text, text, text, numeric
) from public, anon;
grant execute on function public.place_order(
  uuid, text, text, text, text, text, text, text, text, text, numeric
) to authenticated;
