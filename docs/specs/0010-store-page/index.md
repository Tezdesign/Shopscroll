# 0010. Build the Store Page

**Date**: 2026-09-30
**Status**: Proposed

## Summary

This adds a Store Page: a read only screen showing one seller's profile, their products, and their
short videos (reels). It is the destination for four taps that already exist in the app but go
nowhere today: a promo banner, a store avatar on Home or Discover, the store row on product detail,
and the store name on a reel. Building it also means adding one small new package so the "Go to
website" link actually opens a browser.

## Context

<Reasoning and options: see [rationale.md](rationale.md).>

## Requirements

**User stories**:
- As a shopper, I want to tap a seller's name or picture and see their storefront, so that I can browse everything they sell without hunting through search.
- As a shopper, I want a promo banner about a specific brand to take me to that brand's page, so that the banner is actually useful instead of a dead end.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1**: Tapping a seller's avatar or name anywhere it currently does nothing, Home's "Most visited stores" row, Discover's store grid, product detail's store row, and the Reels player's store name/avatar, opens that seller's Store Page at `/store/:id`.
- **AC-2**: The Store Page header shows the store's avatar, name, and an abbreviated follower count (e.g. "147K Followers"), a back button that returns to wherever the page was opened from, and a decorative report icon that does nothing (matching the existing decorative icon on the Order Receipt page).
- **AC-3**: Follow and Message buttons are shown but do nothing when tapped, the same treatment already used for Reels' Follow button and product detail's "Chat now" button.
- **AC-4**: "Go to website" opens the seller's `websiteUrl` in an external browser when it is set, and the row is hidden when it is not; the address row shows the seller's location as plain text when set, and is hidden when it is not.
- **AC-5**: A Products/Reels tab switcher shows either a two column grid of the seller's products or a three column grid of the seller's reel thumbnails, both scoped to that seller only.
- **AC-6**: Tapping a product in the Products grid opens its product detail page, and "Add to cart" adds it to the cart, the same as everywhere else in the app.
- **AC-7**: Tapping a reel thumbnail in the Reels grid opens the existing full screen reel player, with the seller's other reels as the swipe order.
- **AC-8**: An empty Products or Reels tab shows a "No products listed" / "No reels posted" message naming the store, not a blank grid or an error.
- **AC-9**: While a tab's products or reels are loading it shows a loading indicator, and shows a message with "Try again" if the load fails.
- **AC-10**: An unknown or deleted `storeId` shows a "Store not found" message instead of a blank screen or a crash.
- **AC-11**: The Store Page never shows the seller's email, phone, or bio, even though the `UserProfile` model carries them; the design shows none of them.
- **AC-12**: A promo banner slide on Home or Discover that has a `storeId` opens that seller's Store Page when tapped; a slide with no `storeId` stays non interactive, as today.
- **AC-13**: The Store Page opens as a full screen page with no bottom tab bar, the same as product detail and the reel player.
- **AC-14**: Every tappable element on the page has a spoken accessibility label and at least a 44 by 44 point tap target.

## Decision

**Chosen option**: Option 2: Full Store Page, every dead tap wired

Build the Store Page exactly as designed (Products and Reels tabs, a real website link, decorative
Follow/Message), and wire all four existing dead taps to it in the same pass, not just the promo
banners the scope row named.

**Implementation skills**: `supabase` (`supabase/agent-skills`, `.agents/skills/supabase/`) · `supabase-postgres-best-practices` (`supabase/agent-skills`, `.agents/skills/supabase-postgres-best-practices/`)

## Rationale

<Reasoning and options: see [rationale.md](rationale.md).>

## Feature design

**Data model sketch**:
- `UserProfile` (existing, unchanged): `id`, `name`, `avatarUrl`, `followerCount`, `isVerified`, `websiteUrl`, `location`; also carries `bio`, `email`, `phone`, none of which this page renders (AC-11). Fetched with the existing `userProfileByIdProvider(storeId)`.
- `Product` (existing, unchanged) is 1:N with `UserProfile` through `storeId`. Needs one new repository method, `getProductsByStore(storeId)`, mirroring the existing `getProductsByCategory(category)` exactly (same shape on `ProductRepository`, the mock repository, and the Supabase repository), plus a new `productsByStoreProvider` family provider mirroring `productsByCategoryProvider`.
- `Reel` (existing, unchanged) is 1:N with `UserProfile` through `storeId`. Already has `getReelsByStore(storeId)` and `reelsByStoreProvider`; reused as is.
- Banner slide (a local, static record in `home_screen.dart`'s `_CampaignBannerCarousel` and `discover_screen.dart`'s `_PromoBannerTile`, not a database table): gains one new optional field, `storeId: String?`. Set it on the two single brand slides ("Tech Week Deals" → the Apple seller id, "New Sneaker Drops" → the Nike seller id); leave it unset on the storewide "Fall Sale" slide, which stays a plain, non tappable tile.

No new database table and no migration; every entity already exists.

**State transitions**: none, this is a read only page.

