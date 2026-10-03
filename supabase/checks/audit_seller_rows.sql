-- Decision record: docs/specs/_root/0012-one-backend-seller-role.md (AC-8, build plan task 1)
--
-- Read only. Lists every profile that is already role = 'seller' and is not one
-- of the seeded demo sellers (ids start with 11111111-). Review each row before
-- migration 0004 gives sellers write power: a row that became a seller only
-- because a client could set its own `role` (or because of the old column
-- default 'seller') should be set back to 'buyer', or approved on purpose.
-- Emails and phones are shown as flags, not values.
select
  id,
  name,
  username,
  is_verified,
  (email is not null) as has_email,
  (phone is not null) as has_phone,
  (select count(*) from public.products p where p.store_id = u.id) as products,
  (select count(*) from public.reels r where r.store_id = u.id) as reels,
  created_at
from public.user_profiles u
where role = 'seller'
  and id not like '11111111-%'
order by created_at;
