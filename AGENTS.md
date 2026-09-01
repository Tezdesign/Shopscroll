# marketplace_app (Shopscroll)

A Flutter mobile marketplace/shopping app ("Shopscroll"), UI built from a Figma design file
("ShopScroll-UI"), buyer side only (no seller flows yet).

## Stack

- **Language / Runtime**: Dart, Flutter SDK ^3.12.2
- **Framework**: Flutter (Material 3, `useMaterial3: true`)
- **Key dependencies**: `flutter_riverpod` (state, v3), `go_router` (routing), `cached_network_image`, `video_player` + `chewie` (for the planned reels feature)
- **Package manager**: `flutter pub` (pub)

## Build approach

<TBD, set by /scope>

## Commands

```bash
# Install
flutter pub get

# Dev / run — needs --dart-define-from-file=env.json (see .env.example) or
# Supabase/Clerk stay unconfigured and the app silently falls back to mock
# data and ComingSoonScreen placeholders (e.g. the Profile tab looks empty).
flutter run --dart-define-from-file=env.json

# Build
flutter build <ios|apk|...> --dart-define-from-file=env.json

# Test
flutter test
```

## Specs

Stored in `docs/specs/`. Format: `docs/specs/NNNN-title.md`. None written yet.

## Rules

- No real backend: all data comes from `lib/data/mock/*` through `lib/data/providers/*`, using Riverpod `FutureProvider`/`FutureProvider.family` with an artificial delay (`network_delay.dart`, 300ms) to simulate a real `GET` round trip. Doc comments on each provider name the REST endpoint it stands in for (e.g. "as if fetched from `GET /products`") — keep that convention for new providers.
- Models (`lib/data/models/*`) carry `fromJson`/`toJson`/`copyWith` even though nothing is serialized yet, so they're ready for a real API later.
- Design tokens live in `lib/core/theme/app_theme.dart` (`AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`), sourced from the Figma file's variable collection. Never write a literal `Color(0x...)` or raw size value in a screen/widget; use the tokens.
- Screens and widgets document the Figma node they reproduce (e.g. "Figma node 791:7454") and explain any deviation from the source design in a doc comment above the widget. Follow this when adding new UI.
- Feature code lives under `lib/features/<feature>/`; only `catalog` (home + product detail) is built out. `cart/`, `profile/`, and `reels/` exist as empty scaffold directories for planned features.
- Routing is centralized in `lib/core/router/app_router.dart` (`go_router`); only `/` and `/product/:id` are registered so far.
- Shared, reusable UI lives in `lib/shared/widgets/`; screen-only one-off widgets stay private (`_Prefixed`) inside the screen file.
- Widget tests wrap the widget under test in `MaterialApp(theme: AppTheme.light, home: Scaffold(...))` for realistic styling. When a widget depends on a mock provider's artificial delay, `pump()` past `mockNetworkDelay` rather than `pumpAndSettle()`, which never settles against animating spinners or network images.
- Test files mirror the `lib/` path they cover under `test/` (e.g. `lib/shared/widgets/product_card.dart` → `test/shared/widgets/product_card_test.dart`).

## Agent skills

MCP servers: Figma (connected)
Declined: further Agent Skill / MCP discovery search

## Context files

<!-- Nested AGENTS.md files are listed here as they are created -->

_Drafted by /audit from the repo, worth a quick human pass. Edit freely: once a line stops matching this draft, later runs treat it as curated and will flag rather than overwrite it._
