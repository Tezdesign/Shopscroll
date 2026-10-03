# 0003. Adopt Supabase as the backend — rationale

## Context

The app (`AGENTS.md`: "buyer side only, no seller flows yet") has never had a real backend. Every
screen reads mock data from `lib/data/mock/*` through Riverpod providers that add an artificial
300ms delay to stand in for a network round trip. The models (`Product`, `Reel`, `UserProfile`,
`CartItem`, `Order`) already carry `fromJson`/`toJson`/`copyWith`, written in advance for a real API
that never existed until now.

The engineer asked directly for Supabase: a standalone SQL file to create the tables, and the
connection code wired into the app. Two forces shape this beyond "which BaaS": first, the app has no
login screen at all, so `CartItem` and `Order`, both inherently per person, have nobody to belong to
yet; second, `Reel.isSaved` and `Reel.likeCount` are currently flat columns on the reel itself, which
was never really correct once more than one person can like or save the same reel. Both were resolved
during the design conversation: anonymous auth gives every install a real, stable identity without a
login screen, and likes/saves become their own per-user relations.

## Options considered

### Option 1: Supabase (managed Postgres + Auth)

A managed Postgres database with an instant REST/Realtime API, built in auth (including anonymous
sign in), and an official Flutter SDK.

**Pros**:
- Relational by default, and this app's data is genuinely relational (orders reference products
  reference stores; reels tag many products)
- Anonymous auth closes the exact gap this project has: real per-user ownership with no login UI
- Official `supabase_flutter` SDK handles session persistence, realtime, and deep link callbacks
- The schema itself is plain Postgres; leaving Supabase later means dumping a portable database, not
  rewriting a proprietary data model

**Cons**:
- Some vendor specific surface (Auth internals, Realtime, the generated REST API) is not portable
  even though the schema is
- A hosted dependency: uptime, quotas, and pricing now apply where nothing did before

### Option 2: Firebase (Firestore + Auth)

A mature, widely used mobile BaaS with its own real anonymous auth and generous free tier.

**Pros**:
- Anonymous auth exists here too, and the mobile SDKs are mature
- Very large community and documentation base

**Cons**:
- Firestore is a document store; this app's data is clearly relational, so modeling `orders` →
  `order_items` → `products` → `stores` in Firestore means manual denormalization and no real foreign
  keys or joins, fighting the natural shape of the data instead of matching it

### Option 3: Self-hosted Postgres behind a hand-rolled API

A Postgres instance on a small VM or platform (Render, Fly), fronted by a REST or GraphQL API the
team writes and hosts itself.

**Pros**:
- Full control, zero vendor lock-in of any kind

**Cons**:
- The team would now operate a database, write and host an API server, and build authentication from
  scratch, all at once, for a project that currently has no backend infrastructure of any kind. Rolling
  your own auth in particular is a well known failure pattern (session fixation, token storage, refresh
  rotation are each a potential breach) with no reason here to accept that risk

### Option 4: Another BaaS (Appwrite or PocketBase)

Open source, self-hostable alternatives; Appwrite has relational-ish collections, PocketBase runs on
SQLite.

**Pros**:
- Open source, avoids a specific vendor
- PocketBase in particular is extremely simple to self host for a small project

**Cons**:
- Neither has a Flutter SDK as polished or as widely used as `supabase_flutter`
- Smaller community and less mature managed hosting than Supabase, for no offsetting benefit here

## Rationale

The engineer specified Supabase directly, and independent evaluation agrees it is the right fit, not
just the requested one. The app's data is relational (a product belongs to a store, a reel tags many
products, an order is made of line items that reference products), which is exactly what Postgres is
for and exactly what a document store like Firestore fights. Supabase's anonymous auth is the load
bearing detail: it gives `cart_items` and `orders` a real, database-enforced owner (`auth.uid()`) on
day one, without requiring a login screen this project does not have yet, and it upgrades to real auth
later (`linkIdentity`) without a data migration. Self-hosting (Option 3) was rejected because it asks
the team to stand up a database, an API layer, and an auth system simultaneously, for a project that
currently has none of the three; that is a lot of new operational surface to accept for control nobody
asked for. The cost accepted with Supabase is some vendor-specific surface in Auth and Realtime, offset
by the fact that the schema itself is ordinary Postgres and the app's data access sits behind a
repository interface, so both the backend and the data layer stay swappable if that cost is ever worth
paying to leave.

## References

**Project sources**:
- `AGENTS.md`, the "No real backend" rule this decision replaces
- Installed community skills `supabase` and `supabase-postgres-best-practices`
  (`.agents/skills/supabase/`, `.agents/skills/supabase-postgres-best-practices/`)

**Practices & standards**:
- Row Level Security as the enforcement point for per-user data, not application-level filtering alone
- Anonymous auth as a zero friction path to a stable user id before real login exists
- The repository pattern, for a swappable data access layer

**Links**:
- Supabase Flutter quickstart: https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- `supabase_flutter` on pub.dev: https://pub.dev/packages/supabase_flutter
- Dart client initialization reference: https://supabase.com/docs/reference/dart/initializing
- Anonymous sign in reference: https://supabase.com/docs/reference/dart/auth-signinanonymously
- Anonymous auth guide (enabling it in the dashboard): https://supabase.com/docs/guides/auth/auth-anonymous
- RLS performance guidance: https://supabase.com/docs/guides/database/postgres/row-level-security#rls-performance-recommendations
