# Scope: Shopscroll (repo wide)

Work that spans the buyer app, the seller app and the shared package. Buyer features live in
`../buyer/scope.md`. See `AGENTS.md` for the stack.

## At a glance

| # | Feature | Phase | Status |
|---|---------|-------|--------|
| 16 | Monorepo restructure | Unplanned | in-progress |
| 17 | Seller backend sync | Unplanned | dropped |
| 18 | Seller access rules | Unplanned | in-progress |
| 19 | Seller application request | Unplanned | in-progress |
| 20 | Seller application admin dashboard | Unplanned | planned |
| 21 | Seller application notifications | Unplanned | in-progress |
| 22 | Shared login and store area | Unplanned | in-progress |
| 23 | Visitor application retention job | Unplanned | planned |
| 24 | Seller product creation | Unplanned | in-progress |
| 25 | Seller application admin email | Unplanned | in-progress |
| 26 | Applicant in app decision notice | Unplanned | planned |

## Features

### 16. Monorepo restructure · in-progress

Move the buyer app to `apps/buyer`, extract the shared code (theme, neutral widgets, models, thin backend
helpers) into `packages/shared`, join them with a Dart workspace, and scaffold an empty seller app in
`apps/seller`. Docs and specs get `_root`, `buyer` and `seller` subfolders.
**Done when:** both apps run from their own folders, all existing buyer tests still pass from the new
location, the shared package has its own tests, and the seller app starts with the shared theme.
- [x] Design it (spec): `/architect monorepo restructure`
- [x] Build it: `/develop monorepo restructure`
- [ ] Verify it: `/check verify monorepo restructure`
- [ ] Test it: `/test monorepo restructure`

Spec [0011](../../specs/_root/0011-monorepo-buyer-seller-apps.md) (a decision only spec, `/develop` derives the steps) · code in `apps/buyer`, `apps/seller`, `packages/shared`, `pubspec.yaml` (workspace root)

### 17. Seller backend sync · dropped

Design how the buyer and seller Supabase projects stay in step through Edge Functions: which data flows which
way (products, reels, orders, delivery status, messages), how a function proves who is calling, retries,
conflict rules, and how a seller's Clerk account links to the store row buyers see.
**Done when:** a product or post created in the seller project shows in the buyer app, and an order placed in
the buyer app shows in the seller project, with failures handled (see the spec once it exists).
- [ ] Design it (spec): `/architect seller backend sync`
- [ ] Build it: `/develop seller backend sync`
- [ ] Verify it: `/check verify seller backend sync`
- [ ] Test it: `/test seller backend sync`

From spec [0011](../../specs/_root/0011-monorepo-buyer-seller-apps.md)

Dropped: spec [0012](../../specs/_root/0012-one-backend-seller-role/index.md) uses one Supabase project and one Clerk
instance for both apps, so there is nothing to sync.

### 18. Seller access rules · in-progress

Use one Supabase project and one Clerk instance for both apps: lock the profile `role` and counters, add
`become_seller()`, let sellers write their own catalog rows, and move `supabase/` to the repo root.
**Done when:** a buyer can become a seller from the same account, a seller can add their own products and reels, a
client cannot set its own role, and all buyer, shared and seller tests still pass.
- [x] Design it (spec): `/architect seller access rules`
- [ ] Build it: `/develop seller access rules`
  - [x] Audit live seller rows and move `supabase/` to the repo root (AC-1, AC-8)
  - [ ] Buyer sign in change and migration `0004` with `become_seller()` and seller write rules (AC-3, AC-4, AC-5)
  - [ ] Seller app sign in and profile creation (AC-7)
  - [ ] Migration `0005` locking profile columns, after the new buyer build is the only one in use (AC-2)
  - [ ] SQL checks and the full test run (AC-2, AC-4, AC-5, AC-6)
- [ ] Verify it: `/check verify seller access rules`
- [ ] Test it: `/test seller access rules`

