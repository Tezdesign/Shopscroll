-- ============================================================
-- 0008: seller product creation (spec 0015, build plan task 1)
-- ============================================================
-- Run against a TEST or BRANCH project first (supabase db push), never first
-- on live. Never a rerun of schema.sql.
--
-- What it does:
--   1. Adds a store currency, and the status, currency, attributes and
--      updated_at columns on products. Prices widen to 3 decimals.
--   2. Adds product_variants (one row per color and size, with price, stock,
--      optional SKU and photo) and gives every existing product its variants.
--   3. Adds product_categories (the one list of allowed categories) and
--      product_drafts (a seller's half finished work, kept apart from the
--      catalog).
--   4. Closes direct client writes to products and product_variants. They now
--      change only through save_product, set_product_archived,
--      update_variant_quick and (in 0009) place_order.
--   5. Shoppers read only live products. A seller also reads their own
--      archived ones.
--   6. Adds the product-images bucket and its rules.
--
-- Photo columns: products.image_url and image_urls hold the storage path with
-- the bucket in front ('product-images/<sub>/<id>/<file>.jpg') for photos a
-- seller uploads. SQL does not know the project URL, so the buyer app turns
-- such a value into the public URL. Seed rows keep their full https URLs.
--
-- Rollback: this changes live behavior (read policy, grants). To undo, restore
-- the 0004 grants and policies on products, drop the new tables and functions,
-- and drop the new columns. Rows written to the new tables are lost.

-- ------------------------------------------------------------
-- 1. Currency, status and the other new product columns
-- ------------------------------------------------------------
alter table public.user_profiles
  add column if not exists currency text not null default 'TND';

alter table public.user_profiles
  drop constraint if exists user_profiles_currency_check;
alter table public.user_profiles
  add constraint user_profiles_currency_check check (currency ~ '^[A-Z]{3}$');

alter table public.products
  alter column price type numeric(12, 3),
  alter column original_price type numeric(12, 3);

alter table public.products
  add column if not exists status text not null default 'live',
  add column if not exists currency text not null default 'TND',
  add column if not exists attributes jsonb not null default '{}'::jsonb,
  add column if not exists updated_at timestamptz not null default now();

alter table public.products
  drop constraint if exists products_status_check,
  drop constraint if exists products_currency_check,
  drop constraint if exists products_attributes_check;
alter table public.products
  add constraint products_status_check check (status in ('live', 'archived')),
  add constraint products_currency_check check (currency ~ '^[A-Z]{3}$'),
  add constraint products_attributes_check check (jsonb_typeof(attributes) = 'object');

create index if not exists products_store_status_idx
  on public.products (store_id, status);

-- ------------------------------------------------------------
-- 2. Categories
-- ------------------------------------------------------------
-- The slug is the exact text products.category already holds, because the
-- buyer app filters by that text.
create table if not exists public.product_categories (
  slug text primary key,
  label text not null,
  position integer not null
);

insert into public.product_categories (slug, label, position) values
  ('Fashion', 'Fashion', 1),
  ('Tech', 'Tech', 2),
  ('Sports', 'Sports', 3),
  ('Makeup', 'Makeup', 4)
on conflict (slug) do nothing;

alter table public.product_categories enable row level security;
revoke all on public.product_categories from anon, authenticated;
grant select on public.product_categories to anon, authenticated;

drop policy if exists "categories are publicly readable" on public.product_categories;
create policy "categories are publicly readable"
on public.product_categories for select
to anon, authenticated
using (true);

-- ------------------------------------------------------------
-- 3. Variants
-- ------------------------------------------------------------
create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  color_name text check (char_length(color_name) <= 30),
  -- Same form as products.color_options: a full ARGB value.
  color_value bigint,
  size text check (char_length(size) <= 20),
  price numeric(12, 3) not null check (price > 0 and price <= 99999999),
  stock integer not null default 0 check (stock >= 0),
  sku text check (char_length(sku) <= 64),
  -- One of the product's photo paths (without the bucket name).
  image_path text,
  position integer not null default 0
);

create unique index if not exists product_variants_option_key
  on public.product_variants (product_id, coalesce(color_value, -1), coalesce(size, ''));
create index if not exists product_variants_product_idx
  on public.product_variants (product_id);

