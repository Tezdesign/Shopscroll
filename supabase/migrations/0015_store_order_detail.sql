-- ============================================================
-- 0015: the seller's order detail (spec 0018, task 4)
-- ============================================================
-- Run against a TEST or BRANCH project first, after 0014. This only adds a
-- function, so there is nothing to roll back but dropping it:
--   drop function public.store_order_detail(uuid);
--
-- store_order_detail returns one order as the calling store sees it: the
-- header, the customer contact, the delivery fields, the store's own lines and
-- their subtotal. It never returns the buyer's account id, the whole order
-- total, the delivery fee or another store's lines.
--
-- Same convention as supabase/AGENTS.md: security definer, empty search_path,
-- execute revoked from public and anon and granted to authenticated only.
-- Refusals are raised as the whole error message: no_session, not_seller,
-- not_found. An order with no row for this store (no line of theirs) and an
-- unknown id give the same not_found, so a seller cannot tell them apart.
create or replace function public.store_order_detail(p_order_id uuid)
returns table (
  order_id uuid,
  order_number bigint,
  status text,
  created_at timestamptz,
  customer_name text,
  customer_email text,
  customer_phone text,
  city text,
  address text,
  zip text,
  note text,
  delivery_method text,
  payment_method text,
  subtotal numeric,
  currency text,
  lines jsonb
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
    so.order_id,
    o.order_number,
    so.status,
    so.created_at,
    o.contact_name,
    o.contact_email,
    o.contact_phone,
    o.ship_city,
    o.ship_address,
    o.ship_zip,
    o.ship_note,
    o.delivery_method,
    o.payment_method,
    l.subtotal,
    o.currency,
    l.lines
  from public.store_orders as so
  join public.orders as o on o.id = so.order_id
  cross join lateral (
    select
      coalesce(sum(oi.unit_price * oi.quantity), 0) as subtotal,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'title', oi.title,
            'image_url', oi.image_url,
            'selected_size', oi.selected_size,
            'selected_color', oi.selected_color,
            'unit_price', oi.unit_price,
            'quantity', oi.quantity
          )
          order by oi.id
        ),
        '[]'::jsonb
      ) as lines
    from public.order_items as oi
    where oi.order_id = so.order_id and oi.store_id = so.store_id
  ) as l
  where so.order_id = p_order_id and so.store_id = v_store;

  if not found then
    raise exception 'not_found';
  end if;
end;
$$;

revoke all on function public.store_order_detail(uuid) from public, anon;
grant execute on function public.store_order_detail(uuid) to authenticated;
