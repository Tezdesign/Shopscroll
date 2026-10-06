# 0016. Email each new seller application to the admin through Mailjet, with a review page that approves or rejects

**Date**: 2026-10-05
**Status**: In Progress

> Builds on [0013](../0013-seller-application-request/index.md) (the application and its approve and reject functions) and [0014](../0014-shared-login-seller-area/index.md) (visitor applications). It changes none of their rules. It is not the admin dashboard (scope feature 20) and not the applicant notice (scope feature 21).

## Summary

When anyone sends a seller application, from an account or from "Apply now" with no account, the admin gets an email through Mailjet within about a minute. The email lists the store and contact details and holds one private link. The link opens a small review page that shows the application, the ID photos through links that expire in minutes, and two buttons: Approve and Reject (Reject asks for a reason). Nothing is decided just by opening the link. If Mailjet fails, the application is still saved and the email is retried every few minutes.

## Requirements

**User stories**:
- As the admin, I want an email for every new seller application so that I do not have to watch the database.
- As the admin, I want to open the application from the email and see the details and the ID photos without logging into the dashboard, so that I can judge it quickly.
- As the admin, I want to approve or reject from that page, with a reason when I reject, so that I do not need the SQL editor.
- As an applicant, I want my ID photos kept out of anyone's inbox so that my private documents stay private.
- As the developer, I want a failed email to retry on its own and never block or undo an application.

**Acceptance criteria** (the contract, each one independently checkable):
- **AC-1**: Every new row in `seller_applications` (origin `account` or `visitor`) causes at most one email per successful send to `ADMIN_EMAIL` through the Mailjet API. A crash after Mailjet accepted but before the row was updated may resend once. The row's `admin_notified_at` is set when Mailjet accepts it. A missing or broken email setup never makes the submit fail or roll back.
- **AC-2**: The email shows: origin, store name, username, location, about text, website, public store phone and email, the date, and the applicant's name, email and phone (for an account application from the profile, for a visitor from the application). It holds no ID or business photo, no photo link, and no data other than the one review link. Mailjet click and open tracking are turned off for the message, so the link is never rewritten or stored by Mailjet. Every value that a person typed is escaped, so it cannot add markup or links to the email, and the subject has no line breaks.
- **AC-3**: The review link carries a random token of 32 bytes in the URL fragment (after `#`). Only its SHA-256 hash is stored, with `expires_at` (7 days after creation) and `used_at`. Each send attempt creates a new token, and older unused tokens are not deleted, they expire on their own, so a resend never breaks the link in an email that did arrive.
- **AC-4**: Opening the link shows the review page, which asks `review-application` for the application. The page shows the same details as the email plus the ID photo, the business document and the logo through signed links that last 5 minutes and are made again each time the page opens. Images show inline, and a document that is not an image (a PDF) shows as a short lived link. The page removes the token from the address bar right after reading it. Opening the link never changes an application.
- **AC-5**: Approve calls `approve_seller_application` with the service role, sets `reviewed_by` to `email review`, marks the token used, and the page shows the result. An account application then makes the person a seller (0013 AC-6), and a visitor application is marked approved for the later claim (0014).
- **AC-6**: Reject needs a reason of 1 to 500 characters after trimming (the page and the `review-application` function both check, the database only checks it is not empty), then calls `reject_seller_application` with the reason, marks the token used and shows the result.
- **AC-7**: An unknown, expired or already used token gets the same answer (`invalid_link`, status 404) and no application data. The answer does not say which of the three it was.
- **AC-8**: If the application is no longer `reviewing` the page says it was already decided and the token stays used. If the decision is refused with `username_taken` or `already_seller`, the page shows that reason in plain words and the token stays usable, so the admin can reject instead.
- **AC-9**: When Mailjet or the network fails, or the function is not reachable at all, `admin_notified_at` stays empty. A scheduled job retries unsent applications older than 1 minute every 5 minutes and raises `admin_notify_attempts` itself each time it posts, so the 10 attempt limit holds even when the function never runs. It then stops. `admin_notify_error` holds a short code of the last failure (for example `mailjet_http_401`), never a message with personal data.
- **AC-10**: Calling the notify function again for an application that is already notified sends nothing. Two calls close together send one email: the first takes a 2 minute lease (`admin_notify_claimed_at`) and the second sees it and does nothing.
- **AC-11**: The notify function refuses a call without the shared secret header (401). `application_review_tokens` has row level security on and no grant to `anon` or `authenticated`. The review function reaches the database only with the service role.
- **AC-12**: When migration `0011` runs, existing rows are marked notified, so no old application sends an email, and the current app builds keep working.
- **AC-13**: Logs and `admin_notify_error` hold no name, email, phone, store text or token. Deleting an application (including through account deletion) deletes its tokens.
- **AC-14**: `flutter analyze` is clean, all existing suites pass, and the 0013 and 0014 submit, approve, reject and claim behaviour is unchanged.

