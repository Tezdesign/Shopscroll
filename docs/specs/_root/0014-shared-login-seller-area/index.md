# 0014. Share one login between buyers and sellers, with a store area inside the buyer app and applications from visitors

**Date**: 2026-10-04
**Status**: In Progress

> Partly replaces [0011](../0011-monorepo-buyer-seller-apps.md) (the seller app is no longer a separate app), narrows [0012](../0012-one-backend-seller-role/index.md) AC-7 (no seller app sign in), and replaces [0013](../0013-seller-application-request/index.md) AC-10 and build plan task 6 (the seller app gate). Everything else in 0011, 0012 and 0013 still stands.

## Summary

Buyers and store owners use one app and one login. The login has a Buyer or Store owner choice, and after Log in the choice decides which area opens: the buyer area we built, or a store area inside the same app. Only approved sellers can enter the store area. A person with no account can tap "Apply now", fill the application with a name, an email and a phone number, and send it without signing up. When the same phone later signs up or logs in, the application attaches to that account, and once an admin approves it the person becomes a seller. The separate seller app is removed.

## Requirements

**User stories**:
- As a returning person, I want to log in once and choose Buyer or Store owner so that I land in the right area.
- As an approved seller, I want to switch between the buyer area and my store area with one tap so that I can shop and run my store from one account.
- As a visitor with no account, I want to apply to become a seller from the landing or login screen without signing up first, so that applying is easy.
- As an applicant who signs up on the same phone, I want my application to attach to my new account so that I become a seller when it is approved, without repeating the form.
- As the admin, I want visitor applications in the same list and decided with the same functions as account applications so that there is one review process (spec 0013).
- As the developer, I want one app and one login so that there is no second sign in, no handoff between installs and no duplicate onboarding.

