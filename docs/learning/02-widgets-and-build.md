# 2. Everything is a widget

**Question:** what is a widget, and what does `build` do?

**Open:** `lib/shared/widgets/app_button.dart`

## The one idea

A **widget is a description of a piece of the screen**, not the piece itself. It is a small,
immutable object that says "a button, with this label, in this colour". Flutter reads the
description and draws it.

Because widgets are only descriptions, they are cheap. Flutter throws them away and recreates them
constantly, and that is normal, not a bug.

Text, buttons, padding, a row, a screen, even the whole app: all widgets. Widgets contain other
widgets, which is how you get the tree from lesson 1.

## Two kinds of widget

| Kind | Remembers things between rebuilds? | Use when |
|---|---|---|
| `StatelessWidget` | No. Same inputs, same output. | It only shows what it is given |
| `StatefulWidget` | Yes, in a separate `State` object | It changes on its own (lesson 4) |

`AppButton` is stateless. It does not decide anything: the screen tells it the label, whether it is
`enabled`, and what to do on tap.

## Reading `AppButton`

```dart
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.big,
    this.enabled = true,
    this.leadingIcon,
    this.trailingIcon,
    this.onPressed,
  });

  final String label;
  final AppButtonVariant variant;
  final bool enabled;
  final VoidCallback? onPressed;
  // ...
```

Three things to learn from this constructor:

- **Fields are `final`.** A widget never changes after it is created. To show something different,
  the parent creates a *new* `AppButton`.
- **`required` vs a default.** `label` must be supplied; `enabled` defaults to `true`. That is how
  `AppButton(label: 'Log in')` works with nothing else.
- **`VoidCallback? onPressed`** is a function the button calls when tapped. The button does not know
  what "Log in" does. The *screen* passes that in. This keeps buttons reusable.

## What `build` does

Every widget has a `build` method. It returns other widgets. Flutter calls it whenever the widget
needs to appear or change.

```dart
@override
Widget build(BuildContext context) {
  final spec = _spec;

  return Container(
    width: spec.fixedWidth,
    height: spec.height,
    decoration: BoxDecoration(
      color: spec.background,
      borderRadius: BorderRadius.circular(spec.cornerRadius),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: EdgeInsets.symmetric(/* ... */),
          child: Row(/* icon, then Text(label) */),
        ),
      ),
    ),
  );
}
```

Read it from the outside in: a `Container` (the coloured rounded box) holds a `Material` holds an
`InkWell` (adds the tap ripple) holds `Padding` holds a `Row` holds the `Text`. Each widget does
**one small job** and wraps the next. Flutter code looks nested because it is a tree.

Note `onTap: enabled ? onPressed : null`. Passing `null` makes the `InkWell` ignore taps. That one
line is the entire "disabled" behaviour.

## Composition, not inheritance

`AppButton` does not extend some giant `Button` class and override things. It *assembles* small
widgets. Flutter's rule of thumb is "compose, do not extend", and it is why you end up with the
`_Prefixed` little private widgets in screen files, like `_AccountTypeToggle` in
`log_in_screen.dart`. Root `AGENTS.md` says the same: reusable ones go in `shared/widgets/`, one
off ones stay private in the screen file.

## `BuildContext`

The `context` argument is the widget's **location in the tree**. It is how a widget asks questions
about what is above it (`Navigator.of(context)`, `MediaQuery.of(context)`). You rarely use it
directly yet, but you will pass it around a lot.

## Try it

1. Open `lib/features/onboarding/log_in_screen.dart` and find `AppButton(`. Change the `label` to
   something else. Hot reload (`r`). Undo with Ctrl+Z.
2. In `AppButton.build`, change `onTap: enabled ? onPressed : null` to `onTap: onPressed`.
   Hot reload. Does a disabled button still respond to taps? Undo it.
3. Find the `_spec` getter in the same file. It is a `switch` over the variant and size that picks
   colours. Which token is used for the disabled primary button background?

**Check yourself:** `AppButton` never changes its own `enabled` field. So how does the Log in
button go grey while a request is running? (Hint: who builds the `AppButton`?)
