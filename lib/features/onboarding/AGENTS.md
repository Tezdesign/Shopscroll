# lib/features/onboarding

The first-launch flow spec 0004 introduced: browsing needs no account, but a real one is offered once
and can be skipped (AC-1).

## Flow

1. `welcome_screen.dart` (`WelcomeScreen`, Figma node 561:5267) — Shopscroll wordmark, Sign up, Log
   in, Skip. Shown once per device: `lib/core/onboarding/onboarding_prefs.dart`
   (`OnboardingPrefs`, backed by `shared_preferences`) records "seen" the moment any of the three is
   chosen; `main.dart` reads it at startup (alongside whether a real Clerk session already exists) to
   decide `initialLocationProvider` in `app_router.dart` — nothing re-checks it later at runtime.
2. **Log in** → `sign_in_prompt_screen.dart` (`SignInPromptScreen`): Clerk's own prebuilt
   `ClerkAuthentication` card, themed via a local `ClerkThemeExtension` to match the app's tokens.
3. **Sign up** → `create_account_screen.dart` (`CreateAccountScreen`, Figma node 561:5289): a
   hand-built form (email + password, terms checkbox, Google/Apple), **not** the prebuilt card — see
   that file's doc comment for why Sign up and Log in diverge here, and the two Figma-vs-reality
   deviations it documents (the source frame's duplicate "Enter your email" field, and its
   Facebook button using another button's own invisible-spacer icon as its asset). Calls Clerk's
   headless `attemptSignUp` (two calls in sequence: `password` then `emailCode`, mirroring
   `clerk_flutter`'s own prebuilt panel internally), then hands off to:
4. `verify_email_screen.dart` (`VerifyEmailScreen`) — the email verification code step (AC-2
   requires it); no Figma frame exists for this anywhere in the source file, so it's built from this
   app's own design system tokens, not a node reproduction.

Either path ends in the same place: `lib/core/auth/auth_session_controller.dart` reacts to
`ClerkAuthState` generically (anonymous→real merge, buyer profile upsert), so it doesn't matter which
screen actually completed sign in.

## Conventions

- A screen that reproduces a real Figma frame documents its node id in its doc comment (root
  `AGENTS.md` rule); a screen that doesn't (like `VerifyEmailScreen`) says so explicitly instead of
  implying one exists.
- Errors from any Clerk call surface through the app-wide `ClerkErrorListener` (wired in
  `main.dart`, spec 0004 AC-12) — screens here never show their own error UI.

Governing spec: `docs/specs/0004-clerk-authentication/index.md`.

_Drafted by /sync from the introducing change, worth a quick human pass._
