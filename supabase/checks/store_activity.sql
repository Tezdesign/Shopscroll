-- Decision record: docs/specs/_root/0018-seller-activity-screens/index.md (build plan task 1)
--
-- SQL checks for the seller Activity screens, migrations 0014 to 0017: AC-2 to
-- AC-13. Run the whole file in the SQL editor of a TEST or BRANCH database (or
-- with psql) after applying migrations 0008, 0009 and 0014 to 0017. It creates
-- its own fixtures, acts as buyers and sellers with a fake JWT, and ends with
-- `rollback`, so it leaves no rows behind.
--
-- Output: one NOTICE per check. A failed check raises an error that starts with
-- FAIL and stops the script.

begin;

create function pg_temp.try(p_sql text) returns text
language plpgsql as $$
declare v_rows integer;
begin
  execute p_sql;
  get diagnostics v_rows = row_count;
  return 'ok:' || v_rows;
exception when others then
  return 'err:' || sqlstate || ':' || sqlerrm;
end;
$$;

create function pg_temp.act_as(p_sub text, p_anonymous boolean default false)
returns void language plpgsql as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_sub, 'is_anonymous', p_anonymous)::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

create function pg_temp.expect(p_label text, p_actual text, p_prefix text)
returns void language plpgsql as $$
begin
  if p_actual not like p_prefix || '%' then
    raise exception 'FAIL %: expected %, got %', p_label, p_prefix, p_actual;
  end if;
  raise notice 'ok   %', p_label;
end;
$$;

create function pg_temp.order_sql(p_id uuid, p_subtotal numeric) returns text
language sql as $$
  select format(
    $q$select public.place_order(%L, 'Test Buyer', 'buyer@example.com', '+21600000000',
       'Sousse', '1 Rue Test', '4000', '', 'standard', 'cashOnDelivery', %s)$q$,
    p_id, p_subtotal)
$$;

-- The order ids a seller's list returns, in the order returned.
create function pg_temp.ids(p_args text) returns uuid[]
language plpgsql as $$
declare v uuid[];
begin
  execute format('select coalesce(array_agg(order_id), ''{}'') from public.store_orders_list(%s)', p_args)
  into v;
  return v;
end;
$$;

-- Fixtures, created as the table owner.
insert into public.user_profiles (id, name, username, role, currency) values
  ('chk_sa', 'Chk Seller A', 'chk_sa', 'seller', 'TND'),
  ('chk_sb', 'Chk Seller B', 'chk_sb', 'seller', 'TND'),
  ('chk_b1', 'Chk Buyer 1', 'chk_b1', 'buyer', 'TND');

insert into public.products (id, title, description, price, category, store_id, store_name, currency)
values
  ('00000000-0000-0000-0000-0000000000a1', 'Dress A', 'd', 10, 'Fashion', 'chk_sa', 'Store A', 'TND'),
  ('00000000-0000-0000-0000-0000000000a2', 'Shirt B', 'd', 20.5, 'Fashion', 'chk_sb', 'Store B', 'TND'),
  ('00000000-0000-0000-0000-0000000000a3', 'Gone item', 'd', 5, 'Tech', 'chk_sa', 'Store A', 'TND');

insert into public.product_variants (id, product_id, color_value, size, price, stock) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', null, null, 10, 10),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2', null, null, 20.5, 10);

do $chk$
declare
  p_a constant uuid := '00000000-0000-0000-0000-0000000000a1';
  p_b constant uuid := '00000000-0000-0000-0000-0000000000a2';
  p_gone constant uuid := '00000000-0000-0000-0000-0000000000a3';
  o_new constant uuid := '00000000-0000-0000-0000-0000000000c1';
  o_old_done constant uuid := '00000000-0000-0000-0000-0000000000c2';
  o_old_gone constant uuid := '00000000-0000-0000-0000-0000000000c3';
  o_pct constant uuid := '00000000-0000-0000-0000-0000000000c4';
  o_anon constant uuid := '00000000-0000-0000-0000-0000000000c5';
  v_ids uuid[];
  v_row record;
  v_num bigint;
  v_cursor_at timestamptz;
  v_cursor_id uuid;
  v_page1 uuid[];
  v_page2 uuid[];
  v_page3 uuid[];
  v_all uuid[];
  i integer;