**Acceptance criteria** (the contract, each one independently checkable):
- **AC-1**: On the login screen, choosing **Buyer** and signing in opens the buyer area. Choosing **Store owner** opens the store area only when the signed in profile has `role = 'seller'`. Otherwise the person opens in the buyer area and sees a notice: no application ("You are not a store owner yet. Apply from Settings, Seller application."), an application under review ("Your application is being reviewed."), or a rejected one ("Your application was rejected: <reason>."). The notice has an action that opens the Seller application screen. An application attached by AC-12 counts as theirs for this notice.
- **AC-2**: Routing after sign in waits for the claim step (AC-13) to finish or fail, so an approved applicant who signs in as Store owner reaches the store area in one pass. A claim failure never blocks the sign in.
- **AC-3**: The area last used is remembered on the device. With a saved session the app opens that area. If the profile is not a seller (for example the role was removed), it opens the buyer area. Signing out clears the memory.
- **AC-4**: An approved seller sees a toggle at the top of the buyer area's tab screens and at the top of the store area. Tapping it switches area at once and remembers the choice. A buyer never sees the toggle. Pushed detail screens (a product, the cart) do not show it.
- **AC-5**: The store area is a placeholder screen (the shared `ComingSoonScreen` style) with the toggle. No seller features are built here.
- **AC-6**: `apps/seller` no longer exists: its folder, its Dart workspace entry and its tests are removed. No client code calls `become_seller()`. The server function stays (the launch blocker in spec 0013 is unchanged).
- **AC-7**: "Apply now" on the landing screen and the login screen opens the application wizard for a person with no account. A person who is signed in uses Settings, Seller application as before. For a visitor the wizard has an extra step before Review, "About you", with name, email and phone (all required, the phone chosen with the existing country picker so it is stored in international format). After Send, a confirmation says the team will contact them at the email and phone they gave. The wizard keeps the 0013 rules (resize, JPEG or PNG, 5 MB, retry, one send per double tap).
- **AC-8**: `submit_visitor_application` creates a `seller_applications` row with `origin = 'visitor'`, `status = 'reviewing'`, `applicant_id` null and `submitter_id` equal to the caller's anonymous session id. It refuses a caller with no session (`no_session`) and a real account (`use_account`, they must use `submit_seller_application`). Calling it again with the same `p_id` by the same session returns that row's id and changes nothing (checked first). It validates like 0013 AC-3, plus `applicant_name` 2 to 60 characters, an email with an `@` and a dot in the domain (trimmed, stored lowercase, up to 200 characters) and a phone in international format matching `^\+[1-9][0-9]{6,14}$` (`invalid_field`). A username counts as taken when a profile has it, or a `reviewing` application, or an approved visitor application that is not claimed yet (`username_taken`). Each file must exist in `visitor-documents` at `<sub>/<p_id>/<kind>-<name>` where kind is `id`, `business` or `logo` (`file_not_found` or `invalid_field`). A visitor can have one `reviewing` application per session, per email and per phone: a second one with a new id for any of the three is refused (`already_open`). Two submits at the same moment end in one row and a documented error, never a raw database error.
- **AC-9**: In `visitor-documents` (private, JPEG and PNG, 5 MB) an anonymous session can add files only under its own session id folder, and at most 12 files in total in that folder. A real account cannot add files there. No client can read, update or delete files in it. Existing 0013 bucket rules are unchanged: anonymous sessions still cannot add to `store-logos` or `application-documents`.
- **AC-10**: A signed in client reads only rows where `submitter_id`, `applicant_id` or `bound_account_id` equals its own id, so a visitor's session sees its own application and an account sees the application attached to it. No client inserts, updates or deletes rows directly. `anon` has no access.
- **AC-11**: `approve_seller_application` and `reject_seller_application` work on visitor rows. Approving a visitor row sets `status = 'approved'`, `reviewed_at` and `reviewed_by` and changes no profile. Rejecting needs a reason as before. The behaviour for account rows is unchanged, except that approving an account row now also refuses a username reserved by an unclaimed approved visitor application (`username_taken`).
- **AC-12**: When a person signs up or logs in on a phone whose anonymous session sent visitor applications, `merge_anonymous_identity` (which already runs once at sign in, on the anonymous session, before the switch) sets `bound_account_id` to the new account on those rows that are still unattached (`applicant_id` null and `bound_account_id` null). It skips a row when the account already has an open application (`reviewing`, by `applicant_id` or `bound_account_id`), and the one open rule counts attached visitor rows. A visitor application is never attached by matching on an email or phone.
- **AC-13**: The app calls the Edge Function `claim-seller-application` after every real sign in, when the app launches or resumes with a signed in buyer, and when the Seller application screen opens or is refreshed. The function verifies the Clerk session token itself and looks for the oldest `approved` visitor application with `bound_account_id` equal to that account and `claimed_at` null. Found: it copies the logo (if any) to `store-logos/<clerk id>/<application id>.<ext>` (an existing destination counts as done), then `claim_seller_application` runs in one transaction. That function locks the application and the profile, rechecks that the row is still approved and unclaimed, copies the store details onto the profile exactly as approval does in 0013 AC-6 (empty optional fields become null), sets `role = 'seller'`, sets `applicant_id` and `claimed_at`, and refuses with `already_seller`, `username_taken` or `no_profile` leaving everything as it was. A second call returns `{ "claimed": false }` with no error and changes nothing. A signed in client cannot call `claim_seller_application` or `find_claimable_application` directly.
- **AC-14**: Deleting an account first reads the paths on the applications that belong to it (by `applicant_id` or `bound_account_id`), removes those files from `visitor-documents`, deletes those rows (attached visitor rows have no cascade), and only then runs the rest of the cleanup, in that order and not in parallel. The 0013 cleanup of the `store-logos` and `application-documents` folders stays.
- **AC-15**: Signed in applications work as in 0013 (AC-1 to AC-9 still hold), signing up and the other onboarding steps behave as before, `flutter analyze` is clean in every package, and all test suites pass.

## Decision

