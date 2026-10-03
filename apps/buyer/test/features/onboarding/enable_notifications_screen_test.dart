import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:marketplace_app/features/onboarding/enable_notifications_screen.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';
import 'package:shopscroll_shared/widgets/enable_notifications_illustration.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

  EnableNotificationsScreen screen({
    VoidCallback? onEnable,
    VoidCallback? onRemindLater,
    VoidCallback? onBack,
  }) => EnableNotificationsScreen(
    onEnable: onEnable ?? () {},
    onRemindLater: onRemindLater ?? () {},
    onBack: onBack,
  );

  testWidgets('renders the title, copy, illustration and both choices', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(screen()));

    // The frame's "Enable Notifcations" typo is corrected.
    expect(find.text('Enable notifications'), findsNWidgets(2));
    expect(find.text('Stay up to date'), findsOneWidget);
    expect(
      find.text(
        'Get notified about Offers , new articles , your favorite stores',
      ),
      findsOneWidget,
    );
    expect(find.text('Remind me Later'), findsOneWidget);
    expect(find.byType(EnableNotificationsIllustration), findsOneWidget);
  });

  testWidgets('the primary button reports the choice', (tester) async {
    var enabled = 0;
    await tester.pumpWidget(wrap(screen(onEnable: () => enabled++)));

    // The nav bar title carries the same words, so tap the button itself.
    await tester.tap(
      find.descendant(
        of: find.byType(AppButton),
        matching: find.text('Enable notifications'),
      ),
    );
    await tester.pump();

    expect(enabled, 1);
  });

  testWidgets('Remind me Later reports the choice', (tester) async {
    var reminded = 0;
    await tester.pumpWidget(wrap(screen(onRemindLater: () => reminded++)));

    await tester.tap(find.text('Remind me Later'));
    await tester.pump();

    expect(reminded, 1);
  });

  testWidgets('the back arrow calls onBack', (tester) async {
    var backs = 0;
    await tester.pumpWidget(wrap(screen(onBack: () => backs++)));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(backs, 1);
  });
}
