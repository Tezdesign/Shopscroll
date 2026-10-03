# Scope: Shopscroll (repo wide)

Work that spans the buyer app, the seller app and the shared package. Buyer features live in
`../buyer/scope.md`. See `AGENTS.md` for the stack.

## At a glance

| # | Feature | Phase | Status |
|---|---------|-------|--------|
| 16 | Monorepo restructure | Unplanned | in-progress |
| 17 | Seller backend sync | Unplanned | planned |

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

### 17. Seller backend sync · planned · needs a decision

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
