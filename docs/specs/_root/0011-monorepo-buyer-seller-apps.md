# 0011. Organise the buyer and seller apps as one monorepo with a shared package

**Date**: 2026-10-02
**Status**: Accepted

> Partly superseded by [0012](0012-one-backend-seller-role/index.md): the two Supabase projects, two Clerk instances and Edge Function sync below are replaced by one shared Supabase project and one Clerk instance. The folder layout and shared package decisions here still stand.

## Summary

The seller app will live in the same Git repository as the buyer app, in its own folder, not in a separate repository or a copied folder. The buyer app moves to `apps/buyer`, the new seller app goes in `apps/seller`, and the code both need (theme, shared widgets, data models, thin backend setup helpers) moves into one Dart package, `packages/shared`. Dart's built in workspace feature ties the three together, so one person can change shared code once and both apps pick it up. Each app keeps its own Supabase project and its own sign in, as you chose, and how the two databases stay in step is a separate decision.

## Context

> ⚠️ Premise note: you chose two fully separate Supabase projects joined by Edge Functions (small server side functions). The seller services you named, tracking deliveries, messaging clients and posts, all have a buyer on the other end: a buyer places the order the seller tracks, receives the message the seller sends, and watches the post the seller publishes. With two databases, every one of those becomes a copy job that can lag, fail or disagree, and a single developer then owns two sets of tables, two sets of row level rules, two migration histories and the sync code between them. One Supabase project with sellers as a role (the `role` column already exists) would avoid all of that. You kept the separate setup, so this spec supports it, and the cost is written into Consequences. Treat the sync as the riskiest part of the plan.

This topic also spans more than one decision. This spec settles only the folder and code sharing structure. The cross backend sync (which data moves which way, how a function proves who is calling, what happens on conflict, how a seller account links to the store row buyers see) needs its own spec, and the seller features themselves (delivery tracking, messaging, posts) need their own scope rows.

Today the buyer app is one Flutter project at the repository root: 130 Dart files under `lib/`, with theme tokens, shared widgets, data models, repositories and the Supabase and Clerk wiring all inside it. Sellers already exist as rows in `user_profiles`, but there is no seller flow yet. The owner is a single developer who will build and release both apps. The seller app has the same branding as the buyer app but different services, and it is a Flutter mobile app. There is no continuous integration setup and no monorepo tooling in the repository, so nothing blocks a new layout.

If nothing is decided, the seller app would start as a copy of the buyer project. The two copies of the theme, widgets and models would drift apart, and every fix to shared code would have to be made twice.

## Options considered

### Option 1: One repository, one shared package, native Dart workspaces

The repository holds `apps/buyer`, `apps/seller` and `packages/shared`, joined by a workspace root `pubspec.yaml`. Both apps depend on the shared package by path.

**Pros**:
- One change to the theme, a widget or a model reaches both apps at once.
- No extra tool: workspaces are built into Dart, and there is one lock file and one resolved set of dependency versions.
- One repository, one issue list, one place for docs, which suits one developer.

**Cons**:
- Moving the buyer app touches every path, the iOS and Android projects, `env.json`, the docs and the comments that mention `lib/...`.
- Both apps must agree on one version of each shared dependency, including the beta Clerk packages.
- A bad change in the shared package can break both apps, so both test suites must run.

### Option 2: Two repositories, shared code as a Git dependency

The seller app is a new repository. Shared code is published from a third repository, or from the buyer one, and both apps pull it by Git reference.

**Pros**:
- Hard isolation and fully independent release history.
- Nothing about the buyer app has to move.

**Cons**:
- Every shared change needs a commit, a version bump and an update in both apps before it is seen, which is slow for one person.
- Three repositories to keep in order, and the shared package cannot be tried in an app without publishing it.

### Option 3: One app, two roles

The seller experience lives inside the existing app, behind the "Become a seller" button, with the interface switching on the account's role.

**Pros**:
- One project, one install, no sharing problem at all.

**Cons**:
- Every buyer downloads seller code, and one release gates both audiences.
- It does not fit separate backends and separate sign in, and a separate store listing is not possible.
- You said the seller app is its own product with different services.

### Option 4: One repository, shared package by plain path dependency, no workspace

Same folders as Option 1, but each app keeps its own `pubspec.lock` and points at the shared package with a normal `path:` dependency. There is no workspace root.