begin
  -- ----------------------------------------------------------- AC-13 place_order
  insert into public.cart_items (user_id, product_id, quantity)
  values ('chk_b1', p_a, 2), ('chk_b1', p_b, 1);

  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-13 a cart with two stores places one order',
    pg_temp.try(pg_temp.order_sql(o_new, 40.5)), 'ok:1');
  reset role;

  if (select count(*) from public.store_orders where order_id = o_new) <> 2
     or (select count(distinct store_id) from public.store_orders where order_id = o_new) <> 2 then
    raise exception 'FAIL AC-13: two stores should give two store_orders rows';
  end if;
  if exists (
    select 1 from public.store_orders
    where order_id = o_new and status <> 'inProgress'
  ) then
    raise exception 'FAIL AC-13: new store orders start inProgress';
  end if;
  if exists (
    select 1 from public.store_orders so join public.orders o on o.id = so.order_id
    where so.order_id = o_new and so.created_at <> o.created_at
  ) then
    raise exception 'FAIL AC-13: store_orders.created_at must equal the order date';
  end if;
  if (select count(*) from public.order_items where order_id = o_new and store_id = 'chk_sa') <> 1
     or (select count(*) from public.order_items where order_id = o_new and store_id = 'chk_sb') <> 1 then
    raise exception 'FAIL AC-13: every order line must carry the store of its product';
  end if;
  raise notice 'ok   AC-13 place_order writes order_items.store_id and one row per store';

  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-13 replaying the order succeeds',
    pg_temp.try(pg_temp.order_sql(o_new, 40.5)), 'ok:1');
  reset role;
  if (select count(*) from public.store_orders where order_id = o_new) <> 2 then
    raise exception 'FAIL AC-13: a replay must not add store_orders rows';
  end if;
  raise notice 'ok   AC-13 a replay adds no rows';

  -- ----------------------------------------------------------- AC-13 backfill
  -- Old shape: lines with no store_id, no store_orders row.
  insert into public.orders (id, user_id, status, total_amount, subtotal, delivery_fee,
    contact_name, ship_city, ship_address, created_at)
  values
    (o_old_done, 'chk_b1', 'delivered', 15, 5, 10, 'Old Buyer', 'Tunis', '2 Rue Vieille', now() - interval '30 days'),
    (o_old_gone, 'chk_b1', 'inProgress', 15, 5, 10, null, null, null, now() - interval '31 days');
  insert into public.order_items (order_id, product_id, title, unit_price, quantity) values
    (o_old_done, p_gone, 'Gone item', 5, 1),
    (o_old_gone, null, 'Deleted product', 5, 1);

  -- The backfill statements of migration 0014, section 1 and 2, run again.
  update public.order_items as oi
  set store_id = p.store_id
  from public.products as p
  where p.id = oi.product_id and oi.store_id is null;
  for i in 1..2 loop
    insert into public.store_orders (order_id, store_id, status, created_at)
    select distinct oi.order_id, oi.store_id, o.status, o.created_at
    from public.order_items as oi
    join public.orders as o on o.id = oi.order_id
    where oi.store_id is not null
    on conflict do nothing;
  end loop;

  if (select status from public.store_orders where order_id = o_old_done and store_id = 'chk_sa') is distinct from 'delivered' then
    raise exception 'FAIL AC-13: an old delivered order keeps delivered';
  end if;
  if exists (select 1 from public.store_orders where order_id = o_old_gone) then
    raise exception 'FAIL AC-13: a line whose product is gone gets no store row';
  end if;
  if (select count(*) from public.store_orders where order_id = o_old_done) <> 1 then
    raise exception 'FAIL AC-13: running the backfill again must not duplicate rows';
  end if;
  raise notice 'ok   AC-13 backfill keeps status, skips deleted products, can run again';

  -- ----------------------------------------------------------- AC-2 list and isolation
  perform pg_temp.act_as('chk_sa');
  select * into v_row from public.store_orders_list() where order_id = o_new;
  if v_row.total <> 20 or v_row.status <> 'inProgress' or v_row.currency <> 'TND'
     or v_row.city <> 'Sousse' or v_row.address <> '1 Rue Test' or v_row.customer_name <> 'Test Buyer' then
    raise exception 'FAIL AC-2: seller A row wrong: %', v_row;
  end if;
  raise notice 'ok   AC-2 seller A sees only own lines in the total (20.000, not 40.500)';

  v_ids := pg_temp.ids('');
  if v_ids <> array[o_new, o_old_done] then
    raise exception 'FAIL AC-2: seller A should see their two orders newest first, got %', v_ids;
  end if;
  raise notice 'ok   AC-2 newest first, only own store orders';

  perform pg_temp.act_as('chk_sb');
  select * into v_row from public.store_orders_list() where order_id = o_new;
  if v_row.total <> 20.5 then
    raise exception 'FAIL AC-2: seller B total should be 20.500, got %', v_row.total;
  end if;
  if pg_temp.ids('') <> array[o_new] then
    raise exception 'FAIL AC-12: seller B must not see seller A orders';
  end if;
  raise notice 'ok   AC-12 seller B sees only their own order and total';
  reset role;

  -- An order with no contact name shows a null name and is not matched by name.
  update public.orders set contact_name = null where id = o_old_done;
  perform pg_temp.act_as('chk_sa');
  select * into v_row from public.store_orders_list() where order_id = o_old_done;
  if v_row.customer_name is not null then
    raise exception 'FAIL AC-2: an order with no contact has a null customer_name';
  end if;
  if o_old_done = any (pg_temp.ids($$p_search => 'customer'$$)) then
    raise exception 'FAIL AC-4: the Customer placeholder must not match a name search';
  end if;
  raise notice 'ok   AC-2 an order with no contact name returns null and matches no name';
  reset role;
  update public.orders set contact_name = 'Old Buyer' where id = o_old_done;

  -- ----------------------------------------------------------- AC-3 status filter
  perform pg_temp.act_as('chk_sa');
  if pg_temp.ids($$p_status => 'delivered'$$) <> array[o_old_done] then
    raise exception 'FAIL AC-3: delivered filter wrong';
  end if;
  if pg_temp.ids($$p_status => 'inProgress'$$) <> array[o_new] then
    raise exception 'FAIL AC-3: inProgress filter wrong';
  end if;
  if pg_temp.ids($$p_status => 'canceled'$$) <> '{}' then
    raise exception 'FAIL AC-3: canceled filter should be empty';
  end if;
  perform pg_temp.expect('AC-3 an unknown status is refused',
    pg_temp.try($$select * from public.store_orders_list(p_status => 'bogus')$$), 'err:P0001:bad_status');
  raise notice 'ok   AC-3 status filter';
  reset role;

  -- ----------------------------------------------------------- AC-4 search
  select order_number into v_num from public.orders where id = o_new;
  perform pg_temp.act_as('chk_sa');
  if not (o_new = any (pg_temp.ids(format($$p_search => %L$$, v_num::text)))) then
    raise exception 'FAIL AC-4: the bare order number must find the order';
  end if;
  if not (o_new = any (pg_temp.ids(format($$p_search => %L$$, lpad(v_num::text, 6, '0'))))) then
    raise exception 'FAIL AC-4: the number with leading zeros must find the order';
  end if;
  if not (o_new = any (pg_temp.ids($$p_search => '  tEsT buy  '$$))) then
    raise exception 'FAIL AC-4: name search ignores case and surrounding spaces';
  end if;
  if pg_temp.ids($$p_search => 'nobody'$$) <> '{}' then
    raise exception 'FAIL AC-4: no match gives an empty list';
  end if;
  reset role;

  insert into public.orders (id, user_id, status, total_amount, subtotal, delivery_fee,
    contact_name, ship_city, ship_address, created_at)
  values (o_pct, 'chk_b1', 'inProgress', 15, 5, 10, '100% Real_Name', 'Sfax', '3 Rue', now() - interval '1 day');
  insert into public.order_items (order_id, product_id, store_id, title, unit_price, quantity)
  values (o_pct, p_a, 'chk_sa', 'Dress A', 5, 1);
  insert into public.store_orders (order_id, store_id, created_at)
  select o_pct, 'chk_sa', created_at from public.orders where id = o_pct;

  perform pg_temp.act_as('chk_sa');
  if pg_temp.ids($$p_search => '%'$$) <> array[o_pct] then
    raise exception 'FAIL AC-4: %% must be a plain character';
  end if;
  if pg_temp.ids($$p_search => '_'$$) <> array[o_pct] then
    raise exception 'FAIL AC-4: _ must be a plain character';
  end if;
  if pg_temp.ids($$p_search => 'Real', p_status => 'delivered'$$) <> '{}' then
    raise exception 'FAIL AC-4: search and filter work together';
  end if;
  raise notice 'ok   AC-4 number with or without zeros, name, case, spaces, %% and _ as plain text';
  reset role;

  -- ----------------------------------------------------------- AC-2 paging
  -- Five more orders for seller A. Two share one created_at to test the tie break.
  for i in 1..5 loop
    insert into public.orders (id, user_id, status, total_amount, subtotal, delivery_fee,
      contact_name, ship_city, ship_address, created_at)
    values (('00000000-0000-0000-0000-00000000d00' || i)::uuid, 'chk_b1', 'inProgress', 15, 5, 10,
      'Pager ' || i, 'Tunis', 'x', now() + interval '1 day' - make_interval(mins => case when i in (2, 3) then 2 else i end));
    insert into public.order_items (order_id, product_id, store_id, title, unit_price, quantity)
    values (('00000000-0000-0000-0000-00000000d00' || i)::uuid, p_a, 'chk_sa', 'Dress A', 5, 1);
    insert into public.store_orders (order_id, store_id, created_at)
    select ('00000000-0000-0000-0000-00000000d00' || i)::uuid, 'chk_sa', created_at
    from public.orders where id = ('00000000-0000-0000-0000-00000000d00' || i)::uuid;
  end loop;

  perform pg_temp.act_as('chk_sa');
  v_page1 := pg_temp.ids('p_limit => 3');
  select created_at, order_id into v_cursor_at, v_cursor_id
  from public.store_orders_list(p_limit => 3) order by created_at asc, order_id asc limit 1;
  v_page2 := pg_temp.ids(format('p_limit => 3, p_cursor_created_at => %L, p_cursor_order_id => %L', v_cursor_at, v_cursor_id));
  select created_at, order_id into v_cursor_at, v_cursor_id
  from public.store_orders_list(
    p_limit => 3, p_cursor_created_at => v_cursor_at, p_cursor_order_id => v_cursor_id
  ) order by created_at asc, order_id asc limit 1;
  v_page3 := pg_temp.ids(format('p_limit => 3, p_cursor_created_at => %L, p_cursor_order_id => %L', v_cursor_at, v_cursor_id));
  v_all := v_page1 || v_page2 || v_page3;
  if cardinality(v_all) <> 8 or (select count(distinct x) from unnest(v_all) as x) <> 8 then
    raise exception 'FAIL AC-2: three pages of 3 should give 8 distinct orders, got %', v_all;
  end if;
  if v_all <> pg_temp.ids('p_limit => 50') then
    raise exception 'FAIL AC-2: paging must give the same order as one big page';
  end if;
  raise notice 'ok   AC-2 keyset paging gives no repeat and no gap, with a tie on created_at';

  perform pg_temp.expect('AC-2 a cursor with one part is refused',
    pg_temp.try($$select * from public.store_orders_list(p_cursor_order_id => gen_random_uuid())$$), 'err:P0001:bad_cursor');
  if cardinality(pg_temp.ids('p_limit => 1000')) <> 8 then
    raise exception 'FAIL AC-2: a big limit is capped, not refused';
  end if;
  reset role;

  -- ----------------------------------------------------------- AC-12 rights
  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-12 a buyer gets not_seller',
    pg_temp.try('select * from public.store_orders_list()'), 'err:P0001:not_seller');
  reset role;

  perform pg_temp.act_as('chk_anon', true);
  perform pg_temp.expect('AC-12 an anonymous session gets no_session',
    pg_temp.try('select * from public.store_orders_list()'), 'err:P0001:no_session');
  reset role;

  set local role anon;
  perform pg_temp.expect('AC-12 the anon role is refused by Postgres',
    pg_temp.try('select * from public.store_orders_list()'), 'err:42501');
  reset role;

  perform pg_temp.act_as('chk_sa');
  perform pg_temp.expect('AC-12 no client reads store_orders directly',
    pg_temp.try('select * from public.store_orders'), 'err:42501');
  perform pg_temp.expect('AC-12 no client writes store_orders directly',
    pg_temp.try($$update public.store_orders set status = 'delivered'$$), 'err:42501');
  reset role;
  raise notice 'ok   AC-12 buyer, anonymous, anon role and direct table access are all refused';
