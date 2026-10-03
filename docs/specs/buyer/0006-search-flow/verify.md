# Verify: search flow · spec 0006 · updated 2026-09-22
_Steps derived from spec 0006 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._

## UI / manual
- [ ] On Home, tap the search field → `/search` opens, keyboard is up, field is empty, bottom tab bar shows with Home highlighted → AC-1
- [ ] On Discover, tap the search field → `/discover/search` opens the same screen, with Discover highlighted → AC-1
- [ ] On Reels, confirm its own search field still filters the reel grid inline, unchanged → AC-1
- [ ] Tap Cancel → returns to the tab you came from, with its scroll position and state intact → AC-2
- [ ] Use the system back gesture instead of Cancel → same result → AC-2
- [ ] Open the screen with nothing typed → a "Popular categories" tile per real category (Fashion, Tech, Sports, Makeup), ordered by product count then name; tapping one opens results headed `Results for "<category>"` → AC-3, AC-6
- [ ] Type one character → the Items tab is selected, category chips for matching categories and a suggestion list appear, both an Items and a Stores tab are visible → AC-4
- [ ] Type "nik" → suggestion rows show the typed prefix in bold and each row's category on the right, ranked by frequency then alphabetically, capped at 8 → AC-5
- [ ] Type "apple" (a store name/category only match) → suggestions fall back to matching product titles → AC-5
- [ ] Tap a suggestion, a category chip, and a category tile (three separate runs) → each opens the results view, the field shows the chosen phrase, and the heading reads `Results for "<phrase>"` → AC-6
- [ ] With the keyboard's Search key after typing text → same results view, phrase equals the typed text → AC-6
- [ ] Search "nike" (store name) and "tech" (category) → both return matching products, in the product list's own order → AC-7
- [ ] In the results view, select the Deals chip → only `isDeal` products remain; a category chip/tile chosen earlier also still limits results to that category → AC-7
- [ ] A result row shows image, store avatar + name, title and price; tapping it opens `/product/:id`; tapping its add to cart icon flips it to "added" for the session without changing the real cart → AC-8
- [ ] Type "app" → the Stores tab lists sellers whose name contains it in a 4 column grid; tapping Apple opens results headed `Results for "Apple"` listing only Apple's products by `storeId` → AC-9
- [ ] With nothing typed, confirm the Stores tab is not reachable → AC-9
- [ ] Type text that matches nothing, on both tabs and in the results view → `No results found for "<text>"` each time → AC-10
- [ ] Throttle/disable the network (or simulate a provider error) → a loading indicator, then an error message, on this screen → AC-10
- [ ] From the results view, edit the text → returns to the suggestions view for the new text; clear the field → returns to the nothing typed view → AC-11
- [ ] Close the screen and reopen it → starts blank again, no recent searches shown → AC-11
- [ ] On Discover, confirm typing no longer filters the feed, and its category tabs/store grid/product feed are otherwise unchanged → AC-12
- [ ] Run the same searches against the Supabase backend (`--dart-define-from-file=env.json` with Supabase configured) → same behavior as the mock backend → AC-13
- [ ] With a screen reader on, confirm every row/chip/tile and Cancel announce a label, and each has at least a 44x44 tap area → AC-14
- [ ] On a small phone, open the screen and confirm the bottom tab bar's behavior with the keyboard up is acceptable (build plan task 10, not yet checked) → AC-1

## Commands
- [ ] `flutter test test/features/search/` → all pass (unit tests for `search_logic.dart`, widget tests for `SearchScreen`) → AC-5, AC-7, AC-13
- [ ] `flutter analyze` → no issues → project convention, not a numbered AC

## Acceptance-criteria coverage
- AC-1 … opening from Home/Discover, keyboard/tab bar, Reels unaffected · AC-2 … Cancel/back · AC-3 … Popular categories · AC-4 … Items/Stores tabs appear · AC-5 … suggestion ranking + fallback (`search_logic_test.dart`) · AC-6 … opening the results view · AC-7 … phrase/category/deals matching (`search_logic_test.dart`) · AC-8 … result row + add to cart toggle · AC-9 … Stores tab (`search_logic_test.dart`) · AC-10 … loading/error/no results · AC-11 … edit/clear transitions, nothing persisted · AC-12 … Discover's filter removed · AC-13 … on-device search, backend parity (`search_logic_test.dart`) · AC-14 … accessibility labels and tap areas
