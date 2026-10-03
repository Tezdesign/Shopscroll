import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:marketplace_app/features/onboarding/setting_up_account_screen.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

  testWidgets('shows the ring and its line of text', (tester) async {
    await tester.pumpWidget(
      wrap(SettingUpAccountScreen(onDone: () {}, duration: Duration.zero)),
    );

    expect(find.text('Setting up your account'), findsOneWidget);
    // MaterialApp's own page transition is a RotationTransition too, so look
    // for the one actually turning the ring.
    expect(
      find.ancestor(
        of: find.byType(Image),
        matching: find.byType(RotationTransition),
      ),
      findsOneWidget,
    );

    await tester.pump(SettingUpAccountScreen.rotationPeriod);
  });

  testWidgets('offers nothing to tap: it finishes on its own', (tester) async {
    await tester.pumpWidget(
      wrap(SettingUpAccountScreen(onDone: () {}, duration: Duration.zero)),
    );

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);

    await tester.pump(SettingUpAccountScreen.rotationPeriod);
  });

  testWidgets('calls onDone once the wait is over, not before', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      wrap(
        SettingUpAccountScreen(
          onDone: () => done++,
          duration: const Duration(seconds: 2),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    expect(done, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(done, 1);
  });

  testWidgets('does not call onDone after being left', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      wrap(
        SettingUpAccountScreen(
          onDone: () => done++,
          duration: const Duration(seconds: 2),
        ),
      ),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));

    expect(done, 0);
  });
}
