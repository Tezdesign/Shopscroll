-- Decision record: docs/specs/_root/0014-shared-login-seller-area/index.md
--
-- Visitor applications. A person with no account can send a seller application
-- through their anonymous session (submit_visitor_application). The row is
-- attached to the account that signs up on the same phone
-- (merge_anonymous_identity), an admin approves it with the service role, and
-- the app then claims it (claim_seller_application, called by the
-- claim-seller-application Edge Function), which is the moment the person
-- becomes a seller.
--
-- Safe to apply while the current buyer build runs: submit_seller_application
-- and merge_anonymous_identity are replaced in this same migration, so account
-- applications and sign in keep working. Apply the whole file in one go.
--
-- This does NOT close become_seller() (spec 0012). That stays a launch blocker.
--
-- Apply by hand (`supabase db push`) to a TEST or BRANCH project first, then run
-- supabase/checks/visitor_applications.sql (and the other checks) and the manual
-- Storage checks in the spec's verify.md, before the live project.
--
-- Rollback (only before any visitor row exists, otherwise delete or fix those
-- rows first because they have no applicant_id): drop the new functions
-- (submit_visitor_application, find_claimable_application,
-- claim_seller_application, own_visitor_file_count), the two storage policies
-- and the select policy added here, empty and delete the visitor-documents
-- bucket, drop the new indexes and check constraints and columns, make
-- applicant_id not null again, restore the two 0006 partial unique indexes and
-- the 0006 select policy, and restore the 0006 submit_seller_application,
-- approve_seller_application and the 0001 merge_anonymous_identity.

-- ------------------------------------------------------------
-- 1. Table
-- ------------------------------------------------------------
-- Existing rows are account applications: origin takes its default, and
-- submitter_id is backfilled with applicant_id before it becomes not null.
alter table public.seller_applications
  add column origin text not null default 'account',
  add column submitter_id text,
  add column applicant_name text,
  add column applicant_email text,
  add column applicant_phone text,
  add column bound_account_id text,
  add column claimed_at timestamptz;

update public.seller_applications
set submitter_id = applicant_id
where submitter_id is null;

alter table public.seller_applications
  alter column submitter_id set not null,
  alter column applicant_id drop not null;

alter table public.seller_applications
  add constraint seller_applications_origin_check
    check (origin in ('account', 'visitor')),
  add constraint seller_applications_account_has_applicant_check
    check (origin = 'visitor' or applicant_id is not null),
  add constraint seller_applications_visitor_contact_check
    check (
      origin = 'account'
      or (applicant_name is not null
          and applicant_email is not null
          and applicant_phone is not null)
    );

-- Unique indexes. Each one maps to one named refusal in the submit functions,
-- and each name is checked in supabase/checks/visitor_applications.sql.
drop index public.seller_applications_one_reviewing_per_person;
drop index public.seller_applications_one_reviewing_per_username;

-- One reviewing application per owner: the account (applicant_id, or
-- bound_account_id once a visitor row is attached), or the session before that.
create unique index seller_applications_one_reviewing_per_owner
  on public.seller_applications (coalesce(applicant_id, bound_account_id, submitter_id))
  where status = 'reviewing';
-- Visitors also get one reviewing application per email and per phone.
create unique index seller_applications_one_reviewing_per_email
  on public.seller_applications (lower(applicant_email))
  where origin = 'visitor' and status = 'reviewing';
create unique index seller_applications_one_reviewing_per_phone
  on public.seller_applications (applicant_phone)
  where origin = 'visitor' and status = 'reviewing';
-- One username in flight overall. An approved visitor application keeps its
-- username reserved until it is claimed.
create unique index seller_applications_one_username_in_flight
  on public.seller_applications (username)
  where status = 'reviewing'
     or (origin = 'visitor' and status = 'approved' and claimed_at is null);
-- Serves the claim lookup and the select policy.
create index seller_applications_bound_unclaimed_idx
  on public.seller_applications (bound_account_id)
  where status = 'approved' and claimed_at is null;
create index seller_applications_submitter_id_idx
  on public.seller_applications (submitter_id);

