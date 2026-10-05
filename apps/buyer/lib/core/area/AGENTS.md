# lib/core/area

The one app with two areas (spec 0014): the buyer area every person has, and a store area (`/store`) that only a
person with `role = 'seller'` stays in. There is no separate seller app any more.

## Files

- `app_area.dart` — `AppArea` (`buyer`, `store`); `signedInUserIdProvider` (the Clerk id, or null for a visitor; set by
  `AuthSessionController`, and seeded in `main.dart` for a restored session); `isSellerProvider` (profile role is
  seller, false while loading or on failure); `signInSettledProvider` (a `Future` that completes when the work a sign in
  starts has finished: merge, client switch, profile row, claim); `AreaNotice` and `areaNoticeFor(applications)` (the
  notice a non seller sees after choosing Store owner); `areaNoticeProvider` (set by Log in, shown once by `AppShell` as a
  snack bar with an action to the Seller application screen).
- `landing_after_sign_in.dart` — `landingAfterSignIn`, the pure rule for where Log in lands: Buyer opens the buyer area,
  Store owner opens the store area only for a seller, otherwise the buyer area plus a notice. A failed lookup counts as
  "not a seller", so sign in never fails because of it.
- `seller_claim.dart` — `SellerClaim.claim()` calls the `claim-seller-application` Edge Function (see
  `supabase/AGENTS.md`) and never throws. It skips visitors and sellers, and refreshes the cached profile when it
  returns `claimed: true`.

## Conventions

- Routing to the store area is a convenience only. The server rules (seller write policies from spec 0012) check `role`
  on every write.
- The area last used is remembered as `last_area` in `OnboardingPrefs` (`lib/core/onboarding/onboarding_prefs.dart`) and
  cleared on sign out. It is only a memory: `StoreAreaScreen` (`lib/features/store/`) sends a non seller to the buyer
  area, and clears the memory for a buyer but keeps it when the profile merely failed to load.
- The claim runs after every real sign in (inside `AuthSessionController`, before `signInSettledProvider` completes),
  on app resume (`MarketplaceApp`), and when `sellerApplicationsProvider` loads (the Seller application screen opening
  or refreshing). Log in routing awaits `signInSettledProvider`, so an approved applicant who signs in as Store owner
  reaches the store area in one pass.
- The Buyer or Store owner toggle is `lib/shared/widgets/account_type_toggle.dart`, used by Log in and by
  `AreaToggle` (`lib/features/store/area_toggle.dart`). `AppShell` shows `AreaToggle` only to a seller and only on a
  tab's own screen (the cart, search and other pushed screens do not show it).

Governing spec: `docs/specs/_root/0014-shared-login-seller-area/index.md`.

_Drafted by /sync from the introducing change, worth a quick human pass._