end;
$chk$;

-- ----------------------------------------------------------------- 0015 detail
-- Reuses the fixtures above: o_new has one line of chk_sa and one of chk_sb,
-- o_pct has only a line of chk_sa.
do $chk$
declare
  o_new constant uuid := '00000000-0000-0000-0000-0000000000c1';
  o_pct constant uuid := '00000000-0000-0000-0000-0000000000c4';
  v_row record;
  v_result text;
begin
  perform pg_temp.act_as('chk_sa');
  select * into v_row from public.store_order_detail(o_new);
  if v_row.subtotal <> 20 or jsonb_array_length(v_row.lines) <> 1
     or v_row.lines -> 0 ->> 'title' <> 'Dress A'
     or (v_row.lines -> 0 ->> 'quantity')::int <> 2 then
    raise exception 'FAIL AC-5: seller A should see only their line and subtotal 20, got %', v_row;
  end if;
  if v_row.customer_name <> 'Test Buyer' or v_row.customer_email <> 'buyer@example.com'
     or v_row.customer_phone <> '+21600000000' or v_row.city <> 'Sousse'
     or v_row.address <> '1 Rue Test' or v_row.zip <> '4000'
     or v_row.delivery_method <> 'standard' or v_row.payment_method <> 'cashOnDelivery'
     or v_row.status <> 'inProgress' or v_row.currency <> 'TND' then
    raise exception 'FAIL AC-5: contact, delivery or payment fields wrong: %', v_row;
  end if;
  raise notice 'ok   AC-5 seller A sees their own line, subtotal and the order fields';

  perform pg_temp.act_as('chk_sb');
  select * into v_row from public.store_order_detail(o_new);
  if v_row.subtotal <> 20.5 or v_row.lines -> 0 ->> 'title' <> 'Shirt B' then
    raise exception 'FAIL AC-5: seller B should see only Shirt B and 20.5, got %', v_row;
  end if;
  raise notice 'ok   AC-5 seller B sees only their own line and subtotal';

  perform pg_temp.expect('AC-12 an order of another store gives not_found',
    pg_temp.try(format('select * from public.store_order_detail(%L)', o_pct)), 'err:P0001:not_found');
  perform pg_temp.expect('AC-5 an unknown id gives the same not_found',
    pg_temp.try('select * from public.store_order_detail(gen_random_uuid())'), 'err:P0001:not_found');
  reset role;

  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-12 a buyer gets not_seller',
    pg_temp.try(format('select * from public.store_order_detail(%L)', o_new)), 'err:P0001:not_seller');
  reset role;
  perform pg_temp.act_as('chk_anon', true);
  perform pg_temp.expect('AC-12 an anonymous session gets no_session',
    pg_temp.try(format('select * from public.store_order_detail(%L)', o_new)), 'err:P0001:no_session');
  reset role;
  set local role anon;
  perform pg_temp.expect('AC-12 the anon role is refused by Postgres',
    pg_temp.try(format('select * from public.store_order_detail(%L)', o_new)), 'err:42501');
  reset role;

  v_result := pg_get_function_result('public.store_order_detail(uuid)'::regprocedure);
  if v_result ~ 'user_id|total_amount|delivery_fee|reporter_id' then
    raise exception 'FAIL AC-12: the detail must not return private columns, got %', v_result;
  end if;
  raise notice 'ok   AC-12 the detail returns no buyer id, order total or delivery fee';
