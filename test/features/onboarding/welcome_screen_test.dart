import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/features/onboarding/welcome_screen.dart';

void main() {
  Widget wrap(WelcomeScreen screen) {
    return MaterialApp(theme: AppTheme.light, home: screen);
  }

  testWidgets('renders the wordmark, tagline, and seller callout', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(WelcomeScreen(onSignUp: () {}, onLogIn: () {}, onSkip: () {})),
    );

    expect(find.text('Shopscroll'), findsOneWidget);
    expect(
      find.text('All of your online shopping in one place.'),
      findsOneWidget,
    );
    expect(find.textContaining('Apply now'), findsOneWidget);
  });

  testWidgets('tapping Sign up invokes onSignUp', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        WelcomeScreen(
          onSignUp: () => tapped = true,
          onLogIn: () {},
          onSkip: () {},
        ),
      ),
    );

    await tester.tap(find.text('Sign up'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('tapping Log in invokes onLogIn', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        WelcomeScreen(
          onSignUp: () {},
          onLogIn: () => tapped = true,
          onSkip: () {},
        ),
      ),
    );

    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('tapping Skip for now invokes onSkip', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        WelcomeScreen(
          onSignUp: () {},
          onLogIn: () {},
          onSkip: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Skip for now'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