-- ------------------------------------------------------------
-- 2. Row level security
-- ------------------------------------------------------------
-- A signed in client reads the rows it sent (submitter_id), the rows that are
-- its own (applicant_id) and the visitor rows attached to its account
-- (bound_account_id). Table grants stay select only to authenticated, anon has
-- none (0006).
drop policy "applicants read own applications" on public.seller_applications;

create policy "owners read own applications"
on public.seller_applications for select
to authenticated
using (
  submitter_id = (select auth.jwt() ->> 'sub')
  or applicant_id = (select auth.jwt() ->> 'sub')
  or bound_account_id = (select auth.jwt() ->> 'sub')
);

-- ------------------------------------------------------------
-- 3. Storage: visitor-documents
-- ------------------------------------------------------------
-- Private, JPEG and PNG, 5 MB (the Storage API enforces type and size, SQL
-- cannot check it). Holds the ID photo, the business document and the logo of a
-- visitor application at <session id>/<application id>/<kind>-<name>.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('visitor-documents', 'visitor-documents', false, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- How many files the caller's own folder already holds. The insert policy below
-- needs it, but a policy runs as the caller and clients have no select policy on
-- this bucket, so the count has to bypass row level security. It reads only the
-- caller's own folder (the JWT sub), never one the caller names.
create or replace function public.own_visitor_file_count()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from storage.objects
  where bucket_id = 'visitor-documents'
    and (storage.foldername(name))[1] = (select auth.jwt() ->> 'sub');
$$;

revoke all on function public.own_visitor_file_count() from public, anon;
grant execute on function public.own_visitor_file_count() to authenticated;

-- Only an anonymous session adds files, only under its own session id folder,
-- and at most 12 in total (the count is read before the new file lands, so the
-- twelfth is allowed and the thirteenth is not; two uploads at the same moment
-- can overshoot by a file, which the 5 MB cap keeps harmless). A real account
-- is refused here, it uses application-documents. No select, update or delete
-- policy on purpose: no client reads, replaces or removes a visitor file.
create policy "visitors add own files"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'visitor-documents'
  and (storage.foldername(name))[1] = (select auth.jwt() ->> 'sub')
  and coalesce(((select auth.jwt() ->> 'is_anonymous'))::boolean, false)
  and public.own_visitor_file_count() < 12
);

-- ------------------------------------------------------------
-- 4. Functions
-- ------------------------------------------------------------
-- Same conventions as 0006: security definer, empty search_path, every reference
-- schema qualified, execute revoked from public and anon, refusals raised as the
-- whole error message.

-- Account applications (0006), replaced so the insert writes submitter_id (now
-- required), the open rule counts visitor rows attached to the caller, and the
-- username check also sees reserved visitor usernames. Errors as in 0006.
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
  p_business_document_path text default null
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
     or char_length(v_contact_email) > 300 then
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
      business_document_path
    ) values (
      p_id, v_user, v_user, v_store_name, p_username, v_bio, v_location,
      v_website_url, v_contact_phone, v_contact_email, v_logo_path, v_id_path,
      v_business_path
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
  uuid, text, text, text, text, text, text, text, text, text, text
) from public, anon;
grant execute on function public.submit_seller_application(
  uuid, text, text, text, text, text, text, text, text, text, text
) to authenticated;

