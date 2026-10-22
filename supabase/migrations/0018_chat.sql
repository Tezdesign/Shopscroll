-- ============================================================
-- 0018: chat between buyers and stores, tables and first functions (spec 0011, task 1)
-- ============================================================
-- Run against a TEST or BRANCH project first, after 0017. It only adds new
-- tables and functions, nothing else reads them, so it is safe to apply to the
-- live project once supabase/checks/chat.sql passes.
--
-- What it adds:
--   1. conversations: one row per buyer and store pair.
--   2. messages: one row per message. The client supplies the id so a retry is
--      safe.
--   3. Both tables are closed to every client write. A client may only select
--      its own rows (RLS), and Realtime follows that same policy.
--   4. send_message, mark_conversation_read and chat_thread_info.
--
-- Not here yet (later migrations): the inbox list and unread count (0019), the
-- photo bucket and the photo path check (0020), delete and block (0021). Until
-- 0020, send_message refuses any photo path with bad_image.
--
-- Refusals are raised as the whole error message, like place_order: no_session,
-- no_profile, not_found, not_allowed, blocked, too_long, empty, bad_image,
-- rate_limited, conflict.
--
-- One addition to the spec's table sketch: conversations.created_by, so the
-- "20 new threads per day" limit can count the threads one person started
-- (the buyer or the store can be the one who starts it).
--
-- Rollback: drop table public.messages, public.conversations cascade; and drop
-- the four functions below. Nothing else depends on them.

-- ------------------------------------------------------------
-- 1. conversations
-- ------------------------------------------------------------
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  buyer_id text not null references public.user_profiles (id) on delete cascade,
  store_id text not null references public.user_profiles (id) on delete cascade,
  -- Who sent the first message. Only used for the daily new thread limit.
  created_by text not null,
  created_at timestamptz not null default now(),
  -- The three last_* columns are copied by send_message only (a delete never
  -- moves the time or the sender), so unread needs no query on messages.
  last_message_at timestamptz not null default now(),
  last_sender_id text not null,
  last_message_preview text not null default '',
  buyer_read_at timestamptz,
  store_read_at timestamptz,
  buyer_blocked boolean not null default false,
  store_blocked boolean not null default false,
  constraint conversations_pair_key unique (buyer_id, store_id),
  constraint conversations_not_self check (buyer_id <> store_id),
  constraint conversations_preview_len check (char_length(last_message_preview) <= 120)
);

create index if not exists conversations_buyer_idx
  on public.conversations (buyer_id, last_message_at desc, id desc);
create index if not exists conversations_store_idx
  on public.conversations (store_id, last_message_at desc, id desc);
create index if not exists conversations_created_by_idx
  on public.conversations (created_by, created_at desc);

-- ------------------------------------------------------------
-- 2. messages
-- ------------------------------------------------------------
create table if not exists public.messages (
  id uuid primary key,
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  -- The thread's buyer_id or store_id, taken from the token by send_message.
  sender_id text not null,
  body text,
  -- A path inside the chat-images bucket, always starting with the sender's id.
  image_path text,
  -- A plain reference with no foreign key, so a removed product reads
  -- "Product unavailable".
  product_id uuid,
  created_at timestamptz not null default clock_timestamp(),
  deleted_at timestamptz,
  constraint messages_body_len check (body is null or char_length(body) <= 2000),
  constraint messages_content check (
    (deleted_at is null and (body is not null or image_path is not null or product_id is not null))
    or (deleted_at is not null and body is null and image_path is null and product_id is null)
  )
);

create index if not exists messages_thread_idx
  on public.messages (conversation_id, created_at desc, id desc);
create index if not exists messages_sender_idx
  on public.messages (sender_id, created_at desc);
create index if not exists messages_image_idx
  on public.messages (image_path) where image_path is not null;

-- ------------------------------------------------------------
-- 3. Row level security: select only, for the two people in the thread
-- ------------------------------------------------------------
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