**Chosen option**: Option 1: One app with a role switched store area, and visitor applications held in the same table and attached to the account that signs up on the same phone

The buyer app becomes the only app. The login's Buyer or Store owner choice and the profile's role decide the area. Visitors apply through their existing anonymous session with name, email and phone, the application attaches to the account that signs up on that phone, and an approved one turns that account into a seller.

**Implementation skills**: `supabase` (`supabase/agent-skills`, `.agents/skills/supabase/`) · `supabase-postgres-best-practices` (`supabase/agent-skills`, `.agents/skills/supabase-postgres-best-practices/`)

## Rationale

Reasoning and options: see [rationale.md](./rationale.md).

## Feature design

**Data model** (changes to `seller_applications` from migration 0006, new migration `0007`; every existing column stays):

| Column | Change | Rule |
|---|---|---|
| `applicant_id` | now nullable | Foreign key to `user_profiles`, `on delete cascade`. Null for a visitor until a claim |
| `origin` | new, text, not null, default `'account'` | `account` or `visitor`. Says which bucket holds the photos and which submit path was used. Never changes |
| `submitter_id` | new, text, not null | The session `sub` that sent it: a Clerk id, or an anonymous session id. Names the photo folder. Backfilled with `applicant_id` for existing rows |
| `applicant_name`, `applicant_email`, `applicant_phone` | new, text | Private contact details of a visitor. Phone in international format. Never copied to a profile and never used to match an account. Check: an `account` row needs none, a `visitor` row needs all three |
| `bound_account_id` | new, text, no foreign key | The Clerk id of the account that signed in on the phone that sent the application. Set once by `merge_anonymous_identity` (AC-12), never by a client |
| `claimed_at` | new, timestamptz | Set when the account takes an approved visitor application |

Check constraints: `origin in ('account','visitor')`, `(origin = 'account' and applicant_id is not null) or origin = 'visitor'`, and the visitor contact rule above.

Indexes (each partial unique maps to one named refusal, so each name is listed in the SQL checks):
- `seller_applications_one_reviewing_per_owner`: unique on `coalesce(applicant_id, bound_account_id, submitter_id)` where `status = 'reviewing'` (replaces the 0006 index on `applicant_id`). Maps to `already_open`.
- `seller_applications_one_reviewing_per_email` on `lower(applicant_email)` and `seller_applications_one_reviewing_per_phone` on `applicant_phone`, both where `origin = 'visitor' and status = 'reviewing'`. Map to `already_open`.
- `seller_applications_one_username_in_flight`: unique on `username` where `status = 'reviewing' or (origin = 'visitor' and status = 'approved' and claimed_at is null)` (replaces the 0006 username index). Maps to `username_taken`. An approved visitor application keeps its username reserved until it is claimed.
- A plain index on `(bound_account_id)` where `status = 'approved' and claimed_at is null` serves the claim lookup.

Storage: new private bucket `visitor-documents`, JPEG and PNG, 5 MB. Paths: `<sub>/<application id>/id-<random>.<ext>`, `business-<random>.<ext>` and `logo-<random>.<ext>`, where `<sub>` is the anonymous session id. On a claim the logo is copied to the public `store-logos` bucket as `<clerk id>/<application id>.<ext>` and the profile's `avatar_url` becomes `store-logos/<clerk id>/<application id>.<ext>` (the 0013 rule: the app turns a path without `http` into a public URL).

**State transitions**: status is unchanged (`reviewing` to `approved` or `rejected`, final). A visitor row has two extra steps that happen once and never undo: attached (`bound_account_id` set, any status), then claimed (`applicant_id` and `claimed_at` set, only from `approved`).

**Client state** (no new table): a device preference `last_area` (`buyer` or `store`) in the same preferences store the onboarding flag uses, and an app area provider that combines it with the profile role. Rule: the store area is entered only while `role = 'seller'`.

**API surface**:

