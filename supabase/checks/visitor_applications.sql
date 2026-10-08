-- Decision record: docs/specs/_root/0014-shared-login-seller-area/index.md (build plan task 2)
--
-- SQL checks for visitor applications: AC-8 to AC-13, AC-17. Run the whole file in
-- the SQL editor of a TEST or BRANCH database (or with psql) after applying
-- migrations 0004 to 0013 (the detach step of 0013 is checked by
-- detach_unclaimed_attached.sql). It creates its own fixtures, switches role with a fake
-- JWT to act as each person, and ends with `rollback`, so it leaves no rows
-- behind. Do not run it against live data you care about without reading it
-- first.
--
-- Output: one NOTICE per check. A failed check raises an error that starts with
-- FAIL and stops the script.
--
-- Naming: anon_N is an anonymous session (a visitor), chk_X is a real account.
--
-- Not covered here, because SQL cannot see it (see verify.md): the 5 MB and JPEG
-- or PNG limits (the Storage API enforces them), a real upload with a real
-- anonymous token, two submits at the same moment (needs two sessions), the Edge
-- Function and the Storage copy. The unique indexes behind the race are checked
-- below.

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

-- A submit_visitor_application call with a valid shape, so a test only changes
-- the one argument it is about. Files: the caller's session folder.
create function pg_temp.sv(
  p_id uuid, p_sub text, p_username text, p_email text, p_phone text,
  p_name text default 'Visitor One', p_id_path text default null
) returns text language sql as $$
  select format(
    $q$select public.submit_visitor_application(%L, 'Shop', %L, 'Tunis', %L, %L, %L, %L)$q$,
    p_id, p_username, p_name, p_email, p_phone,
    coalesce(p_id_path, p_sub || '/' || p_id::text || '/id-1.jpg')
  );
$$;

-- A visitor row inserted as the table owner, to hit one unique index at a time.
create function pg_temp.raw_visitor(
  p_id uuid, p_sub text, p_username text, p_email text, p_phone text,
  p_status text default 'reviewing'
) returns text language sql as $$
  select format(
    $q$insert into public.seller_applications (id, origin, applicant_id, submitter_id,
      applicant_name, applicant_email, applicant_phone, store_name, username, location,
      id_document_path, status) values (%L, 'visitor', null, %L, 'Raw Visitor', %L, %L,
      'Raw', %L, 'Tunis', 'x', %L)$q$,
    p_id, p_sub, p_email, p_phone, p_username, p_status
  );
$$;

-- attach_applications_by_contact called as the current role, passing only what Clerk
-- would have verified. The statement is true when it returns p_n.
create function pg_temp.att(p_sub text, p_emails text[], p_phones text[], p_n integer)
returns text language sql as $$
  select format(
    $q$select 1 where public.attach_applications_by_contact(%L, %L::text[], %L::text[]) = %s$q$,
    p_sub, p_emails, p_phones, p_n
  );
$$;

-- Fixtures, created as the table owner.
-- chk_a, chk_b and chk_c are buyers with private email and phone copied from
-- sign in. chk_s is already a seller. chk_holder owns the username 'holder_name'.
-- chk_open already has a reviewing application of its own.
insert into public.user_profiles (id, name, username, role, email, phone, bio, avatar_url) values
  ('chk_a', 'Chk A', 'chk_a', 'buyer', 'a@example.com', '+100', 'old bio', 'https://example.com/a.png'),
  ('chk_b', 'Chk B', 'chk_b', 'buyer', 'b@example.com', '+21699999000', null, null),
  ('chk_c', 'Chk C', 'chk_c', 'buyer', 'c@example.com', '+300', 'c bio', null),
  ('chk_s', 'Chk S', 'chk_s', 'seller', null, null, null, null),
  ('chk_holder', 'Chk Holder', 'holder_name', 'buyer', null, null, null, null),
  ('chk_open', 'Chk Open', 'chk_open', 'buyer', null, null, null, null);

insert into public.seller_applications (id, applicant_id, submitter_id, store_name, username, location, id_document_path)
values ('00000000-0000-0000-0000-0000000000f1', 'chk_open', 'chk_open', 'Open', 'open_shop', 'Tunis', 'x');

-- Uploaded files, as the Storage API would leave them (rows in storage.objects).
-- Application ids: e1 to e9, one per visitor row below.
insert into storage.objects (bucket_id, name) values
  ('visitor-documents', 'anon_1/00000000-0000-0000-0000-0000000000e1/id-1.jpg'),
  ('visitor-documents', 'anon_1/00000000-0000-0000-0000-0000000000e1/business-1.jpg'),
  ('visitor-documents', 'anon_1/00000000-0000-0000-0000-0000000000e1/logo-1.png'),
  ('visitor-documents', 'anon_2/00000000-0000-0000-0000-0000000000e2/id-1.jpg'),
  ('visitor-documents', 'anon_3/00000000-0000-0000-0000-0000000000e3/id-1.jpg'),
  ('visitor-documents', 'anon_4/00000000-0000-0000-0000-0000000000e4/id-1.jpg'),
  ('visitor-documents', 'anon_5/00000000-0000-0000-0000-0000000000e5/id-1.jpg'),
  ('visitor-documents', 'anon_7/00000000-0000-0000-0000-0000000000e7/id-1.jpg'),
  ('visitor-documents', 'anon_8/00000000-0000-0000-0000-0000000000e8/id-1.jpg'),
  ('visitor-documents', 'anon_1/00000000-0000-0000-0000-0000000000e9/id-1.jpg'),
  ('application-documents', 'chk_a/00000000-0000-0000-0000-0000000000a1/id-1.jpg');

do $$
declare
  v1 constant uuid := '00000000-0000-0000-0000-0000000000e1';
  v2 constant uuid := '00000000-0000-0000-0000-0000000000e2';
  v3 constant uuid := '00000000-0000-0000-0000-0000000000e3';
  v4 constant uuid := '00000000-0000-0000-0000-0000000000e4';
  v5 constant uuid := '00000000-0000-0000-0000-0000000000e5';
  v7 constant uuid := '00000000-0000-0000-0000-0000000000e7';
  v8 constant uuid := '00000000-0000-0000-0000-0000000000e8';
  v9 constant uuid := '00000000-0000-0000-0000-0000000000e9';
  v_ghost constant uuid := '00000000-0000-0000-0000-0000000000ee';
  v_a1 constant uuid := '00000000-0000-0000-0000-0000000000a1';
  v_row public.user_profiles;
  v_app public.seller_applications;
  v_n integer;
  v_profiles integer;
