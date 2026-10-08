-- Decision record: docs/specs/_root/0017-applicant-decision-email/index.md
--
-- Email the applicant when a seller application is decided, and attach an approved
-- visitor application to the account whose Clerk verified email matches.
--
-- An after update trigger on seller_applications posts the application id to the
-- Edge Function notify-applicant-decision when the status goes from reviewing to
-- approved or rejected (pg_net, the address and shared secret come from Supabase
-- Vault), which sends the email through Mailjet. A job every 5 minutes retries
-- decided applications that are still unsent. The same migration adds the two
-- service role functions the claim function uses to attach by verified email, and
-- gives submit_seller_application an optional applicant email.
--
-- Safe to apply while the current app builds run: it only adds columns, an index,
-- functions, a trigger and a job. The old submit_seller_application signature is
-- replaced by one with a new optional last parameter, so an older app build that
-- does not send it keeps working. Existing decided applications are marked as
-- notified, so no old decision sends an email.
--
-- BEFORE the emails work, set this once by hand (the value never lives in this
-- repo), then deploy notify-applicant-decision with --no-verify-jwt:
--   select vault.create_secret('https://<project>.supabase.co/functions/v1/notify-applicant-decision', 'applicant_notify_url');
-- The shared secret is the admin_notify_secret entry that 0011 already uses.
-- Without them the trigger and the job do nothing, and decisions work as before.
--
-- Rollback: drop the trigger seller_applications_notify_applicant, unschedule the
-- job (select cron.unschedule('retry_applicant_notifications')), drop the
-- functions (notify_applicant_decision, applicant_notify_post,
-- retry_applicant_notifications, claim_applicant_notification,
-- has_unattached_approved_applications, attach_applications_by_email), drop the
-- index seller_applications_email_attach_idx and the four applicant_notify
-- columns, and restore submit_seller_application from 0007.

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

-- ------------------------------------------------------------
-- 1. Columns and index
-- ------------------------------------------------------------
alter table public.seller_applications
  add column applicant_notified_at timestamptz,
  add column applicant_notify_attempts integer not null default 0,
  add column applicant_notify_error text,
  add column applicant_notify_claimed_at timestamptz;

-- Decisions made before this migration were never meant to send an email.
update public.seller_applications
set applicant_notified_at = now()
where status in ('approved', 'rejected')
  and applicant_notified_at is null;

-- For the attach by verified email: only free, approved visitor rows.
create index seller_applications_email_attach_idx
  on public.seller_applications (lower(applicant_email))
  where origin = 'visitor' and status = 'approved'
    and claimed_at is null and bound_account_id is null;

-- ------------------------------------------------------------
-- 2. Sending: the trigger and the retry job
-- ------------------------------------------------------------
-- Every function here is security definer with an empty search_path and every
-- reference schema qualified. Supabase grants execute on new functions to anon
-- and authenticated by default, so each one is revoked from them explicitly.

-- Posts one application id to the notify function. Does nothing until the two
-- Vault entries exist. pg_net only queues the request, it is sent after the
-- current transaction commits (a rolled back decision sends nothing), and a
-- failed send shows up later in net._http_response, so the retry job is what
-- recovers from it. The long timeout covers a cold start plus the Mailjet call.
create or replace function public.applicant_notify_post(p_application_id uuid)
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
  from vault.decrypted_secrets where name = 'applicant_notify_url';
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

revoke all on function public.applicant_notify_post(uuid)
  from public, anon, authenticated;

-- The trigger never blocks or undoes a decision: any error is swallowed.
create or replace function public.notify_applicant_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    perform public.applicant_notify_post(new.id);
  exception when others then
    null;
  end;
  return new;
end;
$$;

revoke all on function public.notify_applicant_decision()
  from public, anon, authenticated;

create trigger seller_applications_notify_applicant
after update of status on public.seller_applications
for each row
when (old.status = 'reviewing' and new.status in ('approved', 'rejected'))
execute function public.notify_applicant_decision();

