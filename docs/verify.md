# Verify steps

Manual walkthroughs for `/check verify`, one section per built feature. Each step maps to an
acceptance criterion in that feature's spec.

## Reels screen (spec [0002](specs/0002-reels-screen.md))

1. Tap the Reels bottom nav tab → grid loads 10 reel cards with a search field and "For you" /
   "Following" tabs. (AC-1)
2. Type a store name or caption fragment into the search field → the grid narrows live, matching
   case-insensitively. (AC-2)
3. `reel-009` renders dimmed and grayscale with a "No longer available" label, and tapping it does
   nothing. (AC-3)
4. Tap an available reel → the full screen player opens on that reel, autoplays muted, and swiping
   up/down moves through the same (possibly search-filtered) order shown in the grid. (AC-4)
5. The player shows a right side action rail, a bottom overlay (avatar, store name, Follow button,
   caption), a thin per-reel progress bar, and a buffering spinner while a reel is still
   initializing. (AC-5)
6. Tap "Shop the look" on a reel with tagged products → a sheet lists them; tapping a tile
   navigates to `/product/:id`. (AC-6)
7. Tap like/save on a reel → the icon fills and the count updates optimistically; swipe away and
   back → the state persists; leave the player screen and reopen it → every reel resets to its
   original mock values. (AC-7)
8. Confirm the grid and the player's initial load each show their own loading indicator while
   `reelsProvider` resolves, and an empty/error state would render in place of a blank screen.
   (AC-8)
