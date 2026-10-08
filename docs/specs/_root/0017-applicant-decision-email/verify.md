# Verify: seller application notifications · spec 0017 · updated 2026-10-07
_Steps derived from spec 0017 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._

## Setup first (once)
- [ ] Apply migration `0012` on a test or branch database (`supabase db push --include-all`, or apply `0012` on its own the way `0011` was). Confirm it ran: the four `applicant_notify_*` columns exist, the trigger `seller_applications_notify_applicant` exists, and `select jobname from cron.job` lists `retry_applicant_notifications`.
- [ ] Set the one new Vault entry: `select vault.create_secret('https://<project>.supabase.co/functions/v1/notify-applicant-decision', 'applicant_notify_url');`. The `admin_notify_secret` entry from 0011 is reused.
- [ ] `supabase secrets list` shows `MAILJET_API_KEY`, `MAILJET_API_SECRET`, `MAILJET_SENDER_EMAIL`, `ADMIN_EMAIL`, `ADMIN_NOTIFY_SECRET`, `CLERK_ISSUER` and `CLERK_SECRET_KEY`.
- [ ] Deploy both functions: `supabase functions deploy notify-applicant-decision --no-verify-jwt` and `supabase functions deploy claim-seller-application --no-verify-jwt` (the claim function has never been deployed before).

## UI / manual
- [ ] Approve a visitor application from the review page → the applicant gets one email within about a minute, with both paths (new here: create an account with exactly this address; already have one: use the switch) → AC-1, AC-3
- [ ] Open that email → it has no link, no photo, no phone number; the sender is `MAILJET_SENDER_EMAIL`; replying goes to `ADMIN_EMAIL`; `applicant_notified_at` is set on the row → AC-3, AC-5
- [ ] On another phone, sign up with the application email (code or provider sign in), open the app → the person is a store owner and sees the Buyer or Store owner switch at the top of the Profile tab → AC-9, AC-11
- [ ] Applicant who already has an account with that email: approve their visitor application, open the app → becomes a store owner with nothing typed again → AC-9, AC-11
- [ ] Approve an application sent from a signed in account → the email says the account is now a store owner account and shows the switch path only; it went to the "Your email" address, or the store email when that was empty → AC-2, AC-3
- [ ] Reject an application with a reason such as `Photo is <b>blurry</b>` → the email shows the reason as plain text (the tags are not applied), names the store, and says how to apply again → AC-4
- [ ] Signed in application form, contact and logo step → the "Your email (optional)" field shows under the store email with the line "Private...". Type `nope` and tap Next → it refuses. Leave it empty → the form still sends. An older build that has no such field still submits → AC-8
- [ ] An account application with no personal email and no store email, then approve it → no email is sent and `applicant_notify_error` is `no_recipient`, and the job does not try it again → AC-2, AC-6
- [ ] Apple "Hide My Email" or a different address than the one typed → no match by email; the same phone attach from 0014 still works → AC-10
- [ ] Open the admin email and the review page for a signed in application that has a personal email → both show that address under "Applicant email" → AC-12

## Commands
- [ ] Run `supabase/checks/applicant_notification.sql` on the test database → ends with `ALL CHECKS PASSED` and rolls back → AC-1, AC-2, AC-6 to AC-10, AC-13
- [ ] Right after applying `0012`: `select count(*) from public.seller_applications where status in ('approved','rejected') and applicant_notified_at is null;` → `0` (old decisions send nothing) → AC-7
- [ ] Break Mailjet on purpose (wrong `MAILJET_API_SECRET`), approve an application → the decision stands, the row stays unsent with `mailjet_http_401`, `applicant_notify_attempts` rises by 1 every 5 minutes and stops at 10; then fix the secret and set attempts to 0 → one email arrives → AC-1, AC-6
- [ ] `curl -X POST <function url> -H 'content-type: application/json' -d '{"application_id":"<uuid>"}'` with no secret header → `401`; with a bad body → `400` → AC-6
- [ ] Call the claim function with Clerk unreachable (wrong `CLERK_SECRET_KEY`) while an approved visitor application waits → `500`, the app keeps working and nothing changes; next launch with the key fixed attaches and claims → AC-10
- [ ] Two approved visitor applications for one address → the oldest attaches and claims, the other stays unclaimed → AC-9
- [ ] As `anon` and `authenticated`, call `attach_applications_by_email`, `has_unattached_approved_applications`, `claim_applicant_notification` → permission denied → AC-10
- [ ] Look at `supabase functions logs notify-applicant-decision` and the `applicant_notify_error` column → ids and short codes only, no name, email, phone, store text or reason → AC-13
- [ ] `deno test supabase/functions/_shared/` → all pass (`applicant_email_test.ts`, `clerk_emails_test.ts`, `claim_seller_application_test.ts` among them) → AC-1 to AC-6, AC-9, AC-10
- [ ] `flutter analyze` from the repo root, then `flutter test` in `apps/buyer` and `packages/shared` → no new issues, no new failures. At build time `product_flow_screen_test.dart` ("colors and sizes build a table...") already fails on a clean checkout and is not part of this feature → AC-14

## Acceptance-criteria coverage
- AC-1 … covered by steps 1, 2, the Mailjet failure step, and the SQL checks · AC-2 … the account application and no address steps · AC-3 … the approval email steps · AC-4 … the rejection step · AC-5 … the sender and reply step · AC-6 … the failure, 401 and `no_recipient` steps · AC-7 … the old decisions count · AC-8 … the form step · AC-9 … the sign up, existing account and two rows steps · AC-10 … the Hide My Email, Clerk down and permission steps · AC-11 … the sign up and existing account steps · AC-12 … the last UI step · AC-13 … the log step · AC-14 … the analyze and test steps
