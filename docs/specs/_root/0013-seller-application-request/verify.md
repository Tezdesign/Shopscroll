# Verify: seller application request · spec 0013 · updated 2026-10-03
_Steps derived from spec 0013 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones. Covers build plan tasks 1 and 2 (backend). Buyer screens, wizard, seller gate and account deletion add their own steps when built._

## UI / manual
Nothing to click yet. The screens come in tasks 4 to 6.

## Commands
- [ ] `supabase db push` on a TEST or BRANCH project (never first on live) → `0006_seller_applications.sql` applies with no error → AC-1 to AC-7
- [ ] In that project: `select to_regclass('public.seller_applications')` → returns the table name, and `select proname from pg_proc where proname like '%seller_application%'` → 4 rows (submit, approve, reject, path helper) → AC-1, AC-6, AC-7
- [ ] `select id, public, file_size_limit, allowed_mime_types from storage.buckets where id in ('store-logos','application-documents')` → logos public, documents private, both 5242880 and `{image/jpeg,image/png}` → AC-5
- [ ] Run `supabase/checks/seller_applications.sql` on that project (SQL editor or psql) → last notice is `ALL CHECKS PASSED`, then `ROLLBACK` → AC-1 to AC-7 (passed once on a local Supabase on 2026-10-03, rerun on the real test project)
- [ ] Two sessions submit the same `p_id` at once (session 1 holds its transaction open, session 2 starts, session 1 commits) → both return the same id, one row → AC-1 (passed locally on 2026-10-03)
- [ ] Two different people submit the same username at once → the loser gets `username_taken`, never a raw database error → AC-1, AC-3 (passed locally on 2026-10-03)

## Manual API checks (the Storage API, SQL cannot see these)
- [ ] With a real Clerk session token, upload a PNG to `store-logos/<your clerk id>/test.png` with the Storage API → succeeds. This confirms Storage accepts a Clerk user id as the owner (build plan task 1, do it before any UI) → AC-5
- [ ] Same token, upload a `.gif` or `.pdf` to either bucket → refused (type) → AC-5
- [ ] Same token, upload a JPEG over 5 MB to either bucket → refused (size) → AC-5
- [ ] Same token, upload to `application-documents/<another person's id>/x.jpg` → refused (permission) → AC-5
- [ ] Same token, upload again to the same path (upsert) and try to delete a file → refused, since clients have no update or delete → AC-5
- [ ] An anonymous Supabase session uploads to either bucket → refused → AC-5
- [ ] Read another person's file in `application-documents` with the Storage API and a signed in token → not found or denied → AC-5
- [ ] Call `approve_seller_application` and `reject_seller_application` through the REST API with a signed in client token → refused → AC-6, AC-7
- [ ] Call both with the service role key → work, and the profile changes only on approve → AC-6, AC-7

## Acceptance-criteria coverage
- AC-1 … SQL checks (refusals, happy path, retry, other person's id, after approval) and the two session race · AC-2 … SQL checks (`already_open`, unique index, new application after reject) · AC-3 … SQL checks (field limits, username, missing document, every file path rule) · AC-4 … SQL checks (own rows only, no insert, update or delete, `anon` refused) · AC-5 … SQL checks (bucket settings, folder rules, no update or delete, anonymous refused) plus the manual Storage API checks above · AC-6 … SQL checks (service role only, profile copy, empty optionals become null, `not_reviewing`, `already_seller`, `username_taken`) · AC-7 … SQL checks (service role only, reason required, profile untouched)
- AC-8 to AC-12 … not built yet (tasks 3 to 8)
