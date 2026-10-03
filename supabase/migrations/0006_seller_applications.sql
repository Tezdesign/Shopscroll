-- Decision record: docs/specs/_root/0013-seller-application-request/index.md
--
-- Seller applications. A buyer sends an application (submit_seller_application),
-- an admin decides with the service role (approve_ and reject_seller_application),
-- and only approval turns the person into a seller. Safe to apply at any time:
-- it adds a table, three functions, two storage buckets and their policies, and
-- changes nothing that an existing build uses.
--
-- This does NOT close become_seller() (spec 0012). Until a later migration
-- revokes its execute from `authenticated`, any signed in person can skip the
-- review. That is a launch blocker, see the spec's Follow-up.
--
-- Apply by hand (`supabase db push`) to a TEST or BRANCH project first, then run
-- supabase/checks/seller_applications.sql and the manual Storage checks in the
-- spec (build plan task 1) before the live project.
--
-- Rollback: drop the three functions, the helper, the table, the three policies
-- on storage.objects, then delete the two buckets (empty them first, Supabase
-- refuses to drop a bucket that holds files).

-- ------------------------------------------------------------
-- 1. Table
-- ------------------------------------------------------------
-- `id` is supplied by the client: it names the document folder and makes submit
-- safe to retry. `applicant_id` is text because Clerk ids are not uuids.
create table public.seller_applications (
  id uuid primary key,
  applicant_id text not null references public.user_profiles (id) on delete cascade,
  status text not null default 'reviewing'
    check (status in ('reviewing', 'approved', 'rejected')),
  store_name text not null check (char_length(store_name) between 2 and 60),
  username text not null check (username ~ '^[a-z0-9_.]{3,30}$'),
  bio text check (char_length(bio) <= 280),
  location text not null check (btrim(location) <> ''),
  website_url text,
  contact_phone text,
  contact_email text,
  logo_path text,
  id_document_path text not null,
  business_document_path text,
  rejection_reason text,
  reviewed_at timestamptz,
  reviewed_by text,
  created_at timestamptz not null default now(),
  constraint seller_applications_rejection_reason_check
    check (status <> 'rejected' or btrim(coalesce(rejection_reason, '')) <> '')
);

-- One reviewing application per person and per username. The submit function
-- maps a violation of these two (by name) to already_open and username_taken.
create unique index seller_applications_one_reviewing_per_person
  on public.seller_applications (applicant_id) where status = 'reviewing';
create unique index seller_applications_one_reviewing_per_username
  on public.seller_applications (username) where status = 'reviewing';
create index seller_applications_applicant_id_idx
  on public.seller_applications (applicant_id);

-- ------------------------------------------------------------
-- 2. Row level security and grants
-- ------------------------------------------------------------
-- A signed in client reads only its own rows and never writes: rows come from
-- submit_seller_application, decisions from the service role. Revoke first on
-- purpose (Supabase grants table rights on new tables), then grant select back.
alter table public.seller_applications enable row level security;

revoke all on public.seller_applications from anon, authenticated;
grant select on public.seller_applications to authenticated;

create policy "applicants read own applications"
on public.seller_applications for select
to authenticated
using (applicant_id = (select auth.jwt() ->> 'sub'));

-- ------------------------------------------------------------
-- 3. Functions
-- ------------------------------------------------------------
-- All security definer with an empty search_path and every reference schema
-- qualified, execute revoked from public AND anon (Supabase grants anon execute
-- by default). Refusals are raised as the whole error message, like place_order.

