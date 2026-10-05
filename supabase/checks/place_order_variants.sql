-- Decision record: docs/specs/_root/0015-seller-product-creation/index.md (build plan task 9)
--
-- SQL checks for orders that use variants: AC-10 and AC-19. Run the whole file
-- in the SQL editor of a TEST or BRANCH database (or with psql) after applying
-- migrations 0008 and 0009. It creates its own fixtures, acts as buyers with a
-- fake JWT, and ends with `rollback`, so it leaves no rows behind.
--
-- Output: one NOTICE per check. A failed check raises an error that starts with
-- FAIL and stops the script. A race between two sessions at the same moment is
-- not covered by one script; see the manual checks in the spec.

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

-- Calls place_order with valid contact details and standard delivery.
create function pg_temp.order_sql(p_id uuid, p_subtotal numeric) returns text
language sql as $$
  select format(
    $q$select public.place_order(%L, 'Test Buyer', 'buyer@example.com', '+21600000000',
       'Sousse', '1 Rue Test', '4000', '', 'standard', 'cashOnDelivery', %s)$q$,
    p_id, p_subtotal)
$$;

-- Fixtures, created as the table owner.
insert into public.user_profiles (id, name, username, role, currency) values
  ('chk_seller', 'Chk Seller', 'chk_seller', 'seller', 'TND'),
  ('chk_b1', 'Chk Buyer 1', 'chk_b1', 'buyer', 'TND'),
  ('chk_b2', 'Chk Buyer 2', 'chk_b2', 'buyer', 'TND');

insert into public.products (id, title, description, price, category, store_id, store_name, currency)
values
  ('00000000-0000-0000-0000-0000000000a1', 'Dress', 'd', 80.125, 'Fashion', 'chk_seller', 'S', 'TND'),
  ('00000000-0000-0000-0000-0000000000a2', 'Dollar item', 'd', 10, 'Tech', 'chk_seller', 'S', 'USD'),
  ('00000000-0000-0000-0000-0000000000a3', 'Old item', 'd', 20, 'Tech', 'chk_seller', 'S', 'TND');

update public.products set status = 'archived' where id = '00000000-0000-0000-0000-0000000000a3';

insert into public.product_variants (id, product_id, color_value, size, price, stock) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 1, 'S', 80.125, 3),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a1', 1, 'M', 95.500, 1),
  ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000a2', null, null, 10, 5),
  ('00000000-0000-0000-0000-0000000000b4', '00000000-0000-0000-0000-0000000000a3', null, null, 20, 5);

do $$
declare
  p_dress constant uuid := '00000000-0000-0000-0000-0000000000a1';
  p_usd constant uuid := '00000000-0000-0000-0000-0000000000a2';
  p_old constant uuid := '00000000-0000-0000-0000-0000000000a3';
  v_s constant uuid := '00000000-0000-0000-0000-0000000000b1';
  v_m constant uuid := '00000000-0000-0000-0000-0000000000b2';
  o1 constant uuid := '00000000-0000-0000-0000-0000000000c1';
  o2 constant uuid := '00000000-0000-0000-0000-0000000000c2';
  o3 constant uuid := '00000000-0000-0000-0000-0000000000c3';
  o4 constant uuid := '00000000-0000-0000-0000-0000000000c4';
  o5 constant uuid := '00000000-0000-0000-0000-0000000000c5';
  v_seed record;