**API surface** (all as if fetched from a REST backend, matching this project's existing provider doc comment convention; in reality these are Supabase queries behind the existing repository swap):

| Endpoint | Method | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| `GET /users/:id` | GET | `id` (path) | `UserProfile` or null | public (existing) | none, null on no match |
| `GET /products?storeId=` | GET | `storeId` (query) | `Product[]` | public (new) | none, empty list on no match |
| `GET /reels?storeId=` | GET | `storeId` (query) | `Reel[]` | public (existing) | none, empty list on no match |

**Key invariants**:
- A `Product.storeId` or `Reel.storeId` always names a `UserProfile.id` that exists in the same data set (already true of the seed/mock data; no new constraint to enforce, matching how the rest of this mock/Supabase split works).
- The Store Page never renders `UserProfile.bio`, `.email`, or `.phone` (AC-11).
- A banner slide's `storeId`, when set, names an existing seller id; there is no runtime check for this, the same as every other hand authored field on these static slides.

**Security model**:
- Fully public read: viewing a Store Page needs no sign in, the same as Home, Discover, and product detail, all open to anonymous browsing since spec 0004.
- No write surface at all. Follow and Message are inert (AC-3); nothing on this page creates, changes, or exposes a mutation.
- Row level security is unchanged; the `products`, `reels`, and seller rows in `user_profiles` are already public read, granted by spec 0003.

**Critical test scenarios** (each maps to an acceptance criterion in `## Requirements`):
- Happy path: tapping a store avatar on Home opens the Store Page, which loads the seller and both tabs render real, store scoped data, verifies **AC-1**, **AC-5**.
- Failure case: opening `/store/:id` with an id that matches no seller shows "Store not found" rather than a blank screen or a crash, verifies **AC-10**.
- Auth/permission: a signed out buyer opens a Store Page and fully uses it (browses both tabs, taps Go to website) with no sign in prompt anywhere, verifies the public security model above.

## Build plan

1. Add `getProductsByStore(storeId)` to `ProductRepository`, the mock repository, and the Supabase repository (mirrors `getProductsByCategory` exactly), plus `productsByStoreProvider`, satisfies **AC-5**, **AC-6**
2. Add the `url_launcher` package and a small "open external URL" helper, satisfies **AC-4**
3. Build the Store Page shell at `/store/:id` (new top level route, outside the shell): header, profile block (avatar, name, abbreviated follower count, Follow/Message, website/location rows), the Products/Reels `SegmentedTabs` switcher, and the seller load's own loading/not found/error states, satisfies **AC-2**, **AC-3**, **AC-4**, **AC-10**, **AC-11**, **AC-13**, **AC-14**
4. Products tab: a two column grid reusing `ProductCard`, fed by `productsByStoreProvider`, with its own loading/empty/error states, tap through to product detail, and Add to cart, satisfies **AC-5**, **AC-6**, **AC-8**, **AC-9**
5. Reels tab: a three column grid of reel thumbnails fed by the existing `reelsByStoreProvider`, with its own loading/empty/error states, tap through to the existing full screen reel player with the store's reel ids as the swipe order, satisfies **AC-5**, **AC-7**, **AC-8**, **AC-9**
6. Wire the four existing dead taps (Home's and Discover's `MostVisitedItem`, product detail's store row, the Reels player's store row) to `context.push('/store/$id')`, satisfies **AC-1**
7. Add the optional `storeId` field to the banner slide record in `home_screen.dart` and `discover_screen.dart`, assign it on the Apple and Nike slides, and wire the tap through when it is set, satisfies **AC-12**
8. Widget tests: the new screen's states, the new repository method and provider, and the six newly wired taps, covering every AC above

## Consequences

**Positive**:
- Closes four pre-existing dead taps in one pass, three of which were already code-commented as waiting for this exact screen.
- Nearly all of the UI is reused as is (`ProductCard`, `SegmentedTabs`, `AppButton`, `AppIcon`, the existing loading/empty/error message pattern), so the net new surface is small: one screen, one repository method, one dependency.
- No database migration, so this ships with zero backend risk.

**Negative / tradeoffs**:
- Adds one new runtime dependency (`url_launcher`) for a single link.
- Follow and Message stay decorative, so the page can feel unfinished to anyone who taps them expecting a real action; this is a deliberate, scoped choice (see Rationale), not an oversight.
- Widens scope beyond the scope row's original "banner screens" wording to four entry points instead of one; slightly more surface to build and test in this pass.

**Neutral**:
- Introduces a new feature folder, `lib/features/store/`, following the project's one folder per feature convention.
- The banner slide record picks up one new optional field; every other screen that reads it is unaffected since the field defaults to unset.

## Follow-up

- [ ] Follow/unfollow persistence is a separate, not yet designed feature. When it exists, wire the Store Page's Follow button to it instead of leaving it decorative.
- [ ] Chat (scope item "Chat", spec 0008's follow-up) is a separate, not yet designed feature. When it exists, wire the Store Page's Message button to it instead of leaving it decorative.
- [ ] Check whether `url_launcher` needs any iOS `Info.plist` / Android manifest entries for this project's target platforms before relying on it in the build (a normal setup step for this package, not a design question).
