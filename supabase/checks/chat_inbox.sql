-- Decision record: docs/specs/buyer/0011-chat/index.md (build plan task 3)
--
-- SQL checks for chat, migration 0019: AC-8, AC-15, AC-16 (the inbox list and
-- the unread count). Run the whole file in the SQL editor of a TEST or BRANCH
-- database (or with psql) after applying migrations 0014, 0018 and 0019. It
-- creates its own fixtures, acts as buyers and stores with a fake JWT, and
-- ends with `rollback`, so it leaves no rows behind.
--
-- Output: one NOTICE per check. A failed check raises an error that starts with
-- FAIL and stops the script.

begin;

create function pg_temp.act_as(p_sub text, p_anonymous boolean default false)
returns void language plpgsql as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_sub, 'is_anonymous', p_anonymous)::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

create function pg_temp.try(p_sql text) returns text
language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return 'err:' || sqlstate || ':' || sqlerrm;
end;
$$;

-- chk_s1 and chk_s2 are stores, chk_b1 and chk_b2 buyers.
insert into public.user_profiles (id, name, username, role, currency, follower_count) values
  ('chk_s1', 'Chk Store 1', 'chk_s1', 'seller', 'TND', 10),
  ('chk_s2', 'Chk Store 2', 'chk_s2', 'seller', 'TND', 10),
  ('chk_b1', 'Chk Buyer 1', 'chk_b1', 'buyer', 'TND', 0),
  ('chk_b2', 'Chk Buyer 2', 'chk_b2', 'buyer', 'TND', 0);

-- Three threads for b1 (s1 oldest, s2 newest), one for b2 with s1. Times are
-- fixed so the order does not depend on the clock. The s2 thread was last
-- written by the buyer, so it is never unread for b1.
insert into public.conversations
  (id, buyer_id, store_id, created_by, last_message_at, last_sender_id,
   last_message_preview, buyer_read_at, store_read_at)
values
  ('00000000-0000-0000-0000-0000000000e1', 'chk_b1', 'chk_s1', 'chk_b1',
   '2026-01-01 10:00+00', 'chk_s1', 'from s1', null, null),
  ('00000000-0000-0000-0000-0000000000e2', 'chk_b1', 'chk_s2', 'chk_b1',
   '2026-01-02 10:00+00', 'chk_b1', 'from b1', null, null),
  ('00000000-0000-0000-0000-0000000000e3', 'chk_b2', 'chk_s1', 'chk_b2',
   '2026-01-03 10:00+00', 'chk_b2', 'from b2', null, null);

do $chk$
declare
  v_rows integer;
  v_first uuid;
  v_text text;
begin
  -- ------------------------------------------------------- AC-15 sessions
  perform pg_temp.act_as('chk_b1', true);
  if pg_temp.try($q$select * from public.chat_conversations_list('buyer')$q$)
     <> 'err:P0001:no_session' then
    raise exception 'FAIL AC-15: an anonymous session must get no_session';
  end if;
  reset role;
  raise notice 'ok   AC-15 an anonymous session gets no_session';

  perform pg_temp.act_as('chk_nobody');
  if pg_temp.try($q$select public.chat_unread_count('buyer')$q$)
     <> 'err:P0001:no_profile' then
    raise exception 'FAIL AC-15: a caller with no profile must get no_profile';
  end if;
  reset role;
  raise notice 'ok   AC-15 a caller with no profile gets no_profile';

  -- ------------------------------------------------------- AC-16 list
  perform pg_temp.act_as('chk_b1');
  select count(*) into v_rows from public.chat_conversations_list('buyer');
  if v_rows <> 2 then
    raise exception 'FAIL AC-16: b1 must see only their 2 threads, saw %', v_rows;
  end if;
  select conversation_id into v_first from public.chat_conversations_list('buyer') limit 1;
  if v_first <> '00000000-0000-0000-0000-0000000000e2' then
    raise exception 'FAIL AC-16: the newest thread must come first';
  end if;
  raise notice 'ok   AC-16 a buyer sees only their threads, newest first';

  select other_name into v_text from public.chat_conversations_list('buyer') limit 1;
  if v_text <> 'Chk Store 2' then
    raise exception 'FAIL AC-16: the other side must be the store, got %', v_text;
  end if;
  raise notice 'ok   AC-16 a buyer gets the store name';

  -- paging by the (time, id) keyset: page of 1, then the next
  select conversation_id into v_first
  from public.chat_conversations_list('buyer', 1, '2026-01-02 10:00+00', '00000000-0000-0000-0000-0000000000e2');
  if v_first <> '00000000-0000-0000-0000-0000000000e1' then
    raise exception 'FAIL AC-16: the cursor must return the older thread';
  end if;
  if pg_temp.try($q$select * from public.chat_conversations_list('buyer', 1, '2026-01-02 10:00+00', null)$q$)
     <> 'err:P0001:not_found' then
    raise exception 'FAIL AC-16: half a cursor must be refused';
  end if;
  raise notice 'ok   AC-16 paging by the keyset, half a cursor refused';

  -- ------------------------------------------------------- AC-8 unread
  select unread into strict v_rows from (
    select count(*) filter (where unread)::integer as unread
    from public.chat_conversations_list('buyer')
  ) s;
  if v_rows <> 1 or public.chat_unread_count('buyer') <> 1 then
    raise exception 'FAIL AC-8: only the store written thread is unread for b1';
  end if;
  raise notice 'ok   AC-8 the thread whose last message is the store''s is unread';

  perform public.mark_conversation_read('00000000-0000-0000-0000-0000000000e1');
  if public.chat_unread_count('buyer') <> 0 then
    raise exception 'FAIL AC-8: marking read must clear the unread count';
  end if;
  raise notice 'ok   AC-8 marking a thread read clears it';

  -- b1 is not a store: the store role sees no thread of theirs
  select count(*) into v_rows from public.chat_conversations_list('store');
  if v_rows <> 0 then
    raise exception 'FAIL AC-16: b1 acting as a store must see nothing, saw %', v_rows;
  end if;
  raise notice 'ok   AC-16 a buyer asking as a store sees nothing';
  reset role;

  -- ------------------------------------------------------- AC-15 store role
  perform pg_temp.act_as('chk_s1');
  select count(*) into v_rows from public.chat_conversations_list('store');
  if v_rows <> 2 then
    raise exception 'FAIL AC-15: s1 must see their 2 threads, saw %', v_rows;
  end if;
  if exists (select 1 from public.chat_conversations_list('store') where other_id is not null) then
    raise exception 'FAIL AC-15: a store must never receive a buyer''s account id';
  end if;
  if public.chat_unread_count('store') <> 2 then
    raise exception 'FAIL AC-8: both s1 threads were last written by a buyer';
  end if;
  raise notice 'ok   AC-15 a store sees its threads, no buyer id, unread counted';
  reset role;
end
$chk$;

rollback;
