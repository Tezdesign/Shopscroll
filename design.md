# Shopscroll — Design System Reference

Source of truth: Figma file **ShopScroll-UI** (`toOakybJ0DaJmU7vcEC0AW`), page **"The design - user"**.
Cross-checked against `lib/core/theme/app_theme.dart` via Figma's `get_variable_defs` on the Home,
Product details, Cart, Discover, Reels, Profile, Order confirmation, and Log in frames, 2026-07-14.
There is no separate `app_typography.dart` — typography lives inside `app_theme.dart` alongside colors,
spacing, and radius.

This file documents what the tokens mean and where they're used. For the audit log (what was compared,
what matched, what was fixed, what's still open), see the end of this document.

## Color palette

All hex values below are confirmed against Figma's real variables unless marked *(interpolated)* — a
step in a ramp no sampled screen actually binds to a variable, so the code's value is a reasonable but
unverified guess between confirmed neighbors.

### Primary (brand blue)

| Token | Hex | Used for |
|---|---|---|
| `primary50` | `#D9E8FD` | Lightest tint — chip/badge backgrounds |
| `primary100` | `#BFD9FF` | Disabled button fill/text |
| `primary200` *(interpolated)* | `#80B3FF` | — |
| `primary300` *(interpolated)* | `#408CFF` | — |
| `primary400` | `#0066FF` | Brand blue — primary buttons, active tab, links, section-title accent |
| `primary500` | `#004FC6` | Pressed/dark-mode primary |
| `primary600` *(interpolated)* | `#00388C` | — |

### Secondary (orange) — unverified, see audit log

| Token | Hex | Used for |
|---|---|---|
| `secondary100`–`secondary600` | `#FFDABF`…`#8C3B00` | Deals/promo accents *(interpolated — no `Secondary/*` Figma variable was found bound anywhere sampled; the closest real Figma color is `Colours/Stroke/Brand 1/Default` = `#FF5C02`, close to but not identical to `secondary400` = `#FF6B00`. Flagged, not auto-changed — see audit log)* |

### Accent (purple) — unverified

| Token | Hex |
|---|---|
| `accent100`–`accent600` | `#DDBBFF`…`#45008A` *(interpolated, no Figma variable observed)* |

### Neutral (grayscale) — fully confirmed

| Token | Hex | Figma variable |
|---|---|---|
| `neutral100` | `#FFFFFF` | `Colors/Neutral/100` |
| `neutral200` | `#E8E8E8` | `Colors/Neutral/200` |
| `neutral300` | `#D2D2D2` | `Colors/Neutral/300` |
| `neutral400` | `#BBBBBB` | `Colors/Neutral/400` |
| `neutral500` | `#A4A4A4` | `Colors/Neutral/500` |
| `neutral600` | `#8E8E8E` | `Colors/Neutral/600` |
| `neutral700` | `#777777` | `Colors/Neutral/700` |
| `neutral800`/`neutral900` | `#606060`/`#4A4A4A` | *(interpolated)* |
| `neutral1000` | `#333333` | `Colors/Neutral/1000` |
| `neutral1100` | `#000000` | `Colors/Neutral/1100` |
| `neutralAlpha50` | `#80333333` | `Colors/Neutral/Alpha/50` (`#33333380`) — confirmed equal |

### Status colors — confirmed where sampled

| Token | Hex | Figma variable |
|---|---|---|
| `error400` | `#FA0000` | `Colors/Error/400` |
| `error500` | `#C20000` | `Colors/Error/500` |
| `error100`/`200`/`300`/`600` | — | *(interpolated)* |
| `success400` | `#00CC66` | `Colors/Success/400` |
| `success50`/`100`/`200`/`300`/`500`/`600` | — | *(interpolated)* |
| `warning100`–`600` | — | *(interpolated, no Figma variable observed)* |

### One-off paint styles — confirmed

| Token | Hex | Figma source |
|---|---|---|
| `blackAlpha10` | `#EAE9EA` | `Black / Black 10` |
| `blackAlpha20` | `#D4D4D5` | `Black / Black 20` |
| `blackAlpha40` | `#ABA9AB` | `Black / Black 40` |
| `white100` | `#FEFEFE` | `White / White 100` |
| `labelSecondary` *(new)* | `#993C3C43` | `Labels/Secondary` — iOS system secondary-label gray (60% alpha black); used across most screens for muted/secondary text |
| `barBorder` *(new)* | `#4D000000` | `Miscellaneous/Bar border` — black at 30% alpha, hairline borders under bars |

Not yet added: `Colors/Blue` (`#007AFF`, plain iOS system blue) — seen once in the "Product" review frame,
role unconfirmed, needs a designer check before it earns a token.

## Typography system

Two font families, both bound as real Figma variables:

