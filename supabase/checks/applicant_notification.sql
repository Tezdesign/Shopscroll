-- Decision record: docs/specs/_root/0017-applicant-decision-email/index.md (build plan task 2)
--
-- SQL checks for the applicant decision email and the attach by verified contact
-- (spec 0014 AC-12, which replaced the 0017 email attach): AC-1, AC-2 (the
-- database half), AC-6 to AC-8, AC-10 and AC-13. Run the whole file in the SQL
-- editor of a TEST or BRANCH database (or with psql) after applying migrations
-- 0004 to 0007 and 0011 to 0013. It creates its own fixtures, switches
-- role to act as each caller, and ends with `rollback`, so it leaves no rows
-- behind. A queued pg_net request is part of the transaction, so a rolled back
-- run sends no request and no email. The trigger and retry checks count the
-- requests in net.http_request_queue; if the Vault entries do not exist yet, the
-- script creates throw away ones inside the transaction (also rolled back).
--
-- Output: one NOTICE per check. A failed check raises an error that starts with
-- FAIL and stops the script.
--
-- Not covered here, because SQL cannot see it: the Edge Functions, the Mailjet
-- call, a real pg_net post, the Clerk lookup and the cron schedule firing (see
-- verify.md). The backfill of old decided rows (AC-7) runs once inside the
-- migration, so check it by hand right after applying 0012 (verify.md).

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

create function pg_temp.queued() returns bigint
language sql as $$ select count(*) from net.http_request_queue $$;

-- Fixtures. chk_a to chk_i are buyers, chk_s is already a seller. chk_c has an
-- open (reviewing) account application of its own.
insert into public.user_profiles (id, name, username, role, email) values
  ('chk_a', 'Chk A', 'chk_a', 'buyer', 'a@example.com'),
  ('chk_b', 'Chk B', 'chk_b', 'buyer', null),
  ('chk_c', 'Chk C', 'chk_c', 'buyer', null),
  ('chk_d', 'Chk D', 'chk_d', 'buyer', null),
  ('chk_e', 'Chk E', 'chk_e', 'buyer', 'e@example.com'),
  ('chk_f', 'Chk F', 'chk_f', 'buyer', null),
  ('chk_g', 'Chk G', 'chk_g', 'buyer', null),
  ('chk_h', 'Chk H', 'chk_h', 'buyer', null),
  ('chk_i', 'Chk I', 'chk_i', 'buyer', null),
  ('chk_s', 'Chk S', 'chk_s', 'seller', null);

insert into storage.objects (bucket_id, name) values
  ('application-documents', 'chk_e/00000000-0000-0000-0000-0000000000e1/id-1.jpg'),
  ('application-documents', 'chk_f/00000000-0000-0000-0000-0000000000f1/id-1.jpg'),
  ('application-documents', 'chk_g/00000000-0000-0000-0000-0000000000a1/id-1.jpg'),
  ('application-documents', 'chk_g/00000000-0000-0000-0000-0000000000a2/id-1.jpg'),
  ('application-documents', 'chk_g/00000000-0000-0000-0000-0000000000a3/id-1.jpg');

do $$
declare
  n1 constant uuid := '00000000-0000-0000-0000-0000000000b1';
  n2 constant uuid := '00000000-0000-0000-0000-0000000000b2';
  n3 constant uuid := '00000000-0000-0000-0000-0000000000b3';
  n4 constant uuid := '00000000-0000-0000-0000-0000000000b4';
  r1 constant uuid := '00000000-0000-0000-0000-0000000000c1';
  r2 constant uuid := '00000000-0000-0000-0000-0000000000c2';
  r3 constant uuid := '00000000-0000-0000-0000-0000000000c3';
  r4 constant uuid := '00000000-0000-0000-0000-0000000000c4';
  r5 constant uuid := '00000000-0000-0000-0000-0000000000c5';
  r6 constant uuid := '00000000-0000-0000-0000-0000000000c6';
  r7 constant uuid := '00000000-0000-0000-0000-0000000000c7';
  v1 constant uuid := '00000000-0000-0000-0000-0000000000d1';
  v2 constant uuid := '00000000-0000-0000-0000-0000000000d2';
  v3 constant uuid := '00000000-0000-0000-0000-0000000000d3';
  v4 constant uuid := '00000000-0000-0000-0000-0000000000d4';
  v5 constant uuid := '00000000-0000-0000-0000-0000000000d5';
  v6 constant uuid := '00000000-0000-0000-0000-0000000000d6';
  e1 constant uuid := '00000000-0000-0000-0000-0000000000e1';
  f1 constant uuid := '00000000-0000-0000-0000-0000000000f1';
  g1 constant uuid := '00000000-0000-0000-0000-0000000000a1';
  g2 constant uuid := '00000000-0000-0000-0000-0000000000a2';
  g3 constant uuid := '00000000-0000-0000-0000-0000000000a3';
  v_app public.seller_applications;
  v_before bigint;
  v_n integer;
