-- ============================================================
-- 0017: problem reports on an order, and the seller's Reports tab (spec 0018, task 6)
-- ============================================================
-- Run against a TEST or BRANCH project first, after 0014. This only adds tables,
-- a bucket and functions, so nothing existing changes. Rollback:
--   drop function public.resolve_report(uuid);
--   drop function public.store_report_detail(uuid);
--   drop function public.store_reports_list(text, text, integer, timestamptz, uuid);
--   drop function public.store_reports_summary();
--   drop table public.report_items;
--   drop table public.reports;
--   drop policy "sellers read own report attachments" on storage.objects;
--   (then empty and delete the report-attachments bucket, Supabase refuses to
--   drop a bucket that holds files)
--
-- Nothing in this spec creates a report: a later buyer feature does (spec 0018,
-- AC-17), so the Reports tab starts empty. The only write is resolve_report.
--
-- Same convention as supabase/AGENTS.md: security definer, empty search_path,
-- execute revoked from public and anon and granted to authenticated only.
-- Refusals are raised as the whole error message: no_session, not_seller,
-- not_found, bad_status, bad_cursor.

-- ------------------------------------------------------------
-- 1. reports
-- ------------------------------------------------------------
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  -- Shown as #R-0001.
  report_number bigint generated always as identity unique,
  order_id uuid not null,
  -- The seller's Clerk id. No foreign key, same as orders.user_id.
  store_id text not null,
  -- The buyer's Clerk id. Private: no function returns it.
  reporter_id text not null,
  title text not null check (char_length(title) between 1 and 120),
  description text not null check (char_length(description) between 1 and 2000),
  -- Paths in the report-attachments bucket, <store_id>/<report_id>/<file>.
  attachment_paths text[] not null default '{}'
    check (cardinality(attachment_paths) <= 6),
  status text not null default 'unsolved'
    check (status in ('unsolved', 'resolved')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  -- resolved_at is set together with the status, and only then.
  check ((status = 'resolved') = (resolved_at is not null)),
  -- A report only points at a store that sold in that order, and goes away
  -- with it.
  foreign key (order_id, store_id)
    references public.store_orders (order_id, store_id) on delete cascade,
  -- Lets report_items point at a report of one order and one store.
  unique (id, order_id, store_id)
);

create index if not exists reports_list_idx
  on public.reports (store_id, created_at desc, id desc);
create index if not exists reports_status_idx
  on public.reports (store_id, status);

alter table public.reports enable row level security;
revoke all on public.reports from anon, authenticated;

-- ------------------------------------------------------------
-- 2. report_items
-- ------------------------------------------------------------
-- The foreign keys make the database itself guarantee that each item is a line
-- of the report's own order and store.
create table if not exists public.report_items (
  report_id uuid not null,
  order_item_id uuid not null,
  order_id uuid not null,
  store_id text not null,
  primary key (report_id, order_item_id),
  foreign key (report_id, order_id, store_id)
    references public.reports (id, order_id, store_id) on delete cascade,
  foreign key (order_item_id, order_id, store_id)
    references public.order_items (id, order_id, store_id) on delete cascade
);

alter table public.report_items enable row level security;
revoke all on public.report_items from anon, authenticated;