## Decision

**Chosen option**: Option 1: A database trigger calls an Edge Function that emails the admin through Mailjet, and a static review page (hosted on Cloudflare Pages) calls a second Edge Function to show and decide the application with a one time token.

A trigger sends the notification, a retry job covers failures, and the admin decides from a token protected review page instead of the SQL editor.

**Implementation skills**: `supabase` (`supabase/agent-skills`, `.agents/skills/supabase/`) · `supabase-postgres-best-practices` (`supabase/agent-skills`, `.agents/skills/supabase-postgres-best-practices/`)

## Rationale

Reasoning and options: see [rationale.md](./rationale.md).

## Feature design

**Data model** (new migration `0011_admin_notification.sql`, the next free number after `0010`):

`seller_applications`, four new columns:

| Column | Type | Rule |
|---|---|---|
| `admin_notified_at` | timestamptz, null | Set when Mailjet accepted the email. Null means not sent |
| `admin_notify_attempts` | integer, not null, default 0 | Counts send tries, including failed ones. The retry job stops at 10 |
| `admin_notify_error` | text, null | Short code of the last failure. No personal data |
| `admin_notify_claimed_at` | timestamptz, null | A 2 minute lease taken by the function before it sends, so two calls do not both send |

`application_review_tokens` (new):

| Column | Type | Rule |
|---|---|---|
| `id` | uuid, primary key, default `gen_random_uuid()` | |
| `application_id` | uuid, not null, foreign key to `seller_applications(id)`, `on delete cascade` | A token never outlives its application |
| `token_hash` | text, not null, unique | SHA-256 (hex) of the random token. The raw token exists only in the email link |
| `expires_at` | timestamptz, not null | Creation time plus 7 days |
| `used_at` | timestamptz, null | Set by the first decision that goes through |
| `created_at` | timestamptz, not null, default `now()` | |

Index on `(application_id)`. Row level security on, `revoke all` from `anon` and `authenticated`, no policy. Existing rows get `admin_notified_at = now()` in the same migration.

Database objects in the same migration: extensions `pg_net` and `pg_cron` (created if missing), function `public.notify_admin_new_application()` (security definer, empty `search_path`, an `after insert` trigger on `seller_applications`), and one cron job `retry_admin_notifications` every 5 minutes. The trigger and the job read `admin_notify_url` and `admin_notify_secret` from Supabase Vault (schema qualified, `vault.decrypted_secrets`) and post to the function with `net.http_post(..., timeout_milliseconds := 30000)`. A post is only queued and sent after the insert commits, so a network failure shows up later in `net._http_response`, not in the trigger. If a Vault value is missing the trigger catches the error and the insert still succeeds. The retry job raises `admin_notify_attempts` when it posts. Any helper function for the job is not callable by clients (`revoke execute ... from public, anon, authenticated`).

A service role only SQL function `public.decide_application_with_token(p_token_hash text, p_action text, p_reason text)` does the claim and the decision in one transaction: it locks the token row, refuses an unknown, expired or used token, calls `approve_seller_application` or `reject_seller_application`, and marks the token used. Any refusal from those functions rolls the whole thing back, so the token stays usable and nothing needs releasing. The same job also deletes tokens expired more than 30 days ago.

