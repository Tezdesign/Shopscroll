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

## Deleting an account

`_confirmDeleteAccount` in `profile_screen.dart` invokes the `delete-account` Edge Function, which
removes the Clerk user through the Backend API and this app's rows in one call, and then signs out
locally. It deliberately does **not** call `ClerkAuthState.deleteUser()`:

- **It cannot work on `clerk_auth` 0.0.18-beta** (the newest release as of 2026-09-21).
  `Api._delete` calls `_tokenCache.clear()` — wiping the client token, session id and client id, and
  deleting them from the persistor — and only then builds its headers, which attach `Authorization`
  `if (_tokenCache.hasClientToken)`. The request therefore goes out unauthenticated and Clerk
  answers `401 signed_out`. It clears the credentials before the request that needs them.
- The same helper **swallows every failure**: a non-200 or a thrown error is logged and dropped,
  `deleteUser()` ignores the result, and nothing reaches the error stream, so a failed delete looks
  exactly like a successful one. The screen checks `authState.isSignedIn` after the call and raises
  its own error when the session survived, since that is the only signal available.
- It also needs `delete_self` on in the instance (User & Authentication → account actions), or the
  package raises "You are not authorized to delete your user" without calling Clerk at all.

Clerk deletion on its own does **not** clean up Supabase, which is why `delete-account` does both.
`supabase/functions/clerk-webhook` still matters for deletions started elsewhere (the Clerk
dashboard, the Backend API), where the app never sees the event; both share
`functions/_shared/delete_user_data.ts`. Neither works until deployed with its secrets set, and
`delete-account` needs `--no-verify-jwt` since it verifies the caller itself.

Governing spec: `docs/specs/buyer/0005-profile-screen/index.md`.

_Drafted by /sync from the introducing change, worth a quick human pass._
