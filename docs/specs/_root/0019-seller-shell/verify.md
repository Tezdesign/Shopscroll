# 0019 verify: seller shell

Run `flutter analyze` at the root, then `flutter test` in `apps/buyer` and in `packages/shared`.

| AC | Check | Where |
|---|---|---|
| AC-1 | A seller at `/store` sees five labels in order, tapping each opens its route, tapping the active tab returns to its root | `apps/buyer/test/core/router/app_shell_test.dart` |
| AC-2 | `/store/discover` and `/store/reels` land on the dashboard | `apps/buyer/test/core/router/app_shell_test.dart` |
| AC-3 | Leave Products on its Drafts chip, go to Home and back, the chip is still Drafts | manual on a device or simulator |
| AC-4 | A buyer opening `/store/products` ends in the buyer area | `apps/buyer/test/core/router/app_shell_test.dart` |
| AC-5 | The Products tab has no back arrow | `apps/buyer/test/features/seller_products/` |
| AC-6 | Product flow, policies and notifications show no tab bar | manual |
| AC-7 | Quick actions Products, Orders, Reports switch the tab | `apps/buyer/test/features/store/store_area_screen_test.dart` |
| AC-8 | The Messages tab shows the Coming soon page | `apps/buyer/test/core/router/app_shell_test.dart` |
| AC-9 | The buyer bar test and the buyer tab tests still pass unchanged | `packages/shared/test/widgets/app_bottom_nav_bar_test.dart` |
| AC-10 | The seller bar uses `neutral300`, `primary400` and `neutral600` | `packages/shared/test/widgets/seller_bottom_nav_bar_test.dart` |
| AC-11 | Each tab is at least 44 by 44 and says its name and selected state | `packages/shared/test/widgets/seller_bottom_nav_bar_test.dart` |
| AC-12 | `git diff` shows no change under `supabase/` and no new provider | review |