begin
  -- ----------------------------------------------------------- AC-19 price
  insert into public.cart_items (user_id, product_id, quantity, selected_size, selected_color)
  values ('chk_b1', p_dress, 1, 'M', 1);

  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-19 the product price is not the variant price: price_changed',
    pg_temp.try(pg_temp.order_sql(o1, 80.125)), 'err:P0001:price_changed');
  reset role;
  if not exists (select 1 from public.cart_items where user_id = 'chk_b1') then
    raise exception 'FAIL AC-10: a refused order must leave the cart untouched';
  end if;
  if (select stock from public.product_variants where id = v_m) <> 1 then
    raise exception 'FAIL AC-10: a refused order must leave stock untouched';
  end if;
  raise notice 'ok   AC-10 a refused order leaves the cart and the stock alone';

  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-19 the order uses the variant price with 3 decimals',
    pg_temp.try(pg_temp.order_sql(o1, 95.500)), 'ok:1');
  reset role;
  if (select unit_price from public.order_items where order_id = o1) <> 95.500
     or (select subtotal from public.orders where id = o1) <> 95.500
     or (select currency from public.orders where id = o1) <> 'TND' then
    raise exception 'FAIL AC-19: order should hold the variant price and TND';
  end if;
  raise notice 'ok   AC-19 order item, subtotal and currency come from the variant';

  -- ----------------------------------------------------------- AC-10 stock
  if (select stock from public.product_variants where id = v_m) <> 0 then
    raise exception 'FAIL AC-10: the ordered unit should be taken off the stock';
  end if;
  if exists (select 1 from public.cart_items where user_id = 'chk_b1') then
    raise exception 'FAIL AC-10: the cart should be emptied by the order';
  end if;
  raise notice 'ok   AC-10 stock goes down and the cart is cleared';

  insert into public.cart_items (user_id, product_id, quantity, selected_size, selected_color)
  values ('chk_b2', p_dress, 1, 'M', 1);
  perform pg_temp.act_as('chk_b2');
  perform pg_temp.expect('AC-10 the last unit is gone: the second buyer gets out_of_stock',
    pg_temp.try(pg_temp.order_sql(o2, 95.500)), 'err:P0001:out_of_stock:' || p_dress);
  reset role;
  if not exists (select 1 from public.cart_items where user_id = 'chk_b2') then
    raise exception 'FAIL AC-10: the cart should stay after out_of_stock';
  end if;
  raise notice 'ok   AC-10 out_of_stock keeps the cart';

  -- Replaying a finished order changes nothing.
  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-10 replaying a finished order returns it',
    pg_temp.try(pg_temp.order_sql(o1, 95.500)), 'ok:1');
  reset role;
  if (select stock from public.product_variants where id = v_m) <> 0
     or (select count(*) from public.orders where id = o1) <> 1 then
    raise exception 'FAIL AC-10: a replay must not take stock again or make a second order';
  end if;
  raise notice 'ok   AC-10 a replay takes no second unit';

  -- The same variant on two lines is added up, not checked line by line.
  delete from public.cart_items where user_id = 'chk_b2';
  insert into public.cart_items (user_id, product_id, quantity, selected_size, selected_color) values
    ('chk_b2', p_dress, 2, 'S', 1),
    ('chk_b2', p_dress, 2, 'S', 1);
  perform pg_temp.act_as('chk_b2');
  perform pg_temp.expect('AC-10 two lines of the same variant are added up (4 asked, 3 left)',
    pg_temp.try(pg_temp.order_sql(o3, 320.500)), 'err:P0001:out_of_stock:' || p_dress);
  reset role;
  if (select stock from public.product_variants where id = v_s) <> 3 then
    raise exception 'FAIL AC-10: stock should be untouched after the refusal';
  end if;

  delete from public.cart_items where user_id = 'chk_b2';
  insert into public.cart_items (user_id, product_id, quantity, selected_size, selected_color) values
    ('chk_b2', p_dress, 2, 'S', 1),
    ('chk_b2', p_dress, 1, 'S', 1);
  perform pg_temp.act_as('chk_b2');
  perform pg_temp.expect('AC-10 two lines that fit together are ordered (2 + 1 of 3)',
    pg_temp.try(pg_temp.order_sql(o3, 240.375)), 'ok:1');
  reset role;
  if (select stock from public.product_variants where id = v_s) <> 0 then
    raise exception 'FAIL AC-10: both lines should be taken off the stock';
  end if;
  raise notice 'ok   AC-10 stock for several lines is taken off in total';

  -- ------------------------------------------------ unavailable lines
  insert into public.cart_items (user_id, product_id, quantity, selected_size, selected_color)
  values ('chk_b1', p_dress, 1, 'XL', 1);
  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-10 a size with no variant is product_unavailable',
    pg_temp.try(pg_temp.order_sql(o4, 80.125)), 'err:P0001:product_unavailable');
  reset role;

  delete from public.cart_items where user_id = 'chk_b1';
  insert into public.cart_items (user_id, product_id, quantity) values ('chk_b1', p_old, 1);
  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-10 an archived product is product_unavailable even if a cart row points at it',
    pg_temp.try(pg_temp.order_sql(o4, 20)), 'err:P0001:product_unavailable');
  reset role;

  -- ----------------------------------------------------------- currency
  delete from public.cart_items where user_id = 'chk_b1';
  update public.product_variants set stock = 5 where id = v_s;
  insert into public.cart_items (user_id, product_id, quantity, selected_size, selected_color) values
    ('chk_b1', p_dress, 1, 'S', 1),
    ('chk_b1', p_usd, 1, null, null);
  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-19 a cart with two currencies is refused',
    pg_temp.try(pg_temp.order_sql(o4, 90.125)), 'err:P0001:mixed_currency');
  reset role;

  -- ----------------------------------------------------------- empty cart
  perform pg_temp.act_as('chk_nobody');
  perform pg_temp.expect('AC-10 an empty cart is cart_empty and takes no stock',
    pg_temp.try(pg_temp.order_sql(o5, 1)), 'err:P0001:cart_empty');
  reset role;

  -- ----------------------------------------------------------- seeded data
  -- A product that was in the catalog before 0008 has generated variants and
  -- can be ordered by the size and color of its old cart lines.
  select p.id, p.price, v.color_value, v.size, v.id as variant_id, v.stock
  into v_seed
  from public.products p
  join public.product_variants v on v.product_id = p.id
  where p.store_id not like 'chk\_%' and p.status = 'live' and v.stock > 0
  order by p.id, v.position
  limit 1;
  delete from public.cart_items where user_id = 'chk_b2';
  insert into public.cart_items (user_id, product_id, quantity, selected_size, selected_color)
  values ('chk_b2', v_seed.id, 1, v_seed.size, v_seed.color_value);
  perform pg_temp.act_as('chk_b2');
  perform pg_temp.expect('AC-10 a seeded product can still be ordered',
    pg_temp.try(pg_temp.order_sql('00000000-0000-0000-0000-0000000000c6', v_seed.price)), 'ok:1');
  reset role;
  if (select stock from public.product_variants where id = v_seed.variant_id) <> v_seed.stock - 1 then
    raise exception 'FAIL AC-10: a seeded product should lose one unit';
  end if;
  raise notice 'ok   AC-10 seeded products work with their generated variants';

  raise notice 'ALL CHECKS PASSED';
end;
$$;

rollback;