**Pros**:
- Each app resolves its own versions, so the apps could use different Clerk or Riverpod versions.
- Nothing new to learn, and it works with any Flutter version.

**Cons**:
- Three lock files and three `flutter pub get` runs, and shared dependency versions can quietly drift apart.
- No single place that resolves the whole repository, so version conflicts show up later, in one app at a time.

## Decision

**Chosen option**: Option 1: One repository, one shared package, native Dart workspaces

Move the buyer app to `apps/buyer`, create the seller app in `apps/seller`, extract the shared code into `packages/shared`, and join them with a Dart workspace.

## Rationale

The deciding forces are one developer, shared branding, and a seller app that reuses the buyer app's models and look. With one person, the cost that matters is the number of places a change has to be made. A monorepo with a shared package gives one place for shared code and one repository to manage, and workspaces need no tool beyond Dart itself. Option 2 gives isolation that a single developer does not need and charges for it on every shared change. Option 3 cannot work with separate store listings, backends and sign in. Option 4 is the closest rival: it lets the two apps hold different dependency versions. Workspaces win because one lock file and one resolution catch version conflicts at once, and with one person upgrading everything together is a feature. The cost is lockstep versions. If that starts to hurt, for example when the two Clerk setups need different package versions, switching to Option 4 is a small change (give each app its own lock and a `path:` dependency).

Moving the buyer app to `apps/buyer` is the heavier choice. Keeping it at the root would have been less disruptive, but you chose the symmetric layout, and it is a one time cost: with `git mv` the file history stays intact, and doing it first, before the seller app exists, keeps the move simple. The risk is path churn, so the move is a pure refactor that must leave all 406 existing tests passing.

The shared package is limited by one rule: code goes in only if it needs nothing from either app, only Flutter, the packages the shared package itself lists (image and SVG loading, Supabase, Clerk, Riverpod for the wiring helpers), the theme, other shared widgets and shared models. Anything that needs buyer logic stays in the buyer app. This keeps the dependency direction one way, apps depend on shared and never the reverse, and the two apps never import each other.

You asked to share the backend and sign in setup as well. With two Supabase projects and two Clerk instances, the values and the identity flows differ, so only the thin wiring is shared: generic builders that take a project address and key as inputs. The buyer's anonymous browsing and the merge into a real account (`AuthSessionController`, `merge_anonymous_identity`) are buyer only and stay in the buyer app. The seller app requires sign in and has no anonymous mode.

## Proposed stack

| Layer | Choice | Reason |
|---|---|---|
| Repository | One Git repository, the existing `Tezdesign/Shopscroll` | One developer, one place for code and docs. |
| Layout | `apps/buyer`, `apps/seller`, `packages/shared`, workspace root `pubspec.yaml` at the repo root | Symmetric, and it makes the dependency direction visible. |
| Workspace tooling | Native Dart pub workspaces, each member sets `resolution: workspace` | Built in, one lock file, no extra tool to maintain. |
| Shared package | `packages/shared`, package name `shopscroll_shared` | Holds theme tokens, neutral shared widgets, data models and thin backend wiring helpers. |
| Buyer app | Today's app moved with `git mv` to `apps/buyer`, with its own `env.json` and `supabase/` folder | Keeps its behaviour and its own backend. |
| Seller app | New Flutter app in `apps/seller`, iOS and Android only, display name "Shopscroll Seller", iOS bundle id `com.marketplaceapp.shopscrollSeller`, Android application id `com.marketplaceapp.shopscroll_seller` | Own store listing and identity, same pattern as the buyer ids. |
| Backend | Two Supabase projects. The seller project gets `apps/seller/supabase/` for its own migrations and Edge Functions | Your choice, with the cost recorded below. |
| Identity | Two Clerk instances, the seller app requires sign in | Matches the separate backends. Linking a seller account to the store row buyers see belongs to the sync spec. |
| Cross backend sync | Edge Functions, designed in a separate spec | Too large to settle here. |
| State and routing | Riverpod and go_router in both apps | Same as the buyer app today, so one set of habits. |
| Docs | One `docs/` folder at the root with `specs/` and `scope/` split into `_root`, `buyer` and `seller` subfolders | One place to look, shared decisions have a home in `_root`. |
| Config and secrets | One `env.json` and `.env.example` per app, never shared | Each app has its own Supabase and Clerk values. |

