# 0017. Email the applicant when a seller application is decided, and match approved visitors to their account by verified email

**Date**: 2026-10-07
**Status**: In Progress

> Builds on [0013](../0013-seller-application-request/index.md) (the decision functions), [0014](../0014-shared-login-seller-area/index.md) (visitor applications and the claim) and [0016](../0016-seller-application-admin-email/index.md) (the Mailjet and retry pattern). **It changes one 0014 rule**: an approved visitor application can now also reach an account through the account's Clerk verified email, not only through the phone that sent it. It is the email half of scope feature 21. The in app notice is not part of it.
> **Updated 2026-10-08**: the attach by verified email in AC-9 and AC-10 (approved rows only, email only, oldest row only) is replaced by [0014](../0014-shared-login-seller-area/index.md) AC-12 (verified email or phone, every status, every matching row, new functions `attach_applications_by_contact` and `has_unattached_visitor_applications` in migration `0013`). The decision email half of this spec is unchanged.

## Summary

When an admin approves or rejects a seller application, by any path, the applicant gets an email through Mailjet within about a minute. An approval says congratulations and tells the person what to do next: a new person creates an account with the email they applied with, and a person who already has an account just opens the Profile tab and uses the Buyer or Store owner switch. A rejection carries the admin's reason and says they can apply again. To make the approval email true, an approved visitor application now finds its account by the account's verified email (and still by the same phone), so it works on any device and for people who already had an account. Signed in applicants get one new optional field, a personal email, because their form had none.

## Requirements

**User stories**:
- As an applicant, I want an email the moment my application is approved so that I know I can start selling.
- As an applicant with no account, I want the email to tell me what to do, and I want to become a store owner by signing up with the email I applied with, on any phone.
- As an applicant who already has an account with that email, I want to just open the app and switch to my store, with nothing to type again.
- As an applicant whose application is rejected, I want the reason in an email so that I can fix it and apply again.
- As a signed in applicant, I want to give a personal email, optional, so that updates reach me and not only the public store address.
- As the developer, I want a failed email to retry on its own and never block or undo a decision.

