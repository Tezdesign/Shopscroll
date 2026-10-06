-- Decision record: docs/specs/_root/0016-seller-application-admin-email/index.md (build plan task 2)
--
-- SQL checks for the admin email: AC-1, AC-3, AC-5 to AC-12 and AC-13 (the
-- database half). Run the whole file in the SQL editor of a TEST or BRANCH
-- database (or with psql) after applying migrations 0004 to 0007 and 0011. It
-- creates its own fixtures, switches role to act as each caller, and ends with
-- `rollback`, so it leaves no rows behind. A queued pg_net request is part of the
-- transaction, so a rolled back run sends no request and no email.
--
-- Output: one NOTICE per check. A failed check raises an error that starts with
-- FAIL and stops the script.
--
-- Not covered here, because SQL cannot see it: the Edge Functions, the Mailjet
-- call, a real pg_net post and the cron schedule firing (see verify.md).

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

-- Fixtures. chk_a and chk_b are buyers, chk_s is already a seller.
insert into public.user_profiles (id, name, username, role) values
  ('chk_a', 'Chk A', 'chk_a', 'buyer'),
  ('chk_b', 'Chk B', 'chk_b', 'buyer'),
  ('chk_c', 'Chk C', 'chk_c', 'buyer'),
  ('chk_d', 'Chk D', 'chk_d', 'buyer'),
  ('chk_s', 'Chk S', 'chk_s', 'seller');

do $$
declare
  a1 constant uuid := '00000000-0000-0000-0000-0000000000a1';
  a2 constant uuid := '00000000-0000-0000-0000-0000000000a2';
  a3 constant uuid := '00000000-0000-0000-0000-0000000000a3';
  a4 constant uuid := '00000000-0000-0000-0000-0000000000a4';
  a5 constant uuid := '00000000-0000-0000-0000-0000000000a5';
  a6 constant uuid := '00000000-0000-0000-0000-0000000000a6';
  a7 constant uuid := '00000000-0000-0000-0000-0000000000a7';
  v_app public.seller_applications;
  v_n integer;
  v_text text;