-- Supabase grants table level rights to the client roles on new tables, so take
-- them all away and give back select only (supabase/AGENTS.md).
revoke all on public.conversations from anon, authenticated;
revoke all on public.messages from anon, authenticated;
grant select on public.conversations to authenticated;
grant select on public.messages to authenticated;

drop policy if exists conversations_select on public.conversations;
create policy conversations_select on public.conversations
  for select to authenticated
  using (
    buyer_id = (select auth.jwt() ->> 'sub')
    or store_id = (select auth.jwt() ->> 'sub')
  );

drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
  for select to authenticated
  using (
    exists (
      select 1
      from public.conversations as c
      where c.id = messages.conversation_id
        and (
          c.buyer_id = (select auth.jwt() ->> 'sub')
          or c.store_id = (select auth.jwt() ->> 'sub')
        )
    )
  );

-- Row changes for the two tables reach the app through Realtime. Realtime
-- applies the select policies above. Safe to run again.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'conversations'
  ) then
    alter publication supabase_realtime add table public.conversations;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;

-- ------------------------------------------------------------
-- 4. Functions
-- ------------------------------------------------------------
-- Same convention as supabase/AGENTS.md: security definer, empty search_path,
-- execute revoked from public and anon and granted to authenticated only.

-- The caller's account id, or a refusal. Used by every function below. Nobody
-- calls it from outside (no grant), the functions run as their owner.
create or replace function public.chat_caller()
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
  if not exists (select 1 from public.user_profiles where id = v_user) then
    raise exception 'no_profile';
  end if;
  return v_user;
end;
$$;

revoke all on function public.chat_caller() from public, anon, authenticated;

-- send_message: the only way a message is written. Order of work (spec 0011):
--   1. caller, 2. a repeat of a stored message id returns it and stops,
--   3. sender lock and the rate limits, 4. find or create the thread,
--   5. lock the thread and refuse when blocked, 6. validate the content,
--   7. insert the message and copy the preview, time and sender to the thread.
-- p_as says which role the caller acts in. As buyer, name the thread
-- (p_conversation_id) or the store to start with (p_peer_id). As store, name
-- the thread, or an order of its own to start with (p_order_id), never a
-- buyer's account id.
create or replace function public.send_message(
  p_message_id uuid,
  p_as text,
  p_conversation_id uuid default null,
  p_peer_id text default null,
  p_order_id uuid default null,
  p_body text default null,
  p_image_path text default null,
  p_product_id uuid default null
)
returns public.messages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user text := public.chat_caller();
  v_old public.messages;
  v_conv public.conversations;
  v_body text;
  v_buyer text;
  v_store text;
  v_msg public.messages;
