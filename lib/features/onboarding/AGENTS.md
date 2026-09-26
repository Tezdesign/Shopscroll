# lib/features/onboarding

The first-launch flow spec 0004 introduced: browsing needs no account, but a real one is offered once
and can be skipped (AC-1).

## Flow

Being rebuilt one screen at a time from a Figma "Sign in" section. Screens take callbacks instead of
navigating themselves (the same shape `WelcomeScreen` uses); `app_router.dart` wires them together.

1. `welcome_screen.dart` (`WelcomeScreen`, Figma node 561:5267) — Shopscroll wordmark, Sign up, Log
   in, Skip. Shown once per device: `lib/core/onboarding/onboarding_prefs.dart`
   (`OnboardingPrefs`, backed by `shared_preferences`) records "seen" the moment any of the three is
   chosen; `main.dart` reads it at startup (alongside whether a real Clerk session already exists) to
   decide `initialLocationProvider` in `app_router.dart` — nothing re-checks it later at runtime.
   Sign up opens `/sign-up`; Log in opens `/sign-in`.
2. `get_started_screen.dart` (`GetStartedScreen`, Figma node 5284:7789) at `/sign-up` — full name +
   username. `onContinue` stores both in `signUpDraftProvider` (`sign_up_verification.dart`) and
   pushes `/sign-up/phone`; the next step reads them back when it creates the Clerk sign up.
3. `phone_number_screen.dart` (`PhoneNumberScreen`, Figma nodes 5284:9148, 5284:9424, 5284:9570,
   5284:9654) at `/sign-up/phone` — one screen, two stages that advance in place: enter number, then
   verify (number locks, a `VerificationCodeSection` appears). "Use email instead" shows in both
   stages and pushes `/sign-up/email`. Callbacks: `onSendCode`, `onVerify`, `onResendCode`,
   `onUseEmailInstead`, wired to Clerk's `phoneCode` by `sign_up_verification.dart`. The screen's doc
   comment lists its deviations from the Figma frames.
4. `email_address_screen.dart` (`EmailAddressScreen`, Figma nodes 5298:7977, 5298:8283) at
   `/sign-up/email` — the same two stages for an email address; unlike the phone number, the address
   stays editable in the verify stage (editing it returns to stage one). "Use phone number instead"
   pops back to the phone screen. Same callback shape, wired to Clerk's `emailCode` by
   `sign_up_verification.dart`.

5. `interests_screen.dart` (`InterestsScreen`, Figma node 5288:9912) at `/sign-up/interests`, where a
   verified sign up lands — "Set up Your profile", a 3 across grid of category cards that toggle on
   tap (selected gets a `success500` border), and "Let's start". `onStart` reports the chosen
   `Interest`s; the router sends them nowhere yet (no interests field on the profile, and the catalog
   does not filter by them). The `interests` const list in that file is the screen's content: the
   frame repeats a placeholder card, so each category is listed once, and two cards whose label was
   plainly wrong were renamed. A real taxonomy has to come from the catalog. The cards' fills, label
   colors and photos are per card artwork, not tokens, so they live beside the category. The photos
   are the frame's own exports, downscaled to 320px wide and committed under `assets/interests/`
   (the originals run to 3MB each).

6. `enable_notifications_screen.dart` (`EnableNotificationsScreen`, Figma node 5288:9738) at
   `/sign-up/notifications` — "Stay up to date", the phone and bell illustration
   (`EnableNotificationsIllustration`, now the frame's own export rather than the earlier stand-in
   drawn from a brief), then "Enable notifications" and "Remind me Later". Both callbacks currently go
   the same way: there is no push setup to ask permission through (no messaging plugin, no APNs/FCM
   keys), so Enable can only record an intent nothing reads. Asking last, after the value is shown,
   and letting it be declined for free, is deliberate.
7. `setting_up_account_screen.dart` (`SettingUpAccountScreen`, Figma node 5284:8251) at
   `/sign-up/setting-up` — the spinning ring and "Setting up your account", then `onDone` opens the
   home screen. It has no nav bar and nothing to tap, matching the frame. It awaits nothing real: the
   work it stands for (anonymous merge, buyer profile upsert) runs in `AuthSessionController`, which
   exposes no progress, so the wait is a fixed `duration`. Give it a future to await once one exists.