**Acceptance criteria** (the contract, each one independently checkable):
- **AC-1**: When a `seller_applications` row changes from `reviewing` to `approved` or to `rejected` through the 0013 functions (the review page, `approve_seller_application` or `reject_seller_application` run in the SQL editor, a future dashboard), the applicant gets one email through the Mailjet API. `applicant_notified_at` is set when Mailjet accepts it. A crash between the send and that update may cause one duplicate. A missing or broken email setup never makes the decision fail or roll back. A hand written `update` of the status fires the same email, but it skips the profile change, so the account version of the email may then be untrue. Admins must decide through the 0013 functions.
- **AC-2**: The recipient is read from the application row itself, never from a profile or the shared loader. It is `applicant_email` for a visitor row. For an account row it is `applicant_email` when given, else `contact_email`. With no address the function sends nothing, saves the code `no_recipient` in `applicant_notify_error`, and the retry job does not try that row again.
- **AC-3**: The approval email has a plain subject with no line breaks, congratulates the applicant, and names the store. For a **visitor row** it shows both paths: new here, create an account with exactly this email address (the one Clerk verifies with a code or through a sign in provider) and the application is attached on its own; already have an account with that email, open the app and use the Buyer or Store owner switch at the top of the Profile tab. For an **account row** it says the account is now a store owner account and shows the switch path only. It holds no photo, no ID data, no phone number and no link.
- **AC-4**: The rejection email names the store, shows the admin's reason, and says the person can send a new application ("Apply now" with no account, Settings then Seller application with one). The reason and every other typed value is escaped in the HTML part, and the store name is cut to one short line (`oneLine`) in the subject and the body.
- **AC-5**: Every message goes from `MAILJET_SENDER_EMAIL`, has `ReplyTo` set to `ADMIN_EMAIL`, has `TrackClicks` and `TrackOpens` set to `disabled`, and carries the application id as `CustomID`. Both a text part and an HTML part are sent.
- **AC-6**: When Mailjet, the network or the function fails, `applicant_notified_at` stays empty and a job retries every 5 minutes, only rows decided more than 1 minute ago, with the job raising `applicant_notify_attempts` itself on each post, so the 10 attempt limit holds even when the function never runs. `applicant_notify_error` holds a short code only. A second call for an already notified row sends nothing, and two calls close together send one email through a 2 minute lease. The function refuses a call without the shared secret (401).
- **AC-7**: When migration `0012` runs, every already decided row is marked notified, so no old decision sends an email. Rows still `reviewing` stay unsent until decided.
- **AC-8**: The signed in application form has an optional "Your email" field on the contact and logo step, under the store email, labelled as private. It is trimmed, stored lowercase, up to 200 characters, and must look like an email when given (`invalid_field` otherwise). It is saved in `applicant_email`, is never copied to the profile, and is shown to nobody but the admin. `submit_seller_application` takes it as an optional parameter, and an older app build that does not send it keeps working.
- **AC-9**: `claim-seller-application` also attaches by verified email. When the caller is not a seller and at least one approved, unclaimed, unattached visitor application exists (a database check first, so calls make no Clerk request while no approved application is waiting), the function reads the caller's Clerk user through the Backend API and takes only the email addresses whose verification status is `verified`. The service role function `attach_applications_by_email` lowercases and trims the list itself in SQL, then sets `bound_account_id` on the **oldest** approved, unclaimed, unattached visitor row whose lowercase `applicant_email` equals one of them, in one `update` statement. It does nothing when the account has an open (`reviewing`) application, its own or an attached one (the same skip the phone attach uses), and the function skips the Clerk call and the attach when `find_claimable_application` already finds a row for the caller. The normal claim runs in the same call and makes the person a seller. An unverified address, a `reviewing` or `rejected` application, a row already attached to another account, and an account that is already a seller are never attached or changed.
- **AC-10**: The same phone attach from 0014 AC-12 is unchanged and still works. No client can call `attach_applications_by_email` or `has_unattached_approved_applications`. A Clerk lookup failure leaves everything as it was, so the next launch, resume or Seller application screen retries, and the sign in is never blocked.
- **AC-11**: After a successful claim or an approval the person sees the Buyer or Store owner switch at the top of the Profile tab and the other tabs (the 0014 behaviour, unchanged), so the instructions in the email are true.
- **AC-12**: The admin email and the review page (0016) show the application's own `applicant_email` for an account row when it is given, and fall back to the profile email as before.
- **AC-13**: Logs and `applicant_notify_error` hold no name, email, phone, store text or reason. Nothing new is stored beyond the columns in the data model.
- **AC-14**: `flutter analyze` is clean, all existing suites pass, and the 0013, 0014 and 0016 behaviour is unchanged except the added attach rule in AC-9.

## Decision

**Chosen option**: Option 1: A database trigger on the decision calls a new Edge Function that emails the applicant through Mailjet (the 0016 pattern, with a retry job and a lease), and the claim function also attaches approved visitor applications by the account's verified email.

A decision sends one email from any path, and the email's instructions work because the application can now find the person's account by a verified email.

**Implementation skills**: `supabase` (`supabase/agent-skills`, `.agents/skills/supabase/`) · `supabase-postgres-best-practices` (`supabase/agent-skills`, `.agents/skills/supabase-postgres-best-practices/`)

## Rationale

Reasoning and options: see [rationale.md](./rationale.md).

## Feature design

**Data model** (new migration `0012_applicant_notification.sql`, the next free number after `0011`):

`seller_applications`, four new columns and one reused column:

| Column | Type | Rule |
|---|---|---|
| `applicant_notified_at` | timestamptz, null | Set when Mailjet accepted the decision email. Null means not sent |
| `applicant_notify_attempts` | integer, not null, default 0 | Counted by the retry job when it posts. The job stops at 10 |
| `applicant_notify_error` | text, null | Short code only (`mailjet_http_401`, `no_recipient`, `internal_error`). No personal data |
| `applicant_notify_claimed_at` | timestamptz, null | A 2 minute lease taken before sending, so two calls send one email |
| `applicant_email` (exists) | text, null | Now also set by a signed in applicant (optional). Visitor rows still require it. Lowercase, up to 200 characters. The existing check "a visitor needs all three contact fields" already allows it on account rows |