begin
  if p_message_id is null or p_as is null or p_as not in ('buyer', 'store') then
    raise exception 'not_allowed';
  end if;

  -- 2. A repeat. It comes before every other check, so a message that was
  -- stored but whose reply was lost never comes back as blocked or rate_limited.
  select * into v_old from public.messages where id = p_message_id;
  if found then
    select * into v_conv from public.conversations where id = v_old.conversation_id;
    if v_old.sender_id <> v_user
       or (p_as = 'buyer' and v_conv.buyer_id <> v_user)
       or (p_as = 'store' and v_conv.store_id <> v_user)
       or (p_conversation_id is not null and p_conversation_id <> v_old.conversation_id)
       or (p_peer_id is not null and p_peer_id <> v_conv.store_id)
       or (p_order_id is not null and v_conv.buyer_id is distinct from (
             select o.user_id from public.orders as o where o.id = p_order_id)) then
      raise exception 'conflict';
    end if;
    return v_old;
  end if;

  -- 3. One lock per sender, so parallel sends cannot go over the limits.
  perform pg_advisory_xact_lock(hashtextextended('chat_send:' || v_user, 0));
  if (
    select count(*) from public.messages
    where sender_id = v_user and created_at > clock_timestamp() - interval '1 minute'
  ) >= 30 then
    raise exception 'rate_limited';
  end if;

  -- 4. The thread.
  if p_conversation_id is not null then
    select * into v_conv from public.conversations
    where id = p_conversation_id
      and ((p_as = 'buyer' and buyer_id = v_user) or (p_as = 'store' and store_id = v_user));
    if not found then
      raise exception 'not_found';
    end if;
  else
    if p_as = 'buyer' then
      if p_peer_id is null then
        raise exception 'not_found';
      end if;
      if p_peer_id = v_user then
        raise exception 'not_allowed';
      end if;
      if not exists (
        select 1 from public.user_profiles where id = p_peer_id and role = 'seller'
      ) then
        raise exception 'not_found';
      end if;
      v_buyer := v_user;
      v_store := p_peer_id;
    else
      if p_order_id is null then
        raise exception 'not_found';
      end if;
      if not (select public.is_seller()) then
        raise exception 'not_allowed';
      end if;
      select o.user_id into v_buyer
      from public.orders as o
      join public.store_orders as so on so.order_id = o.id and so.store_id = v_user
      where o.id = p_order_id;
      if v_buyer is null or v_buyer = v_user then
        raise exception 'not_allowed';
      end if;
      v_store := v_user;
    end if;

    select * into v_conv from public.conversations
    where buyer_id = v_buyer and store_id = v_store;
    if not found then
      if (
        select count(*) from public.conversations
        where created_by = v_user and created_at > clock_timestamp() - interval '1 day'
      ) >= 20 then
        raise exception 'rate_limited';
      end if;
      -- A race with the other side creating the same pair ends with one row.
      insert into public.conversations (buyer_id, store_id, created_by, last_sender_id)
      values (v_buyer, v_store, v_user, v_user)
      on conflict (buyer_id, store_id) do nothing;
      select * into v_conv from public.conversations
      where buyer_id = v_buyer and store_id = v_store;
    end if;
  end if;

  -- 5. Lock the thread, then look at the block flags under the lock.
  select * into v_conv from public.conversations where id = v_conv.id for update;
  if v_conv.buyer_blocked or v_conv.store_blocked then
    raise exception 'blocked';
  end if;

  -- 6. Content.
  v_body := nullif(btrim(coalesce(p_body, '')), '');
  if v_body is not null and char_length(v_body) > 2000 then
    raise exception 'too_long';
  end if;
  -- Photos arrive with migration 0020, which replaces this function.
  if p_image_path is not null then
    raise exception 'bad_image';
  end if;
  if p_product_id is not null
     and not exists (select 1 from public.products where id = p_product_id) then
    raise exception 'not_found';
  end if;
  if v_body is null and p_product_id is null then
    raise exception 'empty';
  end if;

  -- 7. Store the message and copy the preview, time and sender to the thread.
  insert into public.messages (id, conversation_id, sender_id, body, image_path, product_id, created_at)
  values (p_message_id, v_conv.id, v_user, v_body, p_image_path, p_product_id, clock_timestamp())
  returning * into v_msg;

  update public.conversations
  set last_message_at = v_msg.created_at,
      last_sender_id = v_user,
      last_message_preview = left(
        coalesce(v_body, case when p_image_path is not null then 'Photo' else 'Product' end),
        120)
  where id = v_conv.id;

  return v_msg;
end;
$$;

revoke all on function public.send_message(
  uuid, text, uuid, text, uuid, text, text, uuid
) from public, anon;
grant execute on function public.send_message(
  uuid, text, uuid, text, uuid, text, text, uuid
) to authenticated;

-- mark_conversation_read: sets the caller's read time to the thread's
-- last_message_at, never to the clock, so a message that landed a moment
-- earlier is never marked read unseen. It never moves a read time back.
create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user text := public.chat_caller();
  v_conv public.conversations;
