# 5. Theming and design tokens

**Question:** where do colours and sizes come from?

**Open:** `lib/core/theme/app_theme.dart`

## The one idea

A screen should never contain a raw number or colour like `Color(0xFF0066FF)` or `EdgeInsets.all(16)`.
It should say what the value *means*: "the primary colour", "the standard gap". If the design
changes, you edit one file instead of hunting through fifty.

Those named values are called **design tokens**. This project takes them from the Figma file's
variable collection, so a name in Flutter matches a name in Figma. The root `AGENTS.md` makes this a
rule: *never write a literal `Color(0x...)` or raw size in a screen or widget; use the tokens.*

## The four token classes

All in `app_theme.dart`. Each is a class with only `static const` values, and a private constructor
(`AppSpacing._()`) so nobody can create an instance of it. It is just a namespace.

| Class | What it holds | Example |
|---|---|---|
| `AppColors` | The colour palette | `AppColors.primary400` is `0xFF0066FF` |
| `AppSpacing` | Gaps and padding | `xs 4`, `sm 8`, `md 12`, `base 16`, `lg 20`, `xl 24` |
| `AppRadius` | Corner rounding | `none 0`, `sm 4`, `md 8`, `full 999` |
| `AppTypography` | Fonts and sizes | `sizeBase 16`, fonts Inter and Plus Jakarta Sans |

Colours come in numbered **ramps**: `primary50` through `primary600`, `neutral100` through
`neutral1100`, and so on. Lower numbers are lighter. So in the Log in screen:

- selected toggle half: `primary100` background, `primary500` text
- unselected half: `neutral200` background, `neutral400` text
- error red: `error500`

## Using them

Compare the two ways of writing the same gap:

```dart
const SizedBox(height: 16)                 // a magic number: why 16?
const SizedBox(height: AppSpacing.base)    // "the standard gap", greppable and changeable
```

`AppSpacing.base` is 16 because that is the screen's side gutter in Figma. When the Figma frames
showed `16` between the heading and the field, the code says `AppSpacing.base`, and both point at the
same idea. You have seen this on every screen in the onboarding flow.

Why `static const`? `const` values are fixed at compile time, so using them costs nothing at runtime,
and they can go inside `const` widgets like `const SizedBox(height: AppSpacing.base)`. That is what
lets Flutter skip rebuilding them (lesson 1).

## `ThemeData`: the Flutter side of the same idea

Flutter has its own theming system too. `AppTheme.light` builds a `ThemeData`:

```dart
static ThemeData get light => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: _lightColorScheme,
  scaffoldBackgroundColor: AppColors.neutral100,
  // text theme, button theme, ...
);
```

and `lib/main.dart` hands it to the app (lines 225 and 226):

```dart
theme: AppTheme.light,
darkTheme: AppTheme.dark,
```

`useMaterial3: true` opts into Material 3, Google's current design language. `ColorScheme` tells
Material widgets (a bare `ElevatedButton`, an `AppBar`) what "primary" means, so they match your brand
without being styled one by one.

## The thing to know: this project mostly bypasses `Theme.of`

The usual Flutter way to read a theme value is:

```dart
final color = Theme.of(context).colorScheme.primary;
```

`Theme.of(context)` looks up the tree (remember `BuildContext` from lesson 2) and finds the nearest
theme. It is powerful because a *different* theme can be applied to a whole subtree, and dark mode
works automatically.

**Nothing in `lib/` calls `Theme.of`.** Screens read the tokens directly instead:

```dart
backgroundColor: AppColors.neutral100,
```

That is simpler and matches Figma one to one. It has a cost, though. `AppColors.neutral100` is a
`const` that is *always* white. It cannot change with the theme. So even though `AppTheme.dark`
exists and is passed to `MaterialApp`, a screen that hard reads `AppColors.neutral100` stays white
when the phone is in dark mode.

That is a genuine trade off, not a mistake: the design so far is light only, and tokens keep it
consistent. Whether dark mode is a goal is a product decision. If it becomes one, the tokens would
need to become theme aware, and `Theme.of` (or a `ThemeExtension`) is how.

## Where fonts come from

`AppTypography.fontFamilyBody = 'Inter'` and `fontFamilyDisplay = 'Plus Jakarta Sans'`. A doc comment
in that class notes that Figma's variable is named `GeneralSans` but resolves to Plus Jakarta Sans.
Names in a design file and the real font can disagree, and the code follows what actually renders.

## Try it

1. In `AppSpacing`, change `base` from `16` to `24` and hot reload. Every screen using it shifts at
   once. That is the whole payoff of tokens. Put it back (Ctrl+Z).
2. Set your simulator to **dark mode** and open Log in. Is the background still white? That confirms
   the trade off above with your own eyes.
3. Search the project for `Color(0x`. Outside `app_theme.dart`, how many do you find? Each one is a
   place that breaks the rule.
4. Find `class AppColors` and locate the `error` ramp. Which shade does the field's red border use?

**Check yourself:** why is `AppSpacing` written `AppSpacing._();` with a private constructor?