-- Every existing product gets variants: one per color and size, or one plain
-- variant. Price is the product's price. Stock is 10 for a product that was in
-- stock and 0 for one that was not (seed data had no stock numbers).
insert into public.product_variants (product_id, color_value, size, price, stock, position)
select
  p.id,
  c.color,
  s.size,
  p.price,
  case when p.in_stock then 10 else 0 end,
  (row_number() over (partition by p.id order by c.o, s.o) - 1)::integer
from public.products p
cross join lateral (
  select t.color, min(t.o) as o
  from unnest(
    case when cardinality(p.color_options) = 0
      then array[null::bigint] else p.color_options end
  ) with ordinality as t(color, o)
  group by t.color
) c
cross join lateral (
  select t.size, min(t.o) as o
  from unnest(
    case when cardinality(p.sizes) = 0
      then array[null::text] else p.sizes end
  ) with ordinality as t(size, o)
  group by t.size
) s
where not exists (
  select 1 from public.product_variants v where v.product_id = p.id
);

alter table public.product_variants enable row level security;
revoke all on public.product_variants from anon, authenticated;
grant select on public.product_variants to anon, authenticated;

-- A variant is readable when its product is (the products policy below does
-- the filtering, because this subquery runs as the caller).
drop policy if exists "variants follow their product" on public.product_variants;
create policy "variants follow their product"
on public.product_variants for select
to anon, authenticated
using (
  exists (select 1 from public.products p where p.id = product_id)
);

-- Keeps products.in_stock in step when stock changes anywhere (save_product,
-- update_variant_quick, place_order). security definer so it can write a
-- column clients cannot. Same pattern as sync_reel_like_count.
create or replace function public.sync_product_in_stock()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pid uuid := coalesce(new.product_id, old.product_id);
begin
  update public.products
  set in_stock = exists (
    select 1 from public.product_variants v
    where v.product_id = v_pid and v.stock > 0
  )
  where id = v_pid;
  return null;
end;
$$;

revoke all on function public.sync_product_in_stock() from public, anon, authenticated;

drop trigger if exists product_variants_sync_in_stock on public.product_variants;
create trigger product_variants_sync_in_stock
after insert or update of stock or delete on public.product_variants
for each row execute function public.sync_product_in_stock();

-- ------------------------------------------------------------
-- 4. Drafts
-- ------------------------------------------------------------
-- A draft is a JSON working copy. The app saves it as the seller types; only
-- save_product turns it into a product. id is made by the app and becomes the
-- product id for a new product. payload shape (see spec 0015, Feature design):
--   title, description, category, attributes {key: text}, originalPrice,
--   photos [path], variants [{id, colorName, colorValue, size, price, stock,
--   stockSet, sku, imagePath}]
create table if not exists public.product_drafts (
  id uuid primary key,
  store_id text not null references public.user_profiles (id) on delete cascade,
  source_product_id uuid references public.products (id) on delete cascade,
  step integer not null default 1 check (step between 1 and 3),
  payload jsonb not null default '{}'::jsonb
    check (jsonb_typeof(payload) = 'object' and pg_column_size(payload) < 204800),
  updated_at timestamptz not null default now()
);

create index if not exists product_drafts_store_idx
  on public.product_drafts (store_id, updated_at desc);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists product_drafts_touch on public.product_drafts;
create trigger product_drafts_touch
before update on public.product_drafts
for each row execute function public.touch_updated_at();

alter table public.product_drafts enable row level security;
revoke all on public.product_drafts from anon, authenticated;
grant select, delete on public.product_drafts to authenticated;
grant insert (id, store_id, source_product_id, step, payload)
  on public.product_drafts to authenticated;
grant update (step, payload) on public.product_drafts to authenticated;

drop policy if exists "sellers read own drafts" on public.product_drafts;
create policy "sellers read own drafts"
on public.product_drafts for select
to authenticated
using (
  store_id = (select auth.jwt() ->> 'sub') and (select public.is_seller())
);

drop policy if exists "sellers insert own drafts" on public.product_drafts;
create policy "sellers insert own drafts"
on public.product_drafts for insert
to authenticated
with check (
  store_id = (select auth.jwt() ->> 'sub')
  and (select public.is_seller())
  and not coalesce(((select auth.jwt() ->> 'is_anonymous'))::boolean, false)
  and (
    source_product_id is null
    or exists (
      select 1 from public.products p
      where p.id = source_product_id
        and p.store_id = (select auth.jwt() ->> 'sub')
    )
  )
);

