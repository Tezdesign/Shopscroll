# 0013. Require a reviewed seller application before a person becomes a seller

**Date**: 2026-10-03
**Status**: In Progress

> Partly replaced by [0014](../0014-shared-login-seller-area/index.md): AC-10 and build plan task 6 (the seller app gate) are replaced by the shared login and the store area inside the buyer app. A person with no account can also apply (0014). Everything else here still stands.

## Summary

A buyer who wants to sell sends a seller application from the buyer app (Profile, Settings, Seller application). They fill a four step form (store details, public contact and logo, documents, review) and upload an ID photo. An admin approves or rejects it for now by running a database function with the service role. Only approval turns the person into a seller and copies the store details onto their profile. The seller app lets in only approved sellers and shows a waiting or blocked screen to everyone else. The review is only real once the open `become_seller()` function from spec 0012 is closed, which stays a launch blocker below.

## Requirements

**User stories**:
- As a buyer, I want to apply to become a seller from my profile settings so that I can open a store with my existing account.
- As an applicant, I want to see whether my application is reviewing, approved or rejected, and why, so that I know what to do next.
- As the admin, I want to approve or reject an application and have the store set up from it so that only people I checked can sell.
- As the developer, I want the application, its files and the decision kept in the one Supabase project so that there is no sync code (spec 0012).