end;
$chk$;

-- ----------------------------------------------------------------- 0016 earnings
-- Its own seller (chk_sc, profile currency USD) and buyers, with orders dated
-- relative to now(), which does not move inside a transaction. Counted orders
-- (not canceled, not returned) of chk_sc: e1 20 and e2 30 and e7 10 today (e1
-- also has a 999 line of another store), e5 50 seven days ago, e6 5 thirty days
-- ago. Canceled e3 and returned e4 (100 each) are never counted.
insert into public.user_profiles (id, name, username, role, currency) values
  ('chk_sc', 'Chk Seller C', 'chk_sc', 'seller', 'USD'),
  ('chk_sd', 'Chk Seller D', 'chk_sd', 'seller', 'TND'),
  ('chk_u1', 'Chk Buyer U1', 'chk_u1', 'buyer', 'TND'),
  ('chk_u2', 'Chk Buyer U2', 'chk_u2', 'buyer', 'TND'),
  ('chk_u3', 'Chk Buyer U3', 'chk_u3', 'buyer', 'TND'),
  ('chk_u4', 'Chk Buyer U4', 'chk_u4', 'buyer', 'TND');

do $chk$
declare
  e1 constant uuid := '00000000-0000-0000-0000-0000000000e1';
  e2 constant uuid := '00000000-0000-0000-0000-0000000000e2';
  e3 constant uuid := '00000000-0000-0000-0000-0000000000e3';
  e4 constant uuid := '00000000-0000-0000-0000-0000000000e4';
  e5 constant uuid := '00000000-0000-0000-0000-0000000000e5';
  e6 constant uuid := '00000000-0000-0000-0000-0000000000e6';
  e7 constant uuid := '00000000-0000-0000-0000-0000000000e7';
  v_row record;
  v_result text;
