# 0005. Build the real Profile screen

**Date**: 2026-08-05
**Status**: In Progress

## Summary

The Profile tab in the bottom navigation has been an empty placeholder since spec 0004 chose to
keep it that way. This decision replaces it with the real page from the Figma design (node
322:2872): a signed in person's name, photo, and stores followed count, a way to edit their name,
username, and bio, sign out, and delete their account, plus a set of rows for features that do not
exist yet in this buyer only app (become a seller, delivery addresses, payments, and so on), shown
as visual placeholders for now. Someone who is not signed in sees a short message instead, with a
button that opens the existing sign in screen.

## Requirements

**User stories**:
- As a signed in shopper, I want a real Profile page showing my name, photo, and stores followed
  count, so the app feels like it has a real account behind it.
- As a signed in shopper, I want to change my name, username, and bio, so my profile reflects who I
  am.
- As a signed in shopper, I want to sign out or delete my account from the same page I already use
  for everything else about my account, instead of a screen I can never reach.
- As an anonymous browser, I want the Profile tab to explain that this page needs an account, with a
  clear way to sign in, rather than showing me a broken or empty screen.
- As a shopper looking at a row for a feature that is not built yet (become a seller, delivery
  addresses, payments, and so on), I want a clear "not yet available" response when I tap it, not a
  dead button or a crash.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1**: A signed in real account, opening the Profile tab, sees the full page from the Figma
  design: avatar, name, "N Stores following", a Become a seller button, an Edit profile button, a
  Generals section (Shopping in, Language, Delivery addresses, Payments), a Help and Legal section
  (Contact us, My reports, Privacy policy, Terms and conditions, FAQ), and Log out.
- **AC-2**: An anonymous browser opening the Profile tab sees a short message explaining the page
  becomes available once signed in, plus one button that opens the existing sign in screen. None of
  the Generals, Help and Legal, or account rows render for an anonymous browser.
- **AC-3**: Tapping Log out signs the person out and returns the app to anonymous browsing, the same
  behavior spec 0004 already built (its AC-6), now reachable from real navigation for the first
  time.
- **AC-4**: A Delete account row sits directly under Log out. Tapping it shows the same confirm
  dialog spec 0004 already built (its AC-8) and deletes the account on confirmation.
- **AC-5**: Tapping Edit profile opens a screen to change name, username, and bio (the profile photo
  itself is not editable in this pass, see Follow up). Saving writes the change and returns to the
  Profile page showing the new values.
- **AC-6**: On the Edit profile screen, a blank name, a blank username, or a username already taken
  by someone else shows an inline error message under that field. Saving is blocked until every
  field is valid.
- **AC-7**: Every other row (Become a seller, Shopping in, Language, Delivery addresses, Payments,
  Contact us, My reports, Privacy policy, Terms and conditions, FAQ) opens the same "coming soon"
  placeholder screen already used for the Activity tab, labeled for that specific row, so nothing
  looks broken or does nothing when tapped.
- **AC-8**: The old, unlinked `AccountScreen` no longer exists as a separate screen; sign out and
  delete account only live on the new Profile page.
- **AC-9**: "N Stores following" reads the real `following_count` value from the signed in person's
  own `user_profiles` row. It reads 0 for every real buyer today, since no follow a store feature
  exists yet to change it, and that is expected, not a bug.

## Decision

**Chosen option**: Option 2: Build a new `ProfileScreen` from the design, retire `AccountScreen`

The Profile tab becomes a real screen built from the Figma page. `AccountScreen` is deleted; its sign
out and delete account logic moves directly into the new screen, styled as the Log out and Delete
account rows the design and the engineer agreed on.

## Feature design

**Data model sketch**:

No new tables or columns. Everything this page needs already exists on `user_profiles` (spec 0003,
adjusted by spec 0004): `name`, `username`, `avatar_url`, `bio`, `following_count`. The one gap is
the repository layer: `UserProfileRepository` only reads a profile today
(`getUserProfileById`), so this adds:

```dart
Future<void> updateUserProfile(
  String id, {
  required String name,
  required String username,
  String? bio,
});
```

implemented for both the mock repository and the Supabase repository, the same pairing every other
repository in this project already follows. The existing `update own profile` row level security
policy (spec 0004) already allows this write for the signed in person's own row; no policy change is
needed.

**API surface**:

| Endpoint | Method | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| `UserProfileRepository.getUserProfileById` (existing) | read | `id` | `UserProfile?` | any (public read for sellers, own row for buyers, per spec 0004) | none, returns null if missing |
| `UserProfileRepository.updateUserProfile` (new) | write | `id`, `name`, `username`, `bio?` | void | signed in real account, own row only | unique username conflict, blank name or username |
| Clerk `authState.signOut()` (existing) | client action | none | switches active Supabase client back to anonymous | signed in real account | none surfaced, spec 0004 AC-7 covers expiry |
| Clerk `authState.deleteUser()` (existing) | client action | confirm dialog result | account deleted, webhook cleans up owned rows (spec 0004 AC-8) | signed in real account | Clerk side failure, shown via the existing `ClerkErrorListener` |