Spec [0012](../../specs/_root/0012-one-backend-seller-role/index.md) · code in `supabase/`, `apps/buyer/lib/core/auth/`, `apps/seller/lib/`

### 19. Seller application request · in-progress

A buyer applies to become a seller from Profile, Settings, Seller application (four step form with ID photo upload). An
admin approves or rejects with service role only functions, and only approval turns on `role = 'seller'` and copies
the store details onto the profile. The seller app lets in approved sellers only.
**Done when:** a buyer can submit an application with files and see its status, an approved one becomes a seller who
can sign in to the seller app, a rejected or reviewing one cannot, and all buyer, shared and seller tests still pass.
- [x] Design it (spec): `/architect seller application request`
- [ ] Build it: `/develop seller application request`
  - [ ] Migration `0006` (table, functions, buckets, rules) and SQL checks (AC-1 to AC-7)
  - [x] Buyer data layer, Seller application screen and four step wizard (AC-6, AC-8, AC-9)
  - [ ] Seller app gate: waiting, blocked and apply screens, no `become_seller()` call (AC-10)
  - [x] Account deletion removes files, then the full test run (AC-5, AC-11, AC-12)
- [ ] Verify it: `/check verify seller application request`
- [ ] Test it: `/test seller application request`

Spec [0013](../../specs/_root/0013-seller-application-request/index.md) · code in `supabase/migrations/0006_seller_applications.sql`, `supabase/checks/seller_applications.sql`, `apps/buyer/lib/features/seller_application/`

### 20. Seller application admin dashboard · planned · needs a decision

An admin screen or page to list applications, open the ID files with a signed link, and approve or reject by calling
the spec 0013 functions, with a proper admin role instead of the service role.
**Done when:** an admin can review and decide an application without the SQL editor (see the spec once it exists).
- [ ] Design it (spec): `/architect seller application admin dashboard`
- [ ] Build it: `/develop seller application admin dashboard`
- [ ] Verify it: `/check verify seller application admin dashboard`
- [ ] Test it: `/test seller application admin dashboard`

From spec [0013](../../specs/_root/0013-seller-application-request/index.md)

### 21. Seller application notifications · in-progress

Tell the applicant by email when an application is approved or rejected, through Mailjet. An approval says what to do
next: a new person creates an account with the email they applied with, a person with an account opens the Profile tab
and uses the Buyer or Store owner switch. A rejection carries the admin's reason. Approved visitor applications now also
find their account through the account's Clerk verified email, and signed in applicants get an optional personal email
field. The in app notice is feature 26.
**Done when:** every approval or rejection sends one email to the applicant within about a minute, a visitor who signs up
with the application email on any phone becomes a seller, a failed email retries and never blocks a decision, and all
suites still pass.
- [x] Design it (spec): `/architect seller application notifications`
- [ ] Build it: `/develop seller application notifications`
  - [x] Migration `0012`, the trigger, the retry job, the attach by email functions and SQL checks (AC-1, AC-2, AC-6 to AC-10, AC-13): applied and all SQL checks pass on a local test database, not applied to the shopscroll project yet
  - [x] The decision email module and the `notify-applicant-decision` function (AC-1 to AC-6, AC-12, AC-13): code and tests pass, not deployed yet
  - [x] The claim function attaches by Clerk verified email (AC-9, AC-10): code and tests pass, not deployed yet
  - [x] The optional personal email field in the signed in form (AC-8)
  - [ ] Setup notes, `verify.md` and the full test run (AC-1 to AC-11, AC-14)
- [ ] Verify it: `/check verify seller application notifications`
- [ ] Test it: `/test seller application notifications`

