-- Decision record: docs/specs/_root/0015-seller-product-creation/index.md (build plan task 10)
--
-- SQL checks for the daily limit of "Fill from photos": AC-13. Run in the SQL
-- editor of a TEST or BRANCH database after applying migration 0010. Ends with
-- `rollback`. Output: one NOTICE per check; a failure raises an error that
-- starts with FAIL.

begin;

create function pg_temp.try(p_sql text) returns text
language plpgsql as $$
declare v_rows integer;
begin
  execute p_sql;
  get diagnostics v_rows = row_count;
  return 'ok:' || v_rows;
exception when others then
  return 'err:' || sqlstate || ':' || sqlerrm;
end;
$$;

do $$
declare
  v_last integer;
  v_result text;
begin
  -- Runs 1 to 3 are counted in order.
  for i in 1..3 loop
    v_last := public.take_autofill_run('chk_u1', 3);
    if v_last <> i then
      raise exception 'FAIL AC-13: run % should answer %, got %', i, i, v_last;
    end if;
  end loop;
  raise notice 'ok   AC-13 runs are counted one by one';

  -- The next one is over the limit: -1, and nothing more is counted.
  if public.take_autofill_run('chk_u1', 3) <> -1 then
    raise exception 'FAIL AC-13: the run over the limit should answer -1';
  end if;
  if (select runs from public.ai_autofill_usage where user_id = 'chk_u1') <> 3 then
    raise exception 'FAIL AC-13: a refused run must not be counted';
  end if;
  raise notice 'ok   AC-13 the run over the limit is refused and not counted';

  -- Another person has their own count.
  if public.take_autofill_run('chk_u2', 3) <> 1 then
    raise exception 'FAIL AC-13: another person should start at 1';
  end if;
  raise notice 'ok   AC-13 each person has their own count';

  -- Who may call it: no signed in client.
  perform set_config('request.jwt.claims', '{"sub":"chk_u1"}', true);
  execute 'set local role authenticated';
  v_result := pg_temp.try($q$select public.take_autofill_run('chk_u1', 30)$q$);
  if v_result not like 'err:42501%' then
    raise exception 'FAIL AC-13: a signed in client must not call it, got %', v_result;
  end if;
  v_result := pg_temp.try($q$select * from public.ai_autofill_usage$q$);
  if v_result not like 'err:42501%' then
    raise exception 'FAIL AC-13: a signed in client must not read the usage table, got %', v_result;
  end if;
  execute 'reset role';
  raise notice 'ok   AC-13 a signed in client can neither count nor read';

  raise notice 'ALL CHECKS PASSED';
end;
$$;

rollback;