-- ------------------------------------------------------------
-- 3. report-attachments bucket
-- ------------------------------------------------------------
-- Private. A seller reads only the folder named after their own id. There is
-- no insert policy: only a later buyer feature uploads (through its own
-- function), so no client can add a file here today.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('report-attachments', 'report-attachments', false, 5242880,
        array['image/jpeg', 'image/png'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "sellers read own report attachments" on storage.objects;
create policy "sellers read own report attachments"
on storage.objects for select
to authenticated
using (
  bucket_id = 'report-attachments'
  and (storage.foldername(name))[1] = (select auth.jwt() ->> 'sub')
  and (select public.is_seller())
);

-- ------------------------------------------------------------
-- 4. store_reports_summary
-- ------------------------------------------------------------
-- The three cards on the Reports tab. "Today" is the Africa/Tunis day.
-- returned_orders counts this store's orders with status returned, which stays
-- 0 until a later spec can set that status.
create or replace function public.store_reports_summary()
returns table (
  total bigint,
  new_today bigint,
  unresolved bigint,
  returned_orders bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_store text := public.require_seller();
  v_day timestamp := date_trunc('day', now() at time zone 'Africa/Tunis');
begin
  return query
  select
    count(*),
    count(*) filter (where (r.created_at at time zone 'Africa/Tunis') >= v_day),
    count(*) filter (where r.status = 'unsolved'),
    (
      select count(*)
      from public.store_orders as so
      where so.store_id = v_store and so.status = 'returned'
    )
  from public.reports as r
  where r.store_id = v_store;
end;
$$;

revoke all on function public.store_reports_summary() from public, anon;
grant execute on function public.store_reports_summary() to authenticated;

-- ------------------------------------------------------------
-- 5. store_reports_list
-- ------------------------------------------------------------
-- One row per report of the caller, newest first, ordered by (created_at, id)
-- so the keyset never repeats or skips a row. Search uses strpos on lower case
-- text, not like, so % and _ are plain characters: a report number (leading
-- zeros ignored), the customer name or the title. A null contact name never
-- matches a name search. The first item is the line with the lowest id.
-- No column returns the buyer's account id (reporter_id).
create or replace function public.store_reports_list(
  p_status text default null,
  p_search text default null,
  p_limit integer default 20,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null
)
returns table (
  id uuid,
  report_number bigint,
  created_at timestamptz,
  status text,
  title text,
  customer_name text,
  first_item_title text,
  item_count bigint,
  order_number bigint,
  description text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_store text := public.require_seller();
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_text text := lower(btrim(coalesce(p_search, '')));
  v_digits text := ltrim(lower(btrim(coalesce(p_search, ''))), '0');
begin
  if p_status is not null and p_status not in ('unsolved', 'resolved') then
    raise exception 'bad_status';
  end if;
  if (p_cursor_created_at is null) <> (p_cursor_id is null) then
    raise exception 'bad_cursor';
  end if;

  return query
  select
    r.id,
    r.report_number,
    r.created_at,
    r.status,
    r.title,
    o.contact_name,
    i.first_title,
    i.item_count,
    o.order_number,
    r.description
  from public.reports as r
  join public.orders as o on o.id = r.order_id
  cross join lateral (
    select
      (array_agg(oi.title order by oi.id))[1] as first_title,
      count(*) as item_count
    from public.report_items as ri
    join public.order_items as oi on oi.id = ri.order_item_id
    where ri.report_id = r.id
  ) as i
  where r.store_id = v_store
    and (p_status is null or r.status = p_status)
    and (
      v_text = ''
      or (v_digits <> '' and strpos(r.report_number::text, v_digits) > 0)
      or strpos(lower(r.title), v_text) > 0
      or (
        o.contact_name is not null
        and strpos(lower(o.contact_name), v_text) > 0
      )
    )
    and (
      p_cursor_created_at is null
      or (r.created_at, r.id) < (p_cursor_created_at, p_cursor_id)
    )
  order by r.created_at desc, r.id desc
  limit v_limit;
end;
$$;

revoke all on function public.store_reports_list(
  text, text, integer, timestamptz, uuid
) from public, anon;
grant execute on function public.store_reports_list(
  text, text, integer, timestamptz, uuid
) to authenticated;

-- ------------------------------------------------------------
-- 6. store_report_detail
-- ------------------------------------------------------------
-- One report with the customer's contact from the order, its products and the
-- attachment paths (the app turns them into signed links). An unknown id and
-- another store's id give the same not_found.
create or replace function public.store_report_detail(p_report_id uuid)
returns table (
  id uuid,
  report_number bigint,
  created_at timestamptz,
  status text,
  title text,
  description text,
  customer_name text,
  customer_email text,
  customer_phone text,
  order_number bigint,
  purchased_at timestamptz,
  items jsonb,
  attachment_paths text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_store text := public.require_seller();
begin
  return query
  select
    r.id,
    r.report_number,
    r.created_at,
    r.status,
    r.title,
    r.description,
    o.contact_name,
    o.contact_email,
    o.contact_phone,
    o.order_number,
    o.created_at,
    i.items,
    r.attachment_paths
  from public.reports as r
  join public.orders as o on o.id = r.order_id
  cross join lateral (
    select coalesce(
      jsonb_agg(
        jsonb_build_object('title', oi.title, 'image_url', oi.image_url)
        order by oi.id
      ),
      '[]'::jsonb
    ) as items
    from public.report_items as ri
    join public.order_items as oi on oi.id = ri.order_item_id
    where ri.report_id = r.id
  ) as i
  where r.id = p_report_id and r.store_id = v_store;

  if not found then
    raise exception 'not_found';
  end if;
end;
$$;

revoke all on function public.store_report_detail(uuid) from public, anon;
grant execute on function public.store_report_detail(uuid) to authenticated;

-- ------------------------------------------------------------
-- 7. resolve_report
-- ------------------------------------------------------------
-- The only write in this spec. Limited to the caller's own report, and
-- idempotent: a second call changes nothing and returns the first answer.
create or replace function public.resolve_report(p_report_id uuid)
returns table (status text, resolved_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_store text := public.require_seller();
begin
  return query
  update public.reports as r
  set status = 'resolved',
      resolved_at = coalesce(r.resolved_at, now())
  where r.id = p_report_id and r.store_id = v_store
  returning r.status, r.resolved_at;

  if not found then
    raise exception 'not_found';
  end if;
end;
$$;

revoke all on function public.resolve_report(uuid) from public, anon;
grant execute on function public.resolve_report(uuid) to authenticated;