**State transitions**:
- Notification: `unsent` (notified null, attempts 0 to 9) → `sent` (notified set) or `exhausted` (attempts 10, still null). Sent never undoes. An admin can reset an exhausted one by setting attempts to 0.
- Token: `active` → `used` (a decision went through) or `expired` (7 days). Both end states are final.

**API surface**:

| Function or call | Kind | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| `notify_admin_new_application` | database trigger | the new row | none (posts `{application_id}`) | table owner | never raises |
| `retry_admin_notifications` | cron job, every 5 minutes | none | posts one request per unsent row (`admin_notified_at is null`, `status = 'reviewing'`, attempts below 10, older than 1 minute) and adds 1 to its attempts | database | none |
| `notify-admin-application` | Edge Function, `POST` | `{ application_id }`, header `x-webhook-secret` | `{ sent: true or false }` (sets `admin_notified_at`, or `admin_notify_error`; never changes attempts) | shared secret, deployed with `--no-verify-jwt` | 401 bad secret, 400 bad body, 500 not configured |
| `decide_application_with_token` | database function, service role only | `p_token_hash`, `p_action`, `p_reason` | none | service role only | `invalid_link`, plus the 0013 refusals |
| `review-application` | Edge Function, `POST` (and `OPTIONS`) | `{ token, action: "view" or "approve" or "reject", reason? }` | view: application details and signed photo links. approve and reject: `{ status }` | the token itself, deployed with `--no-verify-jwt` | 404 `invalid_link`, 409 `already_decided`, 409 `username_taken` or `already_seller`, 422 `reason_required`, 500 `failed` |
| Mailjet send | outbound `POST https://api.mailjet.com/v3.1/send` | one message with `From`, `To`, `Subject`, `TextPart`, `HtmlPart`, `CustomID` (the application id), `TrackClicks: "disabled"`, `TrackOpens: "disabled"` | success when HTTP 200 and `Messages[0].Status` is `success` | Basic auth with the API key and secret | any other result is a failed attempt |
| Review page | static page `web/admin-review/`, `GET` | the fragment `#t=<token>` | the page | none | shows "This link is no longer valid." |

Refusals from `approve_` and `reject_seller_application` come back as the whole error message (the 0013 convention), and the function maps them to the codes above.

**Key invariants**:
- A decision goes through only with a token that exists, is not expired and is not used, and the claim and the decision happen in one transaction (`decide_application_with_token`). A refused decision leaves the token usable, and a crash cannot leave it stuck used.
- At most one email is sent while a lease is held. The function takes `update ... set admin_notify_claimed_at = now() where admin_notified_at is null and (admin_notify_claimed_at is null or admin_notify_claimed_at < now() - interval '2 minutes')`. No row updated means another call holds it, so it does nothing.
- Attempts are counted by the retry job when it posts, never by the function, so a failure before the function runs still counts.
- The email never contains photos or photo links. Photo links are made only by `review-application`, last 5 minutes, and are never stored or logged.
- All user text is escaped in the email and set as text (never HTML) on the review page.
- The raw token is never stored, logged or sent anywhere except in the email link, and Mailjet tracking is off so Mailjet does not keep the link. Only the fragment holds it, so the page host and the access logs never see it, and the page removes it from the address bar after reading it.
- The trigger and the retry job never block a submit.
- Mailjet success is recorded after the send, so a failure between the two can produce one duplicate email once the lease ends. This is accepted.

**Security model**: The token is a bearer secret: whoever has the email can decide the application, so the admin inbox is the admin credential, and `reviewed_by = 'email review'` does not name a person. Tokens are 256 bits, hashed at rest, expire in 7 days, and a used or expired one reveals nothing (same `invalid_link` answer). The database holds no admin credential for the page. The notify function checks the shared secret in constant time. The review page is served with a content security policy that allows only itself and the project's Supabase origin, no framing (`frame-ancestors 'none'`), and `Referrer-Policy: no-referrer`. `review-application` answers the `OPTIONS` preflight before any token check, and puts the CORS headers on every response, errors included (otherwise the page could not show `invalid_link` or `already_decided`), only for the exact origin of `REVIEW_PAGE_URL`. A Cloudflare preview address is a different origin and is refused. **Compliance scope**: the email holds a visitor's name, email and phone, which is personal data, and Mailjet is the processor that delivers it. ID photos are never mailed. Follow the data protection rules of the country you operate in, and record Mailjet as a processor.

