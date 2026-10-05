-- Decision record: docs/specs/_root/0012-one-backend-seller-role.md (build plan task 7)
--
-- SQL checks for seller access rules: AC-2, AC-4 and AC-5. Run the whole file
-- in the SQL editor of a TEST or BRANCH database (or with psql) after applying
-- migrations 0004 and 0005. It creates its own fixtures, switches to the
-- `authenticated` role with a fake JWT to act as each user, and ends with
-- `rollback`, so it leaves no rows behind. Do not run it against live data you
-- care about without reading it first.
--
-- Output: one NOTICE per check. A failed check raises an error that starts with
-- FAIL and stops the script. The AC-2 checks are skipped with a notice while
-- 0005 is not applied.

begin;

-- Runs one statement as the current role and reports the outcome as
-- 'ok:<rows>' or 'err:<sqlstate>' (42501 is permission denied or a row level
-- security violation). An update or delete that row level security filters out
-- is not an error, it is 'ok:0'.
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

-- Fixtures, created as the table owner.
insert into public.user_profiles (id, name, username, role, email, phone) values
  ('chk_newbuyer', 'Chk New Buyer', 'chk_newbuyer', 'buyer', 'n@example.com', '+100'),
  ('chk_plain', 'Chk Plain Buyer', 'chk_plain', 'buyer', null, null),
  ('chk_other', 'Chk Other Seller', 'chk_other', 'seller', null, null);

insert into public.products (id, title, description, price, category, store_id, store_name)
values ('00000000-0000-0000-0000-00000000c0b1', 'other prod', 'd', 1, 'c', 'chk_other', 'Other');
insert into public.reels (id, video_url, thumbnail_url, store_id, store_name, caption)
values ('00000000-0000-0000-0000-00000000c0e1', 'v', 't', 'chk_other', 'Other', 'c');

do $$
declare
  v_row public.user_profiles;
  v_other_product constant uuid := '00000000-0000-0000-0000-00000000c0b1';
  v_other_reel constant uuid := '00000000-0000-0000-0000-00000000c0e1';
  v_my_product constant uuid := '00000000-0000-0000-0000-00000000c0b2';
  v_my_reel constant uuid := '00000000-0000-0000-0000-00000000c0e2';