-- The retry job. Decisions still unsent, below 10 attempts, decided more than a
-- minute ago (so it never races the trigger's own post) and not marked
-- no_recipient get another post. The job counts the attempt itself, so the limit
-- holds even when the function is down and never runs. At most 20 per run keeps a
-- flood from turning into a flood of emails. Returns how many it posted.
create or replace function public.retry_applicant_notifications()
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
    where status in ('approved', 'rejected')
      and applicant_notified_at is null
      and applicant_notify_attempts < 10
      and coalesce(reviewed_at, created_at) < now() - interval '1 minute'
      and applicant_notify_error is distinct from 'no_recipient'
    order by coalesce(reviewed_at, created_at)
    limit 20
    for update skip locked
  loop
    update public.seller_applications
    set applicant_notify_attempts = applicant_notify_attempts + 1
    where id = v_id;
    begin
      perform public.applicant_notify_post(v_id);
    exception when others then
      null;
    end;
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.retry_applicant_notifications()
  from public, anon, authenticated;

select cron.schedule(
  'retry_applicant_notifications',
  '*/5 * * * *',
  $$select public.retry_applicant_notifications()$$
);

-- ------------------------------------------------------------
-- 3. The notify function's lease
-- ------------------------------------------------------------
-- Takes a 2 minute lease on one decided application so two calls close together
-- send one email. True means this caller may send. False means it is already
-- sent, not decided, or another call holds the lease. Service role only.
create or replace function public.claim_applicant_notification(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  update public.seller_applications
  set applicant_notify_claimed_at = now()
  where id = p_id
    and status in ('approved', 'rejected')
    and applicant_notified_at is null
    and (applicant_notify_claimed_at is null
         or applicant_notify_claimed_at < now() - interval '2 minutes')
  returning id into v_id;
  return v_id is not null;
end;
$$;

revoke all on function public.claim_applicant_notification(uuid)
  from public, anon, authenticated;
grant execute on function public.claim_applicant_notification(uuid) to service_role;

-- ------------------------------------------------------------
-- 4. Attach by Clerk verified email
-- ------------------------------------------------------------
-- The claim function asks this first, so it makes no Clerk request while no
-- approved visitor application is waiting. Service role only.
create or replace function public.has_unattached_approved_applications()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.seller_applications
    where origin = 'visitor'
      and status = 'approved'
      and claimed_at is null
      and bound_account_id is null
      and applicant_id is null
  );
$$;

revoke all on function public.has_unattached_approved_applications()
  from public, anon, authenticated;
grant execute on function public.has_unattached_approved_applications()
  to service_role;

-- Attaches the oldest approved, unclaimed, unattached visitor application whose
-- lowercase applicant_email equals one of p_emails to this account, and returns
-- how many rows it attached (0 or 1). The caller (the claim function) passes only
-- addresses Clerk has verified. The list is lowercased and trimmed here. Does
-- nothing for an account that is already a seller or has an open (reviewing)
-- application, its own or an attached one: the same skip the phone attach uses.
-- One update statement with the free row conditions repeated in its where, so two
-- simultaneous attaches end with one winner. Service role only.
create or replace function public.attach_applications_by_email(
  p_clerk_id text,
  p_emails text[]
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_emails text[];
  v_count integer;
begin
  if p_clerk_id is null or btrim(p_clerk_id) = '' then
    return 0;
  end if;

  select coalesce(array_agg(distinct lower(btrim(e))), '{}')
  into v_emails
  from unnest(coalesce(p_emails, '{}')) as e
  where btrim(e) <> '';
  if cardinality(v_emails) = 0 then
    return 0;
  end if;

  if exists (
    select 1 from public.user_profiles
    where id = p_clerk_id and role = 'seller'
  ) or exists (
    select 1 from public.seller_applications
    where status = 'reviewing'
      and (applicant_id = p_clerk_id or bound_account_id = p_clerk_id)
  ) then
    return 0;
  end if;

  update public.seller_applications
  set bound_account_id = p_clerk_id
  where id = (
      select id from public.seller_applications
      where origin = 'visitor'
        and status = 'approved'
        and claimed_at is null
        and bound_account_id is null
        and applicant_id is null
        and lower(applicant_email) = any (v_emails)
      order by created_at, id
      limit 1
    )
    and origin = 'visitor'
    and status = 'approved'
    and claimed_at is null
    and bound_account_id is null
    and applicant_id is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.attach_applications_by_email(text, text[])
  from public, anon, authenticated;
grant execute on function public.attach_applications_by_email(text, text[])
  to service_role;

-- ------------------------------------------------------------
-- 5. submit_seller_application with an optional applicant email
-- ------------------------------------------------------------
-- 0007's function plus one optional last parameter, p_applicant_email (private,
-- never copied to the profile). Trimmed, stored lowercase, up to 200 characters
-- and it must look like an email, else invalid_field. The old signature is
-- dropped so only one overload exists. Everything else is unchanged.
drop function public.submit_seller_application(
  uuid, text, text, text, text, text, text, text, text, text, text
);

create or replace function public.submit_seller_application(
  p_id uuid,
  p_store_name text,
  p_username text,
  p_location text,
  p_id_document_path text,
  p_bio text default null,
  p_website_url text default null,
  p_contact_phone text default null,
  p_contact_email text default null,
  p_logo_path text default null,
  p_business_document_path text default null,
  p_applicant_email text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user text := (select auth.jwt() ->> 'sub');
  v_role text;
  v_store_name text := btrim(p_store_name);
  v_location text := btrim(p_location);
  v_bio text := nullif(btrim(p_bio), '');
  v_website_url text := nullif(btrim(p_website_url), '');
  v_contact_phone text := nullif(btrim(p_contact_phone), '');
  v_contact_email text := nullif(btrim(p_contact_email), '');
  v_logo_path text := nullif(btrim(p_logo_path), '');
  v_id_path text := nullif(btrim(p_id_document_path), '');
  v_business_path text := nullif(btrim(p_business_document_path), '');
  v_applicant_email text := nullif(lower(btrim(p_applicant_email)), '');
  v_docs_prefix text;
  v_constraint text;
begin
  if v_user is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'no_session';
  end if;

  if p_id is null then
    raise exception 'invalid_field';
  end if;

  -- Retry of the caller's own application: same row, nothing changes.
  if exists (
    select 1 from public.seller_applications
    where id = p_id and applicant_id = v_user
  ) then
    return p_id;
  end if;

  select role into v_role from public.user_profiles where id = v_user;
  if not found then
    raise exception 'no_profile';
  end if;
  if v_role = 'seller' then
    raise exception 'already_seller';
  end if;
  -- Open means reviewing, either the caller's own or a visitor row attached to
  -- the caller's account.
  if exists (
    select 1 from public.seller_applications
    where status = 'reviewing'
      and (applicant_id = v_user or bound_account_id = v_user)
  ) then
    raise exception 'already_open';
  end if;

  -- The id is already another person's application.
  if exists (select 1 from public.seller_applications where id = p_id) then
    raise exception 'invalid_field';
  end if;

  -- Text fields. Optional fields are capped so a client cannot store megabytes.
  if v_store_name is null or char_length(v_store_name) not between 2 and 60
     or p_username is null or p_username !~ '^[a-z0-9_.]{3,30}$'
     or v_location is null or v_location = ''
     or char_length(v_bio) > 280
     or char_length(v_website_url) > 300
     or char_length(v_contact_phone) > 300
     or char_length(v_contact_email) > 300
     or (v_applicant_email is not null
         and (char_length(v_applicant_email) > 200
              or v_applicant_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')) then
    raise exception 'invalid_field';
  end if;

  if exists (
    select 1 from public.user_profiles
    where username = p_username and id <> v_user
  ) or exists (
    select 1 from public.seller_applications
    where username = p_username
      and (status = 'reviewing'
           or (origin = 'visitor' and status = 'approved' and claimed_at is null))
  ) then
    raise exception 'username_taken';
  end if;

  -- Files: shape first, then existence in the right bucket.
  if v_id_path is null then
    raise exception 'missing_document';
  end if;
  v_docs_prefix := v_user || '/' || p_id::text || '/';
  if not public.seller_application_path_ok(v_id_path, v_docs_prefix)
     or (v_business_path is not null
         and (v_business_path = v_id_path
              or not public.seller_application_path_ok(v_business_path, v_docs_prefix)))
     or (v_logo_path is not null
         and not public.seller_application_path_ok(v_logo_path, v_user || '/')) then
    raise exception 'invalid_field';
  end if;

  if not exists (
    select 1 from storage.objects
    where bucket_id = 'application-documents' and name = v_id_path
  ) or (v_business_path is not null and not exists (
    select 1 from storage.objects
    where bucket_id = 'application-documents' and name = v_business_path
  )) or (v_logo_path is not null and not exists (
    select 1 from storage.objects
    where bucket_id = 'store-logos' and name = v_logo_path
  )) then
    raise exception 'file_not_found';
  end if;

  begin
    insert into public.seller_applications (
      id, applicant_id, submitter_id, store_name, username, bio, location,
      website_url, contact_phone, contact_email, logo_path, id_document_path,
      business_document_path, applicant_email
    ) values (
      p_id, v_user, v_user, v_store_name, p_username, v_bio, v_location,
      v_website_url, v_contact_phone, v_contact_email, v_logo_path, v_id_path,
      v_business_path, v_applicant_email
    );
  exception when unique_violation then
    -- Two submits at the same moment. The same id from the same person is the
    -- retry case, so the loser returns the winner's row, not an error.
    if exists (
      select 1 from public.seller_applications
      where id = p_id and applicant_id = v_user
    ) then
      return p_id;
    end if;
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint = 'seller_applications_one_reviewing_per_owner' then
      raise exception 'already_open';
    elsif v_constraint = 'seller_applications_one_username_in_flight' then
      raise exception 'username_taken';
    end if;
    raise exception 'invalid_field';
  end;

  return p_id;
end;
$$;

revoke all on function public.submit_seller_application(
  uuid, text, text, text, text, text, text, text, text, text, text, text
) from public, anon;
grant execute on function public.submit_seller_application(
  uuid, text, text, text, text, text, text, text, text, text, text, text
) to authenticated;
