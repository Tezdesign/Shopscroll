# Verify: seller application request · spec 0013 · updated 2026-10-03
_Steps derived from spec 0013 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones. Covers build plan tasks 1 to 5, 7 and 8. The seller app gate (task 6, AC-10) adds its own steps when built._

## UI / manual
Run the buyer app with the real Supabase and Clerk values (`flutter run --dart-define-from-file=env.json`) and sign in with a test buyer account.
- [ ] Profile, Generals, "Seller application" row → opens the Seller application screen. The "Become a seller" button opens the same screen → AC-8
- [ ] With no application → shows "No applications yet" and a "Submit an application" button. Pull down → the list reloads → AC-8
- [ ] "Submit an application" → step 1 of 4 opens with no red errors. Touch one field only → the other fields stay quiet. Tap Next with empty fields → each required field shows its message → AC-9
- [ ] Step 1 with a username that has an uppercase letter or is shorter than 3 characters → Next is refused. A valid store name, username and location → step 2. Back → the typed values are still there → AC-9
- [ ] Step 3 with no ID photo → Next is refused with "Add a photo of your ID." Pick a photo from the library or the camera → a preview shows, with Replace and Remove → AC-9
- [ ] Pick a GIF, PDF or HEIC file, and a photo over 5 MB → refused on the phone with a message, before any upload → AC-9
- [ ] Step 4 shows what was entered. "Send application" → the screen shows "Sending..." and closes. The list shows the store name, "Submitted dd/mm/yyyy" and a yellow "Reviewing" chip, and no "Submit a new application" button → AC-8, AC-9, AC-1
- [ ] Double tap "Send application" quickly → one row in `seller_applications`, one set of files in each bucket → AC-9, AC-1
- [ ] Turn the network off before "Send application" → an error and "Try again" show, nothing is submitted. Turn it on, tap "Try again" → one application, no duplicate uploads of photos that already went up → AC-9
- [ ] Submit a username already used by another profile → the wizard goes back to step 1 with "This username is taken." → AC-3, AC-9
- [ ] As the admin, reject the application with a reason (SQL editor, service role) → pull to refresh shows a red "Rejected" chip with "Reason: ...", and "Submit a new application" appears → AC-7, AC-8
- [ ] As the admin, approve a new application → the chip turns green "Approved", the screen says you are a seller and offers no button, and the profile shows the store name and logo (a logo path becomes a public URL) → AC-6, AC-8, AC-12
- [ ] Open `/profile/seller-application` while signed out → the sign in prompt shows → AC-8

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

## Account deletion (AC-11)
- [ ] `deno test supabase/functions/_shared/delete_user_files_test.ts` → 7 tests pass (passed on Node 22 with a shim on 2026-10-03, run it under Deno before deploying) → AC-11
- [ ] As a test user, upload a logo and an ID photo, then delete the account from the Profile tab → the `seller_applications` row is gone, and both buckets hold nothing under that user's id folder (check the sub folder too) → AC-11
- [ ] Do the same through the Clerk dashboard (the `user.deleted` webhook) → the same result → AC-11

## Full run (AC-12)
- [ ] `flutter analyze` and `flutter test` in `apps/buyer`, `apps/seller` and `packages/shared` → clean and all pass (buyer 333, seller 4, shared 126 on 2026-10-03) → AC-12
- [ ] A profile with a full URL in `avatar_url` still shows its avatar, and one with `store-logos/<id>/<name>` shows the logo → AC-12

## Acceptance-criteria coverage
- AC-1 … SQL checks (refusals, happy path, retry, other person's id, after approval) and the two session race · AC-2 … SQL checks (`already_open`, unique index, new application after reject) · AC-3 … SQL checks (field limits, username, missing document, every file path rule) · AC-4 … SQL checks (own rows only, no insert, update or delete, `anon` refused) · AC-5 … SQL checks (bucket settings, folder rules, no update or delete, anonymous refused) plus the manual Storage API checks above · AC-6 … SQL checks (service role only, profile copy, empty optionals become null, `not_reviewing`, `already_seller`, `username_taken`) · AC-7 … SQL checks (service role only, reason required, profile untouched)
- AC-8 … UI steps above, widget tests in `apps/buyer/test/features/seller_application/` · AC-9 … UI steps above, wizard widget tests (validation, Back, photo refusals, one upload per photo, double tap, retry) · AC-11 … deletion steps above, `delete_user_files_test.ts` · AC-12 … full run steps above and the `avatar_url` mapper tests
- AC-10 … not built yet (task 6, waiting on the shared login decision)