begin
  -- ---------------------------------------------------------------- AC-4
  perform pg_temp.act_as('chk_ghost', true);
  perform pg_temp.expect('AC-4 anonymous session is refused',
    pg_temp.try('select public.become_seller()'), 'err:P0001:no_session');
  reset role;

  perform pg_temp.act_as('chk_ghost');
  perform pg_temp.expect('AC-4 caller with no profile row is refused',
    pg_temp.try('select public.become_seller()'), 'err:P0001:no_profile');
  reset role;

  perform pg_temp.act_as('chk_newbuyer');
  perform pg_temp.expect('AC-4 buyer becomes a seller',
    pg_temp.try('select public.become_seller()'), 'ok:');
  reset role;
  select * into v_row from public.user_profiles where id = 'chk_newbuyer';
  if v_row.role <> 'seller' or v_row.email is not null or v_row.phone is not null then
    raise exception 'FAIL AC-4: expected seller with email and phone cleared, got %', v_row;
  end if;
  raise notice 'ok   AC-4 role is seller, email and phone cleared';

  -- The seller adds public contact details, then calls it again.
  update public.user_profiles set email = 'store@example.com' where id = 'chk_newbuyer';
  perform pg_temp.act_as('chk_newbuyer');
  perform pg_temp.expect('AC-4 second call is safe',
    pg_temp.try('select public.become_seller()'), 'ok:');
  reset role;
  if (select email from public.user_profiles where id = 'chk_newbuyer') is distinct from 'store@example.com' then
    raise exception 'FAIL AC-4: second call wiped the seller''s contact details';
  end if;
  raise notice 'ok   AC-4 second call keeps the seller''s contact details';

  perform pg_temp.act_as('chk_plain');
  perform pg_temp.expect('AC-4 only the caller''s own row changes',
    pg_temp.try('select public.become_seller()'), 'ok:');
  reset role;
  if (select role from public.user_profiles where id = 'chk_other') <> 'seller'
     or (select count(*) from public.user_profiles where id like 'chk\_%' and role = 'seller') <> 3 then
    raise exception 'FAIL AC-4: become_seller changed a row it should not have';
  end if;
  update public.user_profiles set role = 'buyer' where id = 'chk_plain';
  raise notice 'ok   AC-4 other profiles untouched (chk_plain reset to buyer for the next checks)';

  -- ---------------------------------------------------------------- AC-5
  -- chk_newbuyer is now a seller. chk_plain is a buyer. chk_other is a seller.
  -- Spec 0015 (migration 0008) closed direct writes to products: they now go
  -- through save_product (see checks/seller_products.sql). The product this
  -- seller owns is created here as the table owner so the reel tag checks
  -- below still have one.
  reset role;
  insert into public.products (id, title, description, price, category, store_id, store_name)
  values (v_my_product, 'mine', 'd', 5, 'Fashion', 'chk_newbuyer', 'Mine');
  perform pg_temp.act_as('chk_newbuyer');
  perform pg_temp.expect('AC-5 seller reads it back',
    pg_temp.try(format('select 1 from public.products where id = %L and store_id = %L', v_my_product, 'chk_newbuyer')), 'ok:1');
  perform pg_temp.expect('AC-5 (0015) seller can no longer update a product directly',
    pg_temp.try(format($q$update public.products set title = 'renamed' where id = %L$q$, v_my_product)), 'err:42501');
  perform pg_temp.expect('AC-5 seller cannot insert into another store',
    pg_temp.try($q$insert into public.products (title, description, price, category, store_id, store_name)
      values ('x', 'd', 1, 'c', 'chk_other', 'Other')$q$), 'err:42501');
  perform pg_temp.expect('AC-5 seller cannot update another seller''s product',
    pg_temp.try(format($q$update public.products set title = 'hacked' where id = %L$q$, v_other_product)), 'err:42501');
  perform pg_temp.expect('AC-5 seller cannot delete another seller''s product',
    pg_temp.try(format('delete from public.products where id = %L', v_other_product)), 'ok:0');
  perform pg_temp.expect('AC-5 seller cannot write products.rating',
    pg_temp.try(format('update public.products set rating = 5 where id = %L', v_my_product)), 'err:42501');
  perform pg_temp.expect('AC-5 seller cannot write products.review_count',
    pg_temp.try(format('update public.products set review_count = 99 where id = %L', v_my_product)), 'err:42501');
  perform pg_temp.expect('AC-5 seller cannot move a product to another store',
    pg_temp.try(format($q$update public.products set store_id = 'chk_other' where id = %L$q$, v_my_product)), 'err:42501');

  perform pg_temp.expect('AC-5 seller inserts own reel',
    pg_temp.try(format($q$insert into public.reels (id, video_url, thumbnail_url, store_id, store_name, caption)
      values (%L, 'v', 't', 'chk_newbuyer', 'Mine', 'c')$q$, v_my_reel)), 'ok:1');
  perform pg_temp.expect('AC-5 seller cannot write reels.like_count',
    pg_temp.try(format('update public.reels set like_count = 500 where id = %L', v_my_reel)), 'err:42501');
  perform pg_temp.expect('AC-5 seller cannot write reels.comment_count',
    pg_temp.try(format('update public.reels set comment_count = 500 where id = %L', v_my_reel)), 'err:42501');
  perform pg_temp.expect('AC-5 seller cannot update another seller''s reel',
    pg_temp.try(format($q$update public.reels set caption = 'hacked' where id = %L$q$, v_other_reel)), 'ok:0');
  perform pg_temp.expect('AC-5 seller tags own product on own reel',
    pg_temp.try(format('insert into public.reel_products (reel_id, product_id) values (%L, %L)', v_my_reel, v_my_product)), 'ok:1');
  perform pg_temp.expect('AC-5 seller cannot tag another seller''s product',
    pg_temp.try(format('insert into public.reel_products (reel_id, product_id) values (%L, %L)', v_my_reel, v_other_product)), 'err:42501');
  perform pg_temp.expect('AC-5 seller cannot tag onto another seller''s reel',
    pg_temp.try(format('insert into public.reel_products (reel_id, product_id) values (%L, %L)', v_other_reel, v_my_product)), 'err:42501');
  perform pg_temp.expect('AC-5 seller untags own reel',
    pg_temp.try(format('delete from public.reel_products where reel_id = %L', v_my_reel)), 'ok:1');
  perform pg_temp.expect('AC-5 seller deletes own reel',
    pg_temp.try(format('delete from public.reels where id = %L', v_my_reel)), 'ok:1');
  perform pg_temp.expect('AC-5 (0015) seller cannot delete a live product, only an archived one',
    pg_temp.try(format('delete from public.products where id = %L', v_my_product)), 'ok:0');
  reset role;

  perform pg_temp.act_as('chk_plain');
  perform pg_temp.expect('AC-5 buyer cannot insert a product',
    pg_temp.try($q$insert into public.products (title, description, price, category, store_id, store_name)
      values ('x', 'd', 1, 'c', 'chk_plain', 'Plain')$q$), 'err:42501');
  perform pg_temp.expect('AC-5 buyer cannot insert a reel',
    pg_temp.try($q$insert into public.reels (video_url, thumbnail_url, store_id, store_name, caption)
      values ('v', 't', 'chk_plain', 'Plain', 'c')$q$), 'err:42501');
  perform pg_temp.expect('AC-5 buyer cannot update a product',
    pg_temp.try(format($q$update public.products set title = 'hacked' where id = %L$q$, v_other_product)), 'err:42501');
  perform pg_temp.expect('AC-5 buyer cannot delete a product',
    pg_temp.try(format('delete from public.products where id = %L', v_other_product)), 'ok:0');
  perform pg_temp.expect('AC-5 buyer cannot tag a reel',
    pg_temp.try(format('insert into public.reel_products (reel_id, product_id) values (%L, %L)', v_other_reel, v_other_product)), 'err:42501');
  reset role;

  -- ---------------------------------------------------------------- AC-2
  if has_column_privilege('authenticated', 'public.user_profiles', 'role', 'update')
     or has_column_privilege('authenticated', 'public.user_profiles', 'role', 'insert') then
    raise notice 'SKIP AC-2 checks: 0005 is not applied (authenticated can still write role)';
  else
    perform pg_temp.act_as('chk_plain');
    perform pg_temp.expect('AC-2 client cannot set its own role',
      pg_temp.try($q$update public.user_profiles set role = 'seller' where id = 'chk_plain'$q$), 'err:42501');
    perform pg_temp.expect('AC-2 client cannot set is_verified',
      pg_temp.try($q$update public.user_profiles set is_verified = true where id = 'chk_plain'$q$), 'err:42501');
    perform pg_temp.expect('AC-2 client cannot set follower_count',
      pg_temp.try($q$update public.user_profiles set follower_count = 9999 where id = 'chk_plain'$q$), 'err:42501');
    perform pg_temp.expect('AC-2 client cannot set following_count',
      pg_temp.try($q$update public.user_profiles set following_count = 9999 where id = 'chk_plain'$q$), 'err:42501');
    perform pg_temp.expect('AC-2 client cannot set product_count',
      pg_temp.try($q$update public.user_profiles set product_count = 9999 where id = 'chk_plain'$q$), 'err:42501');
    perform pg_temp.expect('AC-2 client can still edit name, username and bio',
      pg_temp.try($q$update public.user_profiles set name = 'New', username = 'chk_plain2', bio = 'b' where id = 'chk_plain'$q$), 'ok:1');
    reset role;

    perform pg_temp.act_as('chk_fresh');
    perform pg_temp.expect('AC-2 insert that sends role is refused',
      pg_temp.try($q$insert into public.user_profiles (id, name, username, role) values ('chk_fresh', 'F', 'chk_fresh', 'seller')$q$), 'err:42501');
    -- The buyer app's real sign in write: no role, ignore duplicates.
    perform pg_temp.expect('AC-2 / AC-3 buyer sign in insert (no role, ignore duplicates)',
      pg_temp.try($q$insert into public.user_profiles (id, name, username, email, phone) values ('chk_fresh', 'F', 'chk_fresh', 'f@example.com', '+1')
        on conflict (id) do nothing$q$), 'ok:1');
    perform pg_temp.expect('AC-3 same insert again leaves the row alone',
      pg_temp.try($q$insert into public.user_profiles (id, name, username, email, phone) values ('chk_fresh', 'CHANGED', 'chk_fresh', 'changed@example.com', '+2')
        on conflict (id) do nothing$q$), 'ok:0');
    reset role;
    if (select role from public.user_profiles where id = 'chk_fresh') <> 'buyer'
       or (select name from public.user_profiles where id = 'chk_fresh') <> 'F' then
      raise exception 'FAIL AC-2/AC-3: new profile is not a buyer, or the second insert overwrote it';
    end if;
    raise notice 'ok   AC-2 new profile is a buyer, AC-3 existing profile kept';
  end if;

  raise notice 'ALL CHECKS PASSED';
end;
$$;

rollback;