Spec [0017](../../specs/_root/0017-applicant-decision-email/index.md) · code in `supabase/migrations/0012_applicant_notification.sql`, `supabase/checks/applicant_notification.sql`, `supabase/functions/notify-applicant-decision/`, `supabase/functions/claim-seller-application/`, `supabase/functions/_shared/` (`applicant_email.ts`, `clerk_emails.ts`), `apps/buyer/lib/features/seller_application/` · from spec [0013](../../specs/_root/0013-seller-application-request/index.md)

### 22. Shared login and store area · in-progress

One login for buyers and store owners. The Buyer or Store owner choice picks the area after Log in: the buyer area, or a
store area inside the same app that only approved sellers can enter, with a toggle between them. A person with no account
can send a seller application from "Apply now", and it attaches to the account whose Clerk verified email or phone matches
what they typed, so every signed in person sees only their own applications. The separate seller app is removed.
**Done when:** a buyer who picks Store owner lands in the buyer area with a notice, an approved seller reaches the store
area and can toggle, a visitor can apply and later become a seller after signing up with the email or phone they typed and being
approved, every signed in person sees only their own applications, `apps/seller` is gone, and all suites still pass.
- [x] Design it (spec): `/architect for the shared login`
- [ ] Build it: `/develop shared login and store area`
  - [x] Migration `0007` and SQL checks (AC-8 to AC-13, AC-15)
  - [ ] Claim Edge Function (AC-13)
  - [x] Remove `apps/seller`, area state and store area, login routing and claim triggers (AC-1 to AC-6, AC-13)
  - [x] Visitor application: Apply now, About you step, uploads, confirmation (AC-7)
  - [ ] Account deletion cleanup, then the full test run (AC-14, AC-15)
  - [ ] Attach by Clerk verified contact: migration `0013`, SQL checks, the claim function and the phone fix (AC-10, AC-12, AC-13, AC-16, AC-17, tasks 10 to 16)
- [ ] Verify it: `/check verify shared login and store area`
- [ ] Test it: `/test shared login and store area`

Spec [0014](../../specs/_root/0014-shared-login-seller-area/index.md) · replaces the seller app gate of feature 19 (spec 0013 task 6 and AC-10) · code in `apps/buyer/lib/core/area/`, `apps/buyer/lib/features/seller_application/`, `supabase/migrations/0007_visitor_applications.sql`, `supabase/migrations/0013_attach_by_verified_contact.sql`, `supabase/checks/` (`visitor_applications.sql`, `detach_unclaimed_attached.sql`), `supabase/functions/claim-seller-application/`, `supabase/functions/_shared/` (`claim_seller_application.ts`, `clerk_contacts.ts`, `delete_user_files.ts`)

### 23. Visitor application retention job · planned · needs a decision

Delete rejected and approved but unclaimed visitor applications, and their files, 30 days after the decision, and sweep
uploads in `visitor-documents` that no application points to. A launch requirement of feature 22.
**Done when:** nothing a visitor sent is kept more than 30 days after a decision, and orphan uploads are removed (see the
spec once it exists).
- [ ] Design it (spec): `/architect visitor application retention job`
- [ ] Build it: `/develop visitor application retention job`
- [ ] Verify it: `/check verify visitor application retention job`
- [ ] Test it: `/test visitor application retention job`

From spec [0014](../../specs/_root/0014-shared-login-seller-area/index.md)

### 24. Seller product creation · in-progress

