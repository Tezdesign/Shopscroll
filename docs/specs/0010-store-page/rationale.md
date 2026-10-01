# 0010. Store Page: rationale

## Context

No seller or store facing page exists anywhere in this buyer only app. Yet four places already show
a seller's name or avatar as if it led somewhere, and none of them do anything when tapped: the
"Most visited stores" row on Home and on Discover, the store row on product detail (whose own code
comment already reads "will take you to Store page... not wired since this build is user scope
only"), and the store name/avatar overlay in the Reels player. Promo banners on Home and Discover
are static marketing tiles with no tap target and no reference to any seller at all. The scope row
that motivated this spec, "Banner screens", named only the banners: "make the promo banners
tappable and design the screen a banner opens." Reading it against the rest of the app shows the
same missing screen is the answer for all four taps, not just one.

The app already has most of what this screen needs. `UserProfile` (spec 0005's model, reused for
both buyers and sellers) already carries every field the design shows: avatar, name, follower
count, verified flag, website, location. `Product` and `Reel` already carry a `storeId`/`storeName`
pair. `reelsByStoreProvider` and `userProfileByIdProvider` already exist and are unused for this
purpose. `ProductCard` and `SegmentedTabs` are existing shared widgets that already match the
design's product grid and tab switcher pixel for pixel. The only real gaps are one new read method
(products by store) and one new dependency (opening a URL).

Two things this page's design asks for have no backing feature yet: a real follow relationship
(nothing in this app persists one; Reels' own Follow button is already static for the same reason)
and buyer to store chat (scope item "Chat", still "needs a decision"). Building either now would
pull two undesigned features into this spec.

## Options considered

### Option 1: Minimal, banners only

Build a bare Store Page (Products tab only, no Reels tab) reachable only from a tappable banner,
matching the scope row's literal wording and nothing more.

**Pros**:
- Smallest possible diff; ships fastest.
- Never touches Home, Discover, product detail, or the Reels player.

**Cons**:
- Leaves three pre-existing dead taps unresolved, one of which is explicitly commented in the code
  as waiting for this screen.
- A Store Page with no Reels tab contradicts the Figma design, which shows one (including its own
  empty state).
- Very likely to become a second spec later just to finish the same screen.

### Option 2: Full Store Page, every dead tap wired

Build the Store Page as designed (Products and Reels tabs, decorative Follow/Message, a real
website link), and wire all four existing dead taps, plus store targeted banners, to it in one pass.

**Pros**:
- Resolves every dead tap the app already has for this concept, not just the one the scope row
  named.
- Nearly the entire UI is reuse: `ProductCard`, `SegmentedTabs`, `AppButton`, `AppIcon`, and the
  loading/empty/error pattern already used across Activity and checkout. The genuinely new surface
  is one screen shell, one repository method, and one small dependency.
- No database migration; every entity this page reads already exists and is already public.

**Cons**:
- Touches five existing files beyond the new screen (two banner carousels, two dead tap sites, the
  Reels player), more surface to review and test than Option 1.

### Option 3: Also build real Follow and a chat stub

Everything in Option 2, plus a persisted follow relationship and a placeholder chat thread, so
Follow and Message do something real.

**Pros**:
- The page feels finished rather than partly inert.

**Cons**:
- Follow persistence and chat are each their own undesigned feature (a new table, notification
  rules, message delivery); folding them in here means designing three features under one spec
  number.
- Directly contradicts the precedent this app already set: Reels' Follow button and product
  detail's Chat now button are both deliberately static until their own specs exist.

## Rationale

Option 2 is the right scope. The forces in Context point the same way: this app has spent four
separate screens gesturing at a store page that does not exist, one of them in a code comment
naming it by name. Shipping a Store Page that only three of those four taps can reach would be an
odd half step, and the fourth (product detail's) is the one most explicitly waiting for it. Because
almost every widget this page needs was already built for another screen, wiring all four taps costs
little beyond the dead-simple `context.push` each one needs.

Option 1 optimizes for a smaller diff at the cost of leaving known, already flagged gaps in place,
which this codebase's own comments argue against. Option 3 solves a problem nobody asked this spec
to solve: Follow and Message already have an established, deliberate "decorative until designed"
pattern elsewhere in this app (Reels, product detail), and this page should match that pattern, not
quietly break it by being the one place a fake Follow button looks real.
