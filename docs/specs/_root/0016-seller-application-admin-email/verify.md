# Verify: seller application admin email · spec 0016 · updated 2026-10-05
_Steps derived from spec 0016 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones. Everything marked "local" already passed: the SQL checks on shopscroll and on a local Supabase Postgres, the function logic on Node, and the review page in a browser against a fake function. The steps that need your Mailjet account, the deployed functions and the Cloudflare page are still open._

## Setup (once, by you, never put the values in the repo)
- [ ] Mailjet: an API key and secret, and one verified sender address.
- [ ] `supabase secrets set MAILJET_API_KEY=... MAILJET_API_SECRET=... MAILJET_SENDER_EMAIL=... ADMIN_EMAIL=... ADMIN_NOTIFY_SECRET=<a long random string> REVIEW_PAGE_URL=https://<your-pages-address>/`
- [ ] Cloudflare Pages project with no build command and the output directory `web/admin-review`. `REVIEW_PAGE_URL` must be its exact address (a preview address is refused).
- [ ] `supabase functions deploy notify-admin-application --no-verify-jwt` and `supabase functions deploy review-application --no-verify-jwt`
- [ ] In the SQL editor: `select vault.create_secret('https://eentrzeiqlcmzayjieni.supabase.co/functions/v1/notify-admin-application', 'admin_notify_url');` and `select vault.create_secret('<the same value as ADMIN_NOTIFY_SECRET>', 'admin_notify_secret');`
- [ ] Applying more migrations later: `0011` was applied on its own and recorded, `0008` to `0010` are still pending, so use `supabase db push --include-all`.

## UI / manual
- [ ] Send a visitor application from "Apply now" → within about a minute one email arrives at `ADMIN_EMAIL` with the store, contact details and a "Review this application" link, and no photo or photo link   → AC-1, AC-2
- [ ] Send an application from a signed in account (Settings, Seller application) → one email, applicant details come from the profile   → AC-1, AC-2
- [ ] In the email's source, no `visitor-documents`, `application-documents` or image address appears, and the link has the token after `#`, not in the path   → AC-2, AC-3
- [ ] Mailjet's activity page shows no click or open tracking for the message   → AC-2
- [ ] Type `<b>x</b>` into the store name and about text → the email shows the text, not bold or a link   → AC-2
- [ ] Open the link → the review page shows the details and the photos, the address bar no longer has the token, and the application is still `reviewing`   → AC-3, AC-4
- [ ] Wait 6 minutes and use a photo link from the first load → it is refused, a reload gives new ones   → AC-4
- [ ] Tap Approve then "Yes, approve" → the page says approved, the row is `approved` with `reviewed_by = 'email review'` (account application: the profile is now a seller)   → AC-5
- [ ] On another application tap Reject with the reason empty → blocked. With a reason → rejected, and the applicant sees the reason in Seller application   → AC-6
- [ ] Open a link that was already used, an edited link, and a link older than 7 days → all say "This link is no longer valid." with no details   → AC-7
- [ ] Decide an application in the SQL editor, then open its email link → "already decided"   → AC-8
- [ ] Approve an account application whose profile is already a seller → the page says so and Reject still works   → AC-8
- [ ] Set a wrong `MAILJET_API_KEY`, send an application → it is saved, no email, `admin_notify_error` is `mailjet_http_401` and `admin_notify_attempts` rises every 5 minutes; fix the key → the email arrives and `admin_notified_at` is set   → AC-9
- [ ] After 10 attempts with a broken key it stops, and `update public.seller_applications set admin_notify_attempts = 0 where id = '<id>'` restarts it   → AC-9
- [ ] Open the review page from a different website origin (not `REVIEW_PAGE_URL`) → the browser blocks the answer   → AC-11

## Commands
- [x] `node --experimental-strip-types --import <deno shim> --test supabase/functions/_shared/*_test.ts` (or `deno test supabase/functions/_shared/`) → 69 tests pass (local)   → AC-1 to AC-10
- [x] Run `supabase/checks/admin_notification.sql` on a test database → `ALL CHECKS PASSED` (done on shopscroll and on a local Supabase Postgres)   → AC-1, AC-3, AC-5 to AC-13
- [x] `supabase/checks/seller_applications.sql` and `supabase/checks/visitor_applications.sql` still pass   → AC-14
- [x] `flutter analyze` → no issues   → AC-14
- [ ] `curl -X POST <notify function url> -d '{}'` with no `x-webhook-secret` header → 401   → AC-11
- [ ] `select * from public.application_review_tokens` as the anon key through the REST API → permission denied   → AC-11
- [ ] `select count(*) from public.seller_applications where admin_notified_at is null` right after the migration → 0, and no email for old applications   → AC-12
- [ ] Delete a test application → its rows in `application_review_tokens` are gone   → AC-13
- [ ] The Edge Function logs for a sent and a failed email hold only the application id and a short code   → AC-13

## Acceptance-criteria coverage
- AC-1 · AC-2 · AC-3 · AC-4 · AC-5 · AC-6 · AC-7 · AC-8 · AC-9 covered by the manual steps and the checks above · AC-10 covered by `admin_email_test.ts` and the SQL lease check · AC-11 · AC-12 · AC-13 · AC-14 covered by the command steps
