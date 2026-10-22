-- Decision record: docs/specs/buyer/0011-chat/index.md (build plan task 1)
--
-- SQL checks for chat, migration 0018: AC-5, AC-13, AC-14, AC-15 (server side
-- of the text slice). Run the whole file in the SQL editor of a TEST or BRANCH
-- database (or with psql) after applying migrations 0014 and 0018. It creates
-- its own fixtures, acts as buyers and stores with a fake JWT, and ends with
-- `rollback`, so it leaves no rows behind.
--
-- Output: one NOTICE per check. A failed check raises an error that starts with
-- FAIL and stops the script.

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

create function pg_temp.expect(p_label text, p_actual text, p_prefix text)
returns void language plpgsql as $$
begin
  if p_actual not like p_prefix || '%' then
    raise exception 'FAIL %: expected %, got %', p_label, p_prefix, p_actual;
  end if;
  raise notice 'ok   %', p_label;
end;
$$;

-- A send as a buyer to a store, or as a store into a thread.
create function pg_temp.buyer_send(p_id uuid, p_peer text, p_body text) returns text
language sql as $$
  select format(
    $q$select public.send_message(%L, 'buyer', p_peer_id => %L, p_body => %L)$q$,
    p_id, p_peer, p_body)
$$;

create function pg_temp.thread_send(p_id uuid, p_as text, p_conv uuid, p_body text) returns text
language sql as $$
  select format(
    $q$select public.send_message(%L, %L, p_conversation_id => %L, p_body => %L)$q$,
    p_id, p_as, p_conv, p_body)
$$;

-- Fixtures, created as the table owner. chk_s1 and chk_s2 are stores, chk_b1
-- and chk_b2 buyers, chk_ex is a former seller (now a buyer).
insert into public.user_profiles (id, name, username, role, currency, follower_count) values
  ('chk_s1', 'Chk Store 1', 'chk_s1', 'seller', 'TND', 1200),
  ('chk_s2', 'Chk Store 2', 'chk_s2', 'seller', 'TND', 5),
  ('chk_b1', 'Chk Buyer 1', 'chk_b1', 'buyer', 'TND', 0),
  ('chk_b2', 'Chk Buyer 2', 'chk_b2', 'buyer', 'TND', 0),
  ('chk_ex', 'Chk Ex Seller', 'chk_ex', 'buyer', 'TND', 0);

-- Two orders: b1 bought from s1; b2 bought from s2.
insert into public.orders (id, user_id, status, total_amount, subtotal, delivery_fee,
  contact_name, ship_city, ship_address)
values
  ('00000000-0000-0000-0000-0000000000c1', 'chk_b1', 'inProgress', 15, 5, 10, 'B1', 'Tunis', '1 Rue A'),
  ('00000000-0000-0000-0000-0000000000c2', 'chk_b2', 'inProgress', 15, 5, 10, 'B2', 'Tunis', '2 Rue B');
insert into public.store_orders (order_id, store_id, created_at) values
  ('00000000-0000-0000-0000-0000000000c1', 'chk_s1', now()),
  ('00000000-0000-0000-0000-0000000000c2', 'chk_s2', now());

do $chk$
declare
  m1 constant uuid := '00000000-0000-0000-0000-0000000000d1';
  m2 constant uuid := '00000000-0000-0000-0000-0000000000d2';
  m3 constant uuid := '00000000-0000-0000-0000-0000000000d3';
  m4 constant uuid := '00000000-0000-0000-0000-0000000000d4';
  m5 constant uuid := '00000000-0000-0000-0000-0000000000d5';
  o1 constant uuid := '00000000-0000-0000-0000-0000000000c1';
  o2 constant uuid := '00000000-0000-0000-0000-0000000000c2';
  v_conv uuid;
  v_at timestamptz;
  v_row record;
  v_text text;
  i integer;