begin
  -- ---------------------------------------------------------------- AC-1 new rows
  -- A new application starts unsent, and a decision works whether or not the Vault
  -- entries exist (the trigger never blocks it).
  insert into public.seller_applications
    (id, applicant_id, submitter_id, store_name, username, location, id_document_path)
  values
    (n1, 'chk_a', 'chk_a', 'Shop A', 'shop_a', 'Tunis', 'x'),
    (n2, 'chk_b', 'chk_b', 'Shop B', 'shop_b', 'Tunis', 'x'),
    (n3, 'chk_c', 'chk_c', 'Shop C', 'shop_c', 'Tunis', 'x'),
    (n4, 'chk_d', 'chk_d', 'Shop D', 'shop_d', 'Tunis', 'x');
  select * into v_app from public.seller_applications where id = n1;
  if v_app.applicant_notified_at is not null or v_app.applicant_notify_attempts <> 0
     or v_app.applicant_notify_error is not null or v_app.applicant_notify_claimed_at is not null then
    raise exception 'FAIL AC-1: a new application does not start unsent: %', v_app;
  end if;
  raise notice 'ok   AC-1 a new application starts unsent';

  update public.seller_applications set status = 'approved' where id = n4;
  if (select status from public.seller_applications where id = n4) <> 'approved' then
    raise exception 'FAIL AC-1: a decision failed because of the notification setup';
  end if;
  raise notice 'ok   AC-1 a decision succeeds even when the notification setup is incomplete';

  -- ---------------------------------------------------------------- AC-1 trigger
  if not exists (select 1 from vault.decrypted_secrets where name = 'applicant_notify_url') then
    perform vault.create_secret('https://example.invalid/notify-applicant-decision', 'applicant_notify_url');
  end if;
  if not exists (select 1 from vault.decrypted_secrets where name = 'admin_notify_secret') then
    perform vault.create_secret('check-secret', 'admin_notify_secret');
  end if;

  v_before := pg_temp.queued();
  update public.seller_applications set applicant_name = 'x' where id = n1;
  update public.seller_applications set bio = 'changed' where id = n1;
  if pg_temp.queued() <> v_before then
    raise exception 'FAIL AC-1: an update of another column queued a post';
  end if;
  raise notice 'ok   AC-1 an update that does not touch the status posts nothing';

  update public.seller_applications set status = 'approved' where id = n1;
  if pg_temp.queued() <> v_before + 1 then
    raise exception 'FAIL AC-1: reviewing to approved did not queue exactly one post';
  end if;
  update public.seller_applications
  set status = 'rejected', rejection_reason = 'Photo is blurry' where id = n2;
  if pg_temp.queued() <> v_before + 2 then
    raise exception 'FAIL AC-1: reviewing to rejected did not queue exactly one post';
  end if;
  raise notice 'ok   AC-1 reviewing to approved and reviewing to rejected each queue one post';

  v_before := pg_temp.queued();
  update public.seller_applications
  set status = 'rejected', rejection_reason = 'Changed my mind' where id = n1;
  update public.seller_applications set status = 'reviewing' where id = n1;
  update public.seller_applications set status = 'approved' where id = n1;
  if pg_temp.queued() <> v_before + 1 then
    raise exception 'FAIL AC-1: only the reviewing to decided step should post, queued %',
      pg_temp.queued() - v_before;
  end if;
  raise notice 'ok   AC-1 decided to decided and decided to reviewing post nothing';

  -- ---------------------------------------------------------------- AC-6 retry job
  -- r1 and r2 are picked, the rest are not. All are decided two minutes ago
  -- unless noted.
  insert into public.seller_applications
    (id, applicant_id, submitter_id, store_name, username, location, id_document_path,
     status, rejection_reason, reviewed_at, applicant_notified_at,
     applicant_notify_attempts, applicant_notify_error)
  values
    (r1, 'chk_e', 'chk_e', 'R1', 'shop_r1', 'Tunis', 'x', 'approved', null, now() - interval '2 minutes', null, 0, null),
    (r2, 'chk_f', 'chk_f', 'R2', 'shop_r2', 'Tunis', 'x', 'rejected', 'Reason', now() - interval '2 minutes', null, 9, 'mailjet_http_500'),
    (r3, 'chk_g', 'chk_g', 'R3', 'shop_r3', 'Tunis', 'x', 'approved', null, now(), null, 0, null),
    (r4, 'chk_h', 'chk_h', 'R4', 'shop_r4', 'Tunis', 'x', 'approved', null, now() - interval '2 minutes', null, 10, 'mailjet_http_500'),
    (r5, 'chk_a', 'chk_a', 'R5', 'shop_r5', 'Tunis', 'x', 'approved', null, now() - interval '2 minutes', now(), 0, null),
    (r6, 'chk_b', 'chk_b', 'R6', 'shop_r6', 'Tunis', 'x', 'approved', null, now() - interval '2 minutes', null, 0, 'no_recipient');
  insert into public.seller_applications
    (id, applicant_id, submitter_id, store_name, username, location, id_document_path,
     created_at)
  values
    (r7, 'chk_d', 'chk_d', 'R7', 'shop_r7', 'Tunis', 'x', now() - interval '2 minutes');

  v_before := pg_temp.queued();
  v_n := public.retry_applicant_notifications();
  if v_n <> 2 or pg_temp.queued() <> v_before + 2 then
    raise exception 'FAIL AC-6: the retry job posted % row(s) and queued %, expected 2 and 2',
      v_n, pg_temp.queued() - v_before;
  end if;
  if (select applicant_notify_attempts from public.seller_applications where id = r1) <> 1
     or (select applicant_notify_attempts from public.seller_applications where id = r2) <> 10 then
    raise exception 'FAIL AC-6: the job did not count the attempt itself';
  end if;
  if (select applicant_notify_attempts from public.seller_applications where id = r3) <> 0
     or (select applicant_notify_attempts from public.seller_applications where id = r4) <> 10
     or (select applicant_notify_attempts from public.seller_applications where id = r5) <> 0
     or (select applicant_notify_attempts from public.seller_applications where id = r6) <> 0
     or (select applicant_notify_attempts from public.seller_applications where id = r7) <> 0 then
    raise exception 'FAIL AC-6: the job touched a fresh, exhausted, notified, no_recipient or reviewing row';
  end if;
  raise notice 'ok   AC-6 the job picks only old unsent decisions under 10 attempts and counts the attempt';

  v_n := public.retry_applicant_notifications();
  if v_n <> 1 or (select applicant_notify_attempts from public.seller_applications where id = r1) <> 2 then
    raise exception 'FAIL AC-6: the second run should post only r1, posted %', v_n;
  end if;
  raise notice 'ok   AC-6 a row at 10 attempts is not tried again';

  -- ---------------------------------------------------------------- AC-6 lease
  if not public.claim_applicant_notification(r1) then
    raise exception 'FAIL AC-6: the first call did not get the lease';
  end if;
  if public.claim_applicant_notification(r1) then
    raise exception 'FAIL AC-6: a second call got the lease while it was held';
  end if;
  update public.seller_applications
  set applicant_notify_claimed_at = now() - interval '3 minutes' where id = r1;
  if not public.claim_applicant_notification(r1) then
    raise exception 'FAIL AC-6: an expired lease was not taken over';
  end if;
  if public.claim_applicant_notification(r5) then
    raise exception 'FAIL AC-6: an already notified application gave out a lease';
  end if;
  if public.claim_applicant_notification(r7) then
    raise exception 'FAIL AC-6: an application still under review gave out a lease';
  end if;
  raise notice 'ok   AC-6 one caller holds the lease, an expired one is taken over, notified and reviewing rows give none';

  -- ---------------------------------------------------------------- AC-10 permissions
  perform pg_temp.act_as('chk_a');
  perform pg_temp.expect('AC-10 a signed in client cannot take the lease',
    pg_temp.try(format('select public.claim_applicant_notification(%L)', r1)), 'err:42501');
  perform pg_temp.expect('AC-10 a signed in client cannot run the retry job',
    pg_temp.try('select public.retry_applicant_notifications()'), 'err:42501');
  perform pg_temp.expect('AC-10 a signed in client cannot call the post helper',
    pg_temp.try(format('select public.applicant_notify_post(%L)', r1)), 'err:42501');
  perform pg_temp.expect('AC-10 a signed in client cannot call the trigger function',
    pg_temp.try('select public.notify_applicant_decision()'), 'err:42501');
  perform pg_temp.expect('AC-10 a signed in client cannot call has_unattached_visitor_applications',
    pg_temp.try('select public.has_unattached_visitor_applications()'), 'err:42501');
  perform pg_temp.expect('AC-10 a signed in client cannot attach by contact',
    pg_temp.try($q$select public.attach_applications_by_contact('chk_a', array['x@example.com'], '{}')$q$), 'err:42501');
  reset role;
  set local role anon;
  perform pg_temp.expect('AC-10 anon cannot take the lease',
    pg_temp.try(format('select public.claim_applicant_notification(%L)', r1)), 'err:42501');
  perform pg_temp.expect('AC-10 anon cannot attach by contact',
    pg_temp.try($q$select public.attach_applications_by_contact('chk_a', array['x@example.com'], '{}')$q$), 'err:42501');
  perform pg_temp.expect('AC-10 anon cannot call has_unattached_visitor_applications',
    pg_temp.try('select public.has_unattached_visitor_applications()'), 'err:42501');
  reset role;
  raise notice 'ok   AC-10 no client reaches the lease, the job, the post helper or the attach functions';

  -- ---------------------------------------------------------------- AC-12 attach by contact
  -- Visitor rows. Oldest first by created_at: v1 before v2.
  insert into public.seller_applications
    (id, origin, submitter_id, applicant_name, applicant_email, applicant_phone,
     store_name, username, location, id_document_path, status, rejection_reason,
     reviewed_at, created_at, bound_account_id, claimed_at)
  values
    (v1, 'visitor', 'anon_1', 'V One', 'person@example.com', '+101', 'V1', 'vis_one', 'Tunis', 'x',
     'approved', null, now(), now() - interval '3 days', null, null),
    (v2, 'visitor', 'anon_2', 'V Two', 'person@example.com', '+102', 'V2', 'vis_two', 'Tunis', 'x',
     'approved', null, now(), now() - interval '2 days', null, null),
    (v3, 'visitor', 'anon_3', 'V Three', 'waiting@example.com', '+103', 'V3', 'vis_three', 'Tunis', 'x',
     'reviewing', null, null, now(), null, null),
    (v4, 'visitor', 'anon_4', 'V Four', 'rejected@example.com', '+104', 'V4', 'vis_four', 'Tunis', 'x',
     'rejected', 'No', now(), now(), null, null),
    (v5, 'visitor', 'anon_5', 'V Five', 'taken@example.com', '+105', 'V5', 'vis_five', 'Tunis', 'x',
     'approved', null, now(), now(), 'chk_h', null),
    (v6, 'visitor', 'anon_6', 'V Six', 'claimed@example.com', '+106', 'V6', 'vis_six', 'Tunis', 'x',
     'approved', null, now(), now(), 'chk_h', now());

  set local role service_role;
  if public.has_unattached_visitor_applications() is not true then
    raise exception 'FAIL AC-12: a free visitor application exists but the check says no';
  end if;
  perform pg_temp.expect('AC-12 a null, empty or blank list attaches nothing',
    pg_temp.try($q$select 1 where public.attach_applications_by_contact('chk_a', null, null) = 0
                   and public.attach_applications_by_contact('chk_a', '{}', '{}') = 0
                   and public.attach_applications_by_contact('chk_a', array['   '], array['']) = 0$q$), 'ok:1');
  perform pg_temp.expect('AC-12 a row attached to another account is never taken',
    pg_temp.try($q$select 1 where public.attach_applications_by_contact('chk_a', array['taken@example.com'], array['+105']) = 0$q$), 'ok:1');
  perform pg_temp.expect('AC-12 a claimed row is never taken',
    pg_temp.try($q$select 1 where public.attach_applications_by_contact('chk_a', array['claimed@example.com'], array['+106']) = 0$q$), 'ok:1');
  perform pg_temp.expect('AC-12 an existing seller is never attached',
    pg_temp.try($q$select 1 where public.attach_applications_by_contact('chk_s', array['person@example.com', 'waiting@example.com', 'rejected@example.com'], '{}') = 0$q$), 'ok:1');
  perform pg_temp.expect('AC-12 a reviewing row is skipped when the account has an open application of its own',
    pg_temp.try($q$select 1 where public.attach_applications_by_contact('chk_c', array['waiting@example.com'], array['+103']) = 0$q$), 'ok:1');
  reset role;
  if exists (select 1 from public.seller_applications
             where id in (v1, v2, v3, v4) and bound_account_id is not null) then
    raise exception 'FAIL AC-12: a refused attach still changed a row';
  end if;
  raise notice 'ok   AC-12 taken, claimed rows, a seller and an account with an open application attach nothing';

  -- A reviewing and a rejected row attach to an account with no open application,
  -- by email and by phone. Each is put back afterwards.
  set local role service_role;
  perform pg_temp.expect('AC-12 a verified email attaches a reviewing row',
    pg_temp.try($q$select 1 where public.attach_applications_by_contact('chk_a', array['waiting@example.com'], '{}') = 1$q$), 'ok:1');
  perform pg_temp.expect('AC-12 a verified phone attaches a rejected row',
    pg_temp.try($q$select 1 where public.attach_applications_by_contact('chk_d', '{}', array['+104']) = 1$q$), 'ok:1');
  reset role;
  if (select bound_account_id from public.seller_applications where id = v3) is distinct from 'chk_a'
     or (select bound_account_id from public.seller_applications where id = v4) is distinct from 'chk_d' then
    raise exception 'FAIL AC-12: the reviewing or the rejected row was not attached';
  end if;
  update public.seller_applications set bound_account_id = null where id in (v3, v4);
  raise notice 'ok   AC-12 reviewing and rejected rows attach by email or phone';

  -- chk_b has an attached open row, so a second reviewing row does not attach to it.
  -- (v8 is a second free reviewing row with another email.)
  insert into public.seller_applications
    (id, origin, submitter_id, applicant_name, applicant_email, applicant_phone,
     store_name, username, location, id_document_path, status, created_at)
  values
    ('00000000-0000-0000-0000-0000000000d8', 'visitor', 'anon_8', 'V Eight', 'second@example.com', '+108',
     'V8', 'vis_eight', 'Tunis', 'x', 'reviewing', now());
  update public.seller_applications set bound_account_id = 'chk_b' where id = v3;
  set local role service_role;
  perform pg_temp.expect('AC-12 an account with an attached open application takes no second reviewing row',
    pg_temp.try($q$select 1 where public.attach_applications_by_contact('chk_b', array['second@example.com'], '{}') = 0$q$), 'ok:1');
  reset role;
  update public.seller_applications set bound_account_id = null where id = v3;
  delete from public.seller_applications where id = '00000000-0000-0000-0000-0000000000d8';

  -- The real attach: mixed case and spaces in the list still match, and both
  -- approved rows attach (approved rows always do).
  set local role service_role;
  select public.attach_applications_by_contact('chk_i', array['nobody@example.com', '  PERSON@Example.COM  '], '{}') into v_n;
  reset role;
  if v_n <> 2
     or (select bound_account_id from public.seller_applications where id = v1) is distinct from 'chk_i'
     or (select bound_account_id from public.seller_applications where id = v2) is distinct from 'chk_i' then
    raise exception 'FAIL AC-12: expected both approved rows attached to chk_i, got % attached', v_n;
  end if;
  raise notice 'ok   AC-12 mixed case and spaces match, every matching approved row attaches';

  -- The profile and the application are otherwise untouched, and the normal claim works on it.
  if (select role from public.user_profiles where id = 'chk_i') <> 'buyer' then
    raise exception 'FAIL AC-12: attaching by itself changed the profile';
  end if;
  set local role service_role;
  if (select count(*) from public.find_claimable_application('chk_i')) <> 1 then
    raise exception 'FAIL AC-12: find_claimable_application does not see the attached row';
  end if;
  reset role;
  raise notice 'ok   AC-12 an attached row is found by the normal claim lookup';

  -- ---------------------------------------------------------------- AC-8 the applicant email
  perform pg_temp.act_as('chk_e');
  perform pg_temp.expect('AC-8 a valid personal email is accepted',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop E', 'shop_e', 'Tunis', %L,
      null, null, null, null, null, null, '  Me@Example.COM ')$q$, e1,
      'chk_e/00000000-0000-0000-0000-0000000000e1/id-1.jpg')), 'ok:1');
  reset role;
  select * into v_app from public.seller_applications where id = e1;
  if v_app.applicant_email is distinct from 'me@example.com' then
    raise exception 'FAIL AC-8: the email was not trimmed and lowercased, got %', v_app.applicant_email;
  end if;
  if (select email from public.user_profiles where id = 'chk_e') <> 'e@example.com' then
    raise exception 'FAIL AC-8: the personal email was copied to the profile';
  end if;
  raise notice 'ok   AC-8 the email is trimmed, stored lowercase and never copied to the profile';

  -- the old 11 argument call (an older app build) keeps working
  perform pg_temp.act_as('chk_f');
  perform pg_temp.expect('AC-8 an older build that sends no email still submits',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop F', 'shop_f', 'Tunis', %L)$q$, f1,
      'chk_f/00000000-0000-0000-0000-0000000000f1/id-1.jpg')), 'ok:1');
  reset role;
  if (select applicant_email from public.seller_applications where id = f1) is not null then
    raise exception 'FAIL AC-8: an application with no email stored one';
  end if;
  raise notice 'ok   AC-8 no email leaves applicant_email empty';

  perform pg_temp.act_as('chk_g');
  perform pg_temp.expect('AC-8 a bad email is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop G', 'shop_g', 'Tunis', %L,
      null, null, null, null, null, null, 'not an email')$q$, g1,
      'chk_g/00000000-0000-0000-0000-0000000000a1/id-1.jpg')), 'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 an email over 200 characters is refused',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop G', 'shop_g', 'Tunis', %L,
      null, null, null, null, null, null, %L)$q$, g2,
      'chk_g/00000000-0000-0000-0000-0000000000a2/id-1.jpg', repeat('a', 196) || '@x.com')), 'err:P0001:invalid_field');
  perform pg_temp.expect('AC-8 a blank email counts as not given',
    pg_temp.try(format($q$select public.submit_seller_application(%L, 'Shop G', 'shop_g', 'Tunis', %L,
      null, null, null, null, null, null, '   ')$q$, g3,
      'chk_g/00000000-0000-0000-0000-0000000000a3/id-1.jpg')), 'ok:1');
  reset role;
  if (select applicant_email from public.seller_applications where id = g3) is not null
     or exists (select 1 from public.seller_applications where id in (g1, g2)) then
    raise exception 'FAIL AC-8: a refused email left a row, or a blank email was stored';
  end if;
  raise notice 'ok   AC-8 a refused email leaves no row, a blank one is stored as empty';

  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'submit_seller_application'
    group by p.proname having count(*) > 1
  ) then
    raise exception 'FAIL AC-8: two overloads of submit_seller_application exist';
  end if;
  raise notice 'ok   AC-8 only one submit_seller_application overload exists';

  -- ---------------------------------------------------------------- AC-13 no personal data
  if exists (
    select 1 from public.seller_applications
    where applicant_notify_error is not null
      and applicant_notify_error !~ '^[a-z0-9_]{1,40}$'
  ) then
    raise exception 'FAIL AC-13: applicant_notify_error holds something other than a short code';
  end if;
  raise notice 'ok   AC-13 applicant_notify_error holds short codes only';

  raise notice 'ALL CHECKS PASSED';
end;
$$;

rollback;