**Rules the layout must keep**:
- Apps depend on `shopscroll_shared`. Shared depends on no app. Apps never import each other.
- Code moves to shared only if it needs nothing from either app: Flutter, the packages the shared package lists, the theme, other shared widgets or shared models. Known buyer only code that stays in the buyer app: `shipping_items_section.dart` (imports `features/cart/cart_logic.dart`), `add_to_cart_toggle.dart`, `checkout_sheet.dart`, `checkout_section.dart`, `payment_option_row.dart`, `delivery_method_tile.dart`, and the models `cart_item.dart`, `saved_product.dart`, `saved_reel.dart`, `place_order_request.dart`. The rest is sorted by the rule during extraction.
- Assets used by shared widgets move into the shared package and are referenced with the `package` argument, so they resolve from both apps.
- Row mappers, repositories and providers stay in each app, because the two backends differ. Shared models are the contract both apps read, and seller only models live in the seller app.
- Tests move with the code they cover: shared widget and model tests go to `packages/shared/test`, and the buyer tests stay with the buyer app. Both suites must pass before a shared change is merged.

## Consequences

**Positive**:
- Theme, widgets and models are written once, so the apps keep the same branding without effort.
- One repository, one issue list and one docs tree for one developer.
- The extraction happens before the seller app exists, so the buyer app stays the only thing at risk during the move.

**Negative / tradeoffs**:
- Two Supabase projects mean two schemas, two sets of row level rules, two migration histories and sync code that must be built, monitored and kept correct by one person. Deliveries, messages and posts can lag or disagree between the two databases.
- A seller account has no row in the buyer project until the sync creates one, so the store page, product listing and chat all depend on the sync working.
- The move touches every path, the iOS and Android projects, the docs, existing context files and the comments that say `lib/...`. The iOS project uses Swift Package Manager (there is no Podfile), so after the move `ios/Flutter/Generated.xcconfig` and `ios/Flutter/ephemeral`, which hold absolute paths, must be regenerated by a clean build.
- `git mv` does not move untracked files. `env.json` is gitignored and must be moved by hand, `.gitignore` paths must be updated, and the moved `pubspec.lock`, `build/` and `.dart_tool/` must be deleted because the workspace keeps one lock file at the root.
- The seller app needs its own Clerk setup per bundle id: redirect URLs, plus Google and Apple sign in if used. The Supabase CLI link inside `supabase/` moves with the folder and must be set again for each of the two projects.
- Both apps share one resolved set of dependency versions, so they upgrade together, including the beta Clerk packages.
- A shared package change can break both apps, and the one lock file means a version bump affects both.

**Neutral**:
- Existing buyer specs move under `docs/specs/buyer` with their numbers kept. Spec numbers stay unique across the whole repository, whatever folder a spec lives in, so references like "spec 0010" keep working. This spec keeps `0011` and moves to `docs/specs/_root` during that reorganisation. Links that say `docs/specs/...` need updating in the same pass.
- Commands now run from an app folder (`flutter run` inside `apps/buyer`), not from the repository root.
- Repo wide files stay at the root: `analysis_options.yaml` (each package includes it), `design.md`, `README.md`, `skills-lock.json`, `test-preferences.json`, `.agents/`, `.claude/` and `graphify-out/`.
- The buyer's existing web, Linux, macOS and Windows folders move with the buyer app and are left as they are. The seller app has only iOS and Android.

## Follow-up

- [ ] Design the cross backend sync as its own spec, next: which tables flow which way (products, reels, orders, delivery status, messages), how an Edge Function proves who is calling, retries and replays, conflict rules, and how a seller's Clerk account links to the store row buyers see.
- [ ] Revisit the two project choice after the sync spec. Keep the sync boundary narrow, and note a trigger to reconsider one Supabase project if the sync becomes the main source of bugs.
- [ ] No web check was made for this spec. During the scaffold, confirm the current Dart workspace and Flutter behaviour (the `resolution: workspace` setting, one lock file, regenerated iOS files after the move) against the official docs before relying on it. Also check that a shared package with assets works from both apps.
- [ ] Enroll scope features for the restructure and for the seller services (delivery tracking, messaging, posts). The parked buyer to store chat decision now has a seller side that it must account for.
- [ ] After the move, `/sync` should update the root and nested `AGENTS.md` paths (they say `lib/...`) and add context files per app. Ask `/audit` to bootstrap `apps/seller` the same way.
- [ ] Add continuous integration later, running both app suites and the shared package suite, once the layout settles.