-- True when p_path is exactly `<p_prefix><name>` and name is one non empty
-- segment. Used by submit to hold every file path to the exact shape in the
-- spec, so one person cannot point at another person's file. Internal only.
create or replace function public.seller_application_path_ok(p_path text, p_prefix text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_path is not null
    and starts_with(p_path, p_prefix)
    and char_length(p_path) > char_length(p_prefix)
    and strpos(substr(p_path, char_length(p_prefix) + 1), '/') = 0;
$$;

revoke all on function public.seller_application_path_ok(text, text)
  from public, anon, authenticated;

-- Creates the caller's application, or returns the existing row's id when the
-- same person calls again with the same p_id (a retry after a lost response, or
-- a double tap). That retry check runs before every state check below, and only
-- matches the caller's own rows.
-- Errors: no_session, no_profile, already_seller, already_open, invalid_field,
-- username_taken, missing_document, file_not_found.
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
  if exists (
    select 1 from public.seller_applications
    where applicant_id = v_user and status = 'reviewing'
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
    where username = p_username and status = 'reviewing'
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
      id, applicant_id, store_name, username, bio, location, website_url,
      contact_phone, contact_email, logo_path, id_document_path,
      business_document_path
    ) values (
      p_id, v_user, v_store_name, p_username, v_bio, v_location,
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
    if v_constraint = 'seller_applications_one_reviewing_per_person' then
      raise exception 'already_open';
    elsif v_constraint = 'seller_applications_one_reviewing_per_username' then
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

-- Approval, in one transaction: lock the row, copy the store details onto the
-- applicant's profile and make them a seller. An empty optional field
-- overwrites the profile value with null, so the private email and phone copied
-- from the sign in account never become public. The logo is stored as the
-- bucket relative path `store-logos/<sub>/<name>` because SQL does not know the
-- project URL, the app turns it into a public URL.
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

  select role into v_role
  from public.user_profiles where id = v_app.applicant_id for update;
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
          when v_app.logo_path is null then null
          else 'store-logos/' || v_app.logo_path
        end,
        role = 'seller'
    where id = v_app.applicant_id;
  exception when unique_violation then
    raise exception 'username_taken';
  end;

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

-- Rejection: needs a reason, leaves the profile alone.
-- Service role only. Errors: reason_required, not_found, not_reviewing.
create or replace function public.reject_seller_application(
  p_id uuid,
  p_reason text,
  p_reviewed_by text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception 'reason_required';
  end if;

  select status into v_status
  from public.seller_applications where id = p_id for update;
  if not found then
    raise exception 'not_found';
  end if;
  if v_status <> 'reviewing' then
    raise exception 'not_reviewing';
  end if;

  update public.seller_applications
  set status = 'rejected',
      rejection_reason = btrim(p_reason),
      reviewed_at = now(),
      reviewed_by = nullif(btrim(p_reviewed_by), '')
  where id = p_id;
end;
$$;

revoke all on function public.reject_seller_application(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.reject_seller_application(uuid, text, text)
  to service_role;

-- ------------------------------------------------------------
-- 4. Storage
-- ------------------------------------------------------------
-- store-logos is public read (the logo becomes the store avatar), and
-- application-documents is private (ID photos). Both take only JPEG and PNG up
-- to 5 MB, enforced by the Storage API (SQL cannot check it, see the manual
-- checks in the spec).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('store-logos', 'store-logos', true, 5242880, array['image/jpeg', 'image/png']),
  ('application-documents', 'application-documents', false, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- A real signed in account adds files only under its own id folder. Anonymous
-- sessions are signed in users too (with a Supabase uuid), and would otherwise
-- get free public file hosting, so they are refused. Clerk ids are not uuids, so
-- these compare the folder to the JWT `sub`, never auth.uid() or `owner`.
-- No update or delete policy on purpose: files are never replaced or removed by
-- a client (a retry uploads under a new random name).
create policy "applicants add own logo"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'store-logos'
  and (storage.foldername(name))[1] = (select auth.jwt() ->> 'sub')
  and not coalesce(((select auth.jwt() ->> 'is_anonymous'))::boolean, false)
);

create policy "applicants add own documents"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'application-documents'
  and (storage.foldername(name))[1] = (select auth.jwt() ->> 'sub')
  and not coalesce(((select auth.jwt() ->> 'is_anonymous'))::boolean, false)
);

create policy "applicants read own documents"
on storage.objects for select
to authenticated
using (
  bucket_id = 'application-documents'
  and (storage.foldername(name))[1] = (select auth.jwt() ->> 'sub')
  and not coalesce(((select auth.jwt() ->> 'is_anonymous'))::boolean, false)
);