Index: partial index on `lower(applicant_email)` where `origin = 'visitor' and status = 'approved' and claimed_at is null and bound_account_id is null`, for the email attach. Existing decided rows get `applicant_notified_at = now()` in the same migration. No new table.

Database objects in the same migration (all `security definer`, empty `search_path`, every reference schema qualified, `revoke ... from public, anon, authenticated` explicitly, the way 0011 does it):
- `applicant_notify_post(p_id uuid)` reads `applicant_notify_url` and `admin_notify_secret` from Vault and posts with `net.http_post(..., timeout_milliseconds := 30000)`. It does nothing when a value is missing. The shared secret is the same one 0016 uses, so no new secret has to be set by hand. Only the URL entry is new.
- `notify_applicant_decision()` trigger function and the trigger `seller_applications_notify_applicant`: `after update of status ... for each row when (old.status = 'reviewing' and new.status in ('approved', 'rejected'))`. It catches every error and always returns the row.
- `retry_applicant_notifications()` and a cron job every 5 minutes: rows with `status in ('approved','rejected')`, `applicant_notified_at is null`, attempts below 10, `coalesce(reviewed_at, created_at)` older than 1 minute, and `applicant_notify_error is distinct from 'no_recipient'`, oldest first, at most 20 per run, `for update skip locked`. It adds 1 to the attempts itself and posts.
- `claim_applicant_notification(p_id uuid)` takes the lease and returns true or false. Service role only.
- `has_unattached_approved_applications()` returns a boolean, and `attach_applications_by_email(p_clerk_id text, p_emails text[])` returns how many rows it attached (0 or 1). Both service role only. The attach lowercases and trims `p_emails` itself, skips an account whose profile role is already `seller`, skips an account with an open application (the phone attach rule), takes the oldest matching row, and is a single `update ... where bound_account_id is null and applicant_id is null and status = 'approved' and claimed_at is null`, so two simultaneous attaches end with one winner.
- `submit_seller_application` is replaced with one new optional parameter `p_applicant_email text default null`. The old signature is dropped in the same migration (otherwise two overloads exist), the grants are repeated, and the validation and the one open rule are unchanged. The new parameter is validated and stored lowercase.

**State transitions**:
- Decision email: `unsent` (notified null, attempts 0 to 9) → `sent` (notified set), or `exhausted` (attempts 10), or `skipped` (error `no_recipient`, nothing to send to). Sent never undoes. An admin can reset an exhausted row by setting its attempts to 0. Status is final by convention, not by a database rule: a row set back to `reviewing` by hand and decided again sends no second email unless an admin clears `applicant_notified_at`.
- Attach: a visitor row goes `unattached → attached (bound_account_id) → claimed`, as in 0014. The new route adds a second way to reach "attached", only from `approved`.

**API surface**:

| Function or call | Kind | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| `notify_applicant_decision` | database trigger | the updated row | none (posts `{application_id}`) | table owner | never raises |
| `retry_applicant_notifications` | cron job, every 5 minutes | none | posts one request per unsent decided row, adds 1 to its attempts | database | none |
| `notify-applicant-decision` | Edge Function, `POST` | `{ application_id }`, header `x-webhook-secret` | `{ sent: true or false, reason? }` | shared secret, `--no-verify-jwt` | 401 bad secret, 400 bad body, 500 not configured |
| `claim_applicant_notification` | database function | `p_id` | boolean | service role only | none |
| Mailjet send | outbound `POST https://api.mailjet.com/v3.1/send` | one message: `From`, `To`, `ReplyTo`, `Subject`, `TextPart`, `HTMLPart`, `CustomID`, tracking disabled | success when HTTP 200 and `Messages[0].Status` is `success` | Basic auth, API key and secret | any other result is a failed attempt |
| `submit_seller_application` | database function (changed) | the 0013 inputs plus `p_applicant_email` (optional) | application id | authenticated | the 0013 errors, `invalid_field` for a bad email |
| `has_unattached_approved_applications` | database function | none | boolean | service role only | none |
| `attach_applications_by_email` | database function | `p_clerk_id`, `p_emails` | count attached | service role only | none |
| `claim-seller-application` | Edge Function (changed) | the caller's Clerk token | `{ claimed: true or false }` | verified Clerk token | 401, 500 (also on a Clerk lookup failure) |
| Clerk Backend API | outbound `GET https://api.clerk.com/v1/users/{id}` | the user id from the verified token | `email_addresses[]` with `verification.status` | `CLERK_SECRET_KEY` | any failure aborts the attach, not the sign in |

