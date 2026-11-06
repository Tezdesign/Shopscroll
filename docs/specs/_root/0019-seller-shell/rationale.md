# 0019 rationale: seller shell

## Context

The store area already had a shell: a second `StatefulShellRoute` under `/store` that reused the buyer's `AppShell` with a different border color. Its five tabs were the buyer's (Home, Discover, Reels, Activity, Profile). Products, the product flow, Notifications and Store policies sat outside it as plain routes, so on those screens the bar disappeared and a seller had no tab to go back to. The scope listed this as feature 30 "built without a spec".

## Options

1. **A dedicated seller bar and five seller tabs over the existing store shell.** (chosen)
2. **Keep the buyer tabs and only fix the labels.** Cheap, but Discover and Reels in the store area are buyer screens with buyer data. A seller who opens Reels is shown the buyer feed, not their store's reels.
3. **Make the bar configurable (a list of items passed in).** One widget for both areas. More general than anything needs today, and it would change the buyer bar and its tests for no seller benefit.
4. **No bar, a drawer or a "more" menu.** Moves every seller screen off the bottom of the phone, away from the way the buyer area works and from the Figma frames.

## Decision

Option 1. It gives the seller only seller screens, keeps the buyer bar and its tests untouched, and uses the same pattern the app already has (`StatefulShellRoute`, one bar widget, one shell widget). Option 3 is a later refactor if a third area ever appears.

## Choices made without asking

- **Products as a tab.** Products is the second thing a seller does after looking at the dashboard, and the dashboard reached it through a push. A tab removes that detour.
- **Messages as a placeholder.** Seller chat is not specified (spec 0011 is buyer only). A placeholder keeps the bar final, so the tab list does not change again when the inbox arrives.
- **Discover-seller dropped.** The Figma "Discover-seller" frame was never specified for sellers, and a seller's own discovery is the buyer area one tap away through the Buyer | Seller switch.
- **Detail and task screens stay full screen.** The product flow, policy forms and detail pages are tasks. Showing the bar there invites leaving a half filled form.
