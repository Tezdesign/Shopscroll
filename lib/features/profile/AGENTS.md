# lib/features/profile

The real Profile tab (spec 0005), replacing the empty placeholder `/profile` used to fall back to.

## Files

- `profile_screen.dart` (`ProfileScreen`) — the signed-in page: header (avatar, name, stores-followed
  count, Become a seller, Edit profile), then `_SettingsSection` groups of `SettingsRow`
  (`lib/shared/widgets/settings_row.dart`) for Generals / Help / Legal, plus Log out and Delete
  account rows. Every row for a feature that doesn't exist yet in this buyer-only app opens
  `ComingSoonScreen` rather than doing nothing.
- `profile_anonymous_view.dart` (`ProfileAnonymousView`) — shown at the same `/profile` route for an
  anonymous session: a short sign-in message and a button into `/welcome` (the onboarding flow, see
  `lib/features/onboarding/AGENTS.md`) — not a direct link to Clerk's prebuilt card, every entry into
  sign in/up goes through the same onboarding screens.
- `edit_profile_screen.dart` (`EditProfileScreen`) — name/username/bio form (`AppTextField`), inline
  validation for blank fields and a taken username via
  `UserProfileRepository.updateUserProfile`'s `UsernameTakenException`.

`app_router.dart`'s `/profile` route picks `ProfileScreen` vs `ProfileAnonymousView` via
`ClerkAuthBuilder`'s `signedInBuilder`/`signedOutBuilder`, falling back to the old `ComingSoonScreen`
placeholder only when Clerk isn't configured at all (no `ClerkAuth` ancestor to read).

Governing spec: `docs/specs/0005-profile-screen/index.md`.

_Drafted by /sync from the introducing change, worth a quick human pass._