begin
  insert into public.orders (id, user_id, status, total_amount, subtotal, delivery_fee,
    contact_name, ship_city, ship_address, created_at)
  values
    (e1, 'chk_u1', 'inProgress', 0, 0, 0, 'U One', 'Tunis', '1 Rue E', now()),
    (e2, 'chk_u2', 'inProgress', 0, 0, 0, 'U Two', 'Tunis', '2 Rue E', now()),
    (e3, 'chk_u1', 'inProgress', 0, 0, 0, 'U One', 'Tunis', '3 Rue E', now()),
    (e4, 'chk_u3', 'inProgress', 0, 0, 0, 'U Three', 'Tunis', '4 Rue E', now()),
    (e5, 'chk_u2', 'delivered', 0, 0, 0, 'U Two', 'Tunis', '5 Rue E', now() - interval '7 days'),
    (e6, 'chk_u1', 'delivered', 0, 0, 0, 'U One', 'Tunis', '6 Rue E', now() - interval '30 days'),
    (e7, 'chk_u4', 'inProgress', 0, 0, 0, 'U Four', 'Tunis', '7 Rue E', now());
  insert into public.order_items (order_id, product_id, store_id, title, unit_price, quantity) values
    (e1, null, 'chk_sc', 'E1', 10, 2),
    (e1, null, 'chk_sb', 'Other store', 999, 1),
    (e2, null, 'chk_sc', 'E2', 15, 2),
    (e3, null, 'chk_sc', 'E3', 100, 1),
    (e4, null, 'chk_sc', 'E4', 100, 1),
    (e5, null, 'chk_sc', 'E5', 50, 1),
    (e6, null, 'chk_sc', 'E6', 5, 1),
    (e7, null, 'chk_sc', 'E7', 10, 1);
  insert into public.store_orders (order_id, store_id, status, created_at)
  select o.id, 'chk_sc', s.status, o.created_at
  from public.orders as o
  join (values
    (e1, 'inProgress'), (e2, 'delivered'), (e3, 'canceled'), (e4, 'returned'),
    (e5, 'delivered'), (e6, 'delivered'), (e7, 'inProgress')
  ) as s(id, status) on s.id = o.id;

  perform pg_temp.act_as('chk_sc');
  select * into v_row from public.store_earnings();
  if v_row.total_sales <> 115 then
    raise exception 'FAIL AC-6: total sales should be 115 (no canceled, returned or other store lines), got %', v_row.total_sales;
  end if;
  if v_row.today_sales <> 60 or v_row.today_orders <> 3 then
    raise exception 'FAIL AC-6: today should be 60 over 3 orders, got % over %', v_row.today_sales, v_row.today_orders;
  end if;
  if v_row.week_sales <> 60 or v_row.prev_week_same_span_sales <> 50 then
    raise exception 'FAIL AC-6: week should be 60 and the same span last week 50, got % and %',
      v_row.week_sales, v_row.prev_week_same_span_sales;
  end if;
  raise notice 'ok   AC-6 sales: total, today, week and the same span last week';

  if v_row.customers <> 3 or v_row.new_customers_today <> 1 then
    raise exception 'FAIL AC-6: customers should be 3 with 1 new today, got % and %', v_row.customers, v_row.new_customers_today;
  end if;
  raise notice 'ok   AC-6 customers count distinct buyers with a counted order, new when the first one is today';

  if v_row.currency <> 'USD' then
    raise exception 'FAIL AC-6: the currency is the store profile currency, got %', v_row.currency;
  end if;
  raise notice 'ok   AC-6 currency is the store profile currency';

  if jsonb_array_length(v_row.recent) <> 4
     or (v_row.recent -> 3 ->> 'amount')::numeric <> 50
     or exists (select 1 from jsonb_array_elements(v_row.recent) as r where (r ->> 'amount')::numeric in (100, 999)) then
    raise exception 'FAIL AC-7: recent should be the 4 latest counted orders, got %', v_row.recent;
  end if;
  raise notice 'ok   AC-7 recent sales are the 4 latest counted orders, newest first';

  v_result := pg_get_function_result('public.store_earnings()'::regprocedure);
  if v_result ~ 'user_id|total_amount|delivery_fee|reporter_id'
     or v_row.recent::text ~ 'user_id|total_amount|delivery_fee' then
    raise exception 'FAIL AC-12: earnings must not return private columns, got %', v_result;
  end if;
  raise notice 'ok   AC-12 earnings return no buyer id, order total or delivery fee';

  perform pg_temp.act_as('chk_sd');
  select * into v_row from public.store_earnings();
  if v_row.total_sales <> 0 or v_row.today_sales <> 0 or v_row.today_orders <> 0
     or v_row.week_sales <> 0 or v_row.prev_week_same_span_sales <> 0
     or v_row.customers <> 0 or v_row.new_customers_today <> 0
     or v_row.recent <> '[]'::jsonb then
    raise exception 'FAIL AC-14: a store with no orders shows zeros and no recent sales, got %', v_row;
  end if;
  raise notice 'ok   AC-14 a store with no orders shows zeros';

  perform pg_temp.act_as('chk_sb');
  select * into v_row from public.store_earnings();
  if v_row.total_sales <> (
       select coalesce(sum(total), 0) from public.store_orders_list(p_limit => 50)
       where status not in ('canceled', 'returned')
     ) then
    raise exception 'FAIL AC-6: earnings and the order list must agree for seller B, got %', v_row.total_sales;
  end if;
  raise notice 'ok   AC-6 earnings agree with the order list totals';
  reset role;

  perform pg_temp.act_as('chk_u1');
  perform pg_temp.expect('AC-12 a buyer gets not_seller',
    pg_temp.try('select * from public.store_earnings()'), 'err:P0001:not_seller');
  reset role;
  perform pg_temp.act_as('chk_anon', true);
  perform pg_temp.expect('AC-12 an anonymous session gets no_session',
    pg_temp.try('select * from public.store_earnings()'), 'err:P0001:no_session');
  reset role;
  set local role anon;
  perform pg_temp.expect('AC-12 the anon role is refused by Postgres',
    pg_temp.try('select * from public.store_earnings()'), 'err:42501');
  reset role;
