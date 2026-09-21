# 3. Layout

**Question:** why does the Log in button sit at the bottom, and what goes wrong when it does not fit?

**Open:** `lib/features/onboarding/log_in_screen.dart`, the `build` method of `_LogInScreenState`

## The one idea

Flutter layout runs on a single rule:

> **Constraints go down. Sizes go up. The parent sets the position.**

A parent tells each child "you may be between this wide and that wide, this tall and that tall".
The child picks a size inside those limits and reports it back. The parent then decides where to
put it. Almost every layout bug is a misunderstanding of one of those three sentences.

## The layout widgets you will use most

| Widget | What it does |
|---|---|
| `Column` / `Row` | Lays children out top to bottom / left to right |
| `Padding` | Adds space around one child |
| `SizedBox` | A fixed size box. `SizedBox(height: 16)` is a 16px gap |
| `Expanded` | Inside a Row/Column, take a share of the leftover space |
| `Spacer` | An empty `Expanded`. Pushes things apart |
| `SafeArea` | Keeps content out from under the notch and home indicator |
| `Align` / `Center` | Position one child inside its parent |

## Reading the Log in screen

Trimmed from `_LogInScreenState.build`:

```dart
body: SafeArea(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.base),
        Text('Welcome back !', /* ... */),
        const SizedBox(height: AppSpacing.base),
        _AccountTypeToggle(/* ... */),
        const SizedBox(height: AppSpacing.base),
        AppTextField(/* the identifier */),
        // ... the code field and the switch link appear here in the verify stage ...
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: AppButton(label: 'Log in', /* ... */),
        ),
        // ... two footer lines ...
      ],
    ),
  ),
),
```

Read it outside in:

1. **`SafeArea`** keeps everything clear of the status bar and home indicator.
2. **`Padding` with horizontal 16** is the screen's left and right gutter. This is the `16px` you
   saw all through the Figma frames.
3. **`Column`** stacks everything vertically. `crossAxisAlignment: start` means "left align" (the
   cross axis of a Column is horizontal).
4. **`SizedBox(height: 16)`** between items is how spacing is done. There is no `margin` in Flutter;
   you use padding or gaps.
5. **`Spacer()`** is the important one. It swallows *all leftover vertical space*, which pushes
   everything after it, the button and footers, to the bottom. That is the entire trick behind "a
   button pinned to the bottom".
6. **`SizedBox(width: double.infinity, ...)`** around the button forces it to fill the full width.
   `AppButton` on its own hugs its content; this wrapper is what stretches it.

## Main axis and cross axis

For a `Column`, the **main axis is vertical** and the **cross axis is horizontal**. For a `Row` it
is the other way round. So:

- `mainAxisAlignment` spreads children along the direction of the layout.
- `crossAxisAlignment` aligns them across it.

A frequent beginner mistake is reaching for `crossAxisAlignment` to move something up or down in a
`Column`. That is the main axis.

## `Expanded` in a Row: the toggle

`_AccountTypeToggle` (Buyer / Store owner) is a `Row` with two `Expanded` children:

```dart
child: Row(
  children: [
    Expanded(child: _half(AccountType.buyer, ...)),
    Expanded(child: _half(AccountType.storeOwner, ...)),
  ],
),
```

Two `Expanded` with no `flex` split the width **equally**. This is exactly the fix made in Figma
earlier, where the halves were 105 and 153 wide and the pill changed size when you tapped it.

## The layout problem hiding in this screen

`Column` with a `Spacer` works only because the `Column` is given a **fixed height**: the space
between the app bar and the bottom of the screen. Two consequences:

**1. The screen does not scroll.** No screen in `lib/features/onboarding/` contains a
`SingleChildScrollView` or `ListView`.

**2. When the keyboard opens, `Scaffold` shrinks the body.** This is on by default
(`resizeToAvoidBottomInset`, and nothing in this project turns it off). The body gets shorter by
the keyboard's height. The `Spacer` gives up its space first, so the button rises and stays visible
above the keyboard. That part works.

But if the *fixed* content (heading, toggle, fields, links, button, footers) is taller than the
space that is left, there is nothing for the `Spacer` to give up. Flutter then reports
`A RenderFlex overflowed by N pixels`, drawn as a yellow and black stripe in debug. On a short
phone with the verify stage showing (two fields and a resend line), this is the case to worry about.

The two usual fixes, both real choices:

- **Make it scrollable.** But you cannot just wrap the `Column` in a `SingleChildScrollView`: a
  scroll view gives its child *unbounded* height, and a `Spacer` inside unbounded height throws
  `RenderFlex children have non-zero flex but incoming height constraints are unbounded`. The
  standard answer is `CustomScrollView` with `SliverFillRemaining(hasScrollBody: false)`, which is
  scrollable when it must be and behaves like your `Column` when there is room.
- **Accept it** if the content fits on every phone you support.

## Debugging layout

Run the app and open **Flutter DevTools** (`flutter run` prints a link). The *Widget Inspector* has a
**Layout Explorer**: click a widget and it shows the constraints it received and the size it chose.
That is "constraints go down, sizes go up" made visible.

## Try it

1. In `log_in_screen.dart`, replace `const Spacer(),` with `const SizedBox(height: 24),`. Hot
   reload. The button jumps from the bottom to just under the fields. Undo with Ctrl+Z.
2. Run on a **small simulator** (for example iPhone SE). Go to Log in, tap the field so the keyboard
   opens, and get to the verify stage. Does an overflow stripe appear? This is a real test of the
   concern above. Nobody has run it yet.
3. Change one `Expanded` in `_AccountTypeToggle` to `Expanded(flex: 2, ...)`. Watch the halves stop
   being equal. Undo.

**Check yourself:** why does `SizedBox(width: double.infinity, child: AppButton(...))` stretch the
button, when `AppButton` alone does not?
