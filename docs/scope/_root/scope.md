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
| 21 | Seller application notifications | Unplanned | planned |

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
  - [ ] Buyer data layer, Seller application screen and four step wizard (AC-6, AC-8, AC-9)
  - [ ] Seller app gate: waiting, blocked and apply screens, no `become_seller()` call (AC-10)
  - [ ] Account deletion removes files, then the full test run (AC-5, AC-11, AC-12)
- [ ] Verify it: `/check verify seller application request`
- [ ] Test it: `/test seller application request`

Spec [0013](../../specs/_root/0013-seller-application-request/index.md) · code in `supabase/migrations/0006_seller_applications.sql`, `supabase/checks/seller_applications.sql`

### 20. Seller application admin dashboard · planned · needs a decision

An admin screen or page to list applications, open the ID files with a signed link, and approve or reject by calling
the spec 0013 functions, with a proper admin role instead of the service role.
**Done when:** an admin can review and decide an application without the SQL editor (see the spec once it exists).
- [ ] Design it (spec): `/architect seller application admin dashboard`
- [ ] Build it: `/develop seller application admin dashboard`
- [ ] Verify it: `/check verify seller application admin dashboard`
- [ ] Test it: `/test seller application admin dashboard`

From spec [0013](../../specs/_root/0013-seller-application-request/index.md)

### 21. Seller application notifications · planned · needs a decision

Tell the applicant in the app and by email when an application is approved or rejected.
**Done when:** an applicant gets a notification and an email on each decision (see the spec once it exists).
- [ ] Design it (spec): `/architect seller application notifications`
- [ ] Build it: `/develop seller application notifications`
- [ ] Verify it: `/check verify seller application notifications`
- [ ] Test it: `/test seller application notifications`

From spec [0013](../../specs/_root/0013-seller-application-request/index.md)
