-- Decision record: docs/specs/0008-activity-screens/index.md
--
-- Per person saved products, modelled on reel_saves (spec 0008, AC-9).
-- user_id is text: a Clerk id or an anonymous session's own `sub`, with no
-- foreign key, like every other owned table (spec 0004).
--
-- Safe to run twice: every statement is guarded.

create table if not exists public.product_saves (
  user_id text not null,
  product_id uuid not null references public.products (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create index if not exists product_saves_product_id_idx
  on public.product_saves (product_id);

alter table public.product_saves enable row level security;

-- Own rows only, and no update policy: a save is either there or not.
drop policy if exists "read own product saves" on public.product_saves;
create policy "read own product saves"
on public.product_saves for select
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

drop policy if exists "insert own product saves" on public.product_saves;
create policy "insert own product saves"
on public.product_saves for insert
to authenticated
with check ((select auth.jwt() ->> 'sub') = user_id);

drop policy if exists "delete own product saves" on public.product_saves;
create policy "delete own product saves"
on public.product_saves for delete
to authenticated
using ((select auth.jwt() ->> 'sub') = user_id);

grant select, insert, delete on public.product_saves to authenticated;