-- A visitor's application: an anonymous session, no account, no profile. The row
-- keeps the person's contact details privately and never touches a profile.
-- Same retry rule as above (same p_id from the same session returns the row,
-- checked first). Anonymous session only.
-- Errors: no_session, use_account, already_open, invalid_field, username_taken,
-- missing_document, file_not_found.
create or replace function public.submit_visitor_application(
  p_id uuid,
  p_store_name text,
  p_username text,
  p_location text,
  p_applicant_name text,
  p_applicant_email text,
  p_applicant_phone text,
  p_id_document_path text,
  p_bio text default null,
  p_website_url text default null,
  p_contact_phone text default null,
  p_contact_email text default null,
  p_logo_path text default null,
  p_business_document_path text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user text := (select auth.jwt() ->> 'sub');
  v_store_name text := btrim(p_store_name);
  v_location text := btrim(p_location);
  v_name text := btrim(p_applicant_name);
  v_email text := lower(btrim(p_applicant_email));
  v_phone text := btrim(p_applicant_phone);
  v_bio text := nullif(btrim(p_bio), '');
  v_website_url text := nullif(btrim(p_website_url), '');
  v_contact_phone text := nullif(btrim(p_contact_phone), '');
  v_contact_email text := nullif(btrim(p_contact_email), '');
  v_logo_path text := nullif(btrim(p_logo_path), '');
  v_id_path text := nullif(btrim(p_id_document_path), '');
  v_business_path text := nullif(btrim(p_business_document_path), '');
  v_docs_prefix text;
  v_constraint text;
begin
  if v_user is null then
    raise exception 'no_session';
  end if;
  if not coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'use_account';
  end if;

  if p_id is null then
    raise exception 'invalid_field';
  end if;

  -- Retry of this session's own application: same row, nothing changes.
  if exists (
    select 1 from public.seller_applications
    where id = p_id and origin = 'visitor' and submitter_id = v_user
  ) then
    return p_id;
  end if;

  -- The id is already someone else's application.
  if exists (select 1 from public.seller_applications where id = p_id) then
    raise exception 'invalid_field';
  end if;

  -- Text fields first, so a bad value is reported as invalid_field and not as a
  -- conflict with another application.
  if v_store_name is null or char_length(v_store_name) not between 2 and 60
     or p_username is null or p_username !~ '^[a-z0-9_.]{3,30}$'
     or v_location is null or v_location = ''
     or v_name is null or char_length(v_name) not between 2 and 60
     or v_email is null or char_length(v_email) > 200
     or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
     or v_phone is null or v_phone !~ '^\+[1-9][0-9]{6,14}$'
     or char_length(v_bio) > 280
     or char_length(v_website_url) > 300
     or char_length(v_contact_phone) > 300
     or char_length(v_contact_email) > 300 then
    raise exception 'invalid_field';
  end if;

  -- One reviewing application per session, per email and per phone.
  if exists (
    select 1 from public.seller_applications
    where status = 'reviewing'
      and (coalesce(applicant_id, bound_account_id, submitter_id) = v_user
           or (origin = 'visitor'
               and (lower(applicant_email) = v_email or applicant_phone = v_phone)))
  ) then
    raise exception 'already_open';
  end if;

  if exists (
    select 1 from public.user_profiles where username = p_username
  ) or exists (
    select 1 from public.seller_applications
    where username = p_username
      and (status = 'reviewing'
           or (origin = 'visitor' and status = 'approved' and claimed_at is null))
  ) then
    raise exception 'username_taken';
  end if;

  -- Files: shape first (<session id>/<application id>/<kind>-<name>), then
  -- existence in visitor-documents.
  if v_id_path is null then
    raise exception 'missing_document';
  end if;
  v_docs_prefix := v_user || '/' || p_id::text || '/';
  if not public.seller_application_path_ok(v_id_path, v_docs_prefix || 'id-')
     or (v_business_path is not null
         and not public.seller_application_path_ok(v_business_path, v_docs_prefix || 'business-'))
     or (v_logo_path is not null
         and not public.seller_application_path_ok(v_logo_path, v_docs_prefix || 'logo-')) then
    raise exception 'invalid_field';
  end if;

  if not exists (
    select 1 from storage.objects
    where bucket_id = 'visitor-documents' and name = v_id_path
  ) or (v_business_path is not null and not exists (
    select 1 from storage.objects
    where bucket_id = 'visitor-documents' and name = v_business_path
  )) or (v_logo_path is not null and not exists (
    select 1 from storage.objects
    where bucket_id = 'visitor-documents' and name = v_logo_path
  )) then
    raise exception 'file_not_found';
  end if;

  begin
    insert into public.seller_applications (
      id, origin, applicant_id, submitter_id, applicant_name, applicant_email,
      applicant_phone, store_name, username, bio, location, website_url,
      contact_phone, contact_email, logo_path, id_document_path,
      business_document_path
    ) values (
      p_id, 'visitor', null, v_user, v_name, v_email, v_phone, v_store_name,
      p_username, v_bio, v_location, v_website_url, v_contact_phone,
      v_contact_email, v_logo_path, v_id_path, v_business_path
    );
  exception when unique_violation then
    -- Two submits at the same moment. The same id from the same session is the
    -- retry case, so the loser returns the winner's row, not an error.
    if exists (
      select 1 from public.seller_applications
      where id = p_id and origin = 'visitor' and submitter_id = v_user
    ) then
      return p_id;
    end if;
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint in (
      'seller_applications_one_reviewing_per_owner',
      'seller_applications_one_reviewing_per_email',
      'seller_applications_one_reviewing_per_phone'
    ) then
      raise exception 'already_open';
    elsif v_constraint = 'seller_applications_one_username_in_flight' then
      raise exception 'username_taken';
    end if;
    raise exception 'invalid_field';
  end;

  return p_id;
end;
$$;

revoke all on function public.submit_visitor_application(
  uuid, text, text, text, text, text, text, text, text, text, text, text, text, text
) from public, anon;
grant execute on function public.submit_visitor_application(
  uuid, text, text, text, text, text, text, text, text, text, text, text, text, text
) to authenticated;

-- Approval (0013) now also decides visitor rows. A visitor row only gets its
-- status, reviewed_at and reviewed_by: no profile changes, because nobody is
-- attached yet (claim_seller_application does that later). An account row
-- behaves as before, and also refuses a username reserved by an approved visitor
-- application that nobody has claimed yet.
-- Service role only. Errors: not_found, not_reviewing, already_seller,
-- username_taken (the application stays reviewing in every case).
create or replace function public.approve_seller_application(
  p_id uuid,
  p_reviewed_by text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_app public.seller_applications;
  v_role text;
begin
  select * into v_app
  from public.seller_applications where id = p_id for update;
  if not found then
    raise exception 'not_found';
  end if;
  if v_app.status <> 'reviewing' then
    raise exception 'not_reviewing';
  end if;

  if v_app.origin = 'account' then
    select role into v_role
    from public.user_profiles where id = v_app.applicant_id for update;
    if v_role = 'seller' then
      raise exception 'already_seller';
    end if;

    if exists (
      select 1 from public.seller_applications
      where username = v_app.username
        and id <> p_id
        and origin = 'visitor'
        and status = 'approved'
        and claimed_at is null
    ) then
      raise exception 'username_taken';
    end if;

    begin
      update public.user_profiles
      set name = v_app.store_name,
          username = v_app.username,
          bio = v_app.bio,
          location = v_app.location,
          website_url = v_app.website_url,
          phone = v_app.contact_phone,
          email = v_app.contact_email,
          avatar_url = case
            when v_app.logo_path is null then null
            else 'store-logos/' || v_app.logo_path
          end,
          role = 'seller'
      where id = v_app.applicant_id;
    exception when unique_violation then
      raise exception 'username_taken';
    end;
  end if;

  update public.seller_applications
  set status = 'approved',
      reviewed_at = now(),
      reviewed_by = nullif(btrim(p_reviewed_by), '')
  where id = p_id;
end;
$$;

revoke all on function public.approve_seller_application(uuid, text)
  from public, anon, authenticated;
grant execute on function public.approve_seller_application(uuid, text)
  to service_role;

-- reject_seller_application (0013) already works on visitor rows: it only sets
-- the status, the reason and the reviewer, and never reads applicant_id.

-- The oldest approved visitor application attached to this account and not
-- claimed yet, or no row. The Edge Function calls it with the service role.
create or replace function public.find_claimable_application(p_clerk_id text)
returns table (id uuid, logo_path text)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.logo_path
  from public.seller_applications a
  where a.bound_account_id = p_clerk_id
    and a.origin = 'visitor'
    and a.status = 'approved'
    and a.claimed_at is null
  order by a.created_at, a.id
  limit 1;
$$;

revoke all on function public.find_claimable_application(text)
  from public, anon, authenticated;
grant execute on function public.find_claimable_application(text)
  to service_role;

-- The claim, in one transaction: lock the application and then the profile (the
-- same order approve uses), recheck both, copy the store details onto the
-- profile exactly as an account approval does (an empty optional field becomes
-- null), make the person a seller, and mark the row claimed. p_logo_path is the
-- bucket relative path in store-logos that the Edge Function copied the logo to
-- (`<clerk id>/<application id>.<ext>`), or null when there is no logo.
-- Service role only. Errors: not_found, not_claimable (also what a second or
-- simultaneous call sees), no_profile, already_seller, username_taken. Every
-- refusal leaves the application and the profile as they were.
create or replace function public.claim_seller_application(
  p_id uuid,
  p_clerk_id text,
  p_logo_path text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_app public.seller_applications;
  v_role text;
  v_logo_path text := nullif(btrim(p_logo_path), '');
begin
  select * into v_app
  from public.seller_applications where id = p_id for update;
  if not found then
    raise exception 'not_found';
  end if;
  if v_app.origin <> 'visitor'
     or v_app.status <> 'approved'
     or v_app.claimed_at is not null
     or v_app.bound_account_id is distinct from p_clerk_id then
    raise exception 'not_claimable';
  end if;

  select role into v_role
  from public.user_profiles where id = p_clerk_id for update;
  if not found then
    raise exception 'no_profile';
  end if;
  if v_role = 'seller' then
    raise exception 'already_seller';
  end if;

  begin
    update public.user_profiles
    set name = v_app.store_name,
        username = v_app.username,
        bio = v_app.bio,
        location = v_app.location,
        website_url = v_app.website_url,
        phone = v_app.contact_phone,
        email = v_app.contact_email,
        avatar_url = case
          when v_logo_path is null then null
          else 'store-logos/' || v_logo_path
        end,
        role = 'seller'
    where id = p_clerk_id;
  exception when unique_violation then
    raise exception 'username_taken';
  end;

  update public.seller_applications
  set applicant_id = p_clerk_id,
      claimed_at = now()
  where id = p_id;
end;
$$;

revoke all on function public.claim_seller_application(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.claim_seller_application(uuid, text, text)
  to service_role;

-- merge_anonymous_identity (0001), now with a second job: attach the visitor
-- applications that this anonymous session sent to the account that just signed
-- in on the same phone. The cart and order part is unchanged.
-- Attaching is the only way a visitor row reaches an account: nothing a visitor
-- typed (email, phone) is ever used to match. A row is attached only while it is
-- still free (no applicant, no bound account), and is skipped when the account
-- already has an open (reviewing) application, its own or an attached one.
create or replace function public.merge_anonymous_identity(target_user_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id text;
begin
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) is not true then
    return;
  end if;

  caller_id := auth.jwt() ->> 'sub';
  if caller_id is null or caller_id = target_user_id then
    return;
  end if;

  -- Cart: fold matching lines (same product + size + color) into the
  -- target's existing quantity.
  update public.cart_items as target
  set quantity = target.quantity + source.quantity
  from public.cart_items as source
  where source.user_id = caller_id
    and target.user_id = target_user_id
    and target.product_id = source.product_id
    and coalesce(target.selected_size, '') = coalesce(source.selected_size, '')
    and coalesce(target.selected_color, -1) = coalesce(source.selected_color, -1);

  -- The source rows just folded into an existing target row are now
  -- duplicates; remove them before reassigning whatever cart lines are
  -- left (no match in the target's cart) straight onto the target.
  delete from public.cart_items as source
  where source.user_id = caller_id
    and exists (
      select 1 from public.cart_items as target
      where target.user_id = target_user_id
        and target.product_id = source.product_id
        and coalesce(target.selected_size, '') = coalesce(source.selected_size, '')
        and coalesce(target.selected_color, -1) = coalesce(source.selected_color, -1)
    );

  update public.cart_items
  set user_id = target_user_id
  where user_id = caller_id;

  -- Orders: no merge concept between two independent orders, just
  -- reassign ownership; order_items follow automatically (keyed off
  -- order_id, not user_id).
  update public.orders
  set user_id = target_user_id
  where user_id = caller_id;

  -- Visitor applications sent from this phone's session.
  if not exists (
    select 1 from public.seller_applications
    where status = 'reviewing'
      and (applicant_id = target_user_id or bound_account_id = target_user_id)
  ) then
    begin
      update public.seller_applications
      set bound_account_id = target_user_id
      where origin = 'visitor'
        and submitter_id = caller_id
        and applicant_id is null
        and bound_account_id is null;
    exception when unique_violation then
      -- The account sent an application of its own at this very moment. The
      -- one open rule wins and the visitor row stays unattached.
      null;
    end;
  end if;
end;
$$;

revoke all on function public.merge_anonymous_identity(text) from public;
grant execute on function public.merge_anonymous_identity(text) to authenticated;
