-- ============================================================
-- 0016: the seller's earnings numbers (spec 0018, task 5)
-- ============================================================
-- Run against a TEST or BRANCH project first, after 0014. This only adds a
-- function, so there is nothing to roll back but dropping it:
--   drop function public.store_earnings();
--
-- store_earnings returns one row with the numbers on the Earnings tab. A sale
-- is a store order that is not canceled and not returned. Its amount is this
-- store's lines only (the same line sum as store_orders_list and
-- store_order_detail, so the three always agree).
--
-- "Today" and "this week" use the Africa/Tunis day, and the week starts on
-- Monday (the same zone place_order uses for delivery dates). The previous
-- week figure covers the same span as the week so far: from last Monday up to
-- the same weekday and time, so the percent in the app compares like with like.
--
-- Same convention as supabase/AGENTS.md: security definer, empty search_path,
-- execute revoked from public and anon and granted to authenticated only.
-- Refusals are raised as the whole error message: no_session, not_seller.
--
-- Nothing here returns the buyer's account id (it is only used inside to count
-- distinct buyers), the whole order total, the delivery fee or another store's
-- lines.
create or replace function public.store_earnings()
returns table (
  total_sales numeric,
  today_sales numeric,
  today_orders bigint,
  week_sales numeric,
  prev_week_same_span_sales numeric,
  customers bigint,
  new_customers_today bigint,
  currency text,
  recent jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_store text := public.require_seller();
  -- Tunis wall clock time, so the day and week edges are Tunis edges.
  v_now timestamp := now() at time zone 'Africa/Tunis';
  v_day timestamp := date_trunc('day', now() at time zone 'Africa/Tunis');
  v_week timestamp := date_trunc('week', now() at time zone 'Africa/Tunis');
begin
  return query
  with mine as (
    select
      so.order_id,
      so.created_at,
      (so.created_at at time zone 'Africa/Tunis') as local_at,
      o.user_id,
      o.order_number,
      o.contact_name,
      o.ship_city,
      o.ship_address,
      (
        select coalesce(sum(oi.unit_price * oi.quantity), 0)
        from public.order_items as oi
        where oi.order_id = so.order_id and oi.store_id = so.store_id
      ) as amount
    from public.store_orders as so
    join public.orders as o on o.id = so.order_id
    where so.store_id = v_store
      and so.status not in ('canceled', 'returned')
  ),
  buyers as (
    select user_id, min(local_at) as first_at
    from mine
    group by user_id
  )
  select
    coalesce((select sum(amount) from mine), 0),
    coalesce((select sum(amount) from mine where local_at >= v_day), 0),
    (select count(*) from mine where local_at >= v_day),
    coalesce((select sum(amount) from mine where local_at >= v_week), 0),
    coalesce((
      select sum(amount) from mine
      where local_at >= v_week - interval '7 days'
        and local_at <= v_now - interval '7 days'
    ), 0),
    (select count(*) from buyers),
    (select count(*) from buyers where first_at >= v_day),
    coalesce(
      (
        select nullif(btrim(p.currency), '')
        from public.user_profiles as p
        where p.id = v_store
      ),
      'TND'
    ),
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'order_id', r.order_id,
            'order_number', r.order_number,
            'customer_name', r.contact_name,
            'city', r.ship_city,
            'address', r.ship_address,
            'amount', r.amount
          )
          order by r.created_at desc, r.order_id desc
        )
        from (
          select * from mine
          order by created_at desc, order_id desc
          limit 4
        ) as r
      ),
      '[]'::jsonb
    );
end;
$$;

revoke all on function public.store_earnings() from public, anon;
grant execute on function public.store_earnings() to authenticated;
