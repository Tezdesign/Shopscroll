# 1. How the app starts

**Question:** what runs first, and how does the first screen appear?

**Open:** `lib/main.dart`

## The one idea

A Flutter app is a **tree of widgets**. Starting the app means handing Flutter the top of that tree.
Everything you see on screen is a branch of it.

Dart begins at a function called `main()`. Flutter's job in `main()` is to call `runApp(...)` with
the root widget.

## What this project's `main()` does

Trimmed from `lib/main.dart` (the `main` function starts at line 23):

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final onboardingPrefs = OnboardingPrefs(
    await SharedPreferences.getInstance(),
  );

  // ...several branches, each ends with runApp(...)...

  runApp(
    ProviderScope(
      overrides: [ /* ... */ ],
      child: MarketplaceApp(/* ... */),
    ),
  );
}
```

Step by step:

1. **`void main() async`**: `async` lets the function `await` things that take time, like reading
   from disk. Lesson on async is coming; for now, `await` means "wait for this, then continue".
2. **`WidgetsFlutterBinding.ensureInitialized()`**: sets up the connection between Flutter and the
   phone. You must call it before using anything that talks to the platform, *before* `runApp`.
   Here that is `SharedPreferences` (the phone's small key value storage). Forgetting it is a
   classic first crash.
3. **`runApp(...)`**: takes one widget and makes it the root of the tree. Flutter draws it and
   keeps it drawn.

## Why `main()` has three `runApp` calls

`main()` checks how much is configured and starts the app accordingly:

| Condition | What runs |
|---|---|
| No Supabase config (`SupabaseConfig.isConfigured` is false) | Mock data only, no real backend |
| Supabase but no Clerk | Real backend, anonymous users only |
| Both configured | The full app with real sign in |

Each branch ends in `return;` after its own `runApp`, so only one runs. This is why the root
`AGENTS.md` says the app "silently falls back to mock data" without `--dart-define-from-file`.
Nothing crashed; `main()` just took the first branch.

## The tree it builds

```
ProviderScope                 (Riverpod, holds app wide state: a later lesson)
└── MarketplaceApp
    └── ClerkAuth             (only if Clerk is configured)
        └── MaterialApp.router
            └── whichever screen the router says is current
```

`MarketplaceApp` is at line 173. Its `build` method (line 219) returns the `MaterialApp.router`.
`MaterialApp` is the widget that gives you navigation, the theme, and the default look of a
Material app. This project uses the `.router` version because navigation is handled by `go_router`
(a later lesson), which is passed in as `routerConfig`.

## Things to notice

- **`const MarketplaceApp()`**: `const` means the widget is created once at compile time and reused.
  Flutter uses it to skip rebuilding parts of the tree that cannot have changed. You will see
  `const` everywhere; the analyzer even nags you to add it.
- **`ProviderScope` wraps everything**, so any widget below it can read shared state. It has to be
  at the top for that reason.
- **`overrides:`** swap real pieces for other ones. This is how the mock backend gets replaced by
  the Supabase one without any screen changing.

## Try it

1. In a terminal, run `flutter run --dart-define-from-file=env.json`.
2. Then stop it and run just `flutter run` with no flag. Notice the app now shows mock data and
   Profile looks empty. That is the first branch of `main()` you just took.
3. Search `main.dart` for `kDebugMode`. Find what it changes about which screen opens first.

**Check yourself:** why is `ensureInitialized()` before `SharedPreferences.getInstance()` and not
after it?
