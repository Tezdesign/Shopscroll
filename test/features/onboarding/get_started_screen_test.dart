import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/features/onboarding/get_started_screen.dart';

void main() {
  Widget wrap(GetStartedScreen screen) {
    return MaterialApp(theme: AppTheme.light, home: screen);
  }

  testWidgets('renders the heading and both fields', (tester) async {
    await tester.pumpWidget(wrap(GetStartedScreen(onContinue: (_, _) {})));

    expect(find.text('Let’s get started'), findsOneWidget);
    expect(find.text('Fullname'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
  });

  testWidgets('tapping Continue with empty fields shows the error state', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      wrap(GetStartedScreen(onContinue: (_, _) => called = true)),
    );

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Please enter your full name.'), findsOneWidget);
    expect(find.text('Please enter a username.'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets(
    'filling in a field clears its own error (AutovalidateMode.onUserInteraction)',
    (tester) async {
      await tester.pumpWidget(wrap(GetStartedScreen(onContinue: (_, _) {})));

      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Please enter your full name.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Jane Doe');
      await tester.pump();

      expect(find.text('Please enter your full name.'), findsNothing);
      expect(find.text('Please enter a username.'), findsOneWidget);
    },
  );

  testWidgets('filled valid fields call onContinue with the trimmed values', (
    tester,
  ) async {
    String? fullName;
    String? username;
    await tester.pumpWidget(
      wrap(
        GetStartedScreen(
          onContinue: (name, handle) {
            fullName = name;
            username = handle;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, '  Jane Doe  ');
    await tester.enterText(find.byType(TextFormField).last, '  janedoe  ');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(fullName, 'Jane Doe');
    expect(username, 'janedoe');
  });
}
