# 0019. Seller shell: one tab bar for the store area

**Date**: 2026-11-06
**Status**: In Progress

## Summary

The store area (`/store`) gets its own tab bar and one navigation model. A seller moves between five tabs: Home (the dashboard), Products, Activity, Messages and Profile. Discover and Reels, which the store area borrowed from the buyer app, leave it. The five tab roots stay alive when the seller switches tabs, so each keeps its place and its scroll. Everything that is a task or a detail (the product flow, Store policies, Notifications, order and report details) opens full screen over the tabs, like the buyer's product detail. Messages is a placeholder tab, because the chat spec (0011) covers only the buyer's side. This spec records a shell that was built before it had a spec (scope feature 30) and corrects what that build got wrong.

Reasoning and options: see [rationale.md](rationale.md). Verification: see [verify.md](verify.md).

## Requirements

**User stories**:
- As a seller, I want a tab bar that only holds things a seller uses, so that I never land in a buyer screen by accident.
- As a seller, I want each tab to keep my place when I switch away and back, so that I do not lose a half read list.
- As a seller, I want my products one tap away, so that I do not go through the dashboard to reach them.
- As a seller, I want one obvious place for messages from my customers, so that I know where they will appear.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1** (tabs): Inside the store area the bottom bar shows exactly five tabs, in this order: Home (`/store`), Products (`/store/products`), Activity (`/store/activity`), Messages (`/store/messages`) and Profile (`/store/profile`). The active tab is highlighted. Tapping the active tab again returns it to its root page.
- **AC-2** (no buyer tabs): The store area has no Discover or Reels tab. `/store/discover` and `/store/reels` redirect to `/store`, so an old link or a remembered location never reads `discover` or `reels` as a store id (`/store/:id`).
- **AC-3** (state kept): Switching tabs keeps each tab's own stack and scroll position. A search typed in Activity, the status tab chosen in Products and the scroll of a list are still there on return.
- **AC-4** (access): Only a seller stays in the area. A non seller, a visitor and a profile that cannot be read are sent to the buyer area by `SellerGate`, on every tab, exactly as before.
- **AC-5** (products tab): The Products tab is the existing products list, shown as a tab. It has no back arrow, because a tab root has nothing behind it. "Add product" still opens `/store/products/new`, and the draft edit route `/store/products/:draftId/edit` still opens full screen. Both return to the list.
- **AC-6** (full screen flows): These open over the tab bar, without it, and go back to the page that opened them: `/store/products/new`, `/store/products/:draftId/edit`, `/store/policies`, `/store/policies/:section`, `/store/notifications`, `/store/activity/orders/:id` and `/store/activity/reports/:id`.
- **AC-7** (entry points): The Home quick actions Products, Orders and Reports switch tab (they use `go`, not `push`), so the bar keeps showing and the right tab is highlighted. The bell on Home and on Activity opens Notifications. Store policies is reached from Profile, Settings (spec 0018 follow up, unchanged).
- **AC-8** (messages tab): The Messages tab shows the Coming soon page with the label "Messages". It has no data and sends nothing. It exists so the tab bar is final and the inbox has a place to land when the chat spec adds the seller side.
- **AC-9** (buyer area unchanged): The buyer tab bar keeps Home, Discover, Reels, Activity and Profile with the user border color. Nothing in this spec changes a buyer screen or route.
- **AC-10** (bar look): The seller bar draws the Figma "tabbar-seller" component (node `706:3719`): the same height, icon size and label style as the buyer bar, the `neutral300` top border, `primary400` for the active tab and `neutral600` for the others. Labels are Home, Products, Activity, Messages and Profile, with a capital first letter.
- **AC-11** (accessibility): Each tab has a tap area of at least 44 by 44 logical pixels and a spoken label that says the tab name and whether it is selected.
- **AC-12** (scope guard): This spec adds no table, function, provider or network call, and does not build a seller inbox.

## Decision

**Chosen option**: Option 1: a dedicated seller tab bar over the existing store shell

Give the store `StatefulShellRoute` its own five branches and its own bar widget (`SellerBottomNavBar`, with its own `SellerTabItem` enum), instead of reusing the buyer's `AppBottomNavBar` with a color variant. The buyer bar and its enum stay as they are.

**Implementation skills**: none (Flutter only, no Supabase work).

## Feature design

**Design source**: Figma file `toOakybJ0DaJmU7vcEC0AW`, page "The design - seller": the `tabbar-seller` component (`706:3719`, used by Home-seller `3001:12309`, Notifications-seller `3016:9501` and the Settings-seller frame `5601:3746`). The component in the file still carries the buyer labels (Discover, Reels), so the labels and icons below are a deviation to record in the widget's doc comment, and the Figma component should be updated to match.

**Tabs**:

| Tab | Route | Page | Icon (outline / filled) |
|---|---|---|---|
| Home | `/store` | `StoreAreaScreen` | `shopping_bag_outlined` / `shopping_bag` |
| Products | `/store/products` | `SellerProductsScreen` | `inventory_2_outlined` / `inventory_2` |
| Activity | `/store/activity` | `SellerActivityScreen` | `receipt_long_outlined` / `receipt_long` |
| Messages | `/store/messages` | `ComingSoonScreen` | `chat_bubble_outline` / `chat_bubble` |
| Profile | `/store/profile` | `ProfileScreen(area: store)` | `person_outline` / `person` |

**Routing rules**: the shell branches are declared before `/store/:id`. The full screen routes of AC-6 stay top level and are declared after the shell. `/store/discover` and `/store/reels` are plain redirects to `/store`. A tab root and a full screen route never share a path: `/store/products` is a tab, `/store/products/new` is a full screen route.

**Components**: `SellerBottomNavBar` and `SellerTabItem` in `packages/shared/lib/widgets/seller_bottom_nav_bar.dart`. `SellerShell` in `apps/buyer/lib/core/router/seller_shell.dart` wraps the navigation shell with the bar. `AppShell` loses its `variant` parameter, because it only serves the buyer area now. `AppTabBarVariant` stays in the shared package until its own test is retired.

**Data model sketch**: none. No data is added or changed.

## Consequences

- Reels and Discover are no longer reachable from the store area. A seller reaches them by switching to the buyer area. Seller reel creation, if it is ever built, needs its own entry (spec 0015, AC-15).
- The Figma `tabbar-seller` component labels now read Home, Products, Activity, Messages, Profile (done with spec 0020). Its icons are still the buyer's (search for Products, play for Messages) and need swapping.
- Home quick actions that used `push` now use `go`, so Back from Products no longer returns to Home. This is the normal tab behavior.
- The Messages tab is a promise: the inbox needs a spec of its own (scope feature 12).
