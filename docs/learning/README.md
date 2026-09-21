# Learning Flutter through Shopscroll

A short course on Flutter that uses **this project's own code** as the textbook. Every lesson
points at a real file you can open, so you learn Flutter and this codebase at the same time.

These lessons are not specs and no skill reads them. They are for you, so they are free to be
plain and opinionated.

## How to use a lesson

1. Read the lesson.
2. Open the file it points at, next to the lesson, and find the code it quotes.
3. Do the **Try it** step at the end. Changing something and watching what breaks teaches more
   than reading.

Line numbers drift as the code changes. Each lesson names the class or function too, so search
for that if a number is off.

## Fundamentals

| # | Lesson | The question it answers |
|---|---|---|
| 1 | [How the app starts](01-how-the-app-starts.md) | What runs first, and how does the first screen appear? |
| 2 | [Everything is a widget](02-widgets-and-build.md) | What is a widget, and what does `build` do? |
| 3 | [Layout](03-layout.md) | Why does this button sit at the bottom, and why did that crash? |
| 4 | [State and setState](04-state.md) | How does a screen change after it is shown? |
| 5 | [Theming and design tokens](05-theming-and-tokens.md) | Where do colours and sizes come from? |

## Coming next (not written yet)

Say which you want first.

- **Navigation with `go_router`**: how `/sign-in` becomes a screen. See `lib/core/router/app_router.dart`.
- **State across screens with Riverpod**: providers, `ref.watch`, and why the app uses them.
- **Async and futures**: `await`, `FutureProvider`, loading and error states.
- **Models and JSON**: `fromJson`, `toJson`, `copyWith`, and why models carry all three.
- **Talking to a backend**: the mock vs Supabase split and the repository pattern.
- **Testing widgets**: how the files under `test/` work.

## Commands you will use constantly

```bash
flutter pub get                                  # install packages from pubspec.yaml
flutter run --dart-define-from-file=env.json     # run the app with Supabase and Clerk configured
flutter analyze                                  # static checks, like a linter plus type checker
flutter test                                     # run every test under test/
```

While the app is running in a terminal:

- `r` is **hot reload**. It injects your code changes and keeps the app's state.
- `R` is **hot restart**. It restarts the app from `main()` and resets all state.

If a change does not show up after `r`, try `R`. Anything that runs once at startup (like `main()`)
only re-runs on a restart.

## A note on experimenting safely

This repo has a lot of uncommitted work. **Do not use `git checkout` or `git restore` to undo an
experiment.** They would throw away real changes along with your experiment. Undo with your editor
(Ctrl+Z) instead, or commit or stash your work first.

## Map of the project

```
lib/
  main.dart            the entry point (lesson 1)
  core/                app wide plumbing: theme, router, auth, config
  data/                models, mock data, repositories, providers
  features/            one folder per feature: catalog, discover, reels, profile, onboarding
  shared/widgets/      reusable widgets used by several features (lesson 2)
test/                  mirrors lib/: a file in lib/x/y.dart is tested in test/x/y_test.dart
docs/                  scope, specs and these lessons
```