A seller creates, publishes and manages products from the store area: a three step flow (Basics, Price and stock,
Preview) with photos, color and size variants that each have a price and stock, drafts saved to the server, a Products
list with quick edit, Create similar, and Fill from photos using Claude. Orders take stock off the right variant at the
right price.
**Done when:** an approved seller can publish a product with variants from their phone and see it in the buyer app, a
buyer pays the picked variant's price and cannot buy a sold out size, drafts survive closing the app, and all suites
still pass.
- [x] Design it (spec): `/architect seller product creation`
- [ ] Build it: `/develop seller product creation`
  - [ ] Migration `0008` with variants, drafts, `save_product`, storage and SQL checks (AC-2, AC-4, AC-6, AC-7, AC-11, AC-12, AC-16): written and checked on a local Postgres, not yet applied to a Supabase project
  - [x] Shared models, repositories and the buyer side price, cart and Saved changes (AC-9, AC-18, AC-19)
  - [x] The flow end to end: photos, variants, autosave, details, Preview and Publish (AC-1 to AC-8, AC-15, AC-17)
  - [x] Products list, quick edit and live edit (AC-11, AC-12)
  - [ ] Migration `0009` stock and variant price in `place_order` (AC-10, AC-19): written and checked on a local Postgres, not yet applied to a Supabase project
  - [ ] Fill from photos and Create similar, then the full test run (AC-13, AC-14, AC-1 to AC-19): the app side and the function logic are done and tested, migration `0010` and the function deploy are not yet done
- [ ] Verify it: `/check verify seller product creation`
- [ ] Test it: `/test seller product creation`

Spec [0015](../../specs/_root/0015-seller-product-creation/index.md) · code in `supabase/migrations/0008` to `0010`, `supabase/checks/`, `supabase/functions/autofill-product/`, `apps/buyer/lib/features/seller_products/`, `packages/shared/lib/models/` · needs the seller shell (header, tab bar, Home, Activity, Profile) for its final entry points

### 25. Seller application admin email · in-progress

Every new seller application (from an account or from "Apply now" with no account) is emailed to the admin through
Mailjet. The email has the store and contact details and one private link to a review page, where the admin sees the ID
photos through links that expire in minutes and approves or rejects (reject asks for a reason). Failed emails retry
by themselves.
**Done when:** a new application sends one email within about a minute, the link shows the application and its photos,
Approve and Reject decide it through the existing functions, an expired or used link is refused, a Mailjet failure
retries and never blocks an application, and all suites still pass.
- [x] Design it (spec): `/architect seller application admin email`
- [ ] Build it: `/develop seller application admin email`
  - [x] Migration `0011`, the trigger, the retry job, the token table and SQL checks (AC-1, AC-3, AC-9, AC-11, AC-12, AC-13): applied to the shopscroll project (on its own, `0008` to `0010` are still pending there) and all SQL checks pass there and on a local Supabase Postgres
  - [x] Mailjet email module and the `notify-admin-application` function (AC-1, AC-2, AC-3, AC-9, AC-10, AC-11, AC-13): code and tests pass, not deployed yet
  - [x] The `review-application` function and the token decision in SQL (AC-4 to AC-8, AC-11, AC-13): code and tests pass, not deployed yet
  - [x] The review page on Cloudflare Pages (AC-4 to AC-8): written and checked in a browser against a fake function, not deployed yet
  - [ ] Setup notes, `verify.md` and the full test run (AC-1 to AC-9, AC-14)
- [ ] Verify it: `/check verify seller application admin email`
- [ ] Test it: `/test seller application admin email`

Spec [0016](../../specs/_root/0016-seller-application-admin-email/index.md) · code in `supabase/migrations/0011_admin_notification.sql`, `supabase/checks/admin_notification.sql`, `supabase/functions/notify-admin-application/`, `supabase/functions/review-application/`, `supabase/functions/_shared/`, `web/admin-review/` · next to features 20 (admin dashboard, which can replace the review page) and 21 (applicant notices)

### 26. Applicant in app decision notice · planned · needs a decision

Show an approved or rejected applicant a notice inside the app (for example a one time message on the next open), next to
the email from feature 21. Needs a seen flag per application.
**Done when:** an applicant sees one notice per decision in the app (see the spec once it exists).
- [ ] Design it (spec): `/architect applicant in app decision notice`
- [ ] Build it: `/develop applicant in app decision notice`
- [ ] Verify it: `/check verify applicant in app decision notice`
- [ ] Test it: `/test applicant in app decision notice`

From spec [0017](../../specs/_root/0017-applicant-decision-email/index.md)