end;
$chk$;

-- ----------------------------------------------------------------- 0017 reports
-- Reuses the fixtures above: o_new has one line of chk_sa and one of chk_sb,
-- o_pct has only a line of chk_sa (customer "100% Real_Name"). Reports are
-- written as the table owner, because no client creates them yet (AC-17).
do $chk$
declare
  o_new constant uuid := '00000000-0000-0000-0000-0000000000c1';
  o_pct constant uuid := '00000000-0000-0000-0000-0000000000c4';
  r_a1 constant uuid := '00000000-0000-0000-0000-0000000000f1';
  r_a2 constant uuid := '00000000-0000-0000-0000-0000000000f2';
  r_b1 constant uuid := '00000000-0000-0000-0000-0000000000f3';
  v_item_a uuid;
  v_item_b uuid;
  v_item_pct uuid;
  v_row record;
  v_first timestamptz;
  v_n bigint;
  v_ids uuid[];
begin
  select id into v_item_a from public.order_items where order_id = o_new and store_id = 'chk_sa';
  select id into v_item_b from public.order_items where order_id = o_new and store_id = 'chk_sb';
  select id into v_item_pct from public.order_items where order_id = o_pct and store_id = 'chk_sa';

  insert into public.reports (id, order_id, store_id, reporter_id, title, description, attachment_paths, created_at)
  values
    (r_a1, o_new, 'chk_sa', 'chk_b1', 'Product Quality Issue', 'Right earbud not charging.',
     array['chk_sa/' || r_a1 || '/a.png'], now() - interval '2 days'),
    (r_a2, o_pct, 'chk_sa', 'chk_b1', '100% broken_', 'Arrived broken.', '{}', now() - interval '1 day'),
    (r_b1, o_new, 'chk_sb', 'chk_b1', 'Wrong size', 'Too small.', '{}', now());
  insert into public.report_items (report_id, order_item_id, order_id, store_id) values
    (r_a1, v_item_a, o_new, 'chk_sa'),
    (r_a2, v_item_pct, o_pct, 'chk_sa'),
    (r_b1, v_item_b, o_new, 'chk_sb');
  select report_number into v_n from public.reports where id = r_a1;

  -- ----------------------------------------------------------- AC-12 database rules
  perform pg_temp.expect('AC-12 an item of another store cannot join a report',
    pg_temp.try(format(
      'insert into public.report_items values (%L, %L, %L, %L)', r_a1, v_item_b, o_new, 'chk_sa')),
    'err:23503');
  perform pg_temp.expect('AC-12 an item of another order cannot join a report',
    pg_temp.try(format(
      'insert into public.report_items values (%L, %L, %L, %L)', r_a1, v_item_pct, o_new, 'chk_sa')),
    'err:23503');
  perform pg_temp.expect('AC-12 a report needs a store that sold in the order',
    pg_temp.try(format(
      $q$insert into public.reports (order_id, store_id, reporter_id, title, description)
         values (%L, 'chk_sb', 'chk_b1', 't', 'd')$q$, o_pct)),
    'err:23503');
  perform pg_temp.expect('AC-11 resolved_at is set exactly when the status is resolved',
    pg_temp.try(format($q$update public.reports set status = 'resolved' where id = %L$q$, r_a1)),
    'err:23514');
  perform pg_temp.expect('AC-11 an unsolved report has no resolved_at',
    pg_temp.try(format($q$update public.reports set resolved_at = now() where id = %L$q$, r_a1)),
    'err:23514');
  raise notice 'ok   AC-12 foreign keys and checks keep reports consistent';

  -- ----------------------------------------------------------- AC-8 summary
  perform pg_temp.act_as('chk_sa');
  select * into v_row from public.store_reports_summary();
  if v_row.total <> 2 or v_row.unresolved <> 2 or v_row.new_today <> 0 or v_row.returned_orders <> 0 then
    raise exception 'FAIL AC-8: seller A summary wrong: %', v_row;
  end if;
  reset role;
  perform pg_temp.act_as('chk_sb');
  select * into v_row from public.store_reports_summary();
  if v_row.total <> 1 or v_row.new_today <> 1 or v_row.unresolved <> 1 then
    raise exception 'FAIL AC-8: seller B summary wrong: %', v_row;
  end if;
  reset role;
  update public.store_orders set status = 'returned' where order_id = o_pct and store_id = 'chk_sa';
  perform pg_temp.act_as('chk_sa');
  select * into v_row from public.store_reports_summary();
  if v_row.returned_orders <> 1 then
    raise exception 'FAIL AC-8: returned orders count store orders with status returned, got %', v_row.returned_orders;
  end if;
  reset role;
  update public.store_orders set status = 'inProgress' where order_id = o_pct and store_id = 'chk_sa';
  raise notice 'ok   AC-8 summary counts own reports, today in Tunis time, unresolved and returned orders';

  -- ----------------------------------------------------------- AC-9 list
  perform pg_temp.act_as('chk_sa');
  select array_agg(id) into v_ids from public.store_reports_list();
  if v_ids <> array[r_a2, r_a1] then
    raise exception 'FAIL AC-9: seller A sees only their two reports newest first, got %', v_ids;
  end if;
  select * into v_row from public.store_reports_list() where id = r_a1;
  if v_row.title <> 'Product Quality Issue' or v_row.customer_name <> 'Test Buyer'
     or v_row.first_item_title <> 'Dress A' or v_row.item_count <> 1
     or v_row.status <> 'unsolved' or v_row.description <> 'Right earbud not charging.' then
    raise exception 'FAIL AC-9: report row wrong: %', v_row;
  end if;
  raise notice 'ok   AC-9 list is newest first, own store only, with the first product and item count';

  -- ----------------------------------------------------------- AC-4 search
  select array_agg(id) into v_ids
  from public.store_reports_list(p_search => '000' || v_n::text);
  if v_ids is distinct from array[r_a1] then
    raise exception 'FAIL AC-4: a report number typed with leading zeros must find it, got %', v_ids;
  end if;
  select array_agg(id) into v_ids from public.store_reports_list(p_search => '  QUALITY ');
  if v_ids is distinct from array[r_a1] then
    raise exception 'FAIL AC-4: a title search ignores case and spaces, got %', v_ids;
  end if;
  select array_agg(id) into v_ids from public.store_reports_list(p_search => 'test buyer');
  if v_ids is distinct from array[r_a1] then
    raise exception 'FAIL AC-4: a customer name search finds the report, got %', v_ids;
  end if;
  select array_agg(id) into v_ids from public.store_reports_list(p_search => '%');
  if v_ids is distinct from array[r_a2] then
    raise exception 'FAIL AC-4: %% is a plain character, got %', v_ids;
  end if;
  select array_agg(id) into v_ids from public.store_reports_list(p_search => 'zzz');
  if v_ids is not null then
    raise exception 'FAIL AC-4: no match gives no rows, got %', v_ids;
  end if;
  raise notice 'ok   AC-4 report search by number, title and customer, %% as plain text';

  -- ----------------------------------------------------------- AC-9 paging and filter
  select array_agg(id), min(created_at) into v_ids, v_first
  from public.store_reports_list(p_limit => 1);
  if v_ids <> array[r_a2] then
    raise exception 'FAIL AC-9: page one holds the newest report, got %', v_ids;
  end if;
  select array_agg(id) into v_ids
  from public.store_reports_list(p_limit => 1, p_cursor_created_at => v_first, p_cursor_id => r_a2);
  if v_ids <> array[r_a1] then
    raise exception 'FAIL AC-9: page two continues with the next report, got %', v_ids;
  end if;
  perform pg_temp.expect('AC-9 a cursor with one part is refused',
    pg_temp.try(format('select * from public.store_reports_list(p_cursor_id => %L)', r_a1)),
    'err:P0001:bad_cursor');
  perform pg_temp.expect('AC-9 an unknown status is refused',
    pg_temp.try($$select * from public.store_reports_list(p_status => 'done')$$),
    'err:P0001:bad_status');
  raise notice 'ok   AC-9 keyset paging and status validation';
  reset role;

  -- ----------------------------------------------------------- AC-10 detail
  perform pg_temp.act_as('chk_sa');
  select * into v_row from public.store_report_detail(r_a1);
  if v_row.customer_name <> 'Test Buyer' or v_row.customer_email <> 'buyer@example.com'
     or v_row.customer_phone <> '+21600000000'
     or jsonb_array_length(v_row.items) <> 1 or v_row.items -> 0 ->> 'title' <> 'Dress A'
     or v_row.attachment_paths <> array['chk_sa/' || r_a1 || '/a.png'] then
    raise exception 'FAIL AC-10: detail wrong: %', v_row;
  end if;
  if to_jsonb(v_row)::text like '%chk_b1%' then
    raise exception 'FAIL AC-12: the detail must not return the buyer account id';
  end if;
  raise notice 'ok   AC-10 detail returns contact, products and attachment paths, no buyer id';

  perform pg_temp.expect('AC-12 seller A cannot read seller B report detail',
    pg_temp.try(format('select * from public.store_report_detail(%L)', r_b1)), 'err:P0001:not_found');
  perform pg_temp.expect('AC-12 an unknown report id gives the same not_found',
    pg_temp.try($$select * from public.store_report_detail('00000000-0000-0000-0000-00000000ffff')$$),
    'err:P0001:not_found');
  perform pg_temp.expect('AC-12 seller A cannot resolve seller B report',
    pg_temp.try(format('select * from public.resolve_report(%L)', r_b1)), 'err:P0001:not_found');
  reset role;
  if (select status from public.reports where id = r_b1) <> 'unsolved' then
    raise exception 'FAIL AC-12: seller A must not change seller B report';
  end if;
  raise notice 'ok   AC-12 another store report gives not_found and stays unchanged';

  -- ----------------------------------------------------------- AC-11 resolve
  perform pg_temp.act_as('chk_sa');
  select * into v_row from public.resolve_report(r_a1);
  if v_row.status <> 'resolved' or v_row.resolved_at is null then
    raise exception 'FAIL AC-11: resolve must set resolved, got %', v_row;
  end if;
  v_first := v_row.resolved_at;
  reset role;

  -- A second session (another device) resolving again is a no op that succeeds.
  perform pg_temp.act_as('chk_sa');
  select * into v_row from public.resolve_report(r_a1);
  if v_row.status <> 'resolved' or v_row.resolved_at is distinct from v_first then
    raise exception 'FAIL AC-11: resolving twice must return the first answer, got %', v_row;
  end if;
  select * into v_row from public.store_reports_summary();
  if v_row.unresolved <> 1 then
    raise exception 'FAIL AC-11: the unresolved card follows the resolve, got %', v_row.unresolved;
  end if;
  select array_agg(id) into v_ids from public.store_reports_list(p_status => 'resolved');
  if v_ids <> array[r_a1] then
    raise exception 'FAIL AC-3: the resolved filter finds the resolved report, got %', v_ids;
  end if;
  reset role;
  raise notice 'ok   AC-11 resolve sets status and resolved_at once, a repeat is a no op';

  -- ----------------------------------------------------------- AC-12 rights
  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-12 a buyer gets not_seller (summary)',
    pg_temp.try('select * from public.store_reports_summary()'), 'err:P0001:not_seller');
  perform pg_temp.expect('AC-12 a buyer gets not_seller (list)',
    pg_temp.try('select * from public.store_reports_list()'), 'err:P0001:not_seller');
  perform pg_temp.expect('AC-12 a buyer gets not_seller (detail)',
    pg_temp.try(format('select * from public.store_report_detail(%L)', r_a1)), 'err:P0001:not_seller');
  perform pg_temp.expect('AC-12 a buyer gets not_seller (resolve)',
    pg_temp.try(format('select * from public.resolve_report(%L)', r_a1)), 'err:P0001:not_seller');
  reset role;

  perform pg_temp.act_as('chk_anon', true);
  perform pg_temp.expect('AC-12 an anonymous session gets no_session',
    pg_temp.try('select * from public.store_reports_list()'), 'err:P0001:no_session');
  perform pg_temp.expect('AC-12 an anonymous session cannot resolve',
    pg_temp.try(format('select * from public.resolve_report(%L)', r_a2)), 'err:P0001:no_session');
  reset role;

  set local role anon;
  perform pg_temp.expect('AC-12 the anon role is refused by Postgres (list)',
    pg_temp.try('select * from public.store_reports_list()'), 'err:42501');
  perform pg_temp.expect('AC-12 the anon role is refused by Postgres (resolve)',
    pg_temp.try(format('select * from public.resolve_report(%L)', r_a2)), 'err:42501');
  reset role;

  perform pg_temp.act_as('chk_sa');
  perform pg_temp.expect('AC-12 no client reads reports directly',
    pg_temp.try('select * from public.reports'), 'err:42501');
  perform pg_temp.expect('AC-12 no client reads report_items directly',
    pg_temp.try('select * from public.report_items'), 'err:42501');
  perform pg_temp.expect('AC-17 no client creates a report',
    pg_temp.try($$insert into public.reports (order_id, store_id, reporter_id, title, description)
                  values (gen_random_uuid(), 'chk_sa', 'x', 't', 'd')$$), 'err:42501');
  perform pg_temp.expect('AC-17 no client writes a report status directly',
    pg_temp.try($$update public.reports set status = 'resolved', resolved_at = now()$$), 'err:42501');
  reset role;
  raise notice 'ok   AC-12 buyer, anonymous, anon role and direct table access are all refused';

  -- ----------------------------------------------------------- AC-10 attachments
  insert into storage.objects (bucket_id, name, owner_id)
  values ('report-attachments', 'chk_sa/' || r_a1 || '/a.png', 'chk_b1'),
         ('report-attachments', 'chk_sb/' || r_b1 || '/b.png', 'chk_b1');
  perform pg_temp.act_as('chk_sa');
  if (select count(*) from storage.objects where bucket_id = 'report-attachments') <> 1
     or not exists (
       select 1 from storage.objects
       where bucket_id = 'report-attachments' and name = 'chk_sa/' || r_a1 || '/a.png') then
    raise exception 'FAIL AC-10: a seller reads only their own attachment folder';
  end if;
  reset role;
  perform pg_temp.act_as('chk_b1');
  if exists (select 1 from storage.objects where bucket_id = 'report-attachments') then
    raise exception 'FAIL AC-12: a buyer must not read report attachments';
  end if;
  reset role;
  raise notice 'ok   AC-10 a seller reads only their own attachment folder, a buyer none';
end;
$chk$;

rollback;