**Key invariants**:
- A decision never fails or rolls back because of email. The trigger catches everything, and Mailjet success is recorded after the send.
- At most one email is sent while a lease is held. A duplicate after a crash between the send and the update is accepted.
- Attempts are counted by the retry job when it posts, never by the function, so a failure before the function runs still counts.
- The recipient is chosen from the application row only, never from a profile (approval overwrites the profile email with the public store email, so it cannot be trusted).
- An application is attached by email only when it is `approved`, the address comes from a Clerk address with `verification.status = 'verified'`, and nobody else holds the row. Nothing typed by a person and not proven (a visitor's typed email on its own) ever attaches a row.
- An email holds no photo, no ID data, no phone number and no link. All typed text is escaped in the HTML part.
- The attach and the claim are separate atomic steps, and two simultaneous calls end with one winner (the 0014 row locks).

**Security model**: The notify function checks the shared secret in constant time and the database objects are not callable by clients. The new attach route needs a Clerk address that Clerk has verified and an admin approval that already happened, so the person who can claim an application is whoever controls the mailbox the applicant named. A visitor can type someone else's address: the admin sees the ID photos and decides, and only the mailbox owner can claim, so the damage is limited to a store profile with the wrong details on a willing account (see Consequences). The Clerk secret key is used only inside the claim function and never returned. **Compliance scope**: the emails hold a visitor's store name and, for a rejection, the admin's reason, which may mention personal data, so write reasons with that in mind. Mailjet is already recorded as a processor (0016). A transactional email about the person's own application needs no unsubscribe link.

**Failure and edge cases**:
- Mailjet down, wrong key or rate limited: attempt counted, short code saved, retried up to 10 times, then it stops.
- A secret or sender setting is missing: the function answers 500 `not_configured`, the attempt is counted, nothing breaks.
- No address (an account application with no personal email and no store email): nothing is sent, `no_recipient`, the status chip in the app still shows the result. This is accepted.
- The visitor typed a wrong or unreachable address: the email is lost, Mailjet accepts it, and the admin contacts the applicant by phone (the 0014 follow up). The phone attach still works.
- The person signs up with Apple's "Hide My Email" relay address, or any address other than the typed one: no match by email. Some sign in providers mark an address verified on their own word, and Clerk's flag is trusted as it is.
- The person signs up with a phone number only, with no email: the email attach finds nothing, and only the same phone attach can work, as before.
- The person already has a Clerk account with another email than the one they applied with: no match by email, same as the phone only case. They can sign up again with the application email or ask the admin to attach by hand.
- Two approved applications for the same address: only the oldest attaches. The person becomes a seller with it, and the other stays unclaimed (an `already_seller` refusal) until the 30 day retention job removes it. Its username stays reserved until then.
- The username was taken between approval and claim: the claim refuses `username_taken` as in 0014, and the row stays attached and unclaimed.
- Clerk is down: the attach step throws, the function answers 500, the app tolerates it and retries on the next launch, resume or screen open.

**Configuration required**:
- Edge Function secrets already set: `MAILJET_API_KEY`, `MAILJET_API_SECRET`, `MAILJET_SENDER_EMAIL`, `ADMIN_EMAIL`, `ADMIN_NOTIFY_SECRET`. No new secret for the email itself.
- `CLERK_SECRET_KEY` and `CLERK_ISSUER` must be set for `claim-seller-application` (the same secrets `delete-account` uses). Check with `supabase secrets list` that both names exist.
- One new Vault entry, created once by hand: `applicant_notify_url` (the full address of `notify-applicant-decision`). The existing `admin_notify_secret` entry is reused.
- Deploy `notify-applicant-decision` and `claim-seller-application` with `--no-verify-jwt`. The claim function has never been deployed, so this is its first deploy. Migrations `0008` to `0010` are not applied live yet, so apply with `supabase db push --include-all` or apply `0012` on its own and record it, the way `0011` was done.

**Critical test scenarios** (each maps to an acceptance criterion):
- Happy path: a visitor application is approved from the review page, the visitor gets one email with both paths, signs up with that email on another phone, opens the app, becomes a seller and sees the switch in the Profile tab, verifies **AC-1**, **AC-3**, **AC-9**, **AC-11**.
- Happy path: an account application is approved, the person gets the account row version of the email, opens the Profile tab and switches areas, verifies **AC-2**, **AC-3**, **AC-11**.
- Happy path: a rejection from the review page sends the reason, and the person sends a new application, verifies **AC-1**, **AC-4**.
- Failure case: Mailjet answers 401 or the function is unreachable, the decision stands, the row stays unsent, the job retries and stops at 10, verifies **AC-1**, **AC-6**.
- Failure case: two calls for one decision send one email, a call for an already notified row sends none, an account row with no address sends none and is not retried, verifies **AC-2**, **AC-6**.
- Failure case: Clerk is down during a claim, nothing changes and the next call works, verifies **AC-10**.
- Auth/permission: a missing shared secret is refused, no client can call the new database functions, an unverified Clerk address, a `reviewing` application, a row attached to someone else, an account with an open application and an existing seller are never attached, two rows for one address attach only the oldest, mixed case and spaces in the Clerk list still match, verifies **AC-6**, **AC-9**, **AC-10**.
- Regression: old decided rows send no email after the migration, markup in the store name or reason cannot change the email, an old app build still submits, logs hold no personal data, and the 0013, 0014 and 0016 suites pass, verifies **AC-7**, **AC-8**, **AC-12**, **AC-13**, **AC-14**.

## Build plan

Build approach: none recorded in `AGENTS.md` or the scope header, so this plan assumes thin end to end slices (Tracer Bullet): the decision email first for both kinds of application, then the attach by email, then the form field.

1. Write `supabase/migrations/0012_applicant_notification.sql`: the four columns and the backfill, the partial index, `applicant_notify_post`, the trigger and its function, the retry job, `claim_applicant_notification`, `has_unattached_approved_applications`, `attach_applications_by_email`, and the replaced `submit_seller_application` with `p_applicant_email`. Apply it to a test database and confirm each object exists, satisfies **AC-1**, **AC-2**, **AC-6**, **AC-7**, **AC-8**, **AC-9**, **AC-10**, **AC-13**
2. Add `supabase/checks/applicant_notification.sql` (same style as the 0011 checks): the backfill, the trigger fires only on the two transitions, the insert and update succeed with no Vault values, the retry selection picks exactly the right rows and skips `no_recipient`, the lease, the attach rules (verified list only, approved only, unattached only, skips a seller), the permissions for `anon` and `authenticated`, and the new parameter on `submit_seller_application` including a bad email, satisfies **AC-2**, **AC-6**, **AC-7**, **AC-8**, **AC-9**, **AC-10**
3. Add `supabase/functions/_shared/applicant_email.ts` (build the approval and rejection messages, the recipient rule, the notify flow with injected dependencies and the lease, reusing `sendWithMailjet`, `secretsMatch` and the escape helpers from `admin_email.ts`, with `ReplyTo` added to the message type) with a test against fakes, then the `notify-applicant-decision` Edge Function, which reads the recipient fields and the status straight from the row and never through `application_loader.ts`. Separately make the application loader (admin email only) prefer the application's own `applicant_email` for account rows, satisfies **AC-1** to **AC-6**, **AC-12**, **AC-13**
4. Extend the claim: a small `_shared/clerk_emails.ts` that returns the verified addresses of a Clerk user (injected `fetch`), the attach call and the cheap check inside `_shared/claim_seller_application.ts`, and `CLERK_SECRET_KEY` read in `claim-seller-application/index.ts`, with tests against fakes (verified only, no Clerk call when nothing is waiting, Clerk failure throws, order attach then claim), satisfies **AC-9**, **AC-10**
5. Flutter: the optional "Your email" field on the contact and logo step, its check in `seller_application_logic.dart`, the new argument through both repositories (mock and Supabase) and their tests, and a widget test for the field, satisfies **AC-8**, **AC-14**
6. Write `verify.md` with the manual checks (a real approval email for a visitor and an account application, a real rejection, sign up with the application email on another phone, an existing account that switches, Mailjet failure retry, the old decided rows send nothing) and document the setup (Vault entry, deploy commands, new rule) through `/sync` in `supabase/AGENTS.md`, `apps/buyer/lib/core/area/AGENTS.md` and the 0014 spec text, satisfies **AC-1** to **AC-11**
7. Run the SQL checks on a test database, the Edge Function tests, `flutter analyze` and every Flutter suite, satisfies **AC-14**

## Consequences

**Positive**:
- Every applicant hears about the decision, whichever path made it, and rejected people learn why and that they can apply again.
- The approval email's instructions are true: a new person signs up with the email, an existing account just switches, on any phone.
- It reuses the 0016 pattern, one existing secret and one Vault entry, so there is little new to run.
- The decision functions and rules (0013) are untouched.

**Negative / tradeoffs**:
- A changed trust rule: before, nothing a visitor typed could attach an application. Now a typed address plus a verified Clerk address can. A visitor who types someone else's address and gets approved lets that mailbox owner claim a store with the wrong details. The admin approval and the ID photos are the gate.
- The claim function now calls Clerk, and the Clerk secret key is needed there. The database check is global, not per person, so while any approved visitor application waits (up to 30 days) every non seller launch, resume and screen open makes one Clerk request. That is fine at this volume. Beyond a few thousand daily users, move the verified email into the Clerk session token as a custom claim (no Backend call, no secret key).
- One more function and trigger, one more cron job and one more Vault entry to set by hand.
- A person who applied with one email and signs up with another gets no match by email (they can still use the same phone, or ask the admin).
- A wrong typed email loses the notice, and an account application with no email at all sends nothing.
- A typed address is not proven: the decision email goes to whatever address was typed, carrying the typed store name and the admin's reason. The admin decision is the only gate.
- The rejection reason is sent to the applicant's mailbox, so an admin must not put anything in it that they would not say to the person.
- A failure between the Mailjet send and the database update can send one duplicate email after the lease ends.

**Neutral**:
- The in app notice, an applicant notification centre and reminder emails stay in scope feature 21 and later work.
- Migrations `0008` to `0010` and the first deploy of `claim-seller-application` ride along with this release.
- The Buyer or Store owner switch already shows to sellers at the top of each tab, including Profile, so the app only gains the optional email field.

## Follow-up

- [x] Update spec 0014 (its AC-12, its key invariant and the Security model) and `apps/buyer/lib/core/area/AGENTS.md` to say the claim can also attach by a Clerk verified email, through `/architect` update and `/sync` after the build.
- [ ] Fix `merge_anonymous_identity(target_user_id)` (0007), which trusts the account id the caller passes in. Any anonymous session can bind its visitor applications to any account. It predates this spec and weakens the "only the sending phone attaches" claim, so fix it separately by checking the target against the verified identity link. Tracked as its own task.
- [ ] Decide later whether a reminder email should go to an approved applicant who never claims, before the 30 day retention job removes the row.
- [ ] Decide whether an account application with no address should fall back to the Clerk login email (left out by choice).
- [ ] Add a store link to the email once the app is published (left out by choice).
- [ ] Add the in app notice (rest of scope feature 21).
- [ ] Tell applicants in the visitor confirmation and in the form that the decision comes by email.