**Failure and edge cases**:
- Mailjet down, wrong key or rate limited: attempt counted, short error code saved, retried by the job up to 10 times, then it stops and logs one line. The admin can still list `reviewing` applications in the SQL editor.
- `ADMIN_EMAIL` or a Mailjet secret missing: the function answers 500 `not_configured`, the attempt is counted, nothing breaks.
- The application was decided in the SQL editor before the email went out: the function marks it notified and sends nothing.
- Two admins click at the same time: the transaction locks the token row, the first wins, the second gets `already_decided`.
- The function is down, the Vault URL is wrong or the secret does not match: nothing reaches the function, the retry job still counts each attempt, and it stops at 10.
- The admin opens the link after the 7 days: `invalid_link`. The SQL editor still works.
- The email is forwarded to someone else: that person can decide. Accepted and written in the Consequences.
- A spammer creates many applications: each causes one email. The existing limits (one open application per session, email and phone, and the anonymous sign in rate limit) are the brake. See Follow-up.

**Configuration required**:
- Edge Function secrets (set with `supabase secrets set`): `MAILJET_API_KEY`, `MAILJET_API_SECRET`, `MAILJET_SENDER_EMAIL` (a sender address already verified in Mailjet), `ADMIN_EMAIL`, `ADMIN_NOTIFY_SECRET` (a long random string shared with the database), `REVIEW_PAGE_URL` (the Cloudflare Pages address, for the link and for CORS).
- Supabase Vault entries, created once by hand: `admin_notify_url` (the full address of `notify-admin-application`) and `admin_notify_secret` (the same value as `ADMIN_NOTIFY_SECRET`).
- Deploy both functions with `--no-verify-jwt`.
- A Cloudflare Pages project that serves the `web/admin-review/` folder, with its `config.js` pointing at the project's `review-application` address.
- Prerequisites to do first: a Mailjet account, an API key and secret, and one verified sender address. Enable `pg_net` and `pg_cron` in the project if the migration cannot.

**Critical test scenarios** (each maps to an acceptance criterion):
- Happy path: a visitor sends an application, the admin gets one email, opens the link, sees the details and photos, taps Approve, and the application is `approved` with `reviewed_by = 'email review'`, verifies **AC-1**, **AC-2**, **AC-4**, **AC-5**.
- Happy path: an account application approved from the page makes the profile a seller, verifies **AC-5**.
- Failure case: Mailjet answers 401 or the network drops: the submit still works, the row stays unsent, the job retries, and the first success sets `admin_notified_at`, verifies **AC-1**, **AC-9**.
- Failure case: two calls for one application send one email, and a call for an already notified one sends none, verifies **AC-10**.
- Failure case: Reject without a reason is refused, and a decision on an already decided application says so and keeps the token used, verifies **AC-6**, **AC-8**.
- Auth/permission: a wrong, expired and used token all get the same 404 with no data, the notify function refuses a missing secret, and no client can read the tokens table, verifies **AC-7**, **AC-11**.
- Regression: old rows send no email after the migration, a person typing markup into the store name cannot change the email, logs and error codes carry no personal data, and the existing submit, approve, reject and claim suites still pass, verifies **AC-2**, **AC-12**, **AC-13**, **AC-14**.

## Build plan

Build approach: none recorded in `AGENTS.md` or the scope header, so this plan assumes thin end to end slices (Tracer Bullet): the trigger and the email first, then the review function, then the page.

