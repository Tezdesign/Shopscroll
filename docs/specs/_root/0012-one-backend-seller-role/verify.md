# Verify: Seller access rules · spec 0012 · updated 2026-10-03
_Steps derived from spec 0012 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._

Order matters: apply 0004, then use the new buyer build, then apply 0005. Run the SQL checks on a test or branch database first.

## UI / manual
- [ ] Sign in to the buyer app with a brand new account, then read the new `user_profiles` row (SQL editor) → `role = 'buyer'`, `email` and `phone` filled in   → AC-2, AC-3
- [ ] In the seller app (with `env.json` filled), sign in with a different new account → the placeholder screen shows, and the profile row now has `role = 'seller'` with `email` and `phone` null   → AC-4, AC-7
- [ ] Sign in to the seller app with the same account that already exists as a buyer → same row becomes a seller, no second row, no second sign in   → AC-4, AC-7
- [ ] Edit that seller's `name` and `bio` in the database, sign out and in again in the buyer app → name and bio unchanged, `role` still `seller`   → AC-3
- [ ] Open the seller app with no `env.json` → placeholder only, and no `signInAnonymously` call (no `auth.users` anonymous row created)   → AC-7
- [ ] Clerk dashboard lists `com.marketplaceapp.shopscrollSeller` (iOS) and `com.marketplaceapp.shopscroll_seller` (Android) on the same instance   → AC-7

## Commands
- [ ] `ls supabase/migrations supabase/functions supabase/schema.sql && test ! -e apps/buyer/supabase && echo ok` → lists 0001 to 0005 and prints `ok`   → AC-1
- [ ] `supabase db query --linked -f supabase/checks/audit_seller_rows.sql` → `"rows": []` or only rows you approved, run BEFORE applying 0004 (it returned no rows on 2026-10-03)   → AC-8
- [ ] `supabase db push` (0004 only, test or branch database first) → `become_seller`, `is_seller` and the `sellers ... own ...` policies exist; `select column_default from information_schema.columns where table_name='user_profiles' and column_name='role'` shows `'buyer'`   → AC-4, AC-5
- [ ] Run `supabase/checks/seller_access.sql` after 0004 → every line `ok`, AC-2 lines print `SKIP`, ends with `ALL CHECKS PASSED`   → AC-4, AC-5
- [ ] Apply 0005 (after the new buyer build is the only one in use), rerun `supabase/checks/seller_access.sql` → AC-2 lines now run and pass   → AC-2
- [ ] `cd apps/buyer && flutter analyze && flutter test` → no issues, all pass   → AC-3, AC-6
- [ ] `cd packages/shared && flutter analyze && flutter test` → no issues, all pass   → AC-6
- [ ] `cd apps/seller && flutter analyze && flutter test` → no issues, all pass   → AC-7

## Acceptance-criteria coverage
- AC-1 … folder command, audit link · AC-2 … SQL checks after 0005, buyer sign in step · AC-3 … buyer test and manual re-sign in · AC-4 … SQL checks, seller sign in step · AC-5 … SQL checks · AC-6 … three suites, buyer smoke · AC-7 … seller test, manual steps, Clerk dashboard · AC-8 … audit query
