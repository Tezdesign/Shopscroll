-- Decision record: docs/specs/_root/0014-shared-login-seller-area/index.md
-- (AC-10, AC-12, AC-16, AC-17, build plan task 10, update of 2026-10-08)
--
-- A visitor application attaches to an account only when Clerk has verified a
-- contact of that account and it equals the email or the phone typed in the
-- application. Being on the phone that sent it proves nothing, so every signed in
-- person sees only their own applications.
--
-- What changes:
--   1. Rows that were attached by the old same phone rule (and by the 0012 email
--      rule) but not claimed are detached. They attach again only through
--      attach_applications_by_contact. Claimed rows are untouched.
--   2. The two 0012 attach functions and their index are dropped, and
--      has_unattached_visitor_applications and attach_applications_by_contact
--      (service role only, called by the claim-seller-application Edge Function
--      with the contacts Clerk verified) take their place, with two partial
--      indexes that serve the match.
--   3. merge_anonymous_identity goes back to merging the cart and the orders only.
--   4. The select policy no longer lets an anonymous session read a row once it is
--      attached or claimed.
--
-- Safe to apply before the app and the Edge Function are updated: nothing in an
-- older build calls the dropped functions (claim-seller-application has never been
-- deployed). People already attached by the old rule lose the link and get it back
-- at their next claim only if their verified email or phone matches.
--
-- Rollback: restore the 0012 functions and index, merge_anonymous_identity from
-- 0007 and the 0007 policy, then drop the two new functions and indexes. The
-- detached links cannot be restored: they were wrong by design.

-- ------------------------------------------------------------
-- 1. Detach the unclaimed attached rows (AC-16)
-- ------------------------------------------------------------
-- Approved and rejected rows: one statement, nothing can conflict (the one open
-- index covers reviewing rows only).
update public.seller_applications
set bound_account_id = null
where origin = 'visitor'
  and bound_account_id is not null
  and claimed_at is null
  and status in ('approved', 'rejected');

-- Reviewing rows one by one. Detaching moves a row back to its session in the one
-- open index, so it fails when that session sent another reviewing row after the
-- first was attached. That row stays attached and is named for the admin.
do $$
declare
  v_id uuid;
begin
  for v_id in
    select id from public.seller_applications
    where origin = 'visitor'
      and bound_account_id is not null
      and claimed_at is null
      and status = 'reviewing'
    order by created_at, id
  loop
    begin
      update public.seller_applications
      set bound_account_id = null
      where id = v_id;
    exception when unique_violation then
      raise notice 'application % stays attached: its session has another reviewing application. Decide one of the two.', v_id;
    end;
  end loop;
end;
$$;

-- ------------------------------------------------------------
-- 2. Replace the 0012 attach with the attach by verified contact
-- ------------------------------------------------------------
drop function public.attach_applications_by_email(text, text[]);
drop function public.has_unattached_approved_applications();
drop index public.seller_applications_email_attach_idx;

-- The rows an attach can take: visitor rows nobody has attached or claimed.
create index seller_applications_free_email_idx
  on public.seller_applications (lower(applicant_email))
  where origin = 'visitor' and claimed_at is null
    and bound_account_id is null and applicant_id is null;
create index seller_applications_free_phone_idx
  on public.seller_applications (applicant_phone)
  where origin = 'visitor' and claimed_at is null
    and bound_account_id is null and applicant_id is null;

-- The claim function asks this first, so it makes no Clerk request while no free
-- visitor row (of any status) waits. Service role only.
create function public.has_unattached_visitor_applications()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.seller_applications
    where origin = 'visitor'
      and claimed_at is null
      and bound_account_id is null
      and applicant_id is null
  );
$$;

revoke all on function public.has_unattached_visitor_applications()
  from public, anon, authenticated;
grant execute on function public.has_unattached_visitor_applications()
  to service_role;