begin
  -- ---------------------------------------------------------------- AC-8 refusals
  -- anon_1 has no application yet, so every failure below must leave it free to
  -- submit afterwards.
  perform pg_temp.act_as(null, true);
  perform pg_temp.expect('AC-8 caller with no session is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example.com', '+21612345678')),
    'err:P0001:no_session');
  reset role;

  perform pg_temp.act_as('chk_a', false);
  perform pg_temp.expect('AC-8 a real account is refused (use_account)',
    pg_temp.try(pg_temp.sv(v1, 'chk_a', 'alpha_shop', 'alpha@example.com', '+21612345678')),
    'err:P0001:use_account');
  reset role;

  perform pg_temp.act_as('anon_1', true);
  perform pg_temp.expect('AC-8 applicant name of 1 character is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example.com', '+21612345678', 'V')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 applicant name of 61 characters is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example.com', '+21612345678', repeat('x', 61))),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 email without an @ is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha.example.com', '+21612345678')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 email without a dot in the domain is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example', '+21612345678')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 email over 200 characters is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', repeat('a', 196) || '@x.co', '+21612345678')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 phone without the plus is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example.com', '21612345678')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 phone with a leading zero after the plus is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example.com', '+0612345678')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 phone shorter than 7 digits is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example.com', '+216123')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 phone longer than 15 digits is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example.com', '+2161234567890123')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 phone with spaces is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example.com', '+216 12 345 678')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 username with an uppercase letter is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'Alpha_Shop', 'alpha@example.com', '+21612345678')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 username of another profile is refused (username_taken)',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'holder_name', 'alpha@example.com', '+21612345678')),
    'err:P0001:username_taken');
  perform pg_temp.expect('AC-8 username of a reviewing application is refused (username_taken)',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'open_shop', 'alpha@example.com', '+21612345678')),
    'err:P0001:username_taken');
  perform pg_temp.expect('AC-8 missing ID document is refused',
    pg_temp.try(format($q$select public.submit_visitor_application(%L, 'Shop', 'alpha_shop', 'Tunis', 'Visitor One', 'alpha@example.com', '+21612345678', null)$q$, v1)),
    'err:P0001:missing_document');
  perform pg_temp.expect('AC-8 ID path that no file matches is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example.com', '+21612345678', 'Visitor One', 'anon_1/' || v1 || '/id-nope.jpg')),
    'err:P0001:file_not_found');
  perform pg_temp.expect('AC-8 ID path in someone else''s session folder is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example.com', '+21612345678', 'Visitor One', 'anon_2/' || v2 || '/id-1.jpg')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 ID path under a different application id is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example.com', '+21612345678', 'Visitor One', 'anon_1/' || v9 || '/id-1.jpg')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 ID path with the wrong kind prefix is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example.com', '+21612345678', 'Visitor One', 'anon_1/' || v1 || '/business-1.jpg')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 ID path with a sub folder is refused',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'alpha_shop', 'alpha@example.com', '+21612345678', 'Visitor One', 'anon_1/' || v1 || '/id-1.jpg/x')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 business path with the wrong kind prefix is refused',
    pg_temp.try(format($q$select public.submit_visitor_application(%L, 'Shop', 'alpha_shop', 'Tunis', 'Visitor One', 'alpha@example.com', '+21612345678', %L, null, null, null, null, null, %L)$q$,
      v1, 'anon_1/' || v1 || '/id-1.jpg', 'anon_1/' || v1 || '/id-1.jpg')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 logo path in the application-documents style folder is refused',
    pg_temp.try(format($q$select public.submit_visitor_application(%L, 'Shop', 'alpha_shop', 'Tunis', 'Visitor One', 'alpha@example.com', '+21612345678', %L, null, null, null, null, %L)$q$,
      v1, 'anon_1/' || v1 || '/id-1.jpg', 'anon_1/logo-1.png')),
    'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 logo path with no file is refused',
    pg_temp.try(format($q$select public.submit_visitor_application(%L, 'Shop', 'alpha_shop', 'Tunis', 'Visitor One', 'alpha@example.com', '+21612345678', %L, null, null, null, null, %L)$q$,
      v1, 'anon_1/' || v1 || '/id-1.jpg', 'anon_1/' || v1 || '/logo-nope.png')),
    'err:P0001:file_not_found');
  reset role;
  select count(*) into v_n from public.seller_applications where submitter_id = 'anon_1';
  if v_n <> 0 then
    raise exception 'FAIL AC-8: a refused submit left % row(s) behind', v_n;
  end if;
  raise notice 'ok   AC-8 refused submits leave no row';

  -- ---------------------------------------------------------------- AC-8 happy path
  -- anon_1 applies with all three files. Email and name carry spaces and capitals
  -- that must be cleaned, the optional fields are empty.
  perform pg_temp.act_as('anon_1', true);
  perform pg_temp.expect('AC-8 visitor submits an application',
    pg_temp.try(format($q$select public.submit_visitor_application(%L, '  Alpha Shop  ', 'alpha_shop', ' Tunis ', '  Visitor One  ', '  Alpha@Example.COM ', ' +21612345678 ', %L, '', '', '', '', %L, %L)$q$,
      v1, 'anon_1/' || v1 || '/id-1.jpg', 'anon_1/' || v1 || '/logo-1.png', 'anon_1/' || v1 || '/business-1.jpg')),
    'ok:1');
  reset role;
  select * into v_app from public.seller_applications where id = v1;
  if v_app.origin <> 'visitor' or v_app.status <> 'reviewing'
     or v_app.applicant_id is not null or v_app.bound_account_id is not null
     or v_app.submitter_id <> 'anon_1' or v_app.store_name <> 'Alpha Shop'
     or v_app.location <> 'Tunis' or v_app.applicant_name <> 'Visitor One'
     or v_app.applicant_email <> 'alpha@example.com'
     or v_app.applicant_phone <> '+21612345678'
     or v_app.bio is not null or v_app.contact_email is not null
     or v_app.logo_path is null or v_app.business_document_path is null then
    raise exception 'FAIL AC-8: row is wrong: %', v_app;
  end if;
  raise notice 'ok   AC-8 row is a reviewing visitor row, trimmed, email lowercase, no applicant yet';

  perform pg_temp.act_as('anon_1', true);
  perform pg_temp.expect('AC-8 same id again returns the row and changes nothing',
    pg_temp.try(pg_temp.sv(v1, 'anon_1', 'other_name', 'other@example.com', '+21699999999', 'Someone Else')),
    'ok:1');
  reset role;
  select count(*) into v_n from public.seller_applications where submitter_id = 'anon_1';
  if v_n <> 1 or (select store_name from public.seller_applications where id = v1) <> 'Alpha Shop' then
    raise exception 'FAIL AC-8: retry created a row or changed the existing one';
  end if;
  raise notice 'ok   AC-8 retry is a no op';

  -- Another session reusing that id is refused, never returned the row.
  perform pg_temp.act_as('anon_2', true);
  perform pg_temp.expect('AC-8 another session cannot reuse the id',
    pg_temp.try(pg_temp.sv(v1, 'anon_2', 'beta_shop', 'beta@example.com', '+21612345679', 'Visitor Two', 'anon_2/' || v2 || '/id-1.jpg')),
    'err:P0001:invalid_field');
  reset role;

  -- ---------------------------------------------------------------- AC-8 one open
  perform pg_temp.act_as('anon_1', true);
  perform pg_temp.expect('AC-8 second submit with a new id from the same session is refused',
    pg_temp.try(pg_temp.sv(v9, 'anon_1', 'other_name', 'other@example.com', '+21699999999')),
    'err:P0001:already_open');
  reset role;

  perform pg_temp.act_as('anon_2', true);
  perform pg_temp.expect('AC-8 same email in another case from another session is refused',
    pg_temp.try(pg_temp.sv(v2, 'anon_2', 'beta_shop', 'ALPHA@example.com', '+21612345679', 'Visitor Two')),
    'err:P0001:already_open');
  perform pg_temp.expect('AC-8 same phone from another session is refused',
    pg_temp.try(pg_temp.sv(v2, 'anon_2', 'beta_shop', 'beta@example.com', '+21612345678', 'Visitor Two')),
    'err:P0001:already_open');
  perform pg_temp.expect('AC-8 same username as a reviewing visitor application is refused',
    pg_temp.try(pg_temp.sv(v2, 'anon_2', 'alpha_shop', 'beta@example.com', '+21612345679', 'Visitor Two')),
    'err:P0001:username_taken');
  reset role;

  -- The unique indexes are the backstop for two submits at the same moment. Each
  -- insert differs from anon_1's row in every way except the one under test.
  perform pg_temp.expect('AC-8 index refuses a second reviewing row for one session',
    pg_temp.try(pg_temp.raw_visitor(v9, 'anon_1', 'raw_one', 'raw1@example.com', '+21611111111')),
    'err:23505:duplicate key value violates unique constraint "seller_applications_one_reviewing_per_owner"');
  perform pg_temp.expect('AC-8 index refuses a second reviewing row for one email',
    pg_temp.try(pg_temp.raw_visitor(v9, 'anon_raw', 'raw_two', 'ALPHA@example.com', '+21622222222')),
    'err:23505:duplicate key value violates unique constraint "seller_applications_one_reviewing_per_email"');
  perform pg_temp.expect('AC-8 index refuses a second reviewing row for one phone',
    pg_temp.try(pg_temp.raw_visitor(v9, 'anon_raw', 'raw_three', 'raw3@example.com', '+21612345678')),
    'err:23505:duplicate key value violates unique constraint "seller_applications_one_reviewing_per_phone"');
  perform pg_temp.expect('AC-8 index refuses a second row in flight for one username',
    pg_temp.try(pg_temp.raw_visitor(v9, 'anon_raw', 'alpha_shop', 'raw4@example.com', '+21644444444')),
    'err:23505:duplicate key value violates unique constraint "seller_applications_one_username_in_flight"');
  perform pg_temp.expect('AC-8 an account row cannot take a username a visitor row holds',
    pg_temp.try($q$insert into public.seller_applications (id, applicant_id, submitter_id, store_name, username, location, id_document_path)
      values ('00000000-0000-0000-0000-0000000000f2', 'chk_b', 'chk_b', 'Dup', 'alpha_shop', 'Tunis', 'x')$q$),
    'err:23505:duplicate key value violates unique constraint "seller_applications_one_username_in_flight"');
  perform pg_temp.expect('AC-8 a visitor row needs a name, email and phone (check constraint)',
    pg_temp.try($q$insert into public.seller_applications (id, origin, applicant_id, submitter_id, store_name, username, location, id_document_path)
      values ('00000000-0000-0000-0000-0000000000f3', 'visitor', null, 'anon_raw', 'No contact', 'raw_five', 'Tunis', 'x')$q$),
    'err:23514');
  perform pg_temp.expect('AC-8 an account row needs an applicant (check constraint)',
    pg_temp.try($q$insert into public.seller_applications (id, origin, applicant_id, submitter_id, store_name, username, location, id_document_path)
      values ('00000000-0000-0000-0000-0000000000f4', 'account', null, 'anon_raw', 'No owner', 'raw_six', 'Tunis', 'x')$q$),
    'err:23514');

  -- Account applications still work next to visitor rows (migration 0007 replaced
  -- submit_seller_application): chk_b applies, and the username check sees the
  -- visitor reservation.
  perform pg_temp.act_as('chk_b');
  perform pg_temp.expect('AC-15 an account cannot take a username a visitor row holds',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'alpha_shop', 'Tunis', 'chk_b/00000000-0000-0000-0000-0000000000b1/id-1.jpg')$q$, '00000000-0000-0000-0000-0000000000b1')),
    'err:P0001:username_taken');
  reset role;

  -- ---------------------------------------------------------------- AC-10 reads
  perform pg_temp.act_as('anon_1', true);
  select count(*) into v_n from public.seller_applications;
  if v_n <> 1 then
    raise exception 'FAIL AC-10: anon_1 sees % application row(s), expected only its own (1)', v_n;
  end if;
  raise notice 'ok   AC-10 a visitor session reads only its own row';
  perform pg_temp.expect('AC-10 a visitor reads its own row by id',
    pg_temp.try(format('select 1 from public.seller_applications where id = %L', v1)), 'ok:1');
  reset role;
  perform pg_temp.act_as('anon_2', true);
  perform pg_temp.expect('AC-10 another session cannot read the row',
    pg_temp.try(format('select 1 from public.seller_applications where id = %L', v1)), 'ok:0');
  perform pg_temp.expect('AC-10 client cannot insert a row',
    pg_temp.try($q$insert into public.seller_applications (id, origin, submitter_id, applicant_name, applicant_email, applicant_phone, store_name, username, location, id_document_path)
      values ('00000000-0000-0000-0000-0000000000f5', 'visitor', 'anon_2', 'A B', 'a@b.co', '+21600000000', 'S', 'raw_seven', 'T', 'x')$q$),
    'err:42501');
  reset role;
  perform pg_temp.act_as('anon_1', true);
  perform pg_temp.expect('AC-10 client cannot update a row (bound_account_id included)',
    pg_temp.try(format($q$update public.seller_applications set bound_account_id = 'chk_s', status = 'approved' where id = %L$q$, v1)), 'err:42501');
  perform pg_temp.expect('AC-10 client cannot delete a row',
    pg_temp.try(format('delete from public.seller_applications where id = %L', v1)), 'err:42501');
  reset role;
  set local role anon;
  perform pg_temp.expect('AC-10 anon cannot read the table',
    pg_temp.try('select 1 from public.seller_applications'), 'err:42501');
  perform pg_temp.expect('AC-8 anon cannot call submit_visitor_application',
    pg_temp.try(pg_temp.sv(v9, 'anon_1', 'raw_x', 'x@example.com', '+21655555555')), 'err:42501');
  reset role;

  -- ---------------------------------------------------------------- AC-9 storage
  if coalesce((select public from storage.buckets where id = 'visitor-documents'), true)
     or (select file_size_limit from storage.buckets where id = 'visitor-documents') <> 5242880
     or (select allowed_mime_types from storage.buckets where id = 'visitor-documents') <> array['image/jpeg', 'image/png'] then
    raise exception 'FAIL AC-9: visitor-documents bucket is not private, 5 MB, JPEG and PNG';
  end if;
  raise notice 'ok   AC-9 bucket visitor-documents is private, 5 MB, JPEG and PNG';

  perform pg_temp.act_as('anon_5', true);
  perform pg_temp.expect('AC-9 anonymous session adds a file in its own folder',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('visitor-documents', 'anon_5/00000000-0000-0000-0000-0000000000e5/id-2.jpg')$q$), 'ok:1');
  perform pg_temp.expect('AC-9 cannot add a file in another session''s folder',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('visitor-documents', 'anon_1/evil.jpg')$q$), 'err:42501');
  perform pg_temp.expect('AC-9 cannot add a file at the bucket root',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('visitor-documents', 'rootfile.jpg')$q$), 'err:42501');
  perform pg_temp.expect('AC-9 anonymous session still cannot add to store-logos',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('store-logos', 'anon_5/x.png')$q$), 'err:42501');
  perform pg_temp.expect('AC-9 anonymous session still cannot add to application-documents',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('application-documents', 'anon_5/x/id.jpg')$q$), 'err:42501');
  perform pg_temp.expect('AC-9 cannot read a file, not even its own',
    pg_temp.try($q$select 1 from storage.objects where bucket_id = 'visitor-documents' and name = 'anon_5/00000000-0000-0000-0000-0000000000e5/id-1.jpg'$q$), 'ok:0');
  perform pg_temp.expect('AC-9 cannot update a file',
    pg_temp.try($q$update storage.objects set name = 'anon_5/renamed.jpg' where bucket_id = 'visitor-documents' and name = 'anon_5/00000000-0000-0000-0000-0000000000e5/id-1.jpg'$q$), 'ok:0');
  -- Newer Storage versions also block direct deletes with a trigger (42501), older
  -- ones just filter the row out (ok:0). Either way the file must survive.
  perform pg_temp.try($q$delete from storage.objects where bucket_id = 'visitor-documents' and name = 'anon_5/00000000-0000-0000-0000-0000000000e5/id-1.jpg'$q$);
  reset role;
  if not exists (select 1 from storage.objects where bucket_id = 'visitor-documents'
                 and name = 'anon_5/00000000-0000-0000-0000-0000000000e5/id-1.jpg') then
    raise exception 'FAIL AC-9 cannot delete a file: the client deleted it';
  end if;
  raise notice 'ok   AC-9 cannot delete a file';

  perform pg_temp.act_as('anon_5', false);
  perform pg_temp.expect('AC-9 a real account cannot add a file to visitor-documents',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('visitor-documents', 'anon_5/real.jpg')$q$), 'err:42501');
  reset role;
  set local role anon;
  perform pg_temp.expect('AC-9 anon role cannot add a file',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('visitor-documents', 'anon_5/anon.jpg')$q$), 'err:42501');
  reset role;

  -- The cap: 12 files in total per session folder.
  insert into storage.objects (bucket_id, name)
  select 'visitor-documents', 'anon_6/00000000-0000-0000-0000-0000000000e6/f-' || g || '.jpg'
  from generate_series(1, 11) g;
  perform pg_temp.act_as('anon_6', true);
  perform pg_temp.expect('AC-9 the twelfth file is allowed',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('visitor-documents', 'anon_6/00000000-0000-0000-0000-0000000000e6/f-12.jpg')$q$), 'ok:1');
  perform pg_temp.expect('AC-9 the thirteenth file is refused',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('visitor-documents', 'anon_6/00000000-0000-0000-0000-0000000000e6/f-13.jpg')$q$), 'err:42501');
  reset role;
  perform pg_temp.act_as('anon_5', true);
  perform pg_temp.expect('AC-9 the cap counts one folder only (anon_5 is far below it)',
    pg_temp.try($q$insert into storage.objects (bucket_id, name) values ('visitor-documents', 'anon_5/00000000-0000-0000-0000-0000000000e5/id-3.jpg')$q$), 'ok:1');
  reset role;

  -- ---------------------------------------------------------------- AC-8 more visitors
  -- anon_2 .. anon_5, anon_7 and anon_8 apply with valid data (no optional files).
  perform pg_temp.act_as('anon_2', true);
  perform pg_temp.expect('AC-8 anon_2 submits with every optional field',
    pg_temp.try(format($q$select public.submit_visitor_application(%L, 'Beta Shop', 'beta_shop', 'Sfax', 'Visitor Two', 'beta@example.com', '+21612345679', %L, 'Hello', 'https://beta.example.com', '+216', 'beta@store.example.com')$q$,
      v2, 'anon_2/' || v2 || '/id-1.jpg')),
    'ok:1');
  reset role;
  perform pg_temp.act_as('anon_3', true);
  perform pg_temp.expect('AC-8 anon_3 submits',
    pg_temp.try(pg_temp.sv(v3, 'anon_3', 'gamma_shop', 'gamma@example.com', '+21612345680', 'Visitor Three')), 'ok:1');
  reset role;
  perform pg_temp.act_as('anon_4', true);
  perform pg_temp.expect('AC-8 anon_4 submits',
    pg_temp.try(pg_temp.sv(v4, 'anon_4', 'delta_shop', 'delta@example.com', '+21612345681', 'Visitor Four')), 'ok:1');
  reset role;
  -- anon_5 uses the same email and phone as profiles chk_a and chk_b. Those
  -- values must never bring the row to those accounts.
  perform pg_temp.act_as('anon_5', true);
  perform pg_temp.expect('AC-8 anon_5 submits with contact details that match two accounts',
    pg_temp.try(pg_temp.sv(v5, 'anon_5', 'eps_shop', 'a@example.com', '+21699999000', 'Visitor Five')), 'ok:1');
  reset role;
  perform pg_temp.act_as('anon_7', true);
  perform pg_temp.expect('AC-8 anon_7 submits',
    pg_temp.try(pg_temp.sv(v7, 'anon_7', 'zeta_shop', 'zeta@example.com', '+21612345682', 'Visitor Seven')), 'ok:1');
  reset role;
  perform pg_temp.act_as('anon_8', true);
  perform pg_temp.expect('AC-8 anon_8 submits',
    pg_temp.try(pg_temp.sv(v8, 'anon_8', 'eta_shop', 'eta@example.com', '+21612345683', 'Visitor Eight')), 'ok:1');
  reset role;

  -- ---------------------------------------------------------------- AC-12 attach
  -- Being on the phone that sent the application proves nothing: signing in on it
  -- (merge_anonymous_identity) attaches no row, and the session keeps reading its
  -- own free row.
  perform pg_temp.act_as('anon_1', true);
  perform pg_temp.expect('AC-12 anon_1 merges into chk_a',
    pg_temp.try($q$select public.merge_anonymous_identity('chk_a')$q$), 'ok:1');
  select count(*) into v_n from public.seller_applications where id = v1;
  if v_n <> 1 then
    raise exception 'FAIL AC-10: the sending session cannot read its own free row';
  end if;
  reset role;
  if (select bound_account_id from public.seller_applications where id = v1) is not null then
    raise exception 'FAIL AC-12: the sending phone attached a row without proof';
  end if;
  raise notice 'ok   AC-12 signing in on the sending phone attaches nothing';

  perform pg_temp.act_as('chk_a');
  select count(*) into v_n from public.seller_applications;
  if v_n <> 0 then
    raise exception 'FAIL AC-17: chk_a sees % application row(s) before any proof, expected 0', v_n;
  end if;
  reset role;
  raise notice 'ok   AC-17 an account sees no application it has not proved';

  -- No client can run the attach or the check that asks whether one waits.
  perform pg_temp.act_as('chk_a');
  perform pg_temp.expect('AC-12 a signed in client cannot attach',
    pg_temp.try(pg_temp.att('chk_a', array['alpha@example.com'], '{}', 1)), 'err:42501');
  perform pg_temp.expect('AC-12 a signed in client cannot call has_unattached_visitor_applications',
    pg_temp.try('select public.has_unattached_visitor_applications()'), 'err:42501');
  reset role;
  set local role anon;
  perform pg_temp.expect('AC-12 anon cannot attach',
    pg_temp.try(pg_temp.att('chk_a', array['alpha@example.com'], '{}', 1)), 'err:42501');
  perform pg_temp.expect('AC-12 anon cannot call has_unattached_visitor_applications',
    pg_temp.try('select public.has_unattached_visitor_applications()'), 'err:42501');
  reset role;

  -- Proof by contact, as the service role. Every case below attaches nothing.
  set local role service_role;
  perform pg_temp.expect('AC-12 a free reviewing visitor row makes the waiting check true',
    pg_temp.try('select 1 where public.has_unattached_visitor_applications()'), 'ok:1');
  perform pg_temp.expect('AC-12 a null, empty or blank contact list attaches nothing',
    pg_temp.try($q$select 1 where public.attach_applications_by_contact('chk_a', null, null) = 0
                   and public.attach_applications_by_contact('chk_a', '{}', '{}') = 0
                   and public.attach_applications_by_contact('chk_a', array['  '], array['']) = 0$q$), 'ok:1');
  perform pg_temp.expect('AC-12 an email that differs in one character attaches nothing',
    pg_temp.try(pg_temp.att('chk_a', array['alpha@example.co'], '{}', 0)), 'ok:1');
  perform pg_temp.expect('AC-12 a phone that differs in one digit attaches nothing',
    pg_temp.try(pg_temp.att('chk_a', '{}', array['+2161234567'], 0)), 'ok:1');
  perform pg_temp.expect('AC-12 a phone with spaces is not the same number',
    pg_temp.try(pg_temp.att('chk_a', '{}', array['+216 12345678'], 0)), 'ok:1');
  -- v5 was typed with chk_a's profile email and chk_b's profile phone. An account
  -- whose verified contacts are different gets nothing.
  perform pg_temp.expect('AC-12 an account with other verified contacts attaches nothing',
    pg_temp.try(pg_temp.att('chk_b', array['b@example.com'], array['+1555'], 0)), 'ok:1');
  perform pg_temp.expect('AC-12 an existing seller is never attached',
    pg_temp.try(pg_temp.att('chk_s', array['alpha@example.com'], '{}', 0)), 'ok:1');
  perform pg_temp.expect('AC-12 a reviewing row is skipped when the account has an open application',
    pg_temp.try(pg_temp.att('chk_open', array['gamma@example.com'], '{}', 0)), 'ok:1');
  reset role;
  if exists (select 1 from public.seller_applications where bound_account_id is not null) then
    raise exception 'FAIL AC-12: a refused attach still bound a row';
  end if;
  raise notice 'ok   AC-12 wrong, unverified, blank and skipped contacts attach nothing';

  -- The real attach by email: case and spaces do not matter.
  set local role service_role;
  perform pg_temp.expect('AC-12 a verified email attaches the row',
    pg_temp.try(pg_temp.att('chk_a', array['nobody@example.com', '  ALPHA@Example.COM '], '{}', 1)), 'ok:1');
  perform pg_temp.expect('AC-12 an attached row is not attached again',
    pg_temp.try(pg_temp.att('chk_b', array['alpha@example.com'], '{}', 0)), 'ok:1');
  reset role;
  select * into v_app from public.seller_applications where id = v1;
  if v_app.bound_account_id <> 'chk_a' or v_app.applicant_id is not null or v_app.status <> 'reviewing' then
    raise exception 'FAIL AC-12: the row was not attached to chk_a: %', v_app;
  end if;
  raise notice 'ok   AC-12 the row is attached to the account that proved the email (no applicant yet)';

  -- By phone, exact match, on another account.
  set local role service_role;
  perform pg_temp.expect('AC-12 a verified phone attaches the row',
    pg_temp.try(pg_temp.att('chk_b', '{}', array['+21612345681'], 1)), 'ok:1');
  reset role;
  if (select bound_account_id from public.seller_applications where id = v4) is distinct from 'chk_b' then
    raise exception 'FAIL AC-12: the row was not attached to chk_b by phone';
  end if;
  raise notice 'ok   AC-12 a verified phone attaches the row';

  -- Each account reads its own row and nobody else's, and the sending session
  -- stops reading a row once it is attached.
  perform pg_temp.act_as('chk_a');
  select count(*) into v_n from public.seller_applications;
  if v_n <> 1 or not exists (select 1 from public.seller_applications where id = v1) then
    raise exception 'FAIL AC-17: chk_a sees % row(s), expected only its attached one', v_n;
  end if;
  perform pg_temp.expect('AC-12 an attached reviewing row counts as the account''s open application',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop', 'acct_shop', 'Tunis', %L)$q$, v_a1, 'chk_a/' || v_a1 || '/id-1.jpg')),
    'err:P0001:already_open');
  reset role;
  perform pg_temp.act_as('chk_b');
  select count(*) into v_n from public.seller_applications;
  if v_n <> 1 or not exists (select 1 from public.seller_applications where id = v4) then
    raise exception 'FAIL AC-17: chk_b sees % row(s), expected only its attached one', v_n;
  end if;
  reset role;
  perform pg_temp.act_as('anon_1', true);
  select count(*) into v_n from public.seller_applications where id = v1;
  if v_n <> 0 then
    raise exception 'FAIL AC-10: the sending session still reads a row attached to an account';
  end if;
  reset role;
  raise notice 'ok   AC-17 each account reads only its own attached row, the sender stops reading it';

  -- An account that already has an attached open row does not take a second one
  -- (v5 was typed with chk_a's profile email, but only a verified contact counts).
  set local role service_role;
  perform pg_temp.expect('AC-12 an account with an open application takes no second reviewing row',
    pg_temp.try(pg_temp.att('chk_a', array['a@example.com'], '{}', 0)), 'ok:1');
  reset role;
  raise notice 'ok   AC-12 the one open rule holds for attached rows';

  -- ---------------------------------------------------------------- AC-11 decisions
  perform pg_temp.act_as('chk_a');
  perform pg_temp.expect('AC-11 a signed in client cannot approve',
    pg_temp.try(format('select public.approve_seller_application(%L)', v1)), 'err:42501');
  perform pg_temp.expect('AC-11 a signed in client cannot reject',
    pg_temp.try(format($q$select public.reject_seller_application(%L, 'no')$q$, v1)), 'err:42501');
  reset role;

  select count(*) into v_profiles from public.user_profiles;
  set local role service_role;
  perform pg_temp.expect('AC-11 unknown id is refused (not_found)',
    pg_temp.try($q$select public.approve_seller_application('00000000-0000-0000-0000-0000000000ff')$q$), 'err:P0001:not_found');
  perform pg_temp.expect('AC-11 service role approves the visitor row',
    pg_temp.try(format($q$select public.approve_seller_application(%L, 'Admin One')$q$, v1)), 'ok:1');
  perform pg_temp.expect('AC-11 second approve is refused (not_reviewing)',
    pg_temp.try(format('select public.approve_seller_application(%L)', v1)), 'err:P0001:not_reviewing');
  perform pg_temp.expect('AC-11 empty reason is refused',
    pg_temp.try(format($q$select public.reject_seller_application(%L, '   ')$q$, v7)), 'err:P0001:reason_required');
  perform pg_temp.expect('AC-11 service role rejects a visitor row',
    pg_temp.try(format($q$select public.reject_seller_application(%L, '  ID photo is blurry  ', 'Admin Two')$q$, v7)), 'ok:1');
  perform pg_temp.expect('AC-11 reject after reject is refused (not_reviewing)',
    pg_temp.try(format($q$select public.reject_seller_application(%L, 'again')$q$, v7)), 'err:P0001:not_reviewing');
  reset role;

  select * into v_app from public.seller_applications where id = v1;
  if v_app.status <> 'approved' or v_app.reviewed_at is null or v_app.reviewed_by <> 'Admin One'
     or v_app.applicant_id is not null or v_app.claimed_at is not null then
    raise exception 'FAIL AC-11: visitor row not approved as expected: %', v_app;
  end if;
  select * into v_app from public.seller_applications where id = v7;
  if v_app.status <> 'rejected' or v_app.rejection_reason <> 'ID photo is blurry' or v_app.reviewed_by <> 'Admin Two' then
    raise exception 'FAIL AC-11: visitor row not rejected as expected: %', v_app;
  end if;
  if (select count(*) from public.user_profiles) <> v_profiles
     or (select role from public.user_profiles where id = 'chk_a') <> 'buyer' then
    raise exception 'FAIL AC-11: a decision on a visitor row changed a profile';
  end if;
  raise notice 'ok   AC-11 visitor rows are approved and rejected, no profile changes';

  -- A rejected row attaches to an account that proves its contact, even when that
  -- account already has an open application, and both then show (AC-17).
  set local role service_role;
  perform pg_temp.expect('AC-12 a rejected row attaches next to an open application',
    pg_temp.try(pg_temp.att('chk_open', array['zeta@example.com'], '{}', 1)), 'ok:1');
  reset role;
  perform pg_temp.act_as('chk_open');
  select count(*) into v_n from public.seller_applications;
  if v_n <> 2 or (select status from public.seller_applications where id = v7) <> 'rejected' then
    raise exception 'FAIL AC-17: chk_open should read its own reviewing row and the attached rejected one, got % row(s)', v_n;
  end if;
  reset role;
  raise notice 'ok   AC-17 an attached rejected row shows next to the account''s own open application';

  -- An approved visitor application keeps its username reserved until claimed.
  perform pg_temp.act_as('anon_10', true);
  perform pg_temp.expect('AC-8 an approved unclaimed visitor username stays reserved (submit)',
    pg_temp.try(pg_temp.sv(v_ghost, 'anon_10', 'alpha_shop', 'new10@example.com', '+21677777777', 'Visitor Ten')),
    'err:P0001:username_taken');
  reset role;
  perform pg_temp.expect('AC-8 an approved unclaimed visitor username stays reserved (index)',
    pg_temp.try($q$insert into public.seller_applications (id, applicant_id, submitter_id, store_name, username, location, id_document_path)
      values ('00000000-0000-0000-0000-0000000000f6', 'chk_c', 'chk_c', 'Dup', 'alpha_shop', 'Tunis', 'x')$q$),
    'err:23505:duplicate key value violates unique constraint "seller_applications_one_username_in_flight"');
  -- A rejected application frees its username.
  perform pg_temp.expect('AC-8 a rejected application frees its username',
    pg_temp.try($q$insert into public.seller_applications (id, applicant_id, submitter_id, store_name, username, location, id_document_path)
      values ('00000000-0000-0000-0000-0000000000f7', 'chk_c', 'chk_c', 'Reuse', 'zeta_shop', 'Tunis', 'x')$q$),
    'ok:1');
  delete from public.seller_applications where id = '00000000-0000-0000-0000-0000000000f7';

  -- ---------------------------------------------------------------- AC-13 claim
  -- No client can call the claim functions.
  perform pg_temp.act_as('chk_a');
  perform pg_temp.expect('AC-13 a signed in client cannot call find_claimable_application',
    pg_temp.try($q$select * from public.find_claimable_application('chk_a')$q$), 'err:42501');
  perform pg_temp.expect('AC-13 a signed in client cannot call claim_seller_application',
    pg_temp.try(format($q$select public.claim_seller_application(%L, 'chk_a')$q$, v1)), 'err:42501');
  reset role;
  set local role anon;
  perform pg_temp.expect('AC-13 anon cannot call claim_seller_application',
    pg_temp.try(format($q$select public.claim_seller_application(%L, 'chk_a')$q$, v1)), 'err:42501');
  reset role;

  set local role service_role;
  perform pg_temp.expect('AC-13 find returns the approved attached row',
    pg_temp.try($q$select * from public.find_claimable_application('chk_a')$q$), 'ok:1');
  perform pg_temp.expect('AC-13 find returns nothing for an account with no such row',
    pg_temp.try($q$select * from public.find_claimable_application('chk_b')$q$), 'ok:0');
  perform pg_temp.expect('AC-13 claim of an unknown id is refused (not_found)',
    pg_temp.try($q$select public.claim_seller_application('00000000-0000-0000-0000-0000000000ff', 'chk_a')$q$), 'err:P0001:not_found');
  perform pg_temp.expect('AC-13 claim by another account is refused (not_claimable)',
    pg_temp.try(format($q$select public.claim_seller_application(%L, 'chk_b')$q$, v1)), 'err:P0001:not_claimable');
  perform pg_temp.expect('AC-13 claim of a row still reviewing is refused (not_claimable)',
    pg_temp.try(format($q$select public.claim_seller_application(%L, 'chk_open')$q$, v3)), 'err:P0001:not_claimable');
  reset role;

  -- Refusals leave everything as it was: first a taken username, then a profile
  -- that is already a seller, then no profile at all.
  update public.user_profiles set username = 'alpha_shop' where id = 'chk_holder';
  set local role service_role;
  perform pg_temp.expect('AC-13 a username taken since approval is refused (username_taken)',
    pg_temp.try(format($q$select public.claim_seller_application(%L, 'chk_a')$q$, v1)), 'err:P0001:username_taken');
  reset role;
  update public.user_profiles set username = 'holder_name' where id = 'chk_holder';
  select * into v_app from public.seller_applications where id = v1;
  select * into v_row from public.user_profiles where id = 'chk_a';
  if v_app.claimed_at is not null or v_app.applicant_id is not null
     or v_row.role <> 'buyer' or v_row.name <> 'Chk A' or v_row.username <> 'chk_a' then
    raise exception 'FAIL AC-13: username_taken changed the application or the profile';
  end if;
  raise notice 'ok   AC-13 username_taken leaves the row unclaimed and the profile alone';

  update public.seller_applications set bound_account_id = 'chk_s' where id = v8;
  update public.seller_applications set status = 'approved', reviewed_at = now() where id = v8;
  set local role service_role;
  perform pg_temp.expect('AC-13 an account that is already a seller is refused (already_seller)',
    pg_temp.try(format($q$select public.claim_seller_application(%L, 'chk_s')$q$, v8)), 'err:P0001:already_seller');
  reset role;
  update public.seller_applications set bound_account_id = 'chk_ghost' where id = v8;
  set local role service_role;
  perform pg_temp.expect('AC-13 an account with no profile is refused (no_profile)',
    pg_temp.try(format($q$select public.claim_seller_application(%L, 'chk_ghost')$q$, v8)), 'err:P0001:no_profile');
  reset role;
  if (select claimed_at from public.seller_applications where id = v8) is not null
     or (select name from public.user_profiles where id = 'chk_s') <> 'Chk S' then
    raise exception 'FAIL AC-13: already_seller or no_profile changed something';
  end if;
  raise notice 'ok   AC-13 already_seller and no_profile leave everything as it was';

  -- The happy claim. The logo path is the destination the Edge Function copied
  -- to. The profile's old email, phone and bio are overwritten with null because
  -- the application had none (the 0013 rule).
  set local role service_role;
  perform pg_temp.expect('AC-13 service role claims the row',
    pg_temp.try(format($q$select public.claim_seller_application(%L, 'chk_a', %L)$q$, v1, 'chk_a/' || v1 || '.png')), 'ok:1');
  perform pg_temp.expect('AC-13 a second claim is refused (not_claimable)',
    pg_temp.try(format($q$select public.claim_seller_application(%L, 'chk_a', %L)$q$, v1, 'chk_a/' || v1 || '.png')), 'err:P0001:not_claimable');
  perform pg_temp.expect('AC-13 find returns nothing after the claim',
    pg_temp.try($q$select * from public.find_claimable_application('chk_a')$q$), 'ok:0');
  reset role;
  select * into v_row from public.user_profiles where id = 'chk_a';
  if v_row.role <> 'seller' or v_row.name <> 'Alpha Shop' or v_row.username <> 'alpha_shop'
     or v_row.location <> 'Tunis'
     or v_row.avatar_url <> 'store-logos/chk_a/' || v1 || '.png' then
    raise exception 'FAIL AC-13: profile not copied from the application: %', v_row;
  end if;
  if v_row.email is not null or v_row.phone is not null or v_row.bio is not null
     or v_row.website_url is not null then
    raise exception 'FAIL AC-13: empty optional fields did not overwrite the profile with null: %', v_row;
  end if;
  select * into v_app from public.seller_applications where id = v1;
  if v_app.applicant_id <> 'chk_a' or v_app.claimed_at is null or v_app.status <> 'approved' then
    raise exception 'FAIL AC-13: application not marked claimed: %', v_app;
  end if;
  raise notice 'ok   AC-13 the profile is a seller with the store details, the row is claimed';

  -- Optional fields are copied when present, and a claim without a logo clears
  -- the avatar. v2 carries every optional field and no logo.
  update public.seller_applications set bound_account_id = 'chk_c' where id = v2;
  set local role service_role;
  perform pg_temp.expect('AC-11 service role approves v2',
    pg_temp.try(format('select public.approve_seller_application(%L)', v2)), 'ok:1');
  perform pg_temp.expect('AC-13 service role claims v2 without a logo',
    pg_temp.try(format($q$select public.claim_seller_application(%L, 'chk_c')$q$, v2)), 'ok:1');
  reset role;
  select * into v_row from public.user_profiles where id = 'chk_c';
  if v_row.role <> 'seller' or v_row.bio <> 'Hello' or v_row.website_url <> 'https://beta.example.com'
     or v_row.phone <> '+216' or v_row.email <> 'beta@store.example.com' or v_row.avatar_url is not null then
    raise exception 'FAIL AC-13: optional fields were not copied, or avatar was not cleared: %', v_row;
  end if;
  raise notice 'ok   AC-13 optional contact fields are copied, no logo means a null avatar';

  -- ---------------------------------------------------------------- AC-11 account row
  -- An account application is still approved as in 0013 (profile copied, role
  -- set), next to visitor rows.
  update public.user_profiles set role = 'buyer' where id = 'chk_open';
  set local role service_role;
  perform pg_temp.expect('AC-11 an account application is still approved and copies the profile',
    pg_temp.try($q$select public.approve_seller_application('00000000-0000-0000-0000-0000000000f1')$q$), 'ok:1');
  reset role;
  select * into v_row from public.user_profiles where id = 'chk_open';
  if v_row.role <> 'seller' or v_row.username <> 'open_shop' or v_row.name <> 'Open' then
    raise exception 'FAIL AC-11: account approval no longer copies the profile: %', v_row;
  end if;
  raise notice 'ok   AC-11 account approval is unchanged';

  -- ---------------------------------------------------------------- AC-12 race
  -- The account chk_race has no application, but the one open index already has an
  -- entry under its name (a session id that equals it, only possible in a test).
  -- Attaching the reviewing row then hits seller_applications_one_reviewing_per_owner.
  -- That is caught, and the approved row of the same call stays attached.
  perform pg_temp.try(pg_temp.raw_visitor('00000000-0000-0000-0000-0000000000c1', 'chk_race', 'race_a', 'race1@example.com', '+21655550001'));
  perform pg_temp.try(pg_temp.raw_visitor('00000000-0000-0000-0000-0000000000c2', 'anon_race2', 'race_b', 'race2@example.com', '+21655550002'));
  perform pg_temp.try(pg_temp.raw_visitor('00000000-0000-0000-0000-0000000000c3', 'anon_race3', 'race_c', 'race3@example.com', '+21655550003', 'approved'));
  set local role service_role;
  perform pg_temp.expect('AC-12 a unique violation on the reviewing row keeps the approved attach',
    pg_temp.try(pg_temp.att('chk_race', array['race2@example.com', 'race3@example.com'], '{}', 1)), 'ok:1');
  reset role;
  if (select bound_account_id from public.seller_applications where id = '00000000-0000-0000-0000-0000000000c3') is distinct from 'chk_race'
     or (select bound_account_id from public.seller_applications where id = '00000000-0000-0000-0000-0000000000c2') is not null then
    raise exception 'FAIL AC-12: the race left the approved row unattached or attached the reviewing one';
  end if;
  raise notice 'ok   AC-12 a race on the one open rule never undoes the approved and rejected attaches';

  raise notice 'ALL CHECKS PASSED';
end;
$$;

rollback;