`sign_up_verification.dart` holds `signUpDraftProvider` (the name/username from step 2, kept in memory
until there is an identifier to create the sign up with, so leaving early creates no account) and
`SignUpVerification`, which `app_router.dart` builds per route visit — `.email(context, ref)` for step
4, `.phone(context, ref)` for step 3. `sendCode` calls `attemptSignUp(strategy:, emailAddress:` or
`phoneNumber:`, `username:, firstName:, lastName:)`, `verify` calls it again with just the `code`, and
`resendCode` calls `resendCode(strategy)`. `attemptSignUp` is progressive, so the same method both
creates the sign up and completes it. Completing it signs the user in, which `AuthSessionController`
picks up on its own. Two details worth keeping:

- The phone screen reports the number in E.164 already: `PhoneField`'s flag and prefix open
  `showCountryDialCodePicker` (`lib/shared/widgets/country_dial_code.dart`), and the screen prepends
  the picked country's dial code to the digits. Nothing here hardcodes a country, and its length check
  is `CountryDialCode.isPlausibleNationalNumber` (the E.164 range for that country's prefix), not a
  fixed minimum. Clerk still does the real validation.
- `sendCode` (both `SignUpVerification` and `SignInVerification`) returns `Future<bool>`: whether Clerk
  really has a pending verification for that channel afterward. `safelyCall` swallows every Clerk error
  into the snack bar and never rethrows, so awaiting it cannot tell success from failure. The three
  screens (`PhoneNumberScreen`, `EmailAddressScreen`, `LogInScreen`) move to their verify stage only on
  `true`; otherwise "Resend code" would fail with Clerk's "No initial code has been set up to resend".
  Both `sendCode`s also sign out an existing Clerk session first, because Clerk refuses a new sign in
  or sign up while one exists and debug builds always open on Welcome (see `main.dart`).
- Switching channels mid flow leaves the abandoned identifier on Clerk's pending sign up, unverified,
  where it blocks completion; `sendCode` calls `resetClient()` first when it sees one.
- A code can verify without the sign up completing, when Clerk is still waiting on another field
  (a second required identifier, a username, a password). `verify` only attempts while the identifier
  is still unverified, since a second attempt returns "This verification has already been verified",
  and when it is verified but nobody is signed in it reports what is outstanding instead of leaving
  Continue looking broken. A person hitting that message is a dashboard problem, not a code one:
  spec 0004's Configuration required section lists what has to be on and off.

Both factories return null when Clerk isn't configured (no `ClerkAuth` ancestor to read), and the
router falls back to no-op callbacks so the screens still run as UI only.

`verification_code_section.dart` (`VerificationCodeSection`) is the "Verification code" field plus its
"Resend code in 0:30" countdown, shared by steps 3 and 4. It starts its own countdown when it appears
and restarts it on resend; the screens only show it during their verify stage, so a screen never
handles the timer.

## Known gaps (deliberate, until the redesigned screens are built)

- `/sign-in` (Log in) is a `ComingSoonScreen` placeholder. The earlier Log in
  screen (Clerk's prebuilt `ClerkAuthentication` card) and the email/password sign up form
  (`CreateAccountScreen`, Figma node 561:5289) were deleted, so **signing up is the only way to reach
  a real session**; a returning person has no way back into their account yet.
- `verify_email_screen.dart` (`VerifyEmailScreen`) is orphaned and now redundant: it was only
  reachable from the deleted `CreateAccountScreen`, and `sign_up_verification.dart` does the same
  `emailCode` verification for the redesigned screen. Delete it.
- Which countries Clerk will actually text is a dashboard setting, and the picker offers all of them,
  so an unsupported country fails at send time with a snack bar rather than being greyed out.

## Conventions

- A screen that reproduces a real Figma frame documents its node id in its doc comment (root
  `AGENTS.md` rule); a screen that doesn't (like `VerifyEmailScreen`) says so explicitly instead of
  implying one exists.
- Errors from any Clerk call surface through the app-wide `ClerkErrorListener` (wired in
  `main.dart`, spec 0004 AC-12) — screens here never show their own error UI. Field errors (invalid
  number, wrong code length) are validation, not Clerk errors, and are shown by the field itself.

Governing spec: `docs/specs/0004-clerk-authentication/index.md`.

_Drafted by /sync from the introducing change, worth a quick human pass._
