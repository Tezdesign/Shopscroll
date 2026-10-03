# Verify: Supabase backend · spec 0003 · updated 2026-08-01

_This spec is a decision record (ARCHITECTURE mode), not a feature with IDed acceptance criteria, so
these steps are derived from its Data model, Security model, and Consequences sections instead of
AC-N tags. `/check verify` runs these; `/test` locks the durable ones._

## Setup (one time, in the Supabase dashboard)

- [ ] Run `supabase/schema.sql` in full against a brand new project's SQL editor → 9 tables exist,
  no errors → matches "Proposed stack"/"Data model"
- [ ] Authentication > Providers > turn on "Allow anonymous sign-ins" → matches "Configuration required"

## Commands

- [ ] `flutter pub get` → resolves `supabase_flutter: ^2.16.0` cleanly
- [ ] `flutter analyze` → no issues
- [ ] `flutter test` → all existing tests pass unchanged, with zero `--dart-define` set (proves the
  mock repository fallback still works exactly as before) → matches "repository interface, keeps mock
  swappable for tests"

## UI / manual (once `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...` is set)

- [ ] `flutter run` with both dart-defines set → app boots to Home screen, products/reels/sellers load
  from the live Supabase tables (not the 300ms mock delay) → matches "Decision"
- [ ] Quit and relaunch the app twice in a row → the same anonymous user persists (check
  `auth.users` in the dashboard: row count does not grow per launch) → matches the anonymous session
  reuse fix in "Consequences"
- [ ] Cart and orders screens show empty for a fresh anonymous session (no seed data exists for
  owned tables by design) → matches "Seed data" note in `index.md`
- [ ] In the dashboard, try inserting a row into `products` as the `anon` role directly (not via
  service role) → rejected, since no insert policy exists → matches "Security model"

## Not yet coverable

- Any RLS check that needs two distinct real user sessions (e.g. "user A cannot read user B's
  orders") needs an actual second anonymous session to test against; do this manually once the app
  is run twice on two devices/simulators, or defer to a future integration test suite.