drop policy if exists "sellers update own drafts" on public.product_drafts;
create policy "sellers update own drafts"
on public.product_drafts for update
to authenticated
using (
  store_id = (select auth.jwt() ->> 'sub') and (select public.is_seller())
)
with check (
  store_id = (select auth.jwt() ->> 'sub') and (select public.is_seller())
);

drop policy if exists "sellers delete own drafts" on public.product_drafts;
create policy "sellers delete own drafts"
on public.product_drafts for delete
to authenticated
using (
  store_id = (select auth.jwt() ->> 'sub') and (select public.is_seller())
);

-- ------------------------------------------------------------
-- 5. Close direct writes to products, change who can read
-- ------------------------------------------------------------
-- The 0004 grants let a seller write store_name, in_stock and more straight
-- into products. Those go away: insert and update now happen only inside the
-- functions below. Delete stays, for archived products only.
revoke insert, update, delete on public.products from anon, authenticated;
grant delete on public.products to authenticated;

drop policy if exists "sellers insert own products" on public.products;
drop policy if exists "sellers update own products" on public.products;
drop policy if exists "sellers delete own products" on public.products;
create policy "sellers delete own archived products"
on public.products for delete
to authenticated
using (
  store_id = (select auth.jwt() ->> 'sub')
  and (select public.is_seller())
  and status = 'archived'
);

drop policy if exists "products are publicly readable" on public.products;
drop policy if exists "live products are readable" on public.products;
create policy "live products are readable"
on public.products for select
to anon, authenticated
using (
  status = 'live' or store_id = (select auth.jwt() ->> 'sub')
);

-- ------------------------------------------------------------
-- 6. Functions
-- ------------------------------------------------------------
-- Same convention as supabase/AGENTS.md: security definer, empty search_path
-- with every reference schema qualified, execute revoked from public and anon,
-- granted back to authenticated. Refusals are raised as the whole error
-- message and the app reads them.

-- Internal: the caller's id, or no_session / not_seller. Called only from the
-- functions below (which run as the owner), so nobody is granted it.
create or replace function public.require_seller()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user text := (select auth.jwt() ->> 'sub');
begin
  if v_user is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'no_session';
  end if;
  if not exists (
    select 1 from public.user_profiles where id = v_user and role = 'seller'
  ) then
    raise exception 'not_seller';
  end if;
  return v_user;
end;
$$;

revoke all on function public.require_seller() from public, anon, authenticated;