| Function or call | Kind | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| `submit_visitor_application` | database function | `p_id` uuid, `p_store_name`, `p_username`, `p_location`, `p_applicant_name`, `p_applicant_email`, `p_applicant_phone`, `p_id_document_path`, optional `p_bio`, `p_website_url`, `p_contact_phone`, `p_contact_email`, `p_logo_path`, `p_business_document_path` | application id | anonymous session only | `no_session`, `use_account`, `already_open`, `invalid_field`, `username_taken`, `missing_document`, `file_not_found` |
| `merge_anonymous_identity` | database function (existing, replaced) | `target_user_id` | none | signed in anonymous session, as today | as today |
| `find_claimable_application` | database function | `p_clerk_id` text | id and `logo_path` of the oldest approved unclaimed row bound to that account, or none | service role only | none |
| `claim_seller_application` | database function | `p_id` uuid, `p_clerk_id` text, `p_logo_path` text (the copied path, optional) | none | service role only | `not_found`, `not_claimable`, `no_profile`, `already_seller`, `username_taken` |
| `claim-seller-application` | Edge Function | the caller's Clerk session token | `{ "claimed": true or false }` | verified Clerk token | 401 not signed in, 500 not configured |
| `approve_seller_application`, `reject_seller_application` | database functions (0013) | as 0013 | as 0013 | service role only | as 0013, now accept visitor rows |
| `submit_seller_application` | database function (0013, replaced) | as 0013 | as 0013 | as 0013 | as 0013 |
| select on `seller_applications` | table read | none | caller's rows, newest first | signed in | none (empty list) |
| upload to `visitor-documents` | Storage API | file, path | stored path | anonymous session, own folder, under the file cap | permission denied, size or type refused |

Refusals are raised as the whole error message, the same convention as 0013. An admin can attach a row from another device by running `claim_seller_application` by hand with the person's Clerk id (the logo is then not copied, the person adds one in Edit profile).

**Key invariants**:
- `role` becomes `'seller'` only inside `approve_seller_application` (account rows), `claim_seller_application` (visitor rows) or the open `become_seller()` (a launch blocker, unchanged).
- A visitor row is claimed at most once, and only by the account it was attached to by the phone's own anonymous session. Nothing a visitor types (email or phone) ever attaches a row to an account.
- One `reviewing` application per owner: the account (`applicant_id`, or `bound_account_id` once attached), or the session before it is attached. For visitors also one per email and per phone. One username in flight overall.
- A file path on a visitor application matches the exact path rule in AC-8, so a visitor cannot point at someone else's file.
- The claim locks the application and the profile before it rechecks, so two claims cannot both pass.
- Routing to the store area is client convenience. The server rules that matter (seller write policies from 0012) still check `role` on every write.
- The claim never changes a profile that is already a seller.

**Security model**: Same row level security as 0013, with the select policy widened to `submitter_id`, `applicant_id` or `bound_account_id` equal to the caller. Table grants stay `select` only to `authenticated`. `submit_visitor_application` is `security definer`, `search_path = ''`, executable by `authenticated` only and refuses non anonymous sessions inside. `find_claimable_application` and `claim_seller_application` are `security definer`, executable by the service role only. Storage policies compare `(storage.foldername(name))[1]` to `(select auth.jwt() ->> 'sub')`, require `is_anonymous` to be true for `visitor-documents`, and count the files already in the folder (a cap of 12); there is no read, update or delete policy for clients. The Edge Function verifies the Clerk token against the instance's keys with a pinned issuer, never trusting a claimed id. **Compliance scope**: a visitor's ID photo, name, email and phone are personal data of a person who may never create an account. Keep the bucket private, never log them, never return them to other users, and follow the data protection rules of the country you operate in. Decided retention: rejected applications, and approved ones nobody claimed, are deleted 30 days after the decision (a follow up job and a launch requirement, see Follow-up).

