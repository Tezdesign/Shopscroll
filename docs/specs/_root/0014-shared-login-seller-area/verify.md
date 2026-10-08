# Verify: shared login and store area · spec 0014 · updated 2026-10-08
_Steps derived from spec 0014 acceptance criteria, for the attach by verified contact update (build plan tasks 10 to 16). `/check verify` runs these; `/test` locks the durable ones._

Set up once: apply migration `0013_attach_by_verified_contact.sql`, then set `CLERK_SECRET_KEY` and `CLERK_ISSUER` and deploy `claim-seller-application` with `--no-verify-jwt`. Use two phones (or one phone and one simulator): phone 1 sends the application, phone 2 is another device.

## UI / manual
- [ ] On phone 1, tap Apply now, fill the form with email E and phone P (typed with a leading national `0`, for example France `06 12 34 56 78`), send → confirmation says the team will contact you at E and P; the row in `seller_applications` has `applicant_phone = '+33612345678'` (no extra `0`)        → AC-7
- [ ] On phone 1, sign up with an unrelated email and phone, then open Settings, Seller application → the list is empty and no notice mentions an application        → AC-12, AC-17
- [ ] On phone 1, check `bound_account_id` of the row in the database after that sign up → still null (being on the sending phone attaches nothing)        → AC-12
- [ ] On phone 2, sign up with email E and verify the code → Seller application shows the application with the chip Reviewing, and Settings no longer offers a second application        → AC-12, AC-17
- [ ] Back on phone 1 with the unrelated account, open Seller application again → still empty        → AC-10, AC-17
- [ ] Create a second account that verifies only phone P (not E) with another application attached by email → each account sees only its own application        → AC-17
- [ ] Send one application, have the admin reject it, then send another from the same email and keep it pending, sign up with E → both show, the rejected one with its reason        → AC-12, AC-17
- [ ] Admin approves the attached application, then open the app on phone 2 (launch or resume) → the profile becomes a seller with the store details, Settings shows the seller note        → AC-13
- [ ] Log in on phone 2 choosing Store owner → the store area opens in one pass with the toggle        → AC-1, AC-2
- [ ] Log in as a buyer choosing Store owner with a pending, then a rejected, then no application → each gives its notice and the action opens Seller application        → AC-1
- [ ] Set a wrong `CLERK_SECRET_KEY`, sign in with an account that has an already attached approved application → sign in works and the account still becomes a seller; with nothing attached the function answers 500 and sign in still works        → AC-2, AC-13
- [ ] Sign up with an account that has neither E nor P verified → nothing is attached, the admin can attach it by hand with a service role `update` of `bound_account_id`        → AC-12
- [ ] Delete an account that owns a claimed application → its rows and its files in `visitor-documents` are gone before the profile        → AC-14
- [ ] Delete an account that only has an attached application (never claimed) → the row and its photos are still there, with `bound_account_id` null        → AC-14

## Commands
- [ ] `psql "$TEST_DATABASE_URL" -f supabase/checks/detach_unclaimed_attached.sql` on a database that has 0001 to 0012 and not 0013 → `ALL CHECKS PASSED`, one notice names the row that stays attached        → AC-16
- [ ] `psql "$TEST_DATABASE_URL" -f supabase/migrations/0013_attach_by_verified_contact.sql` → no error; `\df public.attach_applications_by_contact` and `\df public.has_unattached_visitor_applications` exist, the two 0012 functions are gone        → AC-12, AC-16
- [ ] `psql "$TEST_DATABASE_URL" -f supabase/checks/visitor_applications.sql` → `ALL CHECKS PASSED`        → AC-8 to AC-13, AC-17
- [ ] `psql "$TEST_DATABASE_URL" -f supabase/checks/applicant_notification.sql` → `ALL CHECKS PASSED`        → AC-12
- [ ] `psql "$TEST_DATABASE_URL" -f supabase/checks/seller_applications.sql` → `ALL CHECKS PASSED` (the 0013 account application rules still hold)        → AC-15
- [ ] `deno test supabase/functions/_shared/` → all pass (`claim_seller_application_test.ts`, `clerk_contacts_test.ts`, `delete_user_files_test.ts`)        → AC-12, AC-13, AC-14
- [ ] `flutter analyze` from the repo root → `No issues found`        → AC-15
- [ ] `cd apps/buyer && flutter test` and `cd packages/shared && flutter test` → all pass (the unrelated overflow in the seller products flow is tracked on its own)        → AC-7, AC-15
- [ ] `git grep -n "attach_applications_by_email\|has_unattached_approved\|clerk_emails\|verifiedEmails" -- supabase/functions apps` → no match        → AC-12
- [ ] Copy a file between `visitor-documents` and `store-logos` with the service role Storage client → succeeds (still unconfirmed against the real project)        → AC-13
- [ ] List claimed visitor rows and compare each typed email and phone with the account's Clerk contacts (the one time audit in Follow up) → no claim went to the wrong person        → AC-17

## Acceptance-criteria coverage
- AC-1 notice for each state · AC-2 claim before routing · AC-7 phone without the extra `0` · AC-10 sender stops reading an attached row · AC-12 proof by verified email or phone, nothing from the sending phone · AC-13 attach then claim, failure never blocks · AC-14 owned rows deleted, attached rows detached · AC-15 analyze and suites · AC-16 detach step of 0013 · AC-17 each person reads only their own rows
- Covered by the earlier tasks and still to run from the first plan: AC-3 to AC-6, AC-8, AC-9, AC-11 (the visitor SQL checks above cover the database half)