begin
  -- ------------------------------------------------------- AC-15 sessions
  perform pg_temp.act_as('chk_b1', true);
  perform pg_temp.expect('AC-15 an anonymous session gets no_session',
    pg_temp.try(pg_temp.buyer_send(m1, 'chk_s1', 'hi')), 'err:P0001:no_session');
  reset role;

  perform set_config('request.jwt.claims', '{}', true);
  execute 'set local role authenticated';
  perform pg_temp.expect('AC-15 a caller with no token gets no_session',
    pg_temp.try(pg_temp.buyer_send(m1, 'chk_s1', 'hi')), 'err:P0001:no_session');
  reset role;

  perform pg_temp.act_as('chk_nobody');
  perform pg_temp.expect('AC-15 a caller with no profile gets no_profile',
    pg_temp.try(pg_temp.buyer_send(m1, 'chk_s1', 'hi')), 'err:P0001:no_profile');
  reset role;

  -- ------------------------------------------------------- AC-14 buyer starts
  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-14 a buyer cannot start a thread with themselves',
    pg_temp.try(pg_temp.buyer_send(m1, 'chk_b1', 'hi')), 'err:P0001:not_allowed');
  perform pg_temp.expect('AC-14 a buyer cannot start a thread with a non seller',
    pg_temp.try(pg_temp.buyer_send(m1, 'chk_b2', 'hi')), 'err:P0001:not_found');
  perform pg_temp.expect('AC-14 a buyer starts a thread with a seller',
    pg_temp.try(pg_temp.buyer_send(m1, 'chk_s1', 'hello store')), 'ok:1');
  reset role;

  select id into v_conv from public.conversations where buyer_id = 'chk_b1' and store_id = 'chk_s1';
  if v_conv is null then
    raise exception 'FAIL AC-5: the first send must create the thread';
  end if;
  select * into v_row from public.conversations where id = v_conv;
  if v_row.last_sender_id <> 'chk_b1' or v_row.last_message_preview <> 'hello store'
     or v_row.created_by <> 'chk_b1' then
    raise exception 'FAIL AC-5: the thread must copy the sender and the preview';
  end if;
  raise notice 'ok   AC-5 the first message created the thread with preview and sender';

  -- ------------------------------------------------------- AC-5 retries
  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-5 a retry with the same id succeeds',
    pg_temp.try(pg_temp.buyer_send(m1, 'chk_s1', 'hello store')), 'ok:1');
  reset role;
  if (select count(*) from public.messages where id = m1) <> 1
     or (select count(*) from public.conversations where buyer_id = 'chk_b1' and store_id = 'chk_s1') <> 1 then
    raise exception 'FAIL AC-5: a retry must not add a message or a thread';
  end if;
  raise notice 'ok   AC-5 a retry adds nothing';

  perform pg_temp.act_as('chk_b2');
  perform pg_temp.expect('AC-5 the same message id from another sender gives conflict',
    pg_temp.try(pg_temp.buyer_send(m1, 'chk_s1', 'hello store')), 'err:P0001:conflict');
  reset role;
  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-5 the same message id for another thread gives conflict',
    pg_temp.try(pg_temp.buyer_send(m1, 'chk_s2', 'hello store')), 'err:P0001:conflict');
  reset role;

  -- ------------------------------------------------------- AC-13 content rules
  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-13 an empty message gives empty',
    pg_temp.try(pg_temp.buyer_send(m2, 'chk_s1', '   ')), 'err:P0001:empty');
  perform pg_temp.expect('AC-13 over 2000 characters gives too_long',
    pg_temp.try(pg_temp.buyer_send(m2, 'chk_s1', repeat('x', 2001))), 'err:P0001:too_long');
  perform pg_temp.expect('AC-13 exactly 2000 characters is accepted',
    pg_temp.try(pg_temp.buyer_send(m2, 'chk_s1', repeat('x', 2000))), 'ok:1');
  perform pg_temp.expect('AC-13 a photo path gives bad_image until 0020',
    pg_temp.try(format(
      $q$select public.send_message(%L, 'buyer', p_conversation_id => %L, p_image_path => 'chk_b1/a.jpg')$q$,
      m3, v_conv)), 'err:P0001:bad_image');
  reset role;

  -- preview is cut to 120 characters
  select last_message_preview into v_text from public.conversations where id = v_conv;
  if char_length(v_text) <> 120 then
    raise exception 'FAIL AC-13: the preview must be cut to 120 characters, got %', char_length(v_text);
  end if;
  raise notice 'ok   AC-13 the preview is cut to 120 characters';

  -- ------------------------------------------------------- AC-15 reads
  perform pg_temp.act_as('chk_b1');
  if (select count(*) from public.messages) <> 2 or (select count(*) from public.conversations) <> 1 then
    raise exception 'FAIL AC-15: the buyer must read exactly their own thread';
  end if;
  reset role;
  perform pg_temp.act_as('chk_b2');
  if (select count(*) from public.messages) <> 0 or (select count(*) from public.conversations) <> 0 then
    raise exception 'FAIL AC-15: another buyer must read nothing';
  end if;
  reset role;
  perform pg_temp.act_as('chk_s1');
  if (select count(*) from public.messages) <> 2 then
    raise exception 'FAIL AC-15: the store must read the messages of its thread';
  end if;
  reset role;
  raise notice 'ok   AC-15 a person reads only their own threads';

  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-15 a direct insert into messages is refused',
    pg_temp.try(format(
      $q$insert into public.messages (id, conversation_id, sender_id, body) values (%L, %L, 'chk_b1', 'x')$q$,
      m4, v_conv)), 'err:42501');
  perform pg_temp.expect('AC-15 a direct update of conversations is refused',
    pg_temp.try($q$update public.conversations set buyer_blocked = true$q$), 'err:42501');
  perform pg_temp.expect('AC-15 a direct delete of messages is refused',
    pg_temp.try($q$delete from public.messages$q$), 'err:42501');
  reset role;

  -- ------------------------------------------------------- store side, existing thread
  perform pg_temp.act_as('chk_s1');
  perform pg_temp.expect('AC-14 the store replies in the thread by conversation id',
    pg_temp.try(pg_temp.thread_send(m3, 'store', v_conv, 'hi buyer')), 'ok:1');
  reset role;
  select last_sender_id into v_text from public.conversations where id = v_conv;
  if v_text <> 'chk_s1' then
    raise exception 'FAIL AC-14: the preview sender must follow the newest message';
  end if;

  perform pg_temp.act_as('chk_b2');
  perform pg_temp.expect('AC-15 a stranger cannot send into the thread',
    pg_temp.try(pg_temp.thread_send(m4, 'buyer', v_conv, 'x')), 'err:P0001:not_found');
  reset role;
  perform pg_temp.act_as('chk_s2');
  perform pg_temp.expect('AC-15 another store cannot send into the thread',
    pg_temp.try(pg_temp.thread_send(m4, 'store', v_conv, 'x')), 'err:P0001:not_found');
  reset role;
  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-14 the wrong role for the thread is refused',
    pg_temp.try(pg_temp.thread_send(m4, 'store', v_conv, 'x')), 'err:P0001:not_found');
  reset role;

  -- ------------------------------------------------------- AC-14 store starts
  perform pg_temp.act_as('chk_s1');
  perform pg_temp.expect('AC-14 a store starts a thread from an order of its own',
    pg_temp.try(format(
      $q$select public.send_message(%L, 'store', p_order_id => %L, p_body => 'your order shipped')$q$,
      m4, o1)), 'ok:1');
  perform pg_temp.expect('AC-14 a store naming another store''s order gets not_allowed',
    pg_temp.try(format(
      $q$select public.send_message(%L, 'store', p_order_id => %L, p_body => 'x')$q$,
      m5, o2)), 'err:P0001:not_allowed');
  perform pg_temp.expect('AC-14 a store naming no order gets not_found',
    pg_temp.try(format(
      $q$select public.send_message(%L, 'store', p_body => 'x')$q$, m5)), 'err:P0001:not_found');
  reset role;
  -- that order's buyer is chk_b1, so the thread is the existing one
  if (select count(*) from public.conversations where buyer_id = 'chk_b1' and store_id = 'chk_s1') <> 1 then
    raise exception 'FAIL AC-14: starting by order must reuse the existing pair thread';
  end if;
  raise notice 'ok   AC-14 a store starting by order reuses the pair thread';

  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-14 a buyer cannot use the order path',
    pg_temp.try(format(
      $q$select public.send_message(%L, 'buyer', p_order_id => %L, p_body => 'x')$q$, m5, o1)),
    'err:P0001:not_found');
  reset role;

  -- a thread started by a store with a buyer who has no thread yet
  perform pg_temp.act_as('chk_s2');
  perform pg_temp.expect('AC-14 a store starts a first thread with its own buyer',
    pg_temp.try(format(
      $q$select public.send_message(%L, 'store', p_order_id => %L, p_body => 'thanks for ordering')$q$,
      m5, o2)), 'ok:1');
  reset role;
  if not exists (
    select 1 from public.conversations where buyer_id = 'chk_b2' and store_id = 'chk_s2' and created_by = 'chk_s2'
  ) then
    raise exception 'FAIL AC-14: the buyer must come from the order on the server';
  end if;
  raise notice 'ok   AC-14 the buyer is taken from the order, never from the client';

  -- a former seller can reply but cannot start by order
  update public.user_profiles set role = 'seller' where id = 'chk_ex';
  insert into public.orders (id, user_id, status, total_amount, subtotal, delivery_fee)
  values ('00000000-0000-0000-0000-0000000000c3', 'chk_b1', 'inProgress', 15, 5, 10);
  insert into public.store_orders (order_id, store_id, created_at)
  values ('00000000-0000-0000-0000-0000000000c3', 'chk_ex', now());
  insert into public.conversations (id, buyer_id, store_id, created_by, last_sender_id)
  values ('00000000-0000-0000-0000-0000000000e1', 'chk_b2', 'chk_ex', 'chk_b2', 'chk_b2');
  update public.user_profiles set role = 'buyer' where id = 'chk_ex';
  perform pg_temp.act_as('chk_ex');
  perform pg_temp.expect('AC-14 a former seller cannot start a thread',
    pg_temp.try(format(
      $q$select public.send_message(%L, 'store', p_order_id => %L, p_body => 'x')$q$,
      m5, '00000000-0000-0000-0000-0000000000c3')), 'err:P0001:not_allowed');
  perform pg_temp.expect('AC-14 a former seller can still reply in an existing thread',
    pg_temp.try(pg_temp.thread_send(m5, 'store', '00000000-0000-0000-0000-0000000000e1', 'still here')),
    'ok:1');
  reset role;

  -- ------------------------------------------------------- blocked (flag set by the owner here)
  update public.conversations set store_blocked = true where id = v_conv;
  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-12 a blocked thread refuses a new message',
    pg_temp.try(pg_temp.thread_send('00000000-0000-0000-0000-0000000000f1', 'buyer', v_conv, 'x')),
    'err:P0001:blocked');
  perform pg_temp.expect('AC-5 a stored message retried while blocked returns the stored row',
    pg_temp.try(pg_temp.buyer_send(m1, 'chk_s1', 'hello store')), 'ok:1');
  reset role;
  update public.conversations set store_blocked = false where id = v_conv;

  -- ------------------------------------------------------- AC-13 rate limit, 30 per minute
  perform pg_temp.act_as('chk_b2');
  for i in 1..40 loop
    v_text := pg_temp.try(pg_temp.buyer_send(gen_random_uuid(), 'chk_s1', 'spam ' || i));
    if i <= 29 and v_text <> 'ok:1' then
      raise exception 'FAIL AC-13: message % should pass, got %', i, v_text;
    end if;
    if i > 29 and v_text <> 'err:P0001:rate_limited' then
      raise exception 'FAIL AC-13: message % should be rate_limited, got %', i, v_text;
    end if;
  end loop;
  reset role;
  -- chk_b2 already sent 2 messages above (one by the store), so 29 + the earlier b2 sends
  if (select count(*) from public.messages
      where sender_id = 'chk_b2' and created_at > clock_timestamp() - interval '1 minute') > 30 then
    raise exception 'FAIL AC-13: more than 30 messages in a minute were stored';
  end if;
  raise notice 'ok   AC-13 no more than 30 messages per minute per sender';

  -- ------------------------------------------------------- AC-13 threads per day
  delete from public.messages where sender_id = 'chk_b1';
  for i in 1..20 loop
    insert into public.user_profiles (id, name, username, role, currency)
    values ('chk_st' || i, 'Store ' || i, 'chk_st' || i, 'seller', 'TND');
    insert into public.conversations (buyer_id, store_id, created_by, last_sender_id)
    values ('chk_b1', 'chk_st' || i, 'chk_b1', 'chk_b1');
  end loop;
  insert into public.user_profiles (id, name, username, role, currency)
  values ('chk_st21', 'Store 21', 'chk_st21', 'seller', 'TND');
  perform pg_temp.act_as('chk_b1');
  perform pg_temp.expect('AC-13 the 21st new thread in a day gives rate_limited',
    pg_temp.try(pg_temp.buyer_send(gen_random_uuid(), 'chk_st21', 'hi')), 'err:P0001:rate_limited');
  perform pg_temp.expect('AC-13 an existing thread is not a new thread',
    pg_temp.try(pg_temp.buyer_send(gen_random_uuid(), 'chk_s1', 'still ok')), 'ok:1');
  reset role;

  -- ------------------------------------------------------- mark_conversation_read
  perform pg_temp.act_as('chk_b2');
  perform pg_temp.expect('AC-8 a stranger cannot mark a thread read',
    pg_temp.try(format($q$select public.mark_conversation_read(%L)$q$, v_conv)), 'err:P0001:not_found');
  reset role;
  perform pg_temp.act_as('chk_s1');
  perform pg_temp.expect('AC-8 the store marks the thread read',
    pg_temp.try(format($q$select public.mark_conversation_read(%L)$q$, v_conv)), 'ok:1');
  reset role;
  select store_read_at, last_message_at into v_row from public.conversations where id = v_conv;
  if v_row.store_read_at is distinct from v_row.last_message_at then
    raise exception 'FAIL AC-8: the read time must equal last_message_at';
  end if;
  raise notice 'ok   AC-8 the read time is last_message_at, never the clock';

  -- ------------------------------------------------------- chat_thread_info
  perform pg_temp.act_as('chk_b1');
  select * into v_row from public.chat_thread_info('buyer', p_peer_id => 'chk_s1');
  if v_row.conversation_id is distinct from v_conv or v_row.other_id <> 'chk_s1'
     or v_row.other_name <> 'Chk Store 1' or v_row.other_follower_count <> 1200 then
    raise exception 'FAIL AC-3: a buyer must get the store name, id and followers';
  end if;
  select * into v_row from public.chat_thread_info('buyer', p_peer_id => 'chk_s2');
  if v_row.conversation_id is not null or v_row.other_name <> 'Chk Store 2' then
    raise exception 'FAIL AC-3: a pair with no thread must give a null conversation id';
  end if;
  perform pg_temp.expect('AC-15 a buyer cannot look up a non seller',
    pg_temp.try($q$select * from public.chat_thread_info('buyer', p_peer_id => 'chk_b2')$q$),
    'err:P0001:not_found');
  perform pg_temp.expect('AC-15 a buyer cannot name a thread that is not theirs',
    pg_temp.try(format($q$select * from public.chat_thread_info('buyer', p_conversation_id => %L)$q$,
      '00000000-0000-0000-0000-0000000000e1')), 'err:P0001:not_found');
  perform pg_temp.expect('AC-15 naming two things is refused',
    pg_temp.try(format($q$select * from public.chat_thread_info('buyer', p_conversation_id => %L, p_peer_id => 'chk_s1')$q$,
      v_conv)), 'err:P0001:not_found');
  reset role;

  perform pg_temp.act_as('chk_s1');
  select * into v_row from public.chat_thread_info('store', p_conversation_id => v_conv);
  if v_row.other_name <> 'Chk Buyer 1' or v_row.other_id is not null
     or v_row.other_follower_count is not null then
    raise exception 'FAIL AC-15: a store must get the buyer name but never the account id';
  end if;
  select * into v_row from public.chat_thread_info('store', p_order_id => o1);
  if v_row.conversation_id is distinct from v_conv or v_row.other_name <> 'Chk Buyer 1' then
    raise exception 'FAIL AC-14: a store must resolve its buyer from its own order';
  end if;
  perform pg_temp.expect('AC-15 a store cannot look up a buyer through another store''s order',
    pg_temp.try(format($q$select * from public.chat_thread_info('store', p_order_id => %L)$q$, o2)),
    'err:P0001:not_allowed');
  reset role;
  raise notice 'ok   AC-15 chat_thread_info answers only for the caller''s own threads and orders';
end;
$chk$;

rollback;
