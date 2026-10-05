-- Decision record: docs/specs/_root/0013-seller-application-request/index.md (build plan task 2)
-- Updated for migration 0007 (spec 0014): submitter_id is required and two unique
-- indexes were renamed. Apply 0007 before running it.
--
-- SQL checks for seller applications: AC-1 to AC-7. Run the whole file in the
-- SQL editor of a TEST or BRANCH database (or with psql) after applying
-- migrations 0004, 0005, 0006 and 0007. It creates its own fixtures, switches role
-- with a fake JWT to act as each person, and ends with `rollback`, so it
-- leaves no rows behind. Do not run it against live data you care about
-- without reading it first.
--
-- Output: one NOTICE per check. A failed check raises an error that starts with
-- FAIL and stops the script.
--
-- Not covered here, because SQL cannot see it (see the spec, build plan task 1
-- and verify.md): the 5 MB and JPEG or PNG limits (the Storage API enforces
-- them), a real upload with a Clerk token, and two submits running at the same
-- moment (needs two sessions). The unique index that backs the last one is
-- checked below.

begin;

-- Runs one statement as the current role and reports the outcome as
-- 'ok:<rows>' or 'err:<sqlstate>:<message>' (42501 is permission denied or a
-- row level security violation, P0001 is a raised refusal). An update or delete
-- that row level security filters out is not an error, it is 'ok:0'.
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

-- Fixtures, created as the table owner. chk_a and chk_b are buyers with
-- private email and phone copied from sign in. chk_s is already a seller.
-- chk_holder owns the username 'chk_holder' on its profile.
insert into public.user_profiles (id, name, username, role, email, phone, bio, avatar_url) values
  ('chk_a', 'Chk A', 'chk_a', 'buyer', 'a@example.com', '+100', 'old bio', 'https://example.com/a.png'),
  ('chk_b', 'Chk B', 'chk_b', 'buyer', 'b@example.com', '+200', null, null),
  ('chk_c', 'Chk C', 'chk_c', 'buyer', null, null, null, null),
  ('chk_d', 'Chk D', 'chk_d', 'buyer', null, null, null, null),
  ('chk_s', 'Chk S', 'chk_s', 'seller', null, null, null, null),
  ('chk_holder', 'Chk Holder', 'chk_holder', 'buyer', null, null, null, null);

-- Uploaded files, as the Storage API would leave them (rows in storage.objects).
-- Application ids: a1 and a2 for chk_a, b1 for chk_b, c1 for chk_c, d1 and d2
-- for chk_d.
insert into storage.objects (bucket_id, name) values
  ('store-logos', 'chk_a/logo-1.png'),
  ('store-logos', 'chk_b/logo-1.png'),
  ('application-documents', 'chk_a/00000000-0000-0000-0000-0000000000a1/id-1.jpg'),
  ('application-documents', 'chk_a/00000000-0000-0000-0000-0000000000a1/business-1.jpg'),
  ('application-documents', 'chk_a/00000000-0000-0000-0000-0000000000a2/id-1.jpg'),
  ('application-documents', 'chk_b/00000000-0000-0000-0000-0000000000b1/id-1.jpg'),
  ('application-documents', 'chk_c/00000000-0000-0000-0000-0000000000c1/id-1.jpg'),
  ('application-documents', 'chk_d/00000000-0000-0000-0000-0000000000d1/id-1.jpg'),
  ('application-documents', 'chk_d/00000000-0000-0000-0000-0000000000d2/id-1.jpg');

do $$
declare
  v_a1 constant uuid := '00000000-0000-0000-0000-0000000000a1';
  v_a2 constant uuid := '00000000-0000-0000-0000-0000000000a2';
  v_b1 constant uuid := '00000000-0000-0000-0000-0000000000b1';
  v_c1 constant uuid := '00000000-0000-0000-0000-0000000000c1';
  v_d1 constant uuid := '00000000-0000-0000-0000-0000000000d1';
  v_d2 constant uuid := '00000000-0000-0000-0000-0000000000d2';
  v_a_id constant text := 'chk_a/00000000-0000-0000-0000-0000000000a1/id-1.jpg';
  v_a_biz constant text := 'chk_a/00000000-0000-0000-0000-0000000000a1/business-1.jpg';
  v_b_id constant text := 'chk_b/00000000-0000-0000-0000-0000000000b1/id-1.jpg';
  v_row public.user_profiles;
  v_app public.seller_applications;
  v_n integer;
