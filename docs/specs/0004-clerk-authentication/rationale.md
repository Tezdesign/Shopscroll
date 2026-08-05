# 0004. Adopt Clerk for real user authentication — rationale

## Context

Spec 0003 introduced Supabase as the app's backend and, with no login screen in place yet, used
Supabase's anonymous sign in so `cart_items` and `orders` still had a stable owner. That spec named its
own limit directly: "Real auth (replacing anonymous only sign in) is its own future decision; needed
before order history can be trusted to follow a person across devices or after a reinstall." An
anonymous session lives in local device storage only; it is lost on uninstall, on clearing app data, or
when a long idle refresh token finally expires, and with it goes whatever cart or order history was
tied to it. This spec is that deferred decision.

The engineer asked for Clerk by name. Two forces shape the design beyond "which login provider":
first, Clerk's user ids are not the `uuid` type this schema currently expects everywhere ownership is
tracked (`auth.users(id)` foreign keys throughout `cart_items`, `orders`, `reel_likes`, `reel_saves`,
and `user_profiles.id` itself); second, the app must keep working for people who never sign up at all,
since browsing is intentionally still open to anonymous sessions.

## Options considered

### Option 1: Clerk

A dedicated login service with prebuilt sign in/sign up UI, session handling, and multi factor support,
connected to Supabase through Supabase's native "Third Party Auth" (Supabase verifies Clerk's login
tokens directly; Clerk accounts never need a row in Supabase's own `auth.users` table).

**Pros**:
- Supabase's Third Party Auth support for Clerk is a first class, documented integration, not a
  workaround
- Prebuilt sign in/sign up screens (email, Google, Apple, phone OTP, password reset, email
  verification) mean almost no custom auth UI has to be built
- Session refresh, MFA, and rate limiting/lockout are handled by Clerk, not this app

**Cons**:
- A second vendor added to the stack, with its own uptime, quotas, and pricing
- The official Flutter package (`clerk_flutter`) is still in beta (v0.0.18 at last check, confirmed
  live on pub.dev), not a fully 1.0 released SDK, and conspicuously absent from Clerk's own public "SDK
  References" documentation page (which lists Next.js, React, Expo, Android, iOS, and others, but no
  Flutter or Dart entry)
- `supabase_flutter`'s `accessToken` callback (needed to run Clerk through Third Party Auth) and its own
  native `auth` namespace are mutually exclusive on one client instance; this decision needs a second
  `SupabaseClient` instance to keep native anonymous sessions working alongside it, more moving parts
  than a single-client design

### Option 2: Supabase's own built in auth (email/password + OAuth), no Clerk

Upgrade the existing anonymous Supabase Auth session directly to a real one, using Supabase Auth's own
email/password and OAuth support (with the community `supabase_auth_ui` package for prebuilt screens),
with no second vendor.

**Pros**:
- No new vendor, no new dependency; the app already runs on Supabase Auth for anonymous sessions
- `linkIdentity` was already the anonymous-to-real upgrade path spec 0003 called out, so this was the
  assumed default before this decision, and it upgrades a session in place: no separate merge function,
  no `security definer` bypass, and no second `SupabaseClient` instance to manage
- `supabase_auth_ui` supplies prebuilt Flutter sign in/sign up widgets for Supabase's own auth, so this
  option is not purely "build every screen by hand" either

**Cons**:
- `supabase_auth_ui`'s prebuilt screens and provider list are narrower than Clerk's (e.g. Clerk's
  built in phone/SMS OTP and broader OAuth catalog), and Clerk is a dedicated identity platform with
  session management, MFA, and abuse protection this option would still be assembling itself
- The engineer specifically asked for Clerk

### Option 3: Firebase Auth alongside the existing Supabase database

Use Firebase Auth for login, passing its tokens to Supabase as a custom JWT.

**Pros**:
- Firebase Auth is mature, with mature Flutter SDKs and wide adoption

**Cons**:
- Supabase has no native "Third Party Auth" entry for Firebase; wiring its tokens in means a hand
  rolled custom JWT bridge, more integration surface than Clerk's native support
- Adds a second vendor for no benefit Clerk doesn't already give here

## Rationale