-- Attaches the free visitor rows whose typed email equals one of p_emails
-- (lowercase, trimmed) or whose typed phone equals one of p_phones (exactly, in
-- international format) to this account, and returns how many it attached. The
-- caller (the claim function) passes only contacts Clerk has verified, this
-- function trusts them and nothing else.
--   * Does nothing when the account is already a seller.
--   * Approved and rejected rows always attach, in one statement.
--   * A reviewing row attaches only when the account has no open application
--     (reviewing, as applicant or as bound account), and only the oldest one, so
--     the one open rule keeps holding. A race with the account's own submit ends
--     in a unique violation on seller_applications_one_reviewing_per_owner, which
--     is caught so the approved and rejected attaches before it stay.
-- Each statement repeats the free row conditions in its where, so two calls at the
-- same moment end with one winner per row. Service role only.
create function public.attach_applications_by_contact(
  p_clerk_id text,
  p_emails text[],
  p_phones text[]
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_emails text[];
  v_phones text[];
  v_count integer := 0;
  v_step integer;
begin
  if p_clerk_id is null or btrim(p_clerk_id) = '' then
    return 0;
  end if;

  select coalesce(array_agg(distinct lower(btrim(e))), '{}')
  into v_emails
  from unnest(coalesce(p_emails, '{}')) as e
  where btrim(e) <> '';
  select coalesce(array_agg(distinct btrim(p)), '{}')
  into v_phones
  from unnest(coalesce(p_phones, '{}')) as p
  where btrim(p) <> '';
  if cardinality(v_emails) = 0 and cardinality(v_phones) = 0 then
    return 0;
  end if;

  if exists (
    select 1 from public.user_profiles
    where id = p_clerk_id and role = 'seller'
  ) then
    return 0;
  end if;

  update public.seller_applications
  set bound_account_id = p_clerk_id
  where origin = 'visitor'
    and status in ('approved', 'rejected')
    and claimed_at is null
    and bound_account_id is null
    and applicant_id is null
    and (lower(applicant_email) = any (v_emails)
         or applicant_phone = any (v_phones));
  get diagnostics v_count = row_count;

  if not exists (
    select 1 from public.seller_applications
    where status = 'reviewing'
      and (applicant_id = p_clerk_id or bound_account_id = p_clerk_id)
  ) then
    begin
      update public.seller_applications
      set bound_account_id = p_clerk_id
      where id = (
          select id from public.seller_applications
          where origin = 'visitor'
            and status = 'reviewing'
            and claimed_at is null
            and bound_account_id is null
            and applicant_id is null
            and (lower(applicant_email) = any (v_emails)
                 or applicant_phone = any (v_phones))
          order by created_at, id
          limit 1
        )
        and status = 'reviewing'
        and claimed_at is null
        and bound_account_id is null
        and applicant_id is null;
      get diagnostics v_step = row_count;
      v_count := v_count + v_step;
    exception when unique_violation then
      null;
    end;
  end if;

  return v_count;
end;
$$;

revoke all on function public.attach_applications_by_contact(text, text[], text[])
  from public, anon, authenticated;
grant execute on function public.attach_applications_by_contact(text, text[], text[])
  to service_role;

-- ------------------------------------------------------------
-- 3. merge_anonymous_identity: the cart and the orders only
-- ------------------------------------------------------------
-- 0007's version without the applications block. The cart and order part is the
-- same as in 0001 and 0007.
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
end;
$$;

revoke all on function public.merge_anonymous_identity(text) from public;
grant execute on function public.merge_anonymous_identity(text) to authenticated;

-- ------------------------------------------------------------
-- 4. Row level security (AC-10, AC-17)
-- ------------------------------------------------------------
-- The session that sent a visitor row reads it only while the row is free. Once it
-- is attached or claimed it belongs to the account, and the phone it was sent
-- from sees nothing of it.
drop policy "owners read own applications" on public.seller_applications;

create policy "owners read own applications"
on public.seller_applications for select
to authenticated
using (
  (submitter_id = (select auth.jwt() ->> 'sub')
    and applicant_id is null
    and bound_account_id is null)
  or applicant_id = (select auth.jwt() ->> 'sub')
  or bound_account_id = (select auth.jwt() ->> 'sub')
);
