# 4. State and setState

**Question:** how does a screen change after it is shown?

**Open:** `lib/features/onboarding/log_in_screen.dart` (`LogInScreen` at line 68, `_LogInScreenState`
at line 108) and `lib/features/onboarding/verification_code_section.dart`

## The one idea

A `StatelessWidget` (lesson 2) can only show what it is handed. To *change over time*, a widget
needs memory. Flutter splits a stateful widget into **two classes**:

```dart
class LogInScreen extends StatefulWidget { ... }                 // line 68: the configuration
class _LogInScreenState extends State<LogInScreen> { ... }       // line 108: the memory
```

Why two? Because widgets are thrown away and recreated all the time (lesson 2), but the `State`
object **survives**. The widget is the disposable description, and the `State` is the long lived
thing that remembers. Every time `LogInScreen` is rebuilt, Flutter reattaches the same
`_LogInScreenState`.

## What this screen remembers

The fields at the top of `_LogInScreenState`:

```dart
final _emailController = TextEditingController();
final _codeController  = TextEditingController();

LogInChannel _channel     = LogInChannel.email;
AccountType  _accountType = AccountType.buyer;
String? _identifierError;
String? _codeError;
bool _verifying = false;
bool _busy      = false;
```

Every one of these is something that changes while the screen is open, and that the screen must
draw differently because of it.

## `setState`: how a change becomes visible

Changing a field does nothing on screen by itself. You have to tell Flutter to rebuild:

```dart
setState(() => _busy = true);
```

`setState` does two things: it runs your function (which changes the field), then it **marks the
widget dirty so `build` runs again**. The new `build` reads the new values and returns a different
tree.

Here is the whole idea in this screen. `_verifying` decides which stage you see:

```dart
if (_verifying) ...[
  VerificationCodeSection(...),   // only exists once a code was sent
  ...
],
```

And `_busy` decides whether the button is grey:

```dart
AppButton(label: 'Log in', enabled: !_busy, /* ... */)
```

Nothing is "shown" or "hidden" by commands. The screen is a **function of its state**: given these
values, `build` returns this tree. Change the values, rebuild, get a different tree. This is the
central habit of Flutter, and the reason you never write "set this label to X" imperatively.

## Follow one tap through `_continue`

Tapping **Log in** on the first stage runs `_continue` (search for it). In order:

1. Validate. If it fails: `setState(() => _identifierError = error)` then `return`. The red message
   appears because `build` now passes `errorText` to the field.
2. Otherwise `setState(() { _identifierError = null; _busy = true; })`. The button goes grey.
3. `await widget.onSendCode(...)`. The screen waits for Clerk. Nothing is frozen: Flutter keeps
   drawing while it waits.
4. `if (!mounted) return;` **See below.**
5. `setState(() { _busy = false; _verifying = true; })`. The button comes back and the code field
   appears.

## `mounted`: the check after every `await`

Step 4 matters. While the app waited for Clerk, the person may have closed the screen. If the code
then called `setState` on a screen that no longer exists, Flutter throws. `mounted` is `true` only
while the `State` is still in the tree, so the pattern is:

```dart
await something();
if (!mounted) return;
setState(() => ...);
```

Any time you `await` and then touch state or the `context`, put the check in.

## `widget.`: reaching the configuration

Inside the `State`, the screen's constructor arguments are reached through `widget`:

```dart
await widget.onSendCode(_channel, _identifier);
```

`onSendCode` was given to `LogInScreen`, not to the `State`, so it is `widget.onSendCode`.

## Lifecycle, and why `dispose` exists

A `State` has a life:

| Method | When | Typical use |
|---|---|---|
| `initState` | Once, when created | Start timers, create things |
| `build` | Every time it must draw | Return the tree. Keep it fast and free of side effects |
| `dispose` | Once, when removed | Release everything you created |

`TextEditingController`s and `Timer`s hold resources. If you do not release them, they leak. So
`_LogInScreenState.dispose` (line 126) ends with:

```dart
_emailController.dispose();
_phoneController.dispose();
_codeController.dispose();
super.dispose();
```

A real example of the pair is in `verification_code_section.dart`. It starts the resend countdown
in `initState` (`Timer.periodic`) and cancels it in `dispose` (`_timer?.cancel()`). Without that
cancel, the timer would keep calling `setState` on a screen that is gone.

Rule of thumb: **anything you create in `initState` or as a field, you `dispose` in `dispose`.**

## State that only one widget owns

`_busy` and `_verifying` live in this `State` because nobody else needs them. That is the simplest
kind of state, called *local* or *ephemeral* state. When *several screens* need the same data (the
cart, the signed in user), it cannot live in one widget's `State`. That is what Riverpod is for,
and it is its own lesson.

## Try it

1. In `_continue`, add a `print('busy: $_busy');` line right after each `setState` that touches
   `_busy`. Run the app, go to Log in, submit a valid email, and read the sequence in the terminal.
2. Temporarily remove `_codeController.dispose();` from `dispose`. Run `flutter analyze`. Does
   anything complain? (Flutter will not always tell you about a leak; that is why it is a habit,
   not a check.) Put it back.
3. In `_switchChannel`, find what it resets. Why does switching channel set `_verifying = false`?

**Check yourself:** why can you not just write `_busy = true;` without `setState`? What would the
screen do?
