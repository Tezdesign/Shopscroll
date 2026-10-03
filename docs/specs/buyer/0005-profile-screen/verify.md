# Verify: Profile screen · spec 0005 · updated 2026-08-05

_`/check verify` runs these against each acceptance criterion (AC-N) in `index.md`'s `## Requirements`;
`/test` locks the durable ones._

## Commands

- [ ] `flutter pub get` → resolves cleanly, no new dependency needed
- [ ] `flutter analyze` → no issues
- [ ] `flutter test` → existing tests still pass unchanged

## UI / manual

- [ ] Sign in with a real account, open the Profile tab → the full page renders: avatar, name, "N
  Stores following", Become a seller button, Edit profile button, Generals section (Shopping in,
  Language, Delivery addresses, Payments), Help and Legal section (Contact us, My reports, Privacy
  policy, Terms and conditions, FAQ), Log out, Delete account → verifies **AC-1**, **AC-4**
- [ ] While anonymous, open the Profile tab → a short message plus a sign in button appears, none of
  the Generals/Help and Legal/account rows render → verifies **AC-2**
- [ ] From the anonymous Profile tab, tap the sign in button → the existing sign in screen opens →
  verifies **AC-2**
- [ ] Signed in, tap Log out → returns to anonymous browsing, the Profile tab now shows the
  anonymous message → verifies **AC-3**
- [ ] Signed in, tap Delete account, confirm → the account is deleted and the app returns to
  anonymous browsing (spec 0004's webhook cleanup still applies) → verifies **AC-4**
- [ ] Signed in, tap Edit profile, change the name and bio, save → returns to the Profile page
  showing the new name; check `user_profiles` in the Supabase dashboard to confirm the row updated
  → verifies **AC-5**
- [ ] On Edit profile, clear the name field and try to save → an inline error appears under the name
  field, save is blocked → verifies **AC-6**
- [ ] On Edit profile, enter a username already used by another account (e.g. one of the seed seller
  usernames) and try to save → an inline error appears under the username field naming the conflict,
  save is blocked → verifies **AC-6**
- [ ] Tap each of Become a seller, Shopping in, Language, Delivery addresses, Payments, Contact us,
  My reports, Privacy policy, Terms and conditions, FAQ → each opens the coming soon placeholder with
  a label matching that row, never a blank screen or a crash → verifies **AC-7**
- [ ] Confirm `account_screen.dart` no longer exists in the repo, and nothing still imports or
  references it → verifies **AC-8**
- [ ] After a fresh real sign in (a brand new account with no prior activity), the Profile page shows
  "0 Stores following" rather than an error, a blank value, or a crash → verifies **AC-9**

## Not yet coverable

- Whether "N Stores following" ever changes is not testable yet; no follow a store feature exists to
  increment it (tracked in spec 0005's Follow up)
- The functional versions of Become a seller, delivery addresses, payments, contact us, reports,
  language/country switching, and the legal pages are each their own future feature; this spec and
  its verify steps only cover the placeholder behavior, not the real feature
