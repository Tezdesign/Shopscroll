-- Decision record: docs/specs/_root/0016-seller-application-admin-email/index.md
--
-- Tell the admin about every new seller application. An after insert trigger on
-- seller_applications posts the application id to the Edge Function
-- notify-admin-application (pg_net, the address and shared secret come from
-- Supabase Vault), which sends the email through Mailjet. A job every 5 minutes
-- retries applications that are still unsent. Decisions from the email's review
-- page go through decide_application_with_token, which claims the one time
-- token and calls the 0013 approve or reject function in one transaction.
--
-- Safe to apply while the current app builds run: it only adds columns, a table,
-- functions, a trigger and a job. Existing rows are marked as notified, so no old
-- application sends an email.
--
-- BEFORE the emails work, set these once by hand (the values never live in this
-- repo), then deploy the two Edge Functions with --no-verify-jwt:
--   select vault.create_secret('https://<project>.supabase.co/functions/v1/notify-admin-application', 'admin_notify_url');
--   select vault.create_secret('<the same value as the ADMIN_NOTIFY_SECRET function secret>', 'admin_notify_secret');
-- Without them the trigger and the job do nothing, and applications work as before.
--
-- Rollback: drop the trigger seller_applications_notify_admin, unschedule the
-- job (select cron.unschedule('retry_admin_notifications')), drop the functions
-- (notify_admin_new_application, admin_notify_post, retry_admin_notifications,
-- claim_admin_notification, decide_application_with_token), drop the table
-- application_review_tokens and the four admin_notify columns.

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

-- ------------------------------------------------------------
-- 1. Columns and token table
-- ------------------------------------------------------------
alter table public.seller_applications
  add column admin_notified_at timestamptz,
  add column admin_notify_attempts integer not null default 0,
  add column admin_notify_error text,
  add column admin_notify_claimed_at timestamptz;

-- Existing applications were seen by the admin already: no email for them.
update public.seller_applications
set admin_notified_at = now()
where admin_notified_at is null;

