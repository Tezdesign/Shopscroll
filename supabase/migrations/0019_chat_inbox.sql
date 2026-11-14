-- ============================================================
-- 0019: chat inbox list and unread count (spec 0011, task 3)
-- ============================================================
-- Run against a TEST or BRANCH project first, after 0018. It only adds two
-- functions and reads the tables 0018 created, so it is safe to apply to the
-- live project once supabase/checks/chat_inbox.sql passes.
--
-- What it adds:
--   1. chat_conversations_list: the caller's threads in one role, newest first,
--      with the other side's name and avatar, the preview, the time, an unread
--      flag and the block flags, in pages by (last_message_at, id).
--   2. chat_unread_count: how many of the caller's threads are unread in one
--      role.
--
-- Why functions and not a select: user_profiles is readable only for sellers
-- and one's own row, so a store could not read a buyer's name by a normal
-- select. The functions return only name and avatar, and only for threads the
-- caller is in, so they cannot look up a stranger. A store never receives a
-- buyer's account id: other_id is null for the store role.
--
-- A thread is unread for the caller when the last message was sent by the
-- other side and is later than the caller's read time (spec 0011 AC-8).
--
-- Rollback: drop function public.chat_conversations_list(text, integer,
-- timestamptz, uuid); drop function public.chat_unread_count(text);

create or replace function public.chat_conversations_list(
  p_as text,
  p_limit integer default 20,
  p_before_at timestamptz default null,
  p_before_id uuid default null
)
returns table (
  conversation_id uuid,
  other_id text,
  other_name text,
  other_avatar_url text,
  last_message_preview text,
  last_message_at timestamptz,
  unread boolean,
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
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
begin
  if p_as is null or p_as not in ('buyer', 'store') then
    raise exception 'not_allowed';
  end if;
  -- Both halves of the cursor, or neither.
  if (p_before_at is null) <> (p_before_id is null) then
    raise exception 'not_found';
  end if;

  return query
  select
    c.id,
    case when p_as = 'buyer' then c.store_id else null end,
    u.name,
    u.avatar_url,
    c.last_message_preview,
    c.last_message_at,
    (
      c.last_sender_id <> v_user
      and c.last_message_at > coalesce(
        case when p_as = 'buyer' then c.buyer_read_at else c.store_read_at end,
        '-infinity'::timestamptz
      )
    ),
    c.buyer_blocked,
    c.store_blocked
  from public.conversations as c
  join public.user_profiles as u
    on u.id = case when p_as = 'buyer' then c.store_id else c.buyer_id end
  where ((p_as = 'buyer' and c.buyer_id = v_user) or (p_as = 'store' and c.store_id = v_user))
    and (
      p_before_at is null
      or (c.last_message_at, c.id) < (p_before_at, p_before_id)
    )
  order by c.last_message_at desc, c.id desc
  limit v_limit;
end;
$$;

revoke all on function public.chat_conversations_list(text, integer, timestamptz, uuid)
  from public, anon;
grant execute on function public.chat_conversations_list(text, integer, timestamptz, uuid)
  to authenticated;

create or replace function public.chat_unread_count(p_as text)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user text := public.chat_caller();
  v_count integer;
begin
  if p_as is null or p_as not in ('buyer', 'store') then
    raise exception 'not_allowed';
  end if;

  select count(*)::integer into v_count
  from public.conversations as c
  where ((p_as = 'buyer' and c.buyer_id = v_user) or (p_as = 'store' and c.store_id = v_user))
    and c.last_sender_id <> v_user
    and c.last_message_at > coalesce(
      case when p_as = 'buyer' then c.buyer_read_at else c.store_read_at end,
      '-infinity'::timestamptz
    );
  return v_count;
end;
$$;

revoke all on function public.chat_unread_count(text) from public, anon;
grant execute on function public.chat_unread_count(text) to authenticated;