-- Turns a draft into a live product (new, or an edit of an existing one) in
-- one transaction, or changes nothing. Reason codes: no_session, not_seller,
-- not_found, bad_title, bad_description, bad_category, no_photo,
-- too_many_photos, bad_photo_path, bad_attributes, bad_price,
-- no_variants, too_many_variants, bad_variant:<n>, duplicate_variant,
-- missing_price:<variant id>, bad_stock:<variant id>, bad_sku:<variant id>.
--
-- A repeat call for a new product that already saved returns its id. For an
-- edit the draft is gone after the first success, so a repeat says not_found
-- and the app checks the product instead.
create or replace function public.save_product(p_draft_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user text := public.require_seller();
  v_draft public.product_drafts;
  v_existing public.products;
  v_profile public.user_profiles;
  v_pid uuid;
  v_p jsonb;
  v_title text;
  v_desc text;
  v_cat text;
  v_attrs jsonb;
  v_orig numeric;
  v_photos text[];
  v_photo text;
  v_vars jsonb;
  v_v jsonb;
  v_n integer;
  v_idx integer;
  v_vid uuid;
  v_price numeric;
  v_stock numeric;
  v_min numeric;
  v_colors bigint[];
  v_sizes text[];
  v_urls text[];
  v_rows integer;
begin
  select * into v_draft
  from public.product_drafts
  where id = p_draft_id and store_id = v_user
  for update;

  if not found then
    if exists (
      select 1 from public.products where id = p_draft_id and store_id = v_user
    ) then
      return p_draft_id;
    end if;
    raise exception 'not_found';
  end if;

  v_pid := coalesce(v_draft.source_product_id, v_draft.id);
  v_p := v_draft.payload;

  -- Lock the product row for the whole save, so two saves cannot both pass.
  select * into v_existing from public.products where id = v_pid for update;
  if found and v_existing.store_id <> v_user then
    raise exception 'not_found';
  end if;
  if not found and v_draft.source_product_id is not null then
    raise exception 'not_found';
  end if;

  -- Basics
  v_title := btrim(coalesce(v_p ->> 'title', ''));
  if char_length(v_title) not between 2 and 100 then
    raise exception 'bad_title';
  end if;

  v_desc := btrim(coalesce(v_p ->> 'description', ''));
  if char_length(v_desc) > 2000 then
    raise exception 'bad_description';
  end if;

  v_cat := coalesce(v_p ->> 'category', '');
  if not exists (select 1 from public.product_categories where slug = v_cat) then
    raise exception 'bad_category';
  end if;

  v_attrs := coalesce(v_p -> 'attributes', '{}'::jsonb);
  if jsonb_typeof(v_attrs) <> 'object'
     or (select count(*) from jsonb_object_keys(v_attrs)) > 20
     or exists (
       select 1 from jsonb_each(v_attrs) e
       where jsonb_typeof(e.value) <> 'string'
          or char_length(e.key) not between 1 and 40
          or char_length(e.value #>> '{}') > 200
     ) then
    raise exception 'bad_attributes';
  end if;

  if nullif(v_p ->> 'originalPrice', '') is not null then
    begin
      v_orig := (v_p ->> 'originalPrice')::numeric;
    exception when others then
      v_orig := null;
    end;
    if v_orig is null or v_orig <= 0 or v_orig > 99999999
       or round(v_orig, 3) <> v_orig then
      raise exception 'bad_price';
    end if;
  end if;

  -- Photos: paths in the caller's own folder, files that really exist.
  if jsonb_typeof(v_p -> 'photos') is distinct from 'array'
     or jsonb_array_length(v_p -> 'photos') = 0 then
    raise exception 'no_photo';
  end if;
  if jsonb_array_length(v_p -> 'photos') > 8 then
    raise exception 'too_many_photos';
  end if;

  select array_agg(t.value #>> '{}' order by t.ord)
  into v_photos
  from jsonb_array_elements(v_p -> 'photos') with ordinality as t(value, ord);

  foreach v_photo in array v_photos loop
    if v_photo is null
       or char_length(v_photo) > 200
       or position('..' in v_photo) > 0
       or not (
         starts_with(v_photo, v_user || '/' || v_draft.id::text || '/')
         or starts_with(v_photo, v_user || '/' || v_pid::text || '/')
       )
       or not exists (
         select 1 from storage.objects o
         where o.bucket_id = 'product-images' and o.name = v_photo
       ) then
      raise exception 'bad_photo_path';
    end if;
  end loop;

  -- Variants
  v_vars := v_p -> 'variants';
  if jsonb_typeof(v_vars) is distinct from 'array'
     or jsonb_array_length(v_vars) = 0 then
    raise exception 'no_variants';
  end if;
  v_n := jsonb_array_length(v_vars);
  if v_n > 100 then
    raise exception 'too_many_variants';
  end if;

  v_idx := 0;
  for v_v in select e from jsonb_array_elements(v_vars) as e loop
    v_idx := v_idx + 1;

    begin
      v_vid := (v_v ->> 'id')::uuid;
    exception when others then
      v_vid := null;
    end;
    if v_vid is null then
      raise exception 'bad_variant:%', v_idx;
    end if;

    begin
      v_price := (v_v ->> 'price')::numeric;
    exception when others then
      v_price := null;
    end;
    if v_price is null or v_price <= 0 or v_price > 99999999
       or round(v_price, 3) <> v_price then
      raise exception 'missing_price:%', v_vid;
    end if;

    begin
      v_stock := (v_v ->> 'stock')::numeric;
    exception when others then
      v_stock := null;
    end;
    if v_stock is null or v_stock < 0 or v_stock > 1000000
       or v_stock <> trunc(v_stock) then
      raise exception 'bad_stock:%', v_vid;
    end if;

    if char_length(coalesce(v_v ->> 'sku', '')) > 64
       or char_length(coalesce(v_v ->> 'size', '')) > 20
       or char_length(coalesce(v_v ->> 'colorName', '')) > 30 then
      raise exception 'bad_sku:%', v_vid;
    end if;

    begin
      perform nullif(v_v ->> 'colorValue', '')::bigint;
    exception when others then
      raise exception 'bad_variant:%', v_idx;
    end;

    if nullif(v_v ->> 'imagePath', '') is not null
       and not ((v_v ->> 'imagePath') = any (v_photos)) then
      raise exception 'bad_photo_path';
    end if;
  end loop;

  if (
    select count(distinct (
      coalesce(nullif(e ->> 'colorValue', '')::bigint, -1),
      coalesce(nullif(btrim(e ->> 'size'), ''), '')
    ))
    from jsonb_array_elements(v_vars) e
  ) <> v_n
  or (
    select count(distinct (e ->> 'id')) from jsonb_array_elements(v_vars) e
  ) <> v_n then
    raise exception 'duplicate_variant';
  end if;

  -- Derived values for the buyer app's existing columns.
  select min((e ->> 'price')::numeric) into v_min
  from jsonb_array_elements(v_vars) e;

  v_urls := array(
    select 'product-images/' || t.p
    from unnest(v_photos) with ordinality as t(p, o)
    order by t.o
  );

  v_colors := array(
    select s.cv from (
      select nullif(t.e ->> 'colorValue', '')::bigint as cv, min(t.ord) as o
      from jsonb_array_elements(v_vars) with ordinality as t(e, ord)
      where nullif(t.e ->> 'colorValue', '') is not null
      group by 1
    ) s order by s.o
  );

  v_sizes := array(
    select s.sz from (
      select nullif(btrim(t.e ->> 'size'), '') as sz, min(t.ord) as o
      from jsonb_array_elements(v_vars) with ordinality as t(e, ord)
      where nullif(btrim(t.e ->> 'size'), '') is not null
      group by 1
    ) s order by s.o
  );

  select * into v_profile from public.user_profiles where id = v_user;

  if v_existing.id is null then
    insert into public.products (
      id, title, description, price, original_price, category, store_id,
      store_name, store_avatar_url, image_url, image_urls, color_options, sizes,
      is_deal, in_stock, status, currency, attributes, updated_at
    ) values (
      v_pid, v_title, v_desc, v_min, v_orig, v_cat, v_user,
      v_profile.name, v_profile.avatar_url, v_urls[1], v_urls, v_colors, v_sizes,
      v_orig is not null and v_orig > v_min, false, 'live', v_profile.currency,
      v_attrs, now()
    );
  else
    update public.products
    set title = v_title,
        description = v_desc,
        price = v_min,
        original_price = v_orig,
        category = v_cat,
        image_url = v_urls[1],
        image_urls = v_urls,
        color_options = v_colors,
        sizes = v_sizes,
        is_deal = v_orig is not null and v_orig > v_min,
        attributes = v_attrs,
        updated_at = now()
    where id = v_pid;
  end if;

  delete from public.product_variants pv
  where pv.product_id = v_pid
    and pv.id not in (
      select (e ->> 'id')::uuid from jsonb_array_elements(v_vars) e
    );

  begin
    insert into public.product_variants (
      id, product_id, color_name, color_value, size, price, stock, sku,
      image_path, position
    )
    select
      (t.e ->> 'id')::uuid,
      v_pid,
      nullif(btrim(t.e ->> 'colorName'), ''),
      nullif(t.e ->> 'colorValue', '')::bigint,
      nullif(btrim(t.e ->> 'size'), ''),
      (t.e ->> 'price')::numeric,
      (t.e ->> 'stock')::numeric::integer,
      nullif(btrim(t.e ->> 'sku'), ''),
      nullif(t.e ->> 'imagePath', ''),
      (t.ord - 1)::integer
    from jsonb_array_elements(v_vars) with ordinality as t(e, ord)
    on conflict (id) do update
    set color_name = excluded.color_name,
        color_value = excluded.color_value,
        size = excluded.size,
        price = excluded.price,
        sku = excluded.sku,
        image_path = excluded.image_path,
        position = excluded.position
    where public.product_variants.product_id = v_pid;
    get diagnostics v_rows = row_count;
  exception when unique_violation then
    raise exception 'duplicate_variant';
  end;

  -- An id that belongs to another product is not updated and not counted.
  if v_rows <> v_n then
    raise exception 'bad_variant:0';
  end if;

  -- On an edit, stock changes only for variants the seller changed on purpose,
  -- so orders placed since the draft was opened are not overwritten.
  update public.product_variants pv
  set stock = (t.e ->> 'stock')::numeric::integer
  from jsonb_array_elements(v_vars) as t(e)
  where pv.id = (t.e ->> 'id')::uuid
    and pv.product_id = v_pid
    and coalesce((t.e ->> 'stockSet')::boolean, false);

  update public.products
  set price = (select min(price) from public.product_variants where product_id = v_pid),
      in_stock = exists (
        select 1 from public.product_variants
        where product_id = v_pid and stock > 0
      )
  where id = v_pid;

  delete from public.product_drafts where id = p_draft_id;
  return v_pid;
end;
$$;

revoke all on function public.save_product(uuid) from public, anon;
grant execute on function public.save_product(uuid) to authenticated;

-- Archives a live product, or restores an archived one. Calling it with the
-- state the product is already in changes nothing.
create or replace function public.set_product_archived(p_id uuid, p_archived boolean)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user text := public.require_seller();
begin
  update public.products
  set status = case when p_archived then 'archived' else 'live' end,
      updated_at = now()
  where id = p_id
    and store_id = v_user
    and status is distinct from case when p_archived then 'archived' else 'live' end;

  if not found and not exists (
    select 1 from public.products where id = p_id and store_id = v_user
  ) then
    raise exception 'not_found';
  end if;
  return p_id;
end;
$$;

revoke all on function public.set_product_archived(uuid, boolean) from public, anon;
grant execute on function public.set_product_archived(uuid, boolean) to authenticated;

-- The small edit from the Products list: one variant's price and stock.
create or replace function public.update_variant_quick(
  p_variant_id uuid,
  p_price numeric,
  p_stock integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user text := public.require_seller();
  v_pid uuid;
begin
  select pv.product_id into v_pid
  from public.product_variants pv
  join public.products p on p.id = pv.product_id
  where pv.id = p_variant_id and p.store_id = v_user;

  if not found then
    raise exception 'not_found';
  end if;

  if p_price is null or p_price <= 0 or p_price > 99999999
     or round(p_price, 3) <> p_price then
    raise exception 'missing_price';
  end if;
  if p_stock is null or p_stock < 0 or p_stock > 1000000 then
    raise exception 'bad_stock';
  end if;

  perform 1 from public.products where id = v_pid for update;

  update public.product_variants
  set price = p_price, stock = p_stock
  where id = p_variant_id;

  update public.products
  set price = (select min(price) from public.product_variants where product_id = v_pid),
      updated_at = now()
  where id = v_pid;

  return p_variant_id;
end;
$$;

revoke all on function public.update_variant_quick(uuid, numeric, integer) from public, anon;
grant execute on function public.update_variant_quick(uuid, numeric, integer) to authenticated;

-- ------------------------------------------------------------
-- 7. Storage
-- ------------------------------------------------------------
-- Public read, JPEG only, 2 MB (the phone shrinks every photo first). The
-- Storage API enforces the size and type, SQL cannot (see the manual checks).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 2097152, array['image/jpeg'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- A seller (not an anonymous session) adds, replaces and removes files only
-- under their own id folder. Clerk ids are not uuids, so the folder is compared
-- to the JWT sub, never auth.uid() or owner.
drop policy if exists "sellers read own product photos" on storage.objects;
create policy "sellers read own product photos"
on storage.objects for select
to authenticated
using (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = (select auth.jwt() ->> 'sub')
  and (select public.is_seller())
);

drop policy if exists "sellers add own product photos" on storage.objects;
create policy "sellers add own product photos"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = (select auth.jwt() ->> 'sub')
  and not coalesce(((select auth.jwt() ->> 'is_anonymous'))::boolean, false)
  and (select public.is_seller())
);

drop policy if exists "sellers replace own product photos" on storage.objects;
create policy "sellers replace own product photos"
on storage.objects for update
to authenticated
using (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = (select auth.jwt() ->> 'sub')
  and (select public.is_seller())
)
with check (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = (select auth.jwt() ->> 'sub')
  and (select public.is_seller())
);

drop policy if exists "sellers remove own product photos" on storage.objects;
create policy "sellers remove own product photos"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = (select auth.jwt() ->> 'sub')
  and (select public.is_seller())
);