-- One row per review link that was emailed. Only the hash of the random token is
-- stored, the raw token exists only in the email. Service role only: row level
-- security on, no policy, no grant to clients.
create table public.application_review_tokens (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null
    references public.seller_applications (id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index application_review_tokens_application_id_idx
  on public.application_review_tokens (application_id);

alter table public.application_review_tokens enable row level security;
revoke all on public.application_review_tokens from anon, authenticated;

-- ------------------------------------------------------------
-- 2. Sending: the trigger and the retry job
-- ------------------------------------------------------------
-- Every function here is security definer with an empty search_path and every
-- reference schema qualified. Supabase grants execute on new functions to anon
-- and authenticated by default, so each one is revoked from them explicitly.

-- Posts one application id to the notify function. Does nothing until the two
-- Vault entries exist. pg_net only queues the request, it is sent after the
-- current transaction commits (a rolled back insert sends nothing), and a failed
-- send shows up later in net._http_response, so the retry job is what recovers
-- from it. The long timeout covers a cold start plus the Mailjet call.
create or replace function public.admin_notify_post(p_application_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets where name = 'admin_notify_url';
  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'admin_notify_secret';
  if v_url is null or v_secret is null then
    return;
  end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    body := jsonb_build_object('application_id', p_application_id),
    timeout_milliseconds := 30000
  );
end;
$$;

revoke all on function public.admin_notify_post(uuid)
  from public, anon, authenticated;

-- The trigger never blocks or undoes an application: any error is swallowed.
create or replace function public.notify_admin_new_application()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    perform public.admin_notify_post(new.id);
  exception when others then
    null;
  end;
  return new;
end;
$$;

revoke all on function public.notify_admin_new_application()
  from public, anon, authenticated;

create trigger seller_applications_notify_admin
after insert on public.seller_applications
for each row execute function public.notify_admin_new_application();

-- The retry job. Applications still unsent, still under review, below 10
-- attempts and older than a minute (so it never races the trigger's own post)
-- get another post. The job counts the attempt itself, so the limit holds even
-- when the function is down and never runs. At most 20 per run keeps a flood
-- from turning into a flood of emails. Also removes tokens that expired more
-- than 30 days ago. Returns how many it posted.
create or replace function public.retry_admin_notifications()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_count integer := 0;
begin
  for v_id in
    select id from public.seller_applications
    where admin_notified_at is null
      and status = 'reviewing'
      and admin_notify_attempts < 10
      and created_at < now() - interval '1 minute'
    order by created_at
    limit 20
    for update skip locked
  loop
    update public.seller_applications
    set admin_notify_attempts = admin_notify_attempts + 1
    where id = v_id;
    begin
      perform public.admin_notify_post(v_id);
    exception when others then
      null;
    end;
    v_count := v_count + 1;
  end loop;

  delete from public.application_review_tokens
  where expires_at < now() - interval '30 days';

  return v_count;
end;
$$;

revoke all on function public.retry_admin_notifications()
  from public, anon, authenticated;

select cron.schedule(
  'retry_admin_notifications',
  '*/5 * * * *',
  $$select public.retry_admin_notifications()$$
);

-- ------------------------------------------------------------
-- 3. The notify function's lease
-- ------------------------------------------------------------
-- Takes a 2 minute lease on one application so two calls close together send one
-- email. True means this caller may send. False means it is already sent, no
-- longer under review, or another call holds the lease. Service role only.
create or replace function public.claim_admin_notification(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  update public.seller_applications
  set admin_notify_claimed_at = now()
  where id = p_id
    and admin_notified_at is null
    and (admin_notify_claimed_at is null
         or admin_notify_claimed_at < now() - interval '2 minutes')
  returning id into v_id;
  return v_id is not null;
end;
$$;

revoke all on function public.claim_admin_notification(uuid)
  from public, anon, authenticated;
grant execute on function public.claim_admin_notification(uuid) to service_role;

-- ------------------------------------------------------------
-- 4. Deciding from the review page
-- ------------------------------------------------------------
-- Claims the token and decides the application in one transaction, so a crash
-- cannot leave a token stuck as used and a refused decision leaves it usable.
-- Returns 'approved' or 'rejected', or 'not_reviewing' when somebody decided the
-- application already (the token is then marked used). Raises 'invalid_link'
-- for an unknown, expired or used token (the same answer for all three),
-- 'reason_required' for a reject with no reason or one over 500 characters, and
-- passes on the 0013 refusals (already_seller, username_taken, not_found), after
-- which nothing has changed. Decisions are recorded as reviewed by 'email
-- review'. Service role only.
create or replace function public.decide_application_with_token(
  p_token_hash text,
  p_action text,
  p_reason text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token public.application_review_tokens;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if p_action not in ('approve', 'reject') then
    raise exception 'invalid_field';
  end if;

  select * into v_token
  from public.application_review_tokens
  where token_hash = p_token_hash
  for update;
  if not found or v_token.used_at is not null or v_token.expires_at <= now() then
    raise exception 'invalid_link';
  end if;

  if p_action = 'reject' and char_length(v_reason) not between 1 and 500 then
    raise exception 'reason_required';
  end if;

  begin
    if p_action = 'approve' then
      perform public.approve_seller_application(
        v_token.application_id, 'email review'
      );
    else
      perform public.reject_seller_application(
        v_token.application_id, v_reason, 'email review'
      );
    end if;
  exception when others then
    if sqlerrm = 'not_reviewing' then
      update public.application_review_tokens
      set used_at = now() where id = v_token.id;
      return 'not_reviewing';
    end if;
    raise;
  end;

  update public.application_review_tokens
  set used_at = now() where id = v_token.id;
  return case p_action when 'approve' then 'approved' else 'rejected' end;
end;
$$;

revoke all on function public.decide_application_with_token(text, text, text)
  from public, anon, authenticated;
grant execute on function public.decide_application_with_token(text, text, text)
  to service_role;