begin
  select * into v_conv from public.conversations
  where id = p_conversation_id and (buyer_id = v_user or store_id = v_user)
  for update;
  if not found then
    raise exception 'not_found';
  end if;

  if v_conv.buyer_id = v_user then
    update public.conversations
    set buyer_read_at = greatest(coalesce(buyer_read_at, '-infinity'), last_message_at)
    where id = v_conv.id;
  else
    update public.conversations
    set store_read_at = greatest(coalesce(store_read_at, '-infinity'), last_message_at)
    where id = v_conv.id;
  end if;
end;
$$;

revoke all on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

-- chat_thread_info: what the thread screen needs about the other side. It
-- exists because user_profiles is readable only for sellers and one's own row,
-- so a store cannot select a buyer's name. It answers only for a thread the
-- caller is in, a seller to start with (buyer role) or an order of the
-- caller's own (store role), so it cannot look up a stranger. Name exactly one
-- of the three. other_id is the store's id for a buyer and null for a store:
-- a store never receives a buyer's account id. conversation_id is null when
-- the thread does not exist yet.
create or replace function public.chat_thread_info(
  p_as text,
  p_conversation_id uuid default null,
  p_peer_id text default null,
  p_order_id uuid default null
)
returns table (
  conversation_id uuid,
  other_id text,
  other_name text,
  other_avatar_url text,
  other_follower_count integer,
  buyer_read_at timestamptz,
  store_read_at timestamptz,
  buyer_blocked boolean,
  store_blocked boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_user text := public.chat_caller();
  v_conv public.conversations;
  v_buyer text;
  v_store text;
  v_other text;
begin
  if p_as is null or p_as not in ('buyer', 'store') then
    raise exception 'not_allowed';
  end if;
  if (p_conversation_id is not null)::int + (p_peer_id is not null)::int
     + (p_order_id is not null)::int <> 1 then
    raise exception 'not_found';
  end if;

  if p_conversation_id is not null then
    select * into v_conv from public.conversations as c
    where c.id = p_conversation_id
      and ((p_as = 'buyer' and c.buyer_id = v_user) or (p_as = 'store' and c.store_id = v_user));
    if not found then
      raise exception 'not_found';
    end if;
  elsif p_peer_id is not null then
    if p_as <> 'buyer' then
      raise exception 'not_allowed';
    end if;
    if p_peer_id = v_user then
      raise exception 'not_allowed';
    end if;
    if not exists (
      select 1 from public.user_profiles as u where u.id = p_peer_id and u.role = 'seller'
    ) then
      raise exception 'not_found';
    end if;
    select * into v_conv from public.conversations as c
    where c.buyer_id = v_user and c.store_id = p_peer_id;
    if not found then
      v_other := p_peer_id;
    end if;
  else
    if p_as <> 'store' or not (select public.is_seller()) then
      raise exception 'not_allowed';
    end if;
    select o.user_id into v_buyer
    from public.orders as o
    join public.store_orders as so on so.order_id = o.id and so.store_id = v_user
    where o.id = p_order_id;
    if v_buyer is null or v_buyer = v_user then
      raise exception 'not_allowed';
    end if;
    select * into v_conv from public.conversations as c
    where c.buyer_id = v_buyer and c.store_id = v_user;
    if not found then
      v_other := v_buyer;
    end if;
  end if;

  if v_conv.id is not null then
    v_other := case when p_as = 'buyer' then v_conv.store_id else v_conv.buyer_id end;
  end if;

  return query
  select
    v_conv.id,
    case when p_as = 'buyer' then v_other else null end,
    u.name,
    u.avatar_url,
    case when p_as = 'buyer' then u.follower_count else null end,
    v_conv.buyer_read_at,
    v_conv.store_read_at,
    coalesce(v_conv.buyer_blocked, false),
    coalesce(v_conv.store_blocked, false)
  from public.user_profiles as u
  where u.id = v_other;
end;
$$;

revoke all on function public.chat_thread_info(text, uuid, text, uuid) from public, anon;
grant execute on function public.chat_thread_info(text, uuid, text, uuid) to authenticated;