The engineer asked for Clerk directly, and it holds up on its own merits: Supabase's Third Party Auth
support for Clerk is a maintained, documented integration rather than a bridge this project would have
to build and maintain itself, which is what ruled out Option 3 (Firebase). Against Option 2 (upgrading
Supabase's own auth), the honest comparison is closer than it first looks: `supabase_auth_ui` and
`linkIdentity` mean Option 2 is not purely "build everything by hand," and it avoids both the merge
function and the two-client architecture Clerk's integration turned out to require (see below). Clerk
still wins on breadth (phone/SMS OTP and its wider OAuth catalog are not native to Option 2's stack) and
because it is what the engineer asked for; the cost accepted is a second vendor, a still-beta Flutter
package, and the extra `SupabaseClient` instance, all judged worth it against Option 2's narrower
prebuilt UI and lack of a dedicated identity platform's session/MFA/abuse handling.

The schema change (every ownership column from `uuid` to `text`) is a direct consequence of the choice,
not a separate decision: Clerk's ids (e.g. `user_2abc123`) are strings, not UUIDs, and Clerk accounts
never populate Supabase's own `auth.users` table, so the existing `references auth.users(id)` foreign
keys have nothing to point at for a real account and must be dropped. Moving every RLS check from
`auth.uid()` (which casts to `uuid`) to `auth.jwt()->>'sub'` (plain text) is what lets one policy shape
cover both anonymous and real sessions without a special case for either.

The anonymous-to-real cart/order merge needed its own reasoning: RLS's `with check` clause can only ever
validate against the *caller's own* current session, so a plain client side `UPDATE` can never reassign
a row's `user_id` from an old anonymous identity to a new real one — neither identity's policy would
permit writing rows under the other's id. A `security definer` Postgres function is the standard escape
hatch for exactly this shape of problem: it deliberately bypasses RLS, but only inside a narrowly scoped
function body, not by weakening any table's policy. Scoping it to anonymous-only callers, and to
additive-only writes into the target account, keeps the bypass's blast radius small even though it is,
in principle, callable with an arbitrary target id; that residual risk is recorded in `index.md`'s
Consequences rather than solved further, since this app has no real payment processing yet to make it
worth the extra complexity of closing it completely.

An initial draft of this design assumed one `SupabaseClient` could hold an anonymous session, then
simply start using Clerk's token once signed in. A cross check against `supabase_flutter`'s actual
behavior found this is not possible: configuring the `accessToken` callback (required for Third Party
Auth) makes the client's own `auth` namespace throw outright, so `signInAnonymously()` and session
refresh cannot coexist with it on the same instance. The fix is a second `SupabaseClient`, built
specifically for the Clerk-backed session, with repositories switching between the two; this is also
what makes the merge call's timing work at all — it must run on the anonymous client, before the switch,
since the function's anonymous-caller check reads the *current* session's own JWT, and that is only
true of the anonymous client. This is recorded here because it changes the shape of `main.dart`'s setup
from spec 0003 (one client) to two, which is worth a future reader knowing was a deliberate, forced
choice, not an oversight.

`user_profiles`'s existing public `select using (true)` policy (spec 0003) was written back when the
table only ever held seller/store rows, intentionally public so product and reel cards can render store
info without a join-time permission check. AC-4 changes that assumption by writing real buyers' name,
email, and phone into the same table; leaving the policy unchanged would mean any anonymous caller with
the publishable key could read every buyer's contact details. Narrowing the policy to owner-or-seller
closes that without touching how seller rows are read anywhere in the app today.

## Amendment: welcome screen, error surfacing, phone removal

After the first build pass shipped, three problems surfaced from actually running it. First, the
Account/Sign in screens had been placed inside the Profile tab, but Profile has no design of its own
yet (it is still meant to be an empty placeholder, matching Activity), and the engineer wanted the
Figma welcome screen (node 561:5267) used as intended, a first launch, one time offer to sign up, not a
permanent tab. Second, a real test sign up hit three Clerk side validation errors (an unsupported
phone country, a short username, a breached password) and none of them appeared anywhere in the app;
the whole thing failed silently, with the only trace in the developer console. Third, the phone number
field was pulling in a country Clerk does not support for SMS, and the engineer decided phone sign in
is not worth carrying for this app at all.

The welcome screen becomes a one time, skippable first launch step rather than a standing tab because
that is what its own design already implies (a Sign up / Log in / implied "not now" choice, not a
settings style screen), and it keeps AC-1's promise, browsing without an account, intact while still
giving every new person the choice once. The tradeoff, accepted directly by the engineer, is that
signing in later has no other entry point until Profile gets its own real design; this is recorded in
Consequences and Follow-up rather than solved further here, the same way Activity and Profile were
already left as placeholders in the base app before this feature existed.

The silent error problem turned out to already have a built in fix: `clerk_flutter` ships
`ClerkErrorListener` specifically for this, a widget that listens to `ClerkAuthState`'s own error
stream and shows a snack bar with Clerk's message. It was simply never wired into `main.dart`. Since
Clerk already writes the message text, this needed no custom error design, only placing the listener
correctly in the widget tree (inside `MaterialApp`, so it can reach a `ScaffoldMessenger`).

Phone number removal turned out not to be an app code decision at all. Clerk's prebuilt sign in/sign up
card renders whatever sign in methods the Clerk dashboard has turned on; there is no per app override.
Turning Phone number off in the dashboard is both necessary and sufficient, the app's build plan step
that used to say "phone/SMS" simply drops it.

## References

**Project sources**:
- Spec 0003, the "Real auth ... is its own future decision" follow-up item this spec resolves
- `supabase/schema.sql`, the exact columns and RLS policies this spec's data model section modifies
- Installed community skills `supabase` and `supabase-postgres-best-practices`
  (`.claude/skills/supabase/`, `.claude/skills/supabase-postgres-best-practices/`)

**Practices & standards**:
- Row Level Security as the enforcement point for per-user data, not application level filtering alone
- `security definer` functions as the standard, narrowly scoped escape hatch for a mutation RLS
  structurally cannot express (cross-identity row reassignment)
- The strangler-style upgrade path (anonymous session first, real account later) already anticipated by
  spec 0003's choice of Supabase anonymous auth
- `clerk_flutter` on pub.dev, confirmed live at time of writing: officially published by Clerk, verified
  publisher, v0.0.18-beta, actively maintained