**Acceptance criteria** (the contract, each one independently checkable):
- **AC-1**: `submit_seller_application` creates a `seller_applications` row with `status = 'reviewing'` for the caller's own id. It refuses an anonymous session (`no_session`), a caller with no profile row (`no_profile`) and a caller whose profile is already `role = 'seller'` (`already_seller`). Calling it again with the same `p_id` by the same person returns that row's id and changes nothing (this check runs first, before `already_open` and `already_seller`, and only matches the caller's own rows). Two submits at the same moment still end in one row and a documented error, never a raw database error.
- **AC-2**: A person can have only one `reviewing` application. A second submit with a new id is refused (`already_open`). After a rejection they can submit again.
- **AC-3**: Submit validates on the server. `store_name` is 2 to 60 characters, `username` is 3 to 30 characters of lowercase letters, digits, `_` and `.`, and `location` is not empty (`invalid_field`). The username must not belong to another profile or to another reviewing application (`username_taken`). `id_document_path` is required (`missing_document`). Each file must exist in the right bucket at an exact path: the logo as `<sub>/<name>` in `store-logos`, the documents as `<sub>/<p_id>/<name>` in `application-documents`, where `<sub>` is the caller's id. The ID and business paths must differ (`file_not_found` or `invalid_field`).
- **AC-4**: A signed in client can read only its own application rows. No client can insert, update or delete `seller_applications` rows directly. `anon` has no access.
- **AC-5**: Storage rules hold. In `store-logos` (public read) a signed in real account can add files only under its own id folder. In `application-documents` (private) it can add and read files only under its own id folder. In neither bucket can a client update or delete a file, and an anonymous session cannot add files to either. Both buckets accept only JPEG and PNG up to 5 MB. Nobody else can read another person's documents.
- **AC-6**: `approve_seller_application` runs only with the service role. It sets `status = 'approved'`, `reviewed_at` and `reviewed_by`, copies `store_name` (to `name`), `username`, `bio`, `location`, `website_url`, `contact_phone` (to `phone`), `contact_email` (to `email`) and the logo (to `avatar_url`) onto the applicant's profile, and sets `role = 'seller'`, in one transaction. An empty optional field overwrites the profile value with null, so the private email and phone copied from the sign in account never become public. It refuses an application that is not `reviewing` (also when two decisions run at the same moment), refuses with `already_seller` if the profile is already a seller, and refuses with `username_taken` if the username was taken since, leaving the application `reviewing`. A signed in client calling it is refused.
- **AC-7**: `reject_seller_application` runs only with the service role. It requires a non empty reason, sets `status = 'rejected'`, `rejection_reason`, `reviewed_at` and `reviewed_by`, and leaves the profile unchanged. A signed in client calling it is refused.
- **AC-8**: In the buyer app, Settings has a "Seller application" row (and the existing "Become a seller" button opens the same screen). The screen shows the empty state ("No applications yet" and "Submit an application"), or the list. Each list row shows the store name, "Submitted dd/mm/yyyy" and a status chip (Reviewing, Approved, Rejected, with the reason for Rejected). "Submit a new application" shows only when the person's profile role is `buyer` and they have no `reviewing` application. A person whose role is already `seller` sees a note that they are a seller and no button. The list is read when the screen opens and on pull to refresh. An anonymous visitor is sent to sign in.
- **AC-9**: The form is a four step wizard with a progress bar: store details, public contact and logo, documents, review and submit. Each step validates before Next, Back keeps what was typed, photos come from `image_picker` (JPEG or PNG, resized to a max width of 1600 and quality 85, and a file still over 5 MB is refused on the phone with a message), and submit is called only after every upload succeeded. A failed upload or submit shows a retry and a double tap sends one application. The ID photo is required, the business registration and logo are optional.
- **AC-10**: The seller app routes by the signed in person's state. Role `seller` enters the app. A `reviewing` application shows a waiting screen. A latest application that is `rejected` (and role not seller) shows a blocked screen with the reason. No application shows a screen telling them to apply in the Shopscroll app. The role is the source of truth for entry. The seller app no longer calls `become_seller()` on sign in, and still creates the profile row without `role`.
- **AC-11**: Deleting an account also deletes that person's `seller_applications` rows and every file under their id folder in both storage buckets, including files in sub folders and files no application points to. Files are otherwise kept while the account exists.
- **AC-12**: `flutter analyze` is clean and the buyer, shared and seller test suites pass, and the seller application avatar rule (a path becomes a public URL) does not change how existing full URL avatars render.

## Decision

**Chosen option**: Option 1: An applications table, files in Supabase Storage, and a server side review that only the service role can complete

A person sends an application through one database function. The admin decides with two functions that only the service role can run, and approval is the only step in this feature that sets `role = 'seller'`.

**Implementation skills**: `supabase` (`supabase/agent-skills`, `.agents/skills/supabase/`) · `supabase-postgres-best-practices` (`supabase/agent-skills`, `.agents/skills/supabase-postgres-best-practices/`)

## Feature design

Design source for the screens: Figma file ShopScroll-UI, canvas "The design - seller", flow header "Profile-seller": Settings 3001:9443 (the "Seller application" row), empty state 3001:9520, list with status 3001:9544. The four wizard steps are not in Figma. They are built from the existing onboarding screens and shared widgets (`AppTextField`, `AppButton`), and the design should be reviewed once they exist.

**Data model**:

`seller_applications` (user_profiles 1 to N seller_applications, at most one `reviewing`)

| Column | Type | Rule |
|---|---|---|
| `id` | uuid, primary key | supplied by the client (also names the file folder), makes submit safe to retry |
| `applicant_id` | text, not null | foreign key to `user_profiles.id`, `on delete cascade` |
| `status` | text, not null | `reviewing`, `approved` or `rejected`, default `reviewing` |
| `store_name` | text, not null | 2 to 60 characters |
| `username` | text, not null | `^[a-z0-9_.]{3,30}$` |
| `bio` | text | optional, up to 280 characters |
| `location` | text, not null | not empty |
| `website_url`, `contact_phone`, `contact_email` | text | optional, public contact |
| `logo_path` | text | optional, path in `store-logos` |
| `id_document_path` | text, not null | path in `application-documents` |
| `business_document_path` | text | optional, same bucket |
| `rejection_reason` | text | required when `status = 'rejected'` (check constraint) |
| `reviewed_at`, `reviewed_by` | timestamptz, text | set on a decision, `reviewed_by` is a free text admin name, optional |
| `created_at` | timestamptz, not null | default `now()` |

Indexes: partial unique on `(applicant_id)` where `status = 'reviewing'`, partial unique on `(username)` where `status = 'reviewing'`, plain index on `applicant_id`.

Storage: bucket `store-logos` (public read) and bucket `application-documents` (private), both limited to `image/jpeg` and `image/png`, 5 MB. File paths: logo `<sub>/<random>.<ext>`, documents `<sub>/<application id>/id-<random>.<ext>` and `<sub>/<application id>/business-<random>.<ext>`, where `<sub>` is the Clerk user id. Every upload attempt uses a new random name, so a retry or a replaced photo never overwrites a file (clients cannot update or delete). The applications table stores the exact paths. For the logo, approval stores the bucket relative path `store-logos/<sub>/<random>.<ext>` in `avatar_url`, and the app turns any `avatar_url` that does not start with `http` into a public URL with the Storage client, because SQL does not know the project URL.

**State transitions**: `reviewing` to `approved`, or `reviewing` to `rejected`. Both are final for that row. A new application is a new row.

**API surface**:

| Function or call | Kind | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| `submit_seller_application` | database function | `p_id` uuid, `p_store_name`, `p_username`, `p_location`, `p_bio`, `p_website_url`, `p_contact_phone`, `p_contact_email`, `p_logo_path`, `p_id_document_path`, `p_business_document_path` | application id | signed in real account | `no_session`, `no_profile`, `already_seller`, `already_open`, `invalid_field`, `username_taken`, `missing_document`, `file_not_found` |
| select on `seller_applications` | table read | none | caller's own rows, newest first | signed in | none (empty list) |
| `approve_seller_application` | database function | `p_id` uuid, `p_reviewed_by` text (optional) | none | service role only | `not_found`, `not_reviewing`, `username_taken` |
| `reject_seller_application` | database function | `p_id` uuid, `p_reason` text, `p_reviewed_by` text (optional) | none | service role only | `not_found`, `not_reviewing`, `reason_required` |
| upload to `store-logos`, `application-documents` | Storage API | file, path | stored path | signed in, own folder | permission denied, size or type refused |

Refusals are raised as the whole error message (the `place_order` convention), and the app maps them to friendly text.

**Key invariants**:
- `role` becomes `'seller'` only inside `approve_seller_application`, or `become_seller()` while that stays open.
- One `reviewing` application per person, and one `reviewing` application per username.
- The profile is changed only on approval. A rejection never touches it.
- A file path stored on an application matches the exact path rules in AC-3, so one person cannot point at another person's file or at a file in the wrong bucket.
- A decision is made once: approve and reject lock the row (`select ... for update`) and re-check `status = 'reviewing'`.
- Submit maps a unique violation (by constraint name) to `already_open` or `username_taken`, and finds an existing row for the same `p_id` and caller before any other check.
- Approval copies the application onto the profile, so the person's public name and username become the store's. This is the cost of one profile for both roles (spec 0012).

**Security model**: The table is readable by its owner through row level security (`applicant_id = (select auth.jwt() ->> 'sub')`), with `revoke all` on the table from `anon` and `authenticated`, then `select` granted back to `authenticated` only. All three functions are `security definer` with `search_path = ''`. `submit_seller_application` has `execute` revoked from `public` and `anon` and granted to `authenticated`. `approve_seller_application` and `reject_seller_application` have `execute` revoked from `public`, `anon` and `authenticated` and are run with the service role or from the SQL editor, so no client can call them. Storage policies on `storage.objects` compare `(storage.foldername(name))[1]` to `(select auth.jwt() ->> 'sub')` and require that the session is not anonymous (`is_anonymous` is not true), because anonymous sessions are signed in users with a Supabase uuid and would otherwise get free public file hosting. They never use `auth.uid()` or the `owner` column (both are uuid and break on a Clerk id). Both buckets allow insert only (the private bucket also select) in the own folder, with no update or delete, and `store-logos` is readable by URL, and the admin reads documents through the dashboard or a signed URL made with the service role. **Compliance scope**: the ID photo and business registration are personal data. Keep them private, never log them, never return their URLs to other users, and follow the data protection rules of the country you operate in (not a named standard here, see Follow-up).

**Failure and edge cases**:
- Anonymous session or no profile row: refused, the app shows the sign in prompt. A seller applying again: `already_seller`, the screen shows Approved.
- Upload works but submit fails, or the app closes between them: files are left in storage (no row points to them). A retry reuses the same `p_id` and uploads again under new random names. A cleanup job is a follow up.
- Two taps or a retry after a lost response: same `p_id` returns the same row.
- Username taken at submit: the form shows the error on step 1. Taken by approval time: approve refuses and the admin rejects with the reason, so the person applies again.
- Account deleted while reviewing: rows cascade, the delete function removes the files (AC-11).
- Offline or expired token during upload: the step shows a retry, and nothing is submitted until all uploads succeed.
- Admin approves twice, or approves and rejects at the same moment: the row is locked, the second call is refused (`not_reviewing`).
- Approving a person who is already a seller (for example through the open `become_seller()`): refused with `already_seller`, so their edited store profile is not overwritten.
- After approval the seller can still edit their store name and username through Edit profile (spec 0012 grants), so the review covers the first version only. An Edit profile save already in flight when approval commits can revert the copied name and bio. Both are accepted.
- Large photos: the picker resizes (max width 1600, quality 85), a file still over 5 MB is refused on the phone, and the bucket limit is the server side backstop.

**Configuration required**:
- No new environment variables. Same Supabase URL, key and Clerk key as spec 0012.
- A new dependency in `apps/buyer`: `image_picker`. iOS `Info.plist` needs `NSPhotoLibraryUsageDescription` and `NSCameraUsageDescription`. Android needs no extra permission for the picker.
- Buckets and their policies are created by the migration, not by hand.

**Critical test scenarios** (each maps to an acceptance criterion):
- Happy path: a buyer uploads files, submits, the admin approves, the profile becomes a seller with the store details, verifies **AC-1**, **AC-6**.
- Failure case: a second submit with a new id while one is reviewing is refused, a retry with the same id is not, verifies **AC-2**, **AC-1**.
- Failure case: bad input (short name, bad username, taken username, missing ID, someone else's file path) is refused, verifies **AC-3**.
- Auth/permission: a client cannot insert or update rows, read another person's rows, call approve or reject, or read another person's documents, verifies **AC-4**, **AC-5**, **AC-6**, **AC-7**.
- Failure case: approving with a username taken since leaves the application reviewing, verifies **AC-6**.
- Regression: reject keeps the profile as a buyer and allows a new application, verifies **AC-7**, **AC-2**.
- Auth/permission: a rejected person opens the seller app and is blocked, an approved one enters, a reviewing one waits, verifies **AC-10**.
- Regression: deleting an account removes applications and both buckets' files, and all existing suites pass, verifies **AC-11**, **AC-12**.

## Build plan

Build approach: none recorded in `AGENTS.md` or the scope header, so this plan uses thin end to end slices (Tracer Bullet): the backend first, then a read only buyer screen, then the form, then the seller gate.

1. Write and apply `supabase/migrations/0006_seller_applications.sql`: table, indexes, row level security and grants, the three functions, the two buckets and their storage policies. Confirm in the database that each exists. Before building any UI, test one upload with a Clerk token on a test or branch project, to confirm Storage accepts a Clerk user id as the owner, and that a wrong type, an over size file and an anonymous session are refused, satisfies **AC-1**, **AC-2**, **AC-3**, **AC-4**, **AC-5**, **AC-6**, **AC-7**
2. [x] Add `supabase/checks/seller_applications.sql` (same style as `seller_access.sql`: fixtures, fake JWTs, one NOTICE per check, rollback) covering submit, the same id retry, two submits at the same moment, the one open rule, validation and file path rules, the table and `storage.objects` permissions (including an anonymous session), approve (including empty contact fields becoming null, `already_seller` and the second approve) and reject, satisfies **AC-1** to **AC-7**
3. [x] Shared and buyer data layer: a `SellerApplication` model in `packages/shared` (`fromJson`, `toJson`, `copyWith`), a `SellerApplicationRepository` in the buyer app with a Supabase implementation and a mock implementation (the mock and Supabase convention in `AGENTS.md`), the error code mapping, and the `avatar_url` rule in the row mapper (a value that does not start with `http` becomes a public Storage URL), satisfies **AC-6**, **AC-8**
4. [x] Buyer screen: the "Seller application" row in Settings, the `/profile/seller-application` route, the empty state, the list with status chips, pull to refresh, the anonymous sign in prompt, and the "Become a seller" button opening it, built to Figma nodes 3001:9443, 3001:9520 and 3001:9544, satisfies **AC-8**
5. [x] Buyer wizard: four steps with a progress bar, validation, `image_picker` with resize, uploads then submit, retry and double tap safety, iOS permission strings, satisfies **AC-9**
6. Seller app: remove the `become_seller()` call from `SellerSessionController`, read the person's role and latest application, and add the waiting, blocked and "apply in Shopscroll" screens. Update its tests, satisfies **AC-10**
7. [x] Extend `supabase/functions/_shared/delete_user_data.ts` to remove every file under the person's id folder in both buckets, walking sub folders through the Storage API (applications cascade with the profile), and test it with a person who has files in both buckets, satisfies **AC-11**
8. [x] Run `flutter analyze` and the buyer, shared and seller test suites, then the SQL checks on a test database, and save the manual API checks (wrong type, over size, cross user read) in `verify.md`, satisfies **AC-5**, **AC-12**

## Rationale

Reasoning and options: see [rationale.md](./rationale.md).

## Consequences

**Positive**:
- Only people the admin approved can sell, and the decision, reason and files are on record.
- No sync code and no new service: the table, files and review all live in the one Supabase project.
- A client generated id makes submit safe to retry, and approval is one transaction.
- Approval and rejection are plain SQL functions, so the later admin dashboard calls them instead of redoing the logic.

**Negative / tradeoffs**:
- Until `become_seller()` is closed, any signed in person can skip the review by calling it. This is accepted for development and must be closed before launch.
- Identity documents are personal data kept for as long as the account exists, which is a long duty to protect them and a reason to review local data protection rules before launch.
- The admin has no screen yet. Review means reading files in the Supabase dashboard and running a function.
- Approval overwrites the buyer's public name and username with the store's, because there is one profile per person, and the seller can edit them afterwards.
- One store per account. The "Got more than one shop?" design is not built, and the button is hidden while an application is reviewing or approved.
- No notification on a decision, so the applicant learns the result only by opening the screen.
- New dependency `image_picker`, and a wizard whose screens have no Figma design.

**Neutral**:
- Spec 0012 AC-7's "calls `become_seller()` on first sign in" is replaced for the seller app by AC-10 here. The server function itself is unchanged.
- The Buyer | Seller toggle on the profile screen in Figma is not part of this feature.

## Follow-up

- [ ] **Launch blocker**: close `become_seller()` to clients (revoke `execute` from `authenticated`) in its own migration, so the review cannot be skipped.
- [ ] Design the admin dashboard (a reviewer role, a list with signed document links, approve and reject buttons that call these functions).
- [ ] Design in app and email notifications for approved and rejected, as you postponed them.
- [ ] Decide multiple stores per account ("Got more than one shop?"), which needs a `stores` table and reworks the spec 0012 ownership rule.
- [ ] Decide how the Buyer | Seller toggle in Figma fits spec 0011's two apps (one app with a toggle, or two apps).
- [ ] Design the four wizard steps in Figma and check them against the built screens.
- [ ] Add a cleanup job for uploaded files that no application points to.
- [ ] Review local data protection rules and write a short retention notice for the ID files before launch.
- [ ] Spec 0012 follow up: add a note there that its AC-7 is narrowed by AC-10 here, and `/sync` should record the new migration and bucket rules in `supabase/AGENTS.md`. The comment in `0005_lock_profile_columns.sql` saying `role` changes only inside `become_seller()` is stale once approval exists.
- [ ] Capture `image_picker` and Storage conventions in `apps/buyer/lib/features/profile/AGENTS.md` once built (area conventions, not root).