1. Write `supabase/migrations/0011_admin_notification.sql`: the four columns, the tokens table with row level security and the backfill, `pg_net` and `pg_cron`, the trigger function that never raises, the trigger, `decide_application_with_token`, the 5 minute retry job (it counts attempts) and the token cleanup. Apply it to a test database and confirm each object exists, satisfies **AC-1**, **AC-3**, **AC-9**, **AC-11**, **AC-12**, **AC-13**
2. Add `supabase/checks/admin_notification.sql` (same style as the 0013 checks): the backfill, the tokens table permissions for `anon` and `authenticated`, token cascade on delete, that an insert succeeds with no Vault values set, and that the retry selection picks exactly the unsent rows, satisfies **AC-9**, **AC-11**, **AC-12**, **AC-13**
3. Add the Mailjet email module `supabase/functions/_shared/admin_email.ts` (build and escape the message, make and hash the token, the Mailjet call through an injected `fetch`, the lease claim, with `TrackClicks` and `TrackOpens` disabled and a test that the payload carries them) free of Deno imports, with a test against fakes, then the `notify-admin-application` Edge Function. This slice goes from a new row to a real email with a link, satisfies **AC-1**, **AC-2**, **AC-3**, **AC-9**, **AC-10**, **AC-11**, **AC-13**
4. Add `supabase/functions/_shared/review_application.ts` (token check, view with signed links, approve and reject through `decide_application_with_token`, the reason length check, error mapping) with tests against fakes, then the `review-application` Edge Function with the `OPTIONS` preflight and CORS on every response, satisfies **AC-4**, **AC-5**, **AC-6**, **AC-7**, **AC-8**, **AC-11**, **AC-13**
5. Add the review page `web/admin-review/` (`index.html`, `config.js`, `_headers`): read the token from the fragment, call `view`, show details and photos as text and images, Approve and Reject with the reason box, images inline and other documents as short lived links, `history.replaceState` to drop the token from the address bar, and the result and refusal states. Deploy to Cloudflare Pages, satisfies **AC-4**, **AC-5**, **AC-6**, **AC-7**, **AC-8**
6. Document the setup (secrets, Vault entries, Mailjet sender, deploy commands, the Cloudflare project) in `supabase/AGENTS.md` through `/sync`, and write `verify.md` with the manual checks: a real email arrives, the link works, an expired and a used link are refused, a Mailjet failure retries, and the photos open only through short links, satisfies **AC-1** to **AC-9**
7. Run the SQL checks on a test database, the Edge Function tests, `flutter analyze` and every Flutter suite, satisfies **AC-14**

## Consequences

**Positive**:
- The admin hears about every application and can decide from a phone, without the SQL editor.
- ID photos are never mailed, stored in a mailbox or logged.
- A Mailjet outage delays an email but never blocks or loses an application.
- The decision still goes through the 0013 functions, so every rule (reason required, one decision, username checks) stays in one place.

**Negative / tradeoffs**:
- A bearer link: anyone who gets the email can decide, and the record does not name the person (`email review`). Treat the admin inbox as the admin key.
- Two more Edge Functions, a token table, `pg_net`, `pg_cron` and Vault, plus a second host (Cloudflare Pages) to run and secure. This is more moving parts than the SQL editor, and it is the price of the one tap decision.
- Edge Functions cannot show an HTML page on their default address, which is why the page lives on Cloudflare Pages.
- Each application causes one email, so a spammer can flood the admin inbox within the existing limits. There is no extra cap yet.
- A failure between the Mailjet send and the database update can send one duplicate email after the lease ends.
- Mailjet click tracking must stay off, or Mailjet stores the review link.
- The email carries personal data of people who may never sign up, and Mailjet processes it.

**Neutral**:
- The applicant is not told anything (scope feature 21). The admin dashboard (feature 20) can replace the review page later and reuse the same decision functions.
- `become_seller()` and the 0013 launch blocker are unchanged.
- The app code does not change at all.

## Follow-up

- [ ] Set up the Mailjet account, API key, secret and one verified sender address before building task 3.
- [ ] Decide on a cap for admin emails (for example 30 per hour with one summary email for the rest) if spam appears.
- [ ] Add a rate limit in front of `review-application` (Supabase has none built in) if the endpoint is probed.
- [ ] Review local data protection rules for emailing applicant details, and record Mailjet as a processor.
- [ ] Decide whether the review page should be replaced by the admin dashboard (scope feature 20), and whether to enroll this feature in the scope as its own row.
- [ ] Add `supabase/AGENTS.md` notes for these functions, the Vault entries and the review page through `/sync` after the build.
