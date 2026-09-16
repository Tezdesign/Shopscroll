# lib/data/repositories

The real-backend counterpart to `lib/data/mock/*` (see root `AGENTS.md`): one abstract interface per
data model (`product_repository.dart`, `reel_repository.dart`, `user_profile_repository.dart`,
`cart_repository.dart`, `order_repository.dart`), each with two implementations:

- `mock/mock_<name>_repository.dart` — reads/writes the existing in-memory mock data
  (`lib/data/mock/*`), unchanged from before this pattern existed.
- `supabase/supabase_<name>_repository.dart` — queries the real Supabase Postgres backend (see
  `supabase/AGENTS.md` for the schema/RLS side); `supabase/row_mappers.dart` holds the shared
  row-to-model mapping helpers these use.

## Wiring

`repository_providers.dart` defines one Riverpod `Provider<XRepository>` per model, **defaulting to
the mock implementation** — so the app, its widget tests, and a plain `flutter run` with no
`--dart-define` all keep working with zero setup, same as before Supabase existed. `main.dart`
overrides every provider with the Supabase-backed implementation once `SupabaseConfig.isConfigured`
(see `lib/core/auth/AGENTS.md`) and a real session exist. Screens/providers depend only on the
abstract interface, never on which implementation is active.

## Conventions

- Add a new data model here as: one abstract interface (method signatures only, doc comment naming
  both implementations), a `mock/` implementation, a `supabase/` implementation, and a provider
  override pair in `repository_providers.dart` + `main.dart` — never a single concrete class.
- Interfaces return domain models (`lib/data/models/*`), never raw Supabase rows or mock JSON.

Governing spec: `docs/specs/0003-supabase-backend/index.md`.

_Drafted by /sync from the introducing change, worth a quick human pass._