**Failure and edge cases**:
- Visitor loses the connection or the app closes mid upload: files are left in `visitor-documents`, no row points to them. A retry with the same `p_id` uploads again under new names, up to the 12 file cap. Orphan cleanup belongs to the retention job.
- Visitor submits from a second device or after reinstalling: a new anonymous session, so the per session rule does not stop it, but the per email and per phone rule does (`already_open`).
- Visitor gives an email or phone of someone else: it changes nothing for that person. The application is only ever attached to the account created on the sending phone, and the admin contacts the applicant before approving.
- Visitor signs up on a different device than the one that sent the application: nothing attaches. The admin can attach it by hand (see API surface), or the person applies again after the old one is cleaned up.
- Visitor signs up while the application is still `reviewing`: it is attached at that sign in, shows on their Seller application screen, and counts toward the one open rule, so they cannot send a second one from Settings. When it is approved later, the next launch, resume or opening of the Seller application screen runs the claim, with no new sign in needed.
- Approved applicant never signs up: the row stays unclaimed, and its username stays reserved until the 30 day retention job removes it.
- Username taken between approval and claim cannot happen through another application (it is reserved), but a profile can still take it: the claim refuses with `username_taken`, the sign in works, and the admin changes the application's username or asks the person to apply again.
- Claim function fails (network, Clerk down): sign in still works and the person stays a buyer. The next launch, resume or Seller application screen retries it.
- Two claims at once: the second waits on the row lock, rechecks and returns `claimed: false`.
- Account deleted while an application is attached or claimed: the files and rows go (AC-14). A visitor row never attached to any account stays until the retention job.
- A seller who loses the role (removed by the admin) while the store area is remembered: next launch falls back to the buyer area (AC-3).

**Configuration required**:
- `CLERK_SECRET_KEY` and `CLERK_ISSUER`: the secrets `delete-account` already uses, now also needed by `claim-seller-application`. Deploy that function with `--no-verify-jwt`, it verifies the token itself.
- Supabase Auth anonymous sign ins stay on (the app already uses them). Review the project's anonymous sign in rate limit, it is the main spam brake on the visitor path.
- Remove the seller bundle ids from the Clerk instance (cleanup after `apps/seller` is removed).
- The new bucket and its policies are created by the migration.

