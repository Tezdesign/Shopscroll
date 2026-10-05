-- Decision record: docs/specs/_root/0015-seller-product-creation/index.md (build plan task 1)
--
-- SQL checks for seller product creation: AC-1, AC-2, AC-4, AC-5, AC-6, AC-7,
-- AC-11, AC-12 and AC-16. Run the whole file in the SQL editor of a TEST or
-- BRANCH database (or with psql) after applying migration 0008. It creates its
-- own fixtures, switches to the `authenticated` or `anon` role with a fake JWT
-- to act as each user, and ends with `rollback`, so it leaves no rows behind.
-- Do not run it against live data you care about without reading it first.
--
-- Output: one NOTICE per check. A failed check raises an error that starts with
-- FAIL and stops the script. What this file cannot check (the Storage API size
-- and type limits) is in the manual checks of the spec.

begin;

-- Runs one statement as the current role and reports the outcome as
-- 'ok:<rows>' or 'err:<sqlstate>:<message>' (42501 is permission denied or a
-- row level security violation). An update or delete that row level security
-- filters out is not an error, it is 'ok:0'.
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

create function pg_temp.act_as_visitor() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{}', true);
  execute 'set local role anon';
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

-- A payload with sensible defaults, overridden key by key with p_over.
-- p_folder is the id used in the photo paths.
create function pg_temp.payload(p_owner text, p_folder uuid, p_over jsonb default '{}')
returns jsonb language sql as $$
  select jsonb_build_object(
    'title', 'Wrap dress',
    'description', 'A soft dress.',
    'category', 'Fashion',
    'attributes', jsonb_build_object('material', '100% polyester'),
    'photos', jsonb_build_array(p_owner || '/' || p_folder || '/a.jpg', p_owner || '/' || p_folder || '/b.jpg'),
    'variants', jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'colorName', 'Burgundy', 'colorValue', 4288230400,
        'size', 'S', 'price', '89.000', 'stock', 4, 'imagePath', p_owner || '/' || p_folder || '/a.jpg'),
      jsonb_build_object('id', gen_random_uuid(), 'colorName', 'Black', 'colorValue', 4278190080,
        'size', 'M', 'price', '95.500', 'stock', 6)
    )
  ) || p_over
$$;

-- Fixtures, created as the table owner.
insert into public.user_profiles (id, name, username, role, avatar_url, currency) values
  ('chk_s1', 'Chk Store One', 'chk_s1', 'seller', 'https://example.com/a.png', 'TND'),
  ('chk_s2', 'Chk Store Two', 'chk_s2', 'seller', null, 'TND'),
  ('chk_b', 'Chk Buyer', 'chk_b', 'buyer', null, 'TND');

insert into storage.objects (bucket_id, name) values
  ('product-images', 'chk_s1/00000000-0000-0000-0000-0000000000d1/a.jpg'),
  ('product-images', 'chk_s1/00000000-0000-0000-0000-0000000000d1/b.jpg'),
  ('product-images', 'chk_s1/00000000-0000-0000-0000-0000000000d2/a.jpg'),
  ('product-images', 'chk_s1/00000000-0000-0000-0000-0000000000d2/b.jpg'),
  ('product-images', 'chk_s2/00000000-0000-0000-0000-0000000000e1/a.jpg');

do $$
declare
  d1 constant uuid := '00000000-0000-0000-0000-0000000000d1';
  d2 constant uuid := '00000000-0000-0000-0000-0000000000d2';
  e1 constant uuid := '00000000-0000-0000-0000-0000000000e1';
  v_pid uuid;
  v_text text;
  v_row public.products;
  v_var uuid;
  v_edit uuid := '00000000-0000-0000-0000-0000000000d3';
  v_vid1 uuid := gen_random_uuid();
  v_vid2 uuid := gen_random_uuid();
  v_seed_without integer;
  v_big jsonb;