**Key invariants**:
- A person can only update their own `user_profiles` row (already enforced by the existing update
  policy).
- `username` stays unique across every profile, buyer and seller alike (already enforced by the
  existing database constraint); the Edit profile screen must surface that conflict as a field error,
  not a crash.
- The Profile tab always renders something for every session state (signed in, anonymous, loading,
  error), never a blank screen.

**Security model**:

No change to spec 0004's security model. The new write (`updateUserProfile`) is covered by the
`update own profile` policy already in place (`(select auth.jwt()->>'sub') = id`, `to
authenticated`). The read side reuses the existing `getUserProfileById`, already scoped so a buyer's
own row is only readable by that same person (spec 0004's narrowed select policy). No new
credentials, no new endpoint outside this app's own Supabase project.

**Critical test scenarios** (each maps to an acceptance criterion in ## Requirements):
- Happy path: sign in, open the Profile tab, see the real page, edit the name and save, see the
  change reflected, verifies **AC-1**, **AC-5**
- Failure case: on Edit profile, submit a username already taken by another account, see an inline
  error under the username field, save stays blocked, verifies **AC-6**
- Auth/permission: an anonymous browser opens the Profile tab and sees the sign in message, not the
  real page or any account data, verifies **AC-2**

## Build plan

1. Add `UserProfileRepository.updateUserProfile` to both the mock and Supabase repositories, plus a
   `currentUserProfileProvider` (wraps the existing `userProfileByIdProvider` with the signed in
   Clerk id) so the rest of the build has a single place to read and write the signed in person's own
   profile, satisfies **AC-5**, **AC-9**
2. Build a small shared row widget for the Generals/Help and Legal list items (a label, an optional
   trailing value, and a chevron or external link icon, matching the Figma pattern), satisfies
   **AC-1**, **AC-7**
3. Build the signed in `ProfileScreen`: header (avatar, name, stores following count, Become a
   seller button, Edit profile button), the Generals and Help and Legal sections, Log out and Delete
   account rows (the retired `AccountScreen`'s logic moves in here), wired into the `/profile` route
   in place of `ComingSoonScreen` for a signed in session, satisfies **AC-1**, **AC-3**, **AC-4**,
   **AC-8**, **AC-9**
4. Build the anonymous view for the same `/profile` route: a short message plus a button that opens
   the existing `/sign-in` route, satisfies **AC-2**
5. Build the Edit profile screen (name, username, bio fields, inline validation for blank fields and
   a taken username) and its route, wired to `updateUserProfile`, satisfies **AC-5**, **AC-6**
6. Wire every remaining row (Become a seller, Shopping in, Language, Delivery addresses, Payments,
   Contact us, My reports, Privacy policy, Terms and conditions, FAQ) to open the existing
   `ComingSoonScreen`, each with its own row specific label, satisfies **AC-7**
7. Delete `account_screen.dart` and remove any leftover reference to it, satisfies **AC-8**

## Consequences

**Positive**:
- Spec 0004's open Follow up item closes: signing out and deleting an account finally has a real,
  reachable home
- The Profile tab stops being the one empty tab in an otherwise fully built navigation shell
- Editing name, username, and bio gives real accounts their first piece of self service, on top of
  what Clerk sign up already collects

**Negative / tradeoffs**:
- Most of the page (Become a seller, Shopping in, Language, Delivery addresses, Payments, Contact
  us, My reports, Privacy policy, Terms and conditions, FAQ) is a visual placeholder, not working
  functionality; someone tapping any of those rows gets a "coming soon" screen, not the real feature
- Profile photo upload is out of scope for this pass (needs a new Supabase Storage bucket and its own
  access policy); Edit profile only covers name, username, and bio
- "N Stores following" will read 0 for every real buyer for a while, since no follow a store feature
  exists yet to change it; expected, but worth knowing before someone reports it as a bug

**Neutral**:
- `AccountScreen` is deleted; anything that referenced it directly (nothing outside the router today)
  would need updating, but nothing else does
- The Generals and Help and Legal row list is a plain, project specific widget, not adopted from an
  external library; it is small enough that this was judged not worth a new dependency

## Follow-up

- [ ] Photo upload for Edit profile is deferred; needs a Supabase Storage bucket and an upload flow,
  worth its own small decision when picked up
- [ ] Every "coming soon" row (Become a seller, delivery addresses, payments, contact us, reports,
  language and country switching, a real store following feature, and static legal pages) is its own
  future feature; each needs its own spec when it is actually picked up, this decision only clones
  the page's look and reachability
- [ ] A seller sign up flow (Become a seller) is out of scope for this buyer side only app per
  `AGENTS.md`; revisit once/if the product takes on seller flows

## Rationale

Reasoning and options considered: see [rationale.md](rationale.md).
