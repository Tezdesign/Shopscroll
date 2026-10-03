-- Decision record: docs/specs/_root/0012-one-backend-seller-role.md
--
-- Seller access rules, part two. DO NOT apply until the buyer build that no
-- longer sends `role` (spec 0012 task 3) is the only build in use. An older
-- build sends `role` in its sign in upsert, and after this migration that write
-- fails with a permission error, so the user never gets a profile row.
--
-- After this, a signed in client cannot write role, is_verified, follower_count,
-- following_count or product_count on any profile row. Those change only inside
-- become_seller() (role) or with the service role key. The existing row level
-- policies stay: a client still writes only its own row.
--
-- Test the buyer's real sign in upsert against it on a branch or test database
-- before applying to the live project, then confirm with supabase/checks/.
--
-- Rollback: grant insert, update on public.user_profiles to authenticated
-- (and to anon if it had them), as it was before this migration.

-- Revoke first on purpose: Supabase gives anon and authenticated table level
-- rights on new tables, and a column grant alone would not narrow them.
revoke insert, update on public.user_profiles from anon, authenticated;

-- `id` needs update rights too: a PostgREST upsert sets every column in its
-- payload on conflict, and older buyer builds send `id` in it.
grant insert (
  id, name, username, avatar_url, bio, website_url, location, phone, email
) on public.user_profiles to authenticated;
grant update (
  id, name, username, avatar_url, bio, website_url, location, phone, email
) on public.user_profiles to authenticated;