- **Inter** — body/UI text (`fontFamilyBody`). Figma variables `Inter/<size>/<weight>`.
- **Plus Jakarta Sans** — display/heading text (`fontFamilyDisplay`). Figma variables are named
  `GeneralSans/<size>/<weight>`, but the font resource each one actually binds to is Plus Jakarta Sans,
  not a typeface called General Sans — that's a naming/binding mismatch inside the Figma file itself.
  Code follows the real bound font.

Neither font is bundled as an asset yet — see "Open follow-ups" below.

### Size/weight/line-height scale (confirmed identical to Figma for every size sampled)

| Role | Family | Size | Weight | Line height | Where used |
|---|---|---|---|---|---|
| `displayLarge` | Display | 36 | 600 | 1.25 | Largest headings (unused so far) |
| `displayMedium` | Display | 30 | 600 | 1.25 | Large headings (unused so far) |
| `displaySmall` | Display | 24 | 600 | 1.5 | Screen-level headings (Cart, Order confirmation titles) |
| `headlineLarge` | Display | 20 | 600 | 1.5 | Section headers, e.g. Home's "Shopscroll" title |
| `headlineMedium` | Body | 18 | 700 | 1.5 | Sub-headers |
| `headlineSmall` | Body | 16 | 700 | 1.5 | Sub-headers |
| `titleLarge` | Display | 18 | 600 | 1.5 | Two-tone section titles ("Big deals", "Most visited stores") |
| `titleMedium` | Body | 16 | 600 | 1.5 | Card/row titles |
| `titleSmall` | Body | 14 | 600 | 1.25 | Tab labels, chip labels |
| `bodyLarge` | Body | 16 | 400 | 1.5 | Long-form copy (product description) |
| `bodyMedium` | Body | 14 | 400 | 1.25 | Standard body text |
| `bodySmall` | Body | 12 | 400 | 1.25 | Fine print |
| `labelLarge` | Body | 14 | 500 | 1.25 | Button labels |
| `labelMedium`/`labelSmall` | Body | 12 | 500 | 1.25 | Captions, store names, badges |

Note: Figma itself uses two different weights at size xl/20 for heading-like roles (SemiBold on Home's
title, Bold on Reels/Discover/Log in headers) — `headlineLarge` currently only captures the SemiBold
case. Not a bug, just a nuance worth knowing if a Reels/Discover heading looks a step lighter than Figma.

## Spacing & radius

| Token | Value | Figma | Note |
|---|---|---|---|
| `AppSpacing.xs` | 4 | *(interpolated)* | See naming note below |
| `AppSpacing.sm` | 8 | `Spacing/Gap/XS`, `Spacing/Padding/S` (both = 8) | |
| `AppSpacing.md` | 12 | *(interpolated)* | |
| `AppSpacing.base` | 16 | *(interpolated)* | |
| `AppSpacing.lg` | 20 | *(interpolated)* | |
| `AppSpacing.xl` | 24 | *(interpolated)* | |
| `AppRadius.md` | 8 | `Radius/M` | confirmed |
| `AppRadius.sm` | 4 | *(interpolated)* | |
| `AppRadius.full` | 999 | — | pill/circle hack, see code comment |

**Naming note** (see audit log): Figma's own smallest named spacing variable, `Gap/XS`, equals **8**, the
same value the code calls `sm`. The numbers (4, 8, 12, 16, 20, 24) are accurate; only the tier names
drift from Figma's naming. Flagged as a recommended rename, not applied automatically (touches every
call site in `lib/`) — see audit log.

## Components already built

All in `lib/shared/widgets/`, each reproducing one named Figma component:

| Component | Figma source | Intended usage |
|---|---|---|
| `ProductCard` | "Product card" (big/medium variants) | Grid/row tiles with image, store, title, price, color swatches, add-to-cart |
| `ProductInfoCard` | Home's compact 4-up tile | Trending row on Home — no price/swatches/cart, just seller + media + description |
| `ItemCard` | "Item card" | Cart rows (quantity stepper + delete) and My-collection rows (saved/bookmark) |
| `AppButton` | "Button" (8 variants) | Primary/secondary × big/small × enabled/disabled actions |
| `AppIcon` | "Icons" set (32 glyphs) | Central glyph registry, mapped to the closest Material icon per glyph |
| `AppBottomNavBar` | "tabbar-user"/"tabbar-seller" | 5-tab bottom nav: Home, Discover, Reels, Activity, Profile |
| `CategoryChip` | "Order-satus-category" | Selectable filter chip with optional leading icon |
| `SearchField` | "Search Field" | Interactive search input, or a tap target that routes to a search screen (`readOnly`+`onTap`) |
| `SegmentedTabs` | recurring underline-tab pattern (Discover, Activity, My collection, Messages, Profile) | Underlined tab row; `distribution` picks the real per-screen layout (compact/spaceBetween/equal) |
| `SizeSelector` | "Sizes available" chips | Product details — pick a size variant |
| `SpecTable` | "Table" | Product details — key/value spec rows (Material, Fit type, Size) |
| `AddToCartToggle` | "add to cart" | Standalone icon(+label) toggle next to the quantity stepper on Product details |
| `InfoRow` | icon+text row | "Fast delivery in 1-2 days", "100% authentic product", Profile's website/address lines |
| `MostVisitedItem` | "Most Visited Item" | Home's "Most visited stores" shortcut tile |
| `NotificationTimeLabel` | "Notification time" | Timestamp label ("Now", "2h") on the Notifications screen |
| `OrderStatusBadge` | "Order-satus" | Activity screen's order-status pill (Delivered/In progress/Canceled) |