begin
  -- ---------------------------------------------------------------- AC-1
  -- Refusals. chk_a has no application yet, so every failure below must leave
  -- it free to submit afterwards.
  perform pg_temp.act_as('chk_ghost', true);
  perform pg_temp.expect('AC-1 anonymous session is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a', 'Tunis', %L)$q$, v_a1, v_a_id)),
    'err:P0001:no_session');
  reset role;

  perform pg_temp.act_as('chk_ghost');
  perform pg_temp.expect('AC-1 caller with no profile row is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a', 'Tunis', %L)$q$, v_a1, v_a_id)),
    'err:P0001:no_profile');
  reset role;

  perform pg_temp.act_as('chk_s');
  perform pg_temp.expect('AC-1 a seller is refused (already_seller)',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_s', 'Tunis', %L)$q$, v_a1, v_a_id)),
    'err:P0001:already_seller');
  reset role;

  -- ---------------------------------------------------------------- AC-3
  perform pg_temp.act_as('chk_a');
  perform pg_temp.expect('AC-3 store name of 1 character is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'S', 'shop_a', 'Tunis', %L)$q$, v_a1, v_a_id)),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-3 store name of 61 characters is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, %L, 'shop_a', 'Tunis', %L)$q$, v_a1, repeat('x', 61), v_a_id)),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-3 username with an uppercase letter is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'Shop_A', 'Tunis', %L)$q$, v_a1, v_a_id)),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-3 username of 2 characters is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'ab', 'Tunis', %L)$q$, v_a1, v_a_id)),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-3 username with a space is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop a', 'Tunis', %L)$q$, v_a1, v_a_id)),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-3 empty location is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a', '   ', %L)$q$, v_a1, v_a_id)),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-3 bio over 280 characters is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a', 'Tunis', %L, %L)$q$, v_a1, v_a_id, repeat('b', 281))),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-3 username of another profile is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'chk_holder', 'Tunis', %L)$q$, v_a1, v_a_id)),
    'err:P0001:username_taken');
  perform pg_temp.expect('AC-3 missing ID document is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a', 'Tunis', null)$q$, v_a1)),
    'err:P0001:missing_document');
  perform pg_temp.expect('AC-3 ID path that no file matches is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a', 'Tunis', %L)$q$, v_a1, 'chk_a/00000000-0000-0000-0000-0000000000a1/nope.jpg')),
    'err:P0001:file_not_found');
  perform pg_temp.expect('AC-3 ID path in someone else''s folder is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a', 'Tunis', %L)$q$, v_a1, v_b_id)),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-3 ID path under a different application id is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a', 'Tunis', %L)$q$, v_a1, 'chk_a/00000000-0000-0000-0000-0000000000a2/id-1.jpg')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-3 ID path with a sub folder is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a', 'Tunis', %L)$q$, v_a1, v_a_id || '/x')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-3 same path for ID and business is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a', 'Tunis', %L, null, null, null, null, null, %L)$q$, v_a1, v_a_id, v_a_id)),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-3 logo path in someone else''s folder is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a', 'Tunis', %L, null, null, null, null, 'chk_b/logo-1.png')$q$, v_a1, v_a_id)),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-3 logo path with no file in store-logos is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a', 'Tunis', %L, null, null, null, null, 'chk_a/nologo.png')$q$, v_a1, v_a_id)),
    'err:P0001:file_not_found');
  reset role;
  select count(*) into v_n from public.seller_applications where applicant_id = 'chk_a';
  if v_n <> 0 then
    raise exception 'FAIL AC-3: a refused submit left % row(s) behind', v_n;
  end if;
  raise notice 'ok   AC-3 refused submits leave no row';

  -- ---------------------------------------------------------------- AC-1 happy path
  -- chk_a applies with every optional field empty, so approval later has to
  -- overwrite the profile's email, phone and bio with null.
  perform pg_temp.act_as('chk_a');
  perform pg_temp.expect('AC-1 buyer submits an application',
    pg_temp.try(format($q$select public.submit_seller_application(%L, '  My Shop  ', 'shop_a', ' Tunis ', %L, '', '', '', '', %L)$q$, v_a1, v_a_id, 'chk_a/logo-1.png')),
    'ok:1');
  reset role;
  select * into v_app from public.seller_applications where id = v_a1;
  if v_app.applicant_id <> 'chk_a' or v_app.status <> 'reviewing'
     or v_app.store_name <> 'My Shop' or v_app.location <> 'Tunis'
     or v_app.bio is not null or v_app.contact_email is not null then
    raise exception 'FAIL AC-1: row is wrong: %', v_app;
  end if;
  raise notice 'ok   AC-1 row is reviewing, owned by the caller, trimmed, empty optionals are null';

  perform pg_temp.act_as('chk_a');
  perform pg_temp.expect('AC-1 same id again returns the row and changes nothing',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Other name', 'other_a', 'Sfax', %L)$q$, v_a1, v_a_id)),
    'ok:1');
  reset role;
  select count(*) into v_n from public.seller_applications where applicant_id = 'chk_a';
  if v_n <> 1 or (select store_name from public.seller_applications where id = v_a1) <> 'My Shop' then
    raise exception 'FAIL AC-1: retry created a row or changed the existing one';
  end if;
  raise notice 'ok   AC-1 retry is a no op';

  -- A different person reusing that id is refused, never returned the row.
  perform pg_temp.act_as('chk_b');
  perform pg_temp.expect('AC-1 another person cannot reuse the id',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_b', 'Tunis', %L)$q$, v_a1, v_b_id)),
    'err:P0001:invalid_field');
  reset role;

  -- ---------------------------------------------------------------- AC-2
  perform pg_temp.act_as('chk_a');
  perform pg_temp.expect('AC-2 second submit with a new id is refused (already_open)',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a2', 'Tunis', %L)$q$, v_a2, 'chk_a/00000000-0000-0000-0000-0000000000a2/id-1.jpg')),
    'err:P0001:already_open');
  reset role;

  -- The unique indexes are the backstop for two submits at the same moment.
  perform pg_temp.expect('AC-2 index refuses a second reviewing row for one person',
    pg_temp.try(format($q$insert into public.seller_applications (id, applicant_id, submitter_id, store_name, username, location, id_document_path)
      values (%L, 'chk_a', 'chk_a', 'Dup', 'dup_a', 'Tunis', 'x')$q$, v_a2)),
    'err:23505:duplicate key value violates unique constraint "seller_applications_one_reviewing_per_owner"');
  perform pg_temp.expect('AC-2 index refuses a second reviewing row for one username',
    pg_temp.try(format($q$insert into public.seller_applications (id, applicant_id, submitter_id, store_name, username, location, id_document_path)
      values (%L, 'chk_c', 'chk_c', 'Dup', 'shop_a', 'Tunis', 'x')$q$, v_c1)),
    'err:23505:duplicate key value violates unique constraint "seller_applications_one_username_in_flight"');

  -- Username held by another reviewing application.
  perform pg_temp.act_as('chk_b');
  perform pg_temp.expect('AC-3 username of another reviewing application is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a', 'Tunis', %L)$q$, v_b1, v_b_id)),
    'err:P0001:username_taken');
  perform pg_temp.expect('AC-1 chk_b submits with a free username',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'B Shop', 'shop_b', 'Sousse', %L, 'Hello', 'https://b.example.com', '+216', 'b@store.example.com')$q$, v_b1, v_b_id)),
    'ok:1');
  reset role;

  -- ---------------------------------------------------------------- AC-4
  perform pg_temp.act_as('chk_a');
  select count(*) into v_n from public.seller_applications;
  if v_n <> 1 then
    raise exception 'FAIL AC-4: chk_a sees % application row(s), expected only its own (1)', v_n;
  end if;
  raise notice 'ok   AC-4 a client reads only its own rows';
  perform pg_temp.expect('AC-4 client cannot read another person''s row',
    pg_temp.try(format('select 1 from public.seller_applications where id = %L', v_b1)), 'ok:0');
  perform pg_temp.expect('AC-4 client cannot insert a row',
    pg_temp.try(format($q$insert into public.seller_applications (id, applicant_id, submitter_id, store_name, username, location, id_document_path)
      values (%L, 'chk_a', 'chk_a', 'Mine', 'mine_a', 'Tunis', 'x')$q$, v_a2)), 'err:42501');
  perform pg_temp.expect('AC-4 client cannot update a row',
    pg_temp.try(format($q$update public.seller_applications set status = 'approved' where id = %L$q$, v_a1)), 'err:42501');
  perform pg_temp.expect('AC-4 client cannot delete a row',
    pg_temp.try(format('delete from public.seller_applications where id = %L', v_a1)), 'err:42501');
  reset role;

  set local role anon;
  perform pg_temp.expect('AC-4 anon cannot read the table',
    pg_temp.try('select 1 from public.seller_applications'), 'err:42501');
  perform pg_temp.expect('AC-4 anon cannot call submit',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_z', 'Tunis', 'x')$q$, v_a2)), 'err:42501');
  reset role;

  -- ---------------------------------------------------------------- AC-5
  if not coalesce((select public from storage.buckets where id = 'store-logos'), false)
     or (select file_size_limit from storage.buckets where id = 'store-logos') <> 5242880
     or (select allowed_mime_types from storage.buckets where id = 'store-logos') <> array['image/jpeg', 'image/png'] then
    raise exception 'FAIL AC-5: store-logos bucket is not public, 5 MB, JPEG and PNG';
  end if;
  if coalesce((select public from storage.buckets where id = 'application-documents'), true)
     or (select file_size_limit from storage.buckets where id = 'application-documents') <> 5242880
     or (select allowed_mime_types from storage.buckets where id = 'application-documents') <> array['image/jpeg', 'image/png'] then
    raise exception 'FAIL AC-5: application-documents bucket is not private, 5 MB, JPEG and PNG';
  end if;
  raise notice 'ok   AC-5 buckets: logos public, documents private, both 5 MB JPEG and PNG';

  perform pg_temp.act_as('chk_d');
  perform pg_temp.expect('AC-5 real account adds a logo in its own folder',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('store-logos', 'chk_d/new.png')$q$), 'ok:1');
  perform pg_temp.expect('AC-5 real account adds a document in its own folder',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('application-documents', 'chk_d/x/new.jpg')$q$), 'ok:1');
  perform pg_temp.expect('AC-5 real account reads its own document',
    pg_temp.try($q$select 1 from storage.objects where bucket_id = 'application-documents' and name = 'chk_d/x/new.jpg'$q$), 'ok:1');
  perform pg_temp.expect('AC-5 cannot add a logo in another folder',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('store-logos', 'chk_a/evil.png')$q$), 'err:42501');
  perform pg_temp.expect('AC-5 cannot add a document in another folder',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('application-documents', 'chk_a/evil.jpg')$q$), 'err:42501');
  perform pg_temp.expect('AC-5 cannot add a file at the bucket root',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('application-documents', 'rootfile.jpg')$q$), 'err:42501');
  perform pg_temp.expect('AC-5 cannot read another person''s document',
    pg_temp.try(format($q$select 1 from storage.objects where bucket_id = 'application-documents' and name = %L$q$, v_a_id)), 'ok:0');
  perform pg_temp.expect('AC-5 cannot update a file',
    pg_temp.try($q$update storage.objects set name = 'chk_d/renamed.png' where bucket_id = 'store-logos' and name = 'chk_d/new.png'$q$), 'ok:0');
  -- Newer Storage versions also block direct deletes with a trigger (42501), older
  -- ones just filter the row out (ok:0). Either way the file must survive.
  perform pg_temp.try($q$delete from storage.objects where bucket_id = 'store-logos' and name = 'chk_d/new.png'$q$);
  reset role;
  if not exists (select 1 from storage.objects where bucket_id = 'store-logos' and name = 'chk_d/new.png') then
    raise exception 'FAIL AC-5 cannot delete a file: the client deleted it';
  end if;
  raise notice 'ok   AC-5 cannot delete a file';
  perform pg_temp.act_as('chk_d');
  perform pg_temp.expect('AC-5 cannot add a file to another bucket',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('avatars', 'chk_d/x.png')$q$), 'err:42501');
  reset role;

  perform pg_temp.act_as('chk_d', true);
  perform pg_temp.expect('AC-5 anonymous session cannot add a logo',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('store-logos', 'chk_d/anon.png')$q$), 'err:42501');
  perform pg_temp.expect('AC-5 anonymous session cannot add a document',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('application-documents', 'chk_d/anon.jpg')$q$), 'err:42501');
  reset role;

  set local role anon;
  perform pg_temp.expect('AC-5 anon role cannot add a logo',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('store-logos', 'chk_d/anon.png')$q$), 'err:42501');
  reset role;

  -- ---------------------------------------------------------------- AC-6
  perform pg_temp.act_as('chk_a');
  perform pg_temp.expect('AC-6 a signed in client cannot approve',
    pg_temp.try(format('select public.approve_seller_application(%L)', v_a1)), 'err:42501');
  reset role;
  perform pg_temp.act_as('chk_s');
  perform pg_temp.expect('AC-7 a signed in client cannot reject',
    pg_temp.try(format($q$select public.reject_seller_application(%L, 'no')$q$, v_a1)), 'err:42501');
  reset role;
  set local role anon;
  perform pg_temp.expect('AC-6 anon cannot approve',
    pg_temp.try(format('select public.approve_seller_application(%L)', v_a1)), 'err:42501');
  reset role;

  -- The service role is what the admin runs the functions as.
  set local role service_role;
  perform pg_temp.expect('AC-6 unknown id is refused (not_found)',
    pg_temp.try($q$select public.approve_seller_application('00000000-0000-0000-0000-0000000000ff')$q$), 'err:P0001:not_found');
  perform pg_temp.expect('AC-6 service role approves chk_a',
    pg_temp.try(format($q$select public.approve_seller_application(%L, 'Admin One')$q$, v_a1)), 'ok:1');
  perform pg_temp.expect('AC-6 second approve is refused (not_reviewing)',
    pg_temp.try(format('select public.approve_seller_application(%L)', v_a1)), 'err:P0001:not_reviewing');
  perform pg_temp.expect('AC-7 reject after approve is refused (not_reviewing)',
    pg_temp.try(format($q$select public.reject_seller_application(%L, 'late')$q$, v_a1)), 'err:P0001:not_reviewing');
  reset role;

  select * into v_app from public.seller_applications where id = v_a1;
  if v_app.status <> 'approved' or v_app.reviewed_at is null or v_app.reviewed_by <> 'Admin One' then
    raise exception 'FAIL AC-6: application not marked approved: %', v_app;
  end if;
  select * into v_row from public.user_profiles where id = 'chk_a';
  if v_row.role <> 'seller' or v_row.name <> 'My Shop' or v_row.username <> 'shop_a'
     or v_row.location <> 'Tunis'
     or v_row.avatar_url <> 'store-logos/chk_a/logo-1.png' then
    raise exception 'FAIL AC-6: profile not copied from the application: %', v_row;
  end if;
  if v_row.email is not null or v_row.phone is not null or v_row.bio is not null
     or v_row.website_url is not null then
    raise exception 'FAIL AC-6: empty optional fields did not overwrite the profile with null: %', v_row;
  end if;
  raise notice 'ok   AC-6 profile is a seller with the store details, private email and phone are gone';

  -- Retry of the same id after approval still returns the row (the retry check
  -- runs before already_seller).
  perform pg_temp.act_as('chk_a');
  perform pg_temp.expect('AC-1 same id after approval still returns the row',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'x', 'xxx', 'y', %L)$q$, v_a1, v_a_id)), 'ok:1');
  perform pg_temp.expect('AC-1 a new id after approval is refused (already_seller)',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'shop_a3', 'Tunis', %L)$q$, v_a2, 'chk_a/00000000-0000-0000-0000-0000000000a2/id-1.jpg')),
    'err:P0001:already_seller');
  reset role;

  -- Optional fields are copied when present (chk_b, with a logo-less application).
  set local role service_role;
  perform pg_temp.expect('AC-6 service role approves chk_b',
    pg_temp.try(format('select public.approve_seller_application(%L)', v_b1)), 'ok:1');
  reset role;
  select * into v_row from public.user_profiles where id = 'chk_b';
  if v_row.role <> 'seller' or v_row.bio <> 'Hello' or v_row.website_url <> 'https://b.example.com'
     or v_row.phone <> '+216' or v_row.email <> 'b@store.example.com' or v_row.avatar_url is not null then
    raise exception 'FAIL AC-6: optional fields were not copied, or avatar was not cleared: %', v_row;
  end if;
  raise notice 'ok   AC-6 optional contact fields are copied, no logo means a null avatar';

  -- Approving a person who is already a seller (for example through the open
  -- become_seller()) is refused and the application stays reviewing.
  perform pg_temp.act_as('chk_c');
  perform pg_temp.expect('AC-1 chk_c submits',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'C Shop', 'c_shop', 'Tunis', %L)$q$, v_c1, 'chk_c/00000000-0000-0000-0000-0000000000c1/id-1.jpg')),
    'ok:1');
  reset role;
  update public.user_profiles set role = 'seller' where id = 'chk_c';
  set local role service_role;
  perform pg_temp.expect('AC-6 approving an existing seller is refused (already_seller)',
    pg_temp.try(format('select public.approve_seller_application(%L)', v_c1)), 'err:P0001:already_seller');
  reset role;
  if (select status from public.seller_applications where id = v_c1) <> 'reviewing'
     or (select name from public.user_profiles where id = 'chk_c') <> 'Chk C' then
    raise exception 'FAIL AC-6: already_seller refusal changed the application or the profile';
  end if;
  raise notice 'ok   AC-6 already_seller leaves the application reviewing and the profile alone';

  -- ---------------------------------------------------------------- AC-7
  -- chk_d: reject keeps the buyer profile, then they can apply again.
  perform pg_temp.act_as('chk_d');
  perform pg_temp.expect('AC-1 chk_d submits',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'D Shop', 'd_shop', 'Tunis', %L)$q$, v_d1, 'chk_d/00000000-0000-0000-0000-0000000000d1/id-1.jpg')),
    'ok:1');
  reset role;

  set local role service_role;
  perform pg_temp.expect('AC-7 empty reason is refused',
    pg_temp.try(format($q$select public.reject_seller_application(%L, '   ')$q$, v_d1)), 'err:P0001:reason_required');
  perform pg_temp.expect('AC-7 null reason is refused',
    pg_temp.try(format('select public.reject_seller_application(%L, null)', v_d1)), 'err:P0001:reason_required');
  perform pg_temp.expect('AC-7 unknown id is refused (not_found)',
    pg_temp.try($q$select public.reject_seller_application('00000000-0000-0000-0000-0000000000ff', 'no')$q$), 'err:P0001:not_found');
  perform pg_temp.expect('AC-7 service role rejects chk_d',
    pg_temp.try(format($q$select public.reject_seller_application(%L, '  ID photo is blurry  ', 'Admin Two')$q$, v_d1)), 'ok:1');
  perform pg_temp.expect('AC-7 second reject is refused (not_reviewing)',
    pg_temp.try(format($q$select public.reject_seller_application(%L, 'again')$q$, v_d1)), 'err:P0001:not_reviewing');
  perform pg_temp.expect('AC-6 approve after reject is refused (not_reviewing)',
    pg_temp.try(format('select public.approve_seller_application(%L)', v_d1)), 'err:P0001:not_reviewing');
  reset role;

  select * into v_app from public.seller_applications where id = v_d1;
  if v_app.status <> 'rejected' or v_app.rejection_reason <> 'ID photo is blurry'
     or v_app.reviewed_at is null or v_app.reviewed_by <> 'Admin Two' then
    raise exception 'FAIL AC-7: application not marked rejected: %', v_app;
  end if;
  select * into v_row from public.user_profiles where id = 'chk_d';
  if v_row.role <> 'buyer' or v_row.name <> 'Chk D' or v_row.username <> 'chk_d' then
    raise exception 'FAIL AC-7: a rejection changed the profile: %', v_row;
  end if;
  raise notice 'ok   AC-7 rejected with a reason, profile untouched';

  -- ---------------------------------------------------------------- AC-2
  perform pg_temp.act_as('chk_d');
  perform pg_temp.expect('AC-2 after a rejection the person can apply again',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'D Shop 2', 'd_shop', 'Tunis', %L)$q$, v_d2, 'chk_d/00000000-0000-0000-0000-0000000000d2/id-1.jpg')),
    'ok:1');
  select count(*) into v_n from public.seller_applications where applicant_id = 'chk_d';
  if v_n <> 2 then
    raise exception 'FAIL AC-2: expected 2 rows for chk_d (rejected and reviewing), got %', v_n;
  end if;
  raise notice 'ok   AC-2 a rejected username is free again for a new application';
  reset role;

  -- ---------------------------------------------------------------- AC-6 username
  -- Username taken by approval time: approve refuses, application stays reviewing.
  update public.user_profiles set username = 'd_shop' where id = 'chk_holder';
  set local role service_role;
  perform pg_temp.expect('AC-6 username taken since submit is refused (username_taken)',
    pg_temp.try(format('select public.approve_seller_application(%L)', v_d2)), 'err:P0001:username_taken');
  reset role;
  select * into v_app from public.seller_applications where id = v_d2;
  if v_app.status <> 'reviewing'
     or (select role from public.user_profiles where id = 'chk_d') <> 'buyer' then
    raise exception 'FAIL AC-6: username_taken refusal changed the application or the profile';
  end if;
  raise notice 'ok   AC-6 username_taken leaves the application reviewing';

  raise notice 'ALL CHECKS PASSED';
end;
$$;

rollback;