**Critical test scenarios** (each maps to an acceptance criterion):
- Happy path: a visitor applies with name, email, phone and photos, signs up on the same phone, the admin approves, the next launch claims it, the person is a seller with the store details and logo, and logging in as Store owner reaches the store area, verifies **AC-7**, **AC-8**, **AC-11**, **AC-12**, **AC-13**, **AC-1**.
- Failure case: a second submit for the same email or phone, or for a new id from the same session, is refused, and a retry with the same id is not, verifies **AC-8**.
- Failure case: bad input (short name, bad email, a phone not in international format, missing ID, someone else's file path, a reserved username) is refused, verifies **AC-8**.
- Auth/permission: a real account cannot call `submit_visitor_application`, an anonymous session cannot upload outside its own folder, past the file cap or to the other buckets, no client can read `visitor-documents`, and no client can call the claim functions or set `bound_account_id`, verifies **AC-8**, **AC-9**, **AC-13**.
- Auth/permission: an account that types the same email or phone as someone's application does not get it, only the phone that sent it can attach it, verifies **AC-12**.
- Failure case: a claim with a taken username leaves the row approved and unclaimed, a person who is already a seller is not changed, and two claims at once give one winner, verifies **AC-13**.
- Regression: a buyer who picks Store owner lands in the buyer area with the right notice for each state, and a seller sees the toggle while a buyer does not, verifies **AC-1**, **AC-4**.
- Regression: signed in applications, signing up and the existing suites still pass, and deleting an account removes the attached application's files and rows, verifies **AC-14**, **AC-15**.

## Build plan

Build approach: none recorded in `AGENTS.md` or the scope header, so this plan assumes thin end to end slices (Tracer Bullet): the backend first, then one thin thread through the app (area and login routing), then the visitor wizard.

1. Write and apply `supabase/migrations/0007_visitor_applications.sql`: the column changes, constraints and the replaced indexes, the `visitor-documents` bucket and policies (with the file cap), the widened select policy, `submit_visitor_application`, `find_claimable_application`, `claim_seller_application`, the visitor branch and username check of `approve_seller_application`, and the replaced `merge_anonymous_identity` that attaches visitor rows. Replace `submit_seller_application` in the same migration so it writes `submitter_id` and `origin` and counts attached rows in its open rule (otherwise it fails once `submitter_id` is required). Confirm in the database that each exists and that existing rows keep working, satisfies **AC-8**, **AC-9**, **AC-10**, **AC-11**, **AC-12**, **AC-13**
2. Add `supabase/checks/visitor_applications.sql` (same style as the 0013 checks) covering submit, retry, each named unique index and the refusal it maps to, validation and path rules, phone format, the file cap, the bucket and table permissions including a real account and `anon`, approve and reject on a visitor row, the attach step with a skipped conflict, and every claim outcome including a second call and a taken username. Update the 0013 checks for the new column and re run them with the 0012 checks, satisfies **AC-8** to **AC-13**, **AC-15**
3. Add the Edge Function `supabase/functions/claim-seller-application/` (token check like `delete-account`, find, copy the logo to its fixed destination, treating an existing one as done, then the claim) with its logic in a small module free of Deno imports and a test against fake clients. Confirm the Storage `copy` between two buckets works with the service role, satisfies **AC-13**
4. Remove `apps/seller` (folder, workspace entry, tests, docs mentions) and any client `become_seller()` call, satisfies **AC-6**
5. Area state and the store area: the device preference, the area provider (role and memory), a `/store` route with the placeholder screen, and the toggle in `AppShell` and the store area for sellers only, satisfies **AC-3**, **AC-4**, **AC-5**
6. Login routing and the claim triggers: make the Buyer or Store owner choice reach the router, call the claim after every real sign in before routing, and also on launch, on resume and when the Seller application screen opens or refreshes (only while the role is buyer), and show the notice for a non seller who chose Store owner with an action to the Seller application screen, satisfies **AC-1**, **AC-2**, **AC-13**
7. Visitor application: wire "Apply now" on the landing and login screens, add the visitor methods to the repository (mock and Supabase), the "About you" step with the country picker phone field, uploads to `visitor-documents`, and the confirmation screen, satisfies **AC-7**
8. Extend `supabase/functions/_shared/delete_user_data.ts` to read the paths of the account's applications (attached or claimed), remove their `visitor-documents` files, delete those rows, and only then run the rest of the cleanup, satisfies **AC-14**
9. Run `flutter analyze` and every test suite, then the SQL checks on a test database, and save the manual checks (anonymous upload outside the folder and past the cap, a real account uploading to `visitor-documents`, a real sign up on the same phone then an approval and a claim, a claim on another device attached by hand) in `verify.md`, satisfies **AC-15**

## Consequences

**Positive**:
- One install and one login for both roles, which matches the shared onboarding in the Figma file.
- The sign in, the toggle and the "Apply now" link already exist as screens, so most of the app work is wiring.
- No handoff between two apps and no second sign in for sellers.
- One review list and one set of approve and reject functions for both kinds of application.
- Attaching by the phone's own anonymous session means nobody can take another person's application by typing their email or phone, and approval is the only manual action for the admin on the normal path.

**Negative / tradeoffs**:
- A new write path open to people with no account: anyone can start an anonymous session and upload photos and submit. The brakes are the one open rule per session, email and phone, a 12 file and 5 MB cap per session and Supabase's anonymous sign in rate limit, and there is no captcha.
- Visitor contact details are not verified when sent, so the admin must confirm them before approving.
- ID photos and contact details of people who may never sign up are kept until the retention job runs (30 days after a decision), a duty to protect them and a reason to check local data protection rules before launch. Until that job exists nothing enforces the 30 days, so it is a launch requirement.
- A person who applies on one phone and signs up on another is not attached automatically, the admin attaches the application by hand.
- Every buyer downloads the (currently empty) store area code, and one release carries both audiences. This reverses spec 0011's rejected "one app, two roles" option, on purpose.
- Approval of a visitor application changes nothing for the person until their account is attached and the claim runs, so approval alone does not make anyone a seller.
- More schema: `applicant_id` becomes optional, three unique indexes and several checks guard the two row shapes, and `merge_anonymous_identity` gets a new job.

**Neutral**:
- The 0013 task 6 seller app gate and AC-10 are replaced by AC-1 to AC-5 here. 0013 tasks 1 to 5, 7 and 8 and AC-1 to AC-9, AC-11 and AC-12 stand.
- `become_seller()` stays on the server, still open to clients. Closing it remains the launch blocker in 0013.
- The Buyer | Store owner choice on the login is now read by the app. Sign up has no such choice, a new account is always a buyer.

## Follow-up

- [ ] **Launch requirement**: build the retention job that deletes rejected and approved but unclaimed visitor applications, and their files, 30 days after the decision, and also sweeps folders in `visitor-documents` that no row points to. Decide how it runs (a scheduled Edge Function or `pg_cron`).
- [ ] Decide a stale rule for visitor applications still in `reviewing` for a long time, and for attached ones whose account was never approved.
- [ ] Review local data protection rules and write a short notice for the people who send an application without an account.
- [ ] Add a captcha or a stricter rate limit to `submit_visitor_application` if spam shows up.
- [ ] Add a note to 0011 (the separate seller app is gone), to 0012 AC-7 (no seller app sign in) and to 0013 (task 6 and AC-10 replaced), and update the scope: 0013 milestone "Seller app gate" and the seller backend rows. `/sync` should then update `supabase/AGENTS.md`, `lib/features/onboarding/AGENTS.md` and the root `AGENTS.md`.
- [ ] Design the store area's real screens and scope the seller features (products, reels, orders) as their own rows and specs.
- [ ] Notify the applicant when an application is approved or rejected (spec 0013's notifications row). Until then the admin contacts them by hand.
- [ ] Consider an automatic attach for a person who signs up on a different device than the one that applied, using Clerk verified contacts on both the email and the phone. Left out now because matching on contact details alone can hand an application to the wrong person.
- [ ] Confirm the Storage `copy` call between two buckets with the service role before building task 3.

## Migration plan

**Strategy**: no migration needed for the app, an additive and ordered change for the table. The table change is one migration that the current buyer build keeps working with, then the app changes follow.

**Phases**:
1. Apply `0007` in one transaction, in this order: add `origin` (default `'account'`), `submitter_id` and `bound_account_id` as nullable, backfill `submitter_id` from `applicant_id`, set `submitter_id` not null, drop the not null on `applicant_id`, add the check constraints, then replace the two partial unique indexes. In the same migration replace `submit_seller_application` and `merge_anonymous_identity`, so the buyer build from spec 0013 and the current sign in keep working throughout.
2. Ship the app changes (tasks 4 to 7) after the migration is live and the SQL checks pass. The claim Edge Function is deployed before the app that calls it.
3. Remove `apps/seller` and its Clerk bundle ids last, once nothing opens it.

**Rollback**: before any visitor row exists, drop the new functions, policies, bucket and columns, restore `applicant_id` as not null and the two old partial unique indexes, and restore the 0006 `submit_seller_application` and the earlier `merge_anonymous_identity`. After a visitor row exists the rollback must delete or fix those rows first, because they have no `applicant_id`.

**Risks**:
- Forgetting to replace `submit_seller_application` in the same migration breaks account applications the moment `submitter_id` becomes required.
- Existing test and fixture rows that insert into `seller_applications` without `submitter_id` fail after the migration, so the 0013 SQL checks are updated alongside.
- The visitor path is new and open to anonymous sessions, so watch for spam in the first weeks.