begin
  -- ---------------------------------------------------------------- AC-1, AC-12
  -- A new application starts unsent, and the insert works whether or not the
  -- Vault entries exist (the trigger never blocks it).
  insert into public.seller_applications
    (id, applicant_id, submitter_id, store_name, username, location, id_document_path)
  values
    (a1, 'chk_a', 'chk_a', 'Shop A', 'shop_a', 'Tunis', 'x'),
    (a2, 'chk_b', 'chk_b', 'Shop B', 'shop_b', 'Tunis', 'x');
  select * into v_app from public.seller_applications where id = a1;
  if v_app.admin_notified_at is not null or v_app.admin_notify_attempts <> 0
     or v_app.admin_notify_error is not null or v_app.admin_notify_claimed_at is not null then
    raise exception 'FAIL AC-1: a new application does not start unsent: %', v_app;
  end if;
  raise notice 'ok   AC-1 a new application starts unsent and the insert works';

  -- ---------------------------------------------------------------- AC-9 retry job
  -- Age two rows, so the one minute rule lets them through. a2 stays fresh.
  update public.seller_applications set created_at = now() - interval '2 minutes' where id = a1;
  insert into public.seller_applications
    (id, applicant_id, submitter_id, store_name, username, location, id_document_path,
     created_at, admin_notify_attempts)
  values
    (a3, 'chk_s', 'chk_s', 'Shop C', 'shop_c', 'Tunis', 'x', now() - interval '2 minutes', 10);
  insert into public.seller_applications
    (id, applicant_id, submitter_id, store_name, username, location, id_document_path,
     created_at, status, reviewed_at)
  values
    (a4, 'chk_d', 'chk_d', 'Shop D', 'shop_d', 'Tunis', 'x', now() - interval '2 minutes',
     'approved', now());
  insert into public.seller_applications
    (id, applicant_id, submitter_id, store_name, username, location, id_document_path,
     created_at, admin_notified_at)
  values
    (a5, 'chk_c', 'chk_c', 'Shop E', 'shop_e', 'Tunis', 'x', now() - interval '2 minutes', now());

  select public.retry_admin_notifications() into v_n;
  if v_n <> 1 then
    raise exception 'FAIL AC-9: the retry job posted % application(s), expected only a1', v_n;
  end if;
  if (select admin_notify_attempts from public.seller_applications where id = a1) <> 1 then
    raise exception 'FAIL AC-9: the job did not count the attempt itself';
  end if;
  if (select admin_notify_attempts from public.seller_applications where id = a2) <> 0
     or (select admin_notify_attempts from public.seller_applications where id = a3) <> 10
     or (select admin_notify_attempts from public.seller_applications where id = a4) <> 0
     or (select admin_notify_attempts from public.seller_applications where id = a5) <> 0 then
    raise exception 'FAIL AC-9: the job touched a fresh, exhausted, decided or already notified row';
  end if;
  raise notice 'ok   AC-9 the job picks only old unsent applications under review and counts the attempt';

  select public.retry_admin_notifications() into v_n;
  select public.retry_admin_notifications() into v_n;
  if (select admin_notify_attempts from public.seller_applications where id = a1) <> 3 then
    raise exception 'FAIL AC-9: attempts do not rise on each run';
  end if;
  raise notice 'ok   AC-9 attempts rise on each run (the limit of 10 is in the selection)';

  -- ---------------------------------------------------------------- AC-10 lease
  perform pg_temp.expect('AC-10 the first call takes the lease',
    pg_temp.try(format('select 1 from (select public.claim_admin_notification(%L) as c) t where c', a2)), 'ok:1');
  -- the first call above ran as the owner; check the table and a second call
  if (select admin_notify_claimed_at from public.seller_applications where id = a2) is null then
    raise exception 'FAIL AC-10: the lease was not recorded';
  end if;
  if public.claim_admin_notification(a2) then
    raise exception 'FAIL AC-10: a second call got the lease while it was held';
  end if;
  update public.seller_applications
  set admin_notify_claimed_at = now() - interval '3 minutes' where id = a2;
  if not public.claim_admin_notification(a2) then
    raise exception 'FAIL AC-10: an expired lease was not taken over';
  end if;
  if public.claim_admin_notification(a5) then
    raise exception 'FAIL AC-10: an already notified application gave out a lease';
  end if;
  raise notice 'ok   AC-10 one caller holds the lease, an expired one is taken over, a notified one gives none';

  -- ---------------------------------------------------------------- AC-11 permissions
  perform pg_temp.act_as('chk_a');
  perform pg_temp.expect('AC-11 a signed in client cannot read the tokens',
    pg_temp.try('select 1 from public.application_review_tokens'), 'err:42501');
  perform pg_temp.expect('AC-11 a signed in client cannot write a token',
    pg_temp.try(format($q$insert into public.application_review_tokens (application_id, token_hash, expires_at)
      values (%L, 'evil', now() + interval '1 day')$q$, a1)), 'err:42501');
  perform pg_temp.expect('AC-11 a signed in client cannot decide with a token',
    pg_temp.try($q$select public.decide_application_with_token('x', 'approve')$q$), 'err:42501');
  perform pg_temp.expect('AC-11 a signed in client cannot take the lease',
    pg_temp.try(format('select public.claim_admin_notification(%L)', a1)), 'err:42501');
  perform pg_temp.expect('AC-11 a signed in client cannot run the retry job',
    pg_temp.try('select public.retry_admin_notifications()'), 'err:42501');
  perform pg_temp.expect('AC-11 a signed in client cannot call the post helper',
    pg_temp.try(format('select public.admin_notify_post(%L)', a1)), 'err:42501');
  reset role;
  set local role anon;
  perform pg_temp.expect('AC-11 anon cannot read the tokens',
    pg_temp.try('select 1 from public.application_review_tokens'), 'err:42501');
  perform pg_temp.expect('AC-11 anon cannot decide with a token',
    pg_temp.try($q$select public.decide_application_with_token('x', 'approve')$q$), 'err:42501');
  reset role;
  raise notice 'ok   AC-11 only the service role reaches the tokens, the lease and the decision';

  -- ---------------------------------------------------------------- AC-3 tokens
  insert into public.application_review_tokens (application_id, token_hash, expires_at) values
    (a1, 'tok_ok',      now() + interval '7 days'),
    (a2, 'tok_expired', now() - interval '1 minute'),
    (a4, 'tok_decided', now() + interval '7 days'),
    (a3, 'tok_seller',  now() + interval '7 days'),
    (a1, 'tok_reject',  now() + interval '7 days');
  perform pg_temp.expect('AC-3 a token hash is unique',
    pg_temp.try(format($q$insert into public.application_review_tokens (application_id, token_hash, expires_at)
      values (%L, 'tok_ok', now() + interval '1 day')$q$, a2)),
    'err:23505');

  -- ---------------------------------------------------------------- AC-5 to AC-8 decisions
  set local role service_role;
  perform pg_temp.expect('AC-7 an unknown token is invalid_link',
    pg_temp.try($q$select public.decide_application_with_token('nope', 'approve')$q$), 'err:P0001:invalid_link');
  perform pg_temp.expect('AC-7 an expired token is invalid_link',
    pg_temp.try($q$select public.decide_application_with_token('tok_expired', 'approve')$q$), 'err:P0001:invalid_link');
  perform pg_temp.expect('AC-6 reject with no reason is refused',
    pg_temp.try($q$select public.decide_application_with_token('tok_reject', 'reject', '   ')$q$), 'err:P0001:reason_required');
  perform pg_temp.expect('AC-6 reject with a reason over 500 characters is refused',
    pg_temp.try(format($q$select public.decide_application_with_token('tok_reject', 'reject', %L)$q$, repeat('x', 501))), 'err:P0001:reason_required');
  perform pg_temp.expect('AC-5 a bad action is refused',
    pg_temp.try($q$select public.decide_application_with_token('tok_ok', 'maybe')$q$), 'err:P0001:invalid_field');
  reset role;
  if (select used_at from public.application_review_tokens where token_hash = 'tok_reject') is not null
     or (select status from public.seller_applications where id = a1) <> 'reviewing' then
    raise exception 'FAIL AC-6: a refused reject changed the token or the application';
  end if;
  raise notice 'ok   AC-6 a refused reject leaves the token usable and the application as it was';

  set local role service_role;
  select public.decide_application_with_token('tok_reject', 'reject', '  ID photo is blurry  ') into v_text;
  reset role;
  if v_text <> 'rejected' then
    raise exception 'FAIL AC-6: reject returned %', v_text;
  end if;
  select * into v_app from public.seller_applications where id = a1;
  if v_app.status <> 'rejected' or v_app.rejection_reason <> 'ID photo is blurry'
     or v_app.reviewed_by <> 'email review' or v_app.reviewed_at is null then
    raise exception 'FAIL AC-6: application not rejected as expected: %', v_app;
  end if;
  if (select used_at from public.application_review_tokens where token_hash = 'tok_reject') is null then
    raise exception 'FAIL AC-6: the token was not marked used';
  end if;
  raise notice 'ok   AC-6 reject records the reason and reviewer and uses the token';

  -- A second token for the same application: the application is decided, so the
  -- answer is not_reviewing and the token is used up (AC-8).
  set local role service_role;
  select public.decide_application_with_token('tok_ok', 'approve') into v_text;
  perform pg_temp.expect('AC-7 a used token is invalid_link',
    pg_temp.try($q$select public.decide_application_with_token('tok_reject', 'approve')$q$), 'err:P0001:invalid_link');
  reset role;
  if v_text <> 'not_reviewing'
     or (select used_at from public.application_review_tokens where token_hash = 'tok_ok') is null
     or (select status from public.seller_applications where id = a1) <> 'rejected' then
    raise exception 'FAIL AC-8: an already decided application was not reported (got %)', v_text;
  end if;
  raise notice 'ok   AC-8 an already decided application says not_reviewing and uses the token';

  -- approve on a profile that is already a seller: refused, token still usable
  set local role service_role;
  perform pg_temp.expect('AC-8 approving an existing seller is refused (already_seller)',
    pg_temp.try($q$select public.decide_application_with_token('tok_seller', 'approve')$q$), 'err:P0001:already_seller');
  reset role;
  if (select used_at from public.application_review_tokens where token_hash = 'tok_seller') is not null
     or (select status from public.seller_applications where id = a3) <> 'reviewing' then
    raise exception 'FAIL AC-8: a refused approval used the token or changed the application';
  end if;
  raise notice 'ok   AC-8 a refused approval leaves the token usable';

  -- the happy approve, on a visitor-style account application for chk_b
  insert into public.application_review_tokens (application_id, token_hash, expires_at)
  values (a2, 'tok_approve', now() + interval '7 days');
  set local role service_role;
  select public.decide_application_with_token('tok_approve', 'approve') into v_text;
  reset role;
  select * into v_app from public.seller_applications where id = a2;
  if v_text <> 'approved' or v_app.status <> 'approved' or v_app.reviewed_by <> 'email review'
     or (select role from public.user_profiles where id = 'chk_b') <> 'seller'
     or (select used_at from public.application_review_tokens where token_hash = 'tok_approve') is null then
    raise exception 'FAIL AC-5: approve did not go through as expected (got %)', v_text;
  end if;
  raise notice 'ok   AC-5 approve decides through the 0013 function, makes the seller and uses the token';

  -- ---------------------------------------------------------------- AC-13 cascade
  select count(*) into v_n from public.application_review_tokens where application_id = a1;
  if v_n = 0 then
    raise exception 'FAIL AC-13: fixture error, a1 has no tokens';
  end if;
  delete from public.seller_applications where id = a1;
  select count(*) into v_n from public.application_review_tokens where application_id = a1;
  if v_n <> 0 then
    raise exception 'FAIL AC-13: deleting an application left % token(s)', v_n;
  end if;
  raise notice 'ok   AC-13 deleting an application deletes its tokens';

  -- token cleanup in the retry job
  insert into public.application_review_tokens (application_id, token_hash, expires_at) values
    (a4, 'tok_old', now() - interval '31 days'),
    (a4, 'tok_recent', now() - interval '1 day');
  perform public.retry_admin_notifications();
  if exists (select 1 from public.application_review_tokens where token_hash = 'tok_old')
     or not exists (select 1 from public.application_review_tokens where token_hash = 'tok_recent') then
    raise exception 'FAIL AC-13: the job did not remove only tokens expired for more than 30 days';
  end if;
  raise notice 'ok   AC-13 the job removes tokens expired for more than 30 days';

  raise notice 'ALL CHECKS PASSED';
end;
$$;

rollback;
