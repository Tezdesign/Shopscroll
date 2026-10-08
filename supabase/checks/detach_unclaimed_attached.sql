-- Decision record: docs/specs/_root/0014-shared-login-seller-area/index.md
-- (AC-16, build plan task 11)
--
-- SQL check for the detach step of migration 0013. Unlike the other checks it
-- applies the migration itself, because it tests what the migration does to
-- rows that already exist. Run it with psql from the repo root, on a TEST or
-- BRANCH database that has migrations 0001 to 0012 and NOT yet 0013:
--
--   psql "$TEST_DATABASE_URL" -f supabase/checks/detach_unclaimed_attached.sql
--
-- It builds its own rows, applies 0013 inside the transaction, checks the rows
-- and ends with `rollback`, so 0013 is not applied afterwards. The migration
-- prints one NOTICE for the row that stays attached.

begin;

insert into public.user_profiles (id, name, username, role) values
  ('chk_w', 'Chk W', 'chk_w', 'seller');

-- A visitor row as the table owner. Phone and email are unique per reviewing row.
create function pg_temp.raw(
  p_n integer, p_session text, p_status text, p_bound text default null,
  p_applicant text default null, p_claimed boolean default false
) returns void language sql as $$
  insert into public.seller_applications (id, origin, applicant_id, submitter_id,
    bound_account_id, claimed_at, applicant_name, applicant_email, applicant_phone,
    store_name, username, location, id_document_path, status, rejection_reason)
  values (
    ('00000000-0000-0000-0000-0000000000d' || p_n)::uuid, 'visitor', p_applicant,
    p_session, p_bound, case when p_claimed then now() end, 'Raw Visitor',
    'raw' || p_n || '@example.com', '+2169999000' || p_n, 'Raw', 'raw_shop_' || p_n,
    'Tunis', 'x', p_status, case when p_status = 'rejected' then 'no' end);
$$;

select pg_temp.raw(1, 'anon_d1', 'approved', 'chk_x');
select pg_temp.raw(2, 'anon_d2', 'rejected', 'chk_x');
select pg_temp.raw(3, 'anon_d3', 'reviewing', 'chk_y');
-- d4 is attached and its session also has a free reviewing row (d5), so detaching
-- d4 would put two reviewing rows on the session.
select pg_temp.raw(4, 'anon_d4', 'reviewing', 'chk_z');
select pg_temp.raw(5, 'anon_d4', 'reviewing');
-- d6 is claimed, d7 is free and approved.
select pg_temp.raw(6, 'anon_d6', 'approved', 'chk_w', 'chk_w', true);
select pg_temp.raw(7, 'anon_d7', 'approved');

\i supabase/migrations/0013_attach_by_verified_contact.sql

do $$
declare
  d constant text := '00000000-0000-0000-0000-0000000000d';
  v_bound text;
begin
  select bound_account_id into v_bound from public.seller_applications where id = (d || 1)::uuid;
  if v_bound is not null then raise exception 'FAIL AC-16: an approved attached row stayed attached'; end if;
  select bound_account_id into v_bound from public.seller_applications where id = (d || 2)::uuid;
  if v_bound is not null then raise exception 'FAIL AC-16: a rejected attached row stayed attached'; end if;
  raise notice 'ok   AC-16 approved and rejected attached rows are detached';

  select bound_account_id into v_bound from public.seller_applications where id = (d || 3)::uuid;
  if v_bound is not null then raise exception 'FAIL AC-16: a reviewing attached row stayed attached'; end if;
  raise notice 'ok   AC-16 a reviewing attached row is detached';

  select bound_account_id into v_bound from public.seller_applications where id = (d || 4)::uuid;
  if v_bound is distinct from 'chk_z' then
    raise exception 'FAIL AC-16: the conflicting reviewing row was detached or moved: %', v_bound;
  end if;
  raise notice 'ok   AC-16 a row whose detach would break the one open rule stays attached';

  select bound_account_id into v_bound from public.seller_applications where id = (d || 6)::uuid;
  if v_bound is distinct from 'chk_w' then raise exception 'FAIL AC-16: a claimed row was changed'; end if;
  if (select applicant_id from public.seller_applications where id = (d || 6)::uuid) is distinct from 'chk_w' then
    raise exception 'FAIL AC-16: a claimed row lost its applicant';
  end if;
  raise notice 'ok   AC-16 a claimed row is untouched';

  if (select count(*) from public.seller_applications where bound_account_id is not null) <> 2 then
    raise exception 'FAIL AC-16: expected exactly the conflicting and the claimed row to stay attached';
  end if;
  raise notice 'ALL CHECKS PASSED';
end;
$$;

rollback;
