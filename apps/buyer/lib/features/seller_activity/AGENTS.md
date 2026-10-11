# lib/features/seller_activity

The seller's Activity area at `/store/activity`: Orders, Earnings and Reports tabs, an order detail page and a
report detail page. Only a seller stays (`SellerGate` is inside each screen).
Governing spec: `docs/specs/_root/0018-seller-activity-screens/index.md` (acceptance criteria AC-1 to AC-17,
checklist in `verify.md` beside it). Backend: `supabase/migrations/0014` to `0017`, see `supabase/AGENTS.md`.

## Files

- `seller_activity_screen.dart` (`SellerActivityScreen`): store header, one search field shared by the tabs, the
  tab row (swaps the body in place, the route stays), and the "+" button to `/store/products/new`. The chat icon
  is inert; the bell opens `/store/notifications`.
- `orders_tab.dart`: status chips (one active, tap again clears), rows, paging of 20, pull to refresh.
- `earnings_tab.dart`: a period selector (Today, This Week, All time), one hero card, a small card row and the 4
  latest sales. The UI audit of Oct 2026 replaced the four always on cards of AC-6 with this.
- `reports_tab.dart`: three number cards, report cards, paging, Resolve. `report_widgets.dart`: the status
  badge, `ReportButton` (44 high) and `confirmAndResolveReport` (the "Confirm resolution" alert).
- `store_order_detail_screen.dart` and `store_report_detail_screen.dart`: the two detail routes
  (`/store/activity/orders/:id`, `/store/activity/reports/:id`). Both are read only except Resolve.
- `store_order_status_badge.dart` (Returned is a fourth neutral style Figma does not draw),
  `activity_message.dart` (`ActivityMessage` and the 44 high `RetryButton`).
- Data: `lib/data/models/store_order.dart`, `store_report.dart`, `lib/data/providers/store_activity_providers.dart`
  and the `StoreActivityRepository` pair (mock and Supabase) under `lib/data/repositories/`.

## Conventions

- Sellers never read tables. Every read goes through a `security definer` function that filters on the caller's
  Clerk id, and an order or report of another store gives `not_found`, the same as an unknown id.
- Lists page by keyset. The cursor keeps `created_at` as the raw string the server wrote, never a `DateTime`,
  which would drop microseconds and repeat or skip a row.
- Providers turn retry off on purpose, so a failed load reaches the screen as an error with its own "Try again".
- Resolve is optimistic: `resolveStoreReportProvider` changes the list row, the detail and the Unresolved card at
  once, touches only providers that are alive (`ref.exists`), and puts them back if the call fails.
- Nothing here lets a seller change an order status, create a report or message a buyer (AC-17). Those are later
  features (28 and 29 in `docs/scope/_root/scope.md`).
- The mock repository follows the SQL (filter, search, paging, resolve), so both backends behave the same.
  Screens show the order's currency with `Money.format`, which adds thousands commas (`478,458.000 TND`).
- Every tap area is at least 44 by 44 (AC-16). `AppButton` is about 42 high, so use `ReportButton` or `RetryButton`.
- Widget tests need a tall view (800 by 6000) so a lazy list builds its rows, and must wait `mockNetworkDelay`
  once per load.

_Drafted by /sync from the introducing change, worth a quick human pass._