begin
  -- ---------------------------------------------------------------- Backfill
  select count(*) into v_seed_without
  from public.products p
  where p.store_id not like 'chk\_%'
    and not exists (select 1 from public.product_variants v where v.product_id = p.id);
  if v_seed_without <> 0 then
    raise exception 'FAIL AC-10 backfill: % seed products have no variant', v_seed_without;
  end if;
  if exists (select 1 from public.products where currency <> 'TND' or status <> 'live') then
    raise exception 'FAIL AC-9 backfill: a seed product is not live TND';
  end if;
  raise notice 'ok   AC-9 every seed product is live, TND, and has variants';

  -- ---------------------------------------------------------------- AC-16 direct writes
  perform pg_temp.act_as('chk_s1');
  perform pg_temp.expect('AC-16 seller cannot insert into products directly',
    pg_temp.try($q$insert into public.products (title, description, price, category, store_id, store_name)
      values ('x', 'd', 1, 'Fashion', 'chk_s1', 'S')$q$), 'err:42501');
  perform pg_temp.expect('AC-16 seller cannot update a product directly',
    pg_temp.try($q$update public.products set title = 'x' where store_id = 'chk_s1'$q$), 'err:42501');
  perform pg_temp.expect('AC-16 seller cannot write product_variants directly',
    pg_temp.try($q$insert into public.product_variants (product_id, price) values (gen_random_uuid(), 1)$q$), 'err:42501');
  reset role;

  -- ---------------------------------------------------------------- AC-6 drafts
  perform pg_temp.act_as('chk_s1');
  perform pg_temp.expect('AC-6 seller creates own draft',
    pg_temp.try(format($q$insert into public.product_drafts (id, store_id, step, payload)
      values (%L, 'chk_s1', 1, %L)$q$, d1, pg_temp.payload('chk_s1', d1))), 'ok:1');
  perform pg_temp.expect('AC-6 seller autosaves the draft and its step',
    pg_temp.try(format($q$update public.product_drafts set step = 2, payload = %L where id = %L$q$,
      pg_temp.payload('chk_s1', d1), d1)), 'ok:1');
  perform pg_temp.expect('AC-16 seller cannot create a draft for another store',
    pg_temp.try(format($q$insert into public.product_drafts (id, store_id) values (%L, 'chk_s2')$q$, gen_random_uuid())), 'err:42501');
  perform pg_temp.expect('AC-16 seller cannot move a draft to another store',
    pg_temp.try(format($q$update public.product_drafts set store_id = 'chk_s2' where id = %L$q$, d1)), 'err:42501');
  perform pg_temp.expect('AC-6 a draft over 200 KB is refused',
    pg_temp.try(format($q$update public.product_drafts set payload = jsonb_build_object('x', repeat('a', 300000)) where id = %L$q$, d1)), 'err:23514');
  reset role;

  perform pg_temp.act_as('chk_s2');
  perform pg_temp.expect('AC-16 another seller sees none of it',
    pg_temp.try('select 1 from public.product_drafts where id = ''' || d1 || ''''), 'ok:0');
  perform pg_temp.expect('AC-16 another seller cannot delete it',
    pg_temp.try('delete from public.product_drafts where id = ''' || d1 || ''''), 'ok:0');
  reset role;

  perform pg_temp.act_as('chk_b');
  perform pg_temp.expect('AC-1 a buyer cannot create a draft',
    pg_temp.try(format($q$insert into public.product_drafts (id, store_id) values (%L, 'chk_b')$q$, gen_random_uuid())), 'err:42501');
  reset role;

  perform pg_temp.act_as('chk_s1', true);
  perform pg_temp.expect('AC-1 an anonymous session cannot create a draft',
    pg_temp.try(format($q$insert into public.product_drafts (id, store_id) values (%L, 'chk_s1')$q$, gen_random_uuid())), 'err:42501');
  reset role;

  -- ---------------------------------------------------------------- AC-1 who may call
  perform pg_temp.act_as('chk_b');
  perform pg_temp.expect('AC-1 buyer cannot call save_product',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:not_seller');
  reset role;
  perform pg_temp.act_as('chk_s1', true);
  perform pg_temp.expect('AC-1 anonymous session cannot call save_product',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:no_session');
  reset role;
  perform pg_temp.act_as_visitor();
  perform pg_temp.expect('AC-1 a visitor has no execute right on save_product',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'err:42501');
  reset role;

  perform pg_temp.act_as('chk_s2');
  perform pg_temp.expect('AC-16 another seller cannot save my draft',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:not_found');
  reset role;

  -- ---------------------------------------------------------------- AC-7 refusals
  perform pg_temp.act_as('chk_s1');

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, '{"title":"x"}') where id = d1;
  perform pg_temp.expect('AC-7 title too short', pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:bad_title');

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, '{"category":"Nope"}') where id = d1;
  perform pg_temp.expect('AC-7 category not in the list', pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:bad_category');

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, '{"photos":[]}') where id = d1;
  perform pg_temp.expect('AC-7 no photo', pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:no_photo');

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, '{"photos":["chk_s1/00000000-0000-0000-0000-0000000000d1/a.jpg","chk_s1/00000000-0000-0000-0000-0000000000d1/a.jpg","chk_s1/00000000-0000-0000-0000-0000000000d1/a.jpg","chk_s1/00000000-0000-0000-0000-0000000000d1/a.jpg","chk_s1/00000000-0000-0000-0000-0000000000d1/a.jpg","chk_s1/00000000-0000-0000-0000-0000000000d1/a.jpg","chk_s1/00000000-0000-0000-0000-0000000000d1/a.jpg","chk_s1/00000000-0000-0000-0000-0000000000d1/a.jpg","chk_s1/00000000-0000-0000-0000-0000000000d1/a.jpg"]}') where id = d1;
  perform pg_temp.expect('AC-5 nine photos is too many', pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:too_many_photos');

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, jsonb_build_object('photos', jsonb_build_array('chk_s2/' || e1 || '/a.jpg'))) where id = d1;
  perform pg_temp.expect('AC-5 a photo in another seller''s folder is refused', pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:bad_photo_path');

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, jsonb_build_object('photos', jsonb_build_array('chk_s1/' || d1 || '/never_uploaded.jpg'))) where id = d1;
  perform pg_temp.expect('AC-5 a photo that was never uploaded is refused', pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:bad_photo_path');

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, jsonb_build_object('photos', jsonb_build_array('chk_s1/' || d1 || '/../' || d2 || '/a.jpg'))) where id = d1;
  perform pg_temp.expect('AC-5 a path with .. is refused', pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:bad_photo_path');

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, '{"variants":[]}') where id = d1;
  perform pg_temp.expect('AC-4 no variants', pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:no_variants');

  v_var := gen_random_uuid();
  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, jsonb_build_object('variants', jsonb_build_array(
    jsonb_build_object('id', v_var, 'size', 'S', 'stock', 1)))) where id = d1;
  perform pg_temp.expect('AC-7 variant with no price names the variant',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:missing_price:' || v_var);

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, jsonb_build_object('variants', jsonb_build_array(
    jsonb_build_object('id', v_var, 'size', 'S', 'price', '10.0001', 'stock', 1)))) where id = d1;
  perform pg_temp.expect('AC-9 a price with 4 decimals is refused',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:missing_price:' || v_var);

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, jsonb_build_object('variants', jsonb_build_array(
    jsonb_build_object('id', v_var, 'size', 'S', 'price', '0', 'stock', 1)))) where id = d1;
  perform pg_temp.expect('AC-7 a price of 0 is refused',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:missing_price:' || v_var);

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, jsonb_build_object('variants', jsonb_build_array(
    jsonb_build_object('id', v_var, 'size', 'S', 'price', '10', 'stock', -1)))) where id = d1;
  perform pg_temp.expect('AC-7 negative stock is refused',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:bad_stock:' || v_var);

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, jsonb_build_object('variants', jsonb_build_array(
    jsonb_build_object('id', v_var, 'size', 'S', 'price', '10', 'stock', 1.5)))) where id = d1;
  perform pg_temp.expect('AC-7 stock that is not a whole number is refused',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:bad_stock:' || v_var);

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, jsonb_build_object('variants', jsonb_build_array(
    jsonb_build_object('id', gen_random_uuid(), 'colorValue', 1, 'size', 'S', 'price', '10', 'stock', 1),
    jsonb_build_object('id', gen_random_uuid(), 'colorValue', 1, 'size', 'S', 'price', '11', 'stock', 2)))) where id = d1;
  perform pg_temp.expect('AC-4 two rows with the same color and size are refused',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:duplicate_variant');

  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'size', 'S' || n, 'price', '10', 'stock', 1))
  into v_big from generate_series(1, 101) n;
  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, jsonb_build_object('variants', v_big)) where id = d1;
  perform pg_temp.expect('AC-4 101 variants is too many',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:too_many_variants');

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, jsonb_build_object('variants', jsonb_build_array(
    jsonb_build_object('id', gen_random_uuid(), 'size', 'S', 'price', '10', 'stock', 1, 'imagePath', 'chk_s1/' || d1 || '/other.jpg')))) where id = d1;
  perform pg_temp.expect('AC-5 a variant photo that is not one of the product photos is refused',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:bad_photo_path');

  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1, '{"attributes":{"material":5}}') where id = d1;
  perform pg_temp.expect('AC-3 attributes must be text values',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'err:P0001:bad_attributes');

  -- Nothing reached the catalog and the draft is untouched.
  reset role;
  if exists (select 1 from public.products where id = d1) or not exists (select 1 from public.product_drafts where id = d1) then
    raise exception 'FAIL AC-7: a refused save changed the catalog or lost the draft';
  end if;
  raise notice 'ok   AC-7 refused saves left the catalog and the draft untouched';

  -- ---------------------------------------------------------------- AC-2, AC-7 happy path
  update public.product_drafts set payload = pg_temp.payload('chk_s1', d1) where id = d1;
  perform pg_temp.act_as('chk_s1');
  select public.save_product(d1) into v_pid;
  reset role;
  if v_pid <> d1 then raise exception 'FAIL AC-7: expected the product id to equal the draft id'; end if;
  select * into v_row from public.products where id = d1;
  if v_row.status <> 'live' or v_row.currency <> 'TND' or v_row.store_name <> 'Chk Store One'
     or v_row.price <> 89.000 or v_row.in_stock is not true
     or v_row.image_url <> 'product-images/chk_s1/' || d1 || '/a.jpg'
     or cardinality(v_row.image_urls) <> 2
     or v_row.color_options <> array[4288230400, 4278190080]::bigint[]
     or v_row.sizes <> array['S', 'M']
     or v_row.attributes ->> 'material' <> '100% polyester' then
    raise exception 'FAIL AC-2: saved product looks wrong: %', v_row;
  end if;
  if (select count(*) from public.product_variants where product_id = d1) <> 2
     or exists (select 1 from public.product_drafts where id = d1) then
    raise exception 'FAIL AC-7: expected 2 variants and the draft removed';
  end if;
  raise notice 'ok   AC-2 AC-7 AC-9 save_product publishes: live, TND, lowest variant price, photos, colors, sizes, draft removed';

  perform pg_temp.act_as('chk_s1');
  perform pg_temp.expect('AC-7 saving again returns the same product and changes nothing',
    pg_temp.try(format('select public.save_product(%L)', d1)), 'ok:1');
  reset role;

  -- ---------------------------------------------------------------- AC-16 reading
  perform pg_temp.act_as_visitor();
  perform pg_temp.expect('AC-16 a visitor sees the live product',
    pg_temp.try(format('select 1 from public.products where id = %L', d1)), 'ok:1');
  perform pg_temp.expect('AC-16 a visitor sees its variants',
    pg_temp.try(format('select 1 from public.product_variants where product_id = %L', d1)), 'ok:2');
  perform pg_temp.expect('AC-16 a visitor reads the category list',
    pg_temp.try('select 1 from public.product_categories'), 'ok:4');
  reset role;

  -- ---------------------------------------------------------------- AC-11 archive, delete, quick edit
  perform pg_temp.act_as('chk_s2');
  perform pg_temp.expect('AC-16 another seller cannot archive it',
    pg_temp.try(format('select public.set_product_archived(%L, true)', d1)), 'err:P0001:not_found');
  reset role;

  perform pg_temp.act_as('chk_s1');
  perform pg_temp.expect('AC-11 a live product cannot be deleted',
    pg_temp.try(format('delete from public.products where id = %L', d1)), 'ok:0');
  perform pg_temp.expect('AC-11 seller archives it',
    pg_temp.try(format('select public.set_product_archived(%L, true)', d1)), 'ok:1');
  perform pg_temp.expect('AC-11 archiving twice is safe',
    pg_temp.try(format('select public.set_product_archived(%L, true)', d1)), 'ok:1');
  perform pg_temp.expect('AC-16 the owner still sees the archived product',
    pg_temp.try(format('select 1 from public.products where id = %L', d1)), 'ok:1');
  reset role;

  perform pg_temp.act_as_visitor();
  perform pg_temp.expect('AC-16 a visitor no longer sees the archived product',
    pg_temp.try(format('select 1 from public.products where id = %L', d1)), 'ok:0');
  perform pg_temp.expect('AC-16 nor its variants',
    pg_temp.try(format('select 1 from public.product_variants where product_id = %L', d1)), 'ok:0');
  reset role;

  perform pg_temp.act_as('chk_s1');
  perform pg_temp.expect('AC-11 seller restores it',
    pg_temp.try(format('select public.set_product_archived(%L, false)', d1)), 'ok:1');
  reset role;
  if (select status from public.products where id = d1) <> 'live' then
    raise exception 'FAIL AC-11: restore did not make the product live';
  end if;
  raise notice 'ok   AC-11 archive and restore change the status';

  select id into v_var from public.product_variants where product_id = d1 order by position limit 1;

  perform pg_temp.act_as('chk_s2');
  perform pg_temp.expect('AC-16 another seller cannot quick edit it',
    pg_temp.try(format('select public.update_variant_quick(%L, 5, 5)', v_var)), 'err:P0001:not_found');
  reset role;

  perform pg_temp.act_as('chk_s1');
  perform pg_temp.expect('AC-11 quick edit changes price and stock',
    pg_temp.try(format('select public.update_variant_quick(%L, 70.250, 9)', v_var)), 'ok:1');
  perform pg_temp.expect('AC-11 quick edit refuses a price of 0',
    pg_temp.try(format('select public.update_variant_quick(%L, 0, 9)', v_var)), 'err:P0001:missing_price');
  perform pg_temp.expect('AC-11 quick edit refuses negative stock',
    pg_temp.try(format('select public.update_variant_quick(%L, 10, -1)', v_var)), 'err:P0001:bad_stock');
  reset role;
  if (select price from public.products where id = d1) <> 70.250 then
    raise exception 'FAIL AC-11: product price should follow the lowest variant price';
  end if;
  raise notice 'ok   AC-11 products.price follows the lowest variant price';

  -- in_stock follows stock.
  update public.product_variants set stock = 0 where product_id = d1;
  if (select in_stock from public.products where id = d1) then
    raise exception 'FAIL AC-10: in_stock should be false when every variant has 0 stock';
  end if;
  update public.product_variants set stock = 3 where id = v_var;
  if not (select in_stock from public.products where id = d1) then
    raise exception 'FAIL AC-10: in_stock should be true when a variant has stock';
  end if;
  raise notice 'ok   AC-10 in_stock follows variant stock';

  -- ---------------------------------------------------------------- AC-12 editing a live product
  perform pg_temp.act_as('chk_s1');
  perform pg_temp.expect('AC-12 seller opens a working copy of a live product',
    pg_temp.try(format($q$insert into public.product_drafts (id, store_id, source_product_id, step, payload)
      values (%L, 'chk_s1', %L, 3, %L)$q$, v_edit, d1,
      pg_temp.payload('chk_s1', d1, jsonb_build_object(
        'title', 'Renamed dress',
        'variants', jsonb_build_array(
          jsonb_build_object('id', v_var, 'colorValue', 4288230400, 'size', 'S', 'price', '80.000', 'stock', 100),
          jsonb_build_object('id', v_vid2, 'size', 'XL', 'price', '99.000', 'stock', 7, 'stockSet', true)))))), 'ok:1');
  select public.save_product(v_edit) into v_pid;
  reset role;
  select * into v_row from public.products where id = d1;
  if v_pid <> d1 or v_row.title <> 'Renamed dress' or v_row.price <> 80.000 then
    raise exception 'FAIL AC-12: edit did not update the product: %', v_row;
  end if;
  -- The variant that was not marked stockSet keeps its real stock (3), not the draft's 100.
  if (select stock from public.product_variants where id = v_var) <> 3 then
    raise exception 'FAIL AC-12: a variant not marked stockSet had its stock overwritten';
  end if;
  if (select stock from public.product_variants where id = v_vid2) <> 7 then
    raise exception 'FAIL AC-12: a new variant should keep the stock from the draft';
  end if;
  if (select count(*) from public.product_variants where product_id = d1) <> 2 then
    raise exception 'FAIL AC-12: the removed variant should be gone';
  end if;
  if exists (select 1 from public.product_drafts where id = v_edit) then
    raise exception 'FAIL AC-12: the working copy should be deleted after saving';
  end if;
  raise notice 'ok   AC-12 editing a live product replaces its fields and variants in one step, keeps real stock';

  -- A variant id that belongs to another product is refused.
  perform pg_temp.act_as('chk_s1');
  insert into public.product_drafts (id, store_id, payload)
  values (d2, 'chk_s1', pg_temp.payload('chk_s1', d2, jsonb_build_object('variants', jsonb_build_array(
    jsonb_build_object('id', v_var, 'size', 'S', 'price', '10', 'stock', 1)))));
  perform pg_temp.expect('AC-16 a variant id from another product is refused',
    pg_temp.try(format('select public.save_product(%L)', d2)), 'err:P0001:bad_variant');
  reset role;

  -- ---------------------------------------------------------------- AC-11 delete
  perform pg_temp.act_as('chk_s1');
  perform pg_temp.expect('AC-11 seller archives to be able to delete',
    pg_temp.try(format('select public.set_product_archived(%L, true)', d1)), 'ok:1');
  perform pg_temp.expect('AC-11 an archived product can be deleted',
    pg_temp.try(format('delete from public.products where id = %L', d1)), 'ok:1');
  reset role;
  if exists (select 1 from public.product_variants where product_id = d1) then
    raise exception 'FAIL AC-11: variants should go with the product';
  end if;
  raise notice 'ok   AC-11 deleting a product removes its variants';

  -- ---------------------------------------------------------------- AC-5 / AC-16 storage
  perform pg_temp.act_as('chk_s1');
  perform pg_temp.expect('AC-5 seller adds a photo in own folder',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('product-images', 'chk_s1/abc/new.jpg')$q$), 'ok:1');
  perform pg_temp.expect('AC-16 seller cannot add a photo in another seller''s folder',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('product-images', 'chk_s2/abc/new.jpg')$q$), 'err:42501');
  perform pg_temp.expect('AC-5 seller removes own photo',
    pg_temp.try($q$delete from storage.objects where bucket_id = 'product-images' and name = 'chk_s1/abc/new.jpg'$q$), 'ok:1');
  perform pg_temp.expect('AC-16 seller cannot remove another seller''s photo',
    pg_temp.try(format($q$delete from storage.objects where bucket_id = 'product-images' and name = 'chk_s2/%s/a.jpg'$q$, e1)), 'ok:0');
  reset role;
  perform pg_temp.act_as('chk_b');
  perform pg_temp.expect('AC-1 a buyer cannot add a product photo',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('product-images', 'chk_b/abc/new.jpg')$q$), 'err:42501');
  reset role;
  perform pg_temp.act_as('chk_s1', true);
  perform pg_temp.expect('AC-1 an anonymous session cannot add a product photo',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('product-images', 'chk_s1/abc/new.jpg')$q$), 'err:42501');
  reset role;

  select 'product-images ' || public || ' ' || file_size_limit || ' ' || allowed_mime_types::text
  into v_text from storage.buckets where id = 'product-images';
  if v_text <> 'product-images true 2097152 {image/jpeg}' then
    raise exception 'FAIL AC-5: bucket settings are %', v_text;
  end if;
  raise notice 'ok   AC-5 bucket is public, 2 MB, JPEG only';

  raise notice 'ALL CHECKS PASSED';
end;
$$;

rollback;