Screens built so far: `HomeScreen` and `ProductDetailScreen` (`lib/features/catalog/`). `cart/`,
`profile/`, and `reels/` are empty scaffold directories — no screens built there yet.

## Open follow-ups

1. **Bundle the real fonts.** Add Inter and Plus Jakarta Sans (both free, e.g. via Google Fonts) under
   `assets/fonts/` and declare them in `pubspec.yaml`'s `flutter: fonts:` section. Until then, the
   corrected `fontFamilyBody`/`fontFamilyDisplay` values name the right fonts, but Flutter falls back to
   the platform default because neither is actually bundled.
2. **Confirm the secondary/accent color ramps.** No `Secondary/*` or `Accent/*` Figma variable was found
   bound anywhere in the 8 screens sampled — the values in code were reverse-engineered from raw pixel
   sampling, per the existing code comment. Worth a designer pass, starting from the one real data point
   found: `Colours/Stroke/Brand 1/Default` = `#FF5C02`.
3. **Rename the spacing scale** from `xs/sm/md/base/lg/xl` (4/8/12/16/20/24) to a scale whose names match
   Figma's own (`Gap/XS` = 8) and the t-shirt-scale convention (`xxs/xs/s/m/l/xl`). Numbers stay the same;
   only names change — but it touches every `AppSpacing.*` call site in `lib/`, so it's a deliberate
   follow-up, not done in this pass.
4. **Migrate opportunistically to `AppColors.labelSecondary`/`barBorder`** where a screen currently
   substitutes a solid `neutral600`/`neutral700` for what Figma actually specifies as a translucent
   label/border color — needs a visual check per call site, not a blind find-and-replace.

---

## Audit log — Figma vs. code, 2026-07-14

**Method**: Figma desktop MCP, `get_variable_defs` against 8 built screens/frames (Home, Product details,
Cart, Discover, Reels, Profile, Order confirmation, Log in) on file `ShopScroll-UI`, page "The design -
user". `get_libraries` confirmed no external library is subscribed — every variable is local to this file.
`search_design_system` returned nothing (it only searches subscribed libraries, and none exist here), so
coverage is whatever each sampled screen actually uses, not the full token set — that's why several ramp
steps above are marked *(interpolated)*.

**Confirmed matches** (code already correct): the full sampled `Neutral` ramp, `Error/400`+`500`,
`Success/400`, all three `Black/Black *` aliases, `White/White 100`, `Neutral/Alpha/50`, `Radius/M`, and
the entire numeric type scale (every size/weight/line-height pair sampled lines up exactly).

**Fixed in this pass** (`lib/core/theme/app_theme.dart`):
- `fontFamilyBody`: `'SF Pro Text'` → `'Inter'` — no Figma variable anywhere named or bound to SF Pro Text.
- `fontFamilyDisplay`: `'Poppins'` → `'Plus Jakarta Sans'` — no Figma variable anywhere named or bound to
  Poppins; the actual bound font behind the `GeneralSans/*` variables is Plus Jakarta Sans.
- Added `AppColors.labelSecondary` and `AppColors.barBorder` — real Figma tokens (iOS label gray, bar
  hairline) that had no code equivalent at all.

**Flagged, not auto-fixed** (needs a human call, listed under "Open follow-ups" above): the
secondary/accent color ramps' authenticity, the spacing-scale naming, and per-call-site migration to the
two new color tokens.

### Why these fixes, not others

Per Don Norman's **consistency** principle (*The Design of Everyday Things*): a design system's power
comes from one name always meaning one value, everywhere — the moment code and design drift on what
`fontFamilyDisplay` *is*, every screen built from it silently drifts from the source of truth, and that
compounds. The confirmed font mismatch was the one case here where the code's value flatly didn't exist
anywhere in Figma's real tokens, so it was corrected directly. Marina Budarina's *UI Design Systems
Mastery* (the referenced PDF) makes the same point concretely: tokens only work if "we use identical
names for tokens, only raw value changes" (p.99), and a scale with an inconsistent naming tier "turns
into a mess" once someone needs a size in between (p.162) — which is exactly the spacing-scale drift
flagged above. The secondary/accent ramps and the spacing rename were left as flagged follow-ups rather
than silent rewrites because neither has the same level of evidence behind it (no variable in Figma
confirms the exact values), and a rename with no visual bug behind it carries real risk (every call site
in `lib/` would need to change) for a purely cosmetic-naming win — better surfaced for a deliberate,
reviewed pass than auto-applied.
