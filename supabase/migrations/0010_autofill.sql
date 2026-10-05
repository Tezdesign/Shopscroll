-- ============================================================
-- 0010: daily limit for "Fill from photos" (spec 0015, task 10)
-- ============================================================
-- Run against a TEST or BRANCH project first, after 0008. It adds one table
-- and one function. Only the `autofill-product` Edge Function (service role)
-- calls the function; no signed in client can.
--
-- Rollback: drop the function and the table. Nothing else depends on them.

create table if not exists public.ai_autofill_usage (
  user_id text not null,
  day date not null,
  runs integer not null default 0 check (runs >= 0),
  primary key (user_id, day)
);

-- No client policy on purpose: the table is read and written only by the
-- function below.
alter table public.ai_autofill_usage enable row level security;
revoke all on public.ai_autofill_usage from anon, authenticated;

-- Counts one run that is about to start, and says how many the person has used
-- today (on the Tunis calendar day), or -1 when the limit is already reached
-- and nothing was counted. Every run that starts counts, even one that fails
-- later, so timing out on purpose cannot run up the cost. One statement does
-- the check and the count, so two parallel calls cannot both take the last run.
create or replace function public.take_autofill_run(p_user text, p_limit integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day date := (now() at time zone 'Africa/Tunis')::date;
  v_runs integer;
begin
  insert into public.ai_autofill_usage as u (user_id, day, runs)
  values (p_user, v_day, 1)
  on conflict (user_id, day) do update
  set runs = u.runs + 1
  where u.runs < p_limit
  returning u.runs into v_runs;

  return coalesce(v_runs, -1);
end;
$$;

revoke all on function public.take_autofill_run(text, integer)
  from public, anon, authenticated;
grant execute on function public.take_autofill_run(text, integer) to service_role;
