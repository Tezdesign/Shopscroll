import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/features/onboarding/log_in_screen.dart';
import 'package:marketplace_app/shared/widgets/app_button.dart';

void main() {
  Widget wrap(LogInScreen screen) =>
      MaterialApp(theme: AppTheme.light, home: screen);

  LogInScreen screen({
    Future<bool> Function(LogInChannel, String)? onSendCode,
    Future<void> Function(LogInChannel, String, String)? onVerify,
    Future<void> Function(LogInChannel, String)? onResendCode,
    VoidCallback? onSignUp,
  }) => LogInScreen(
    onSendCode: onSendCode ?? (_, _) async => true,
    onVerify: onVerify ?? (_, _, _) async {},
    onResendCode: onResendCode ?? (_, _) async {},
    onSignUp: onSignUp ?? () {},
  );

  Future<void> reachVerifyStage(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'jane@example.com');
    await tester.tap(find.byType(AppButton));
    await tester.pump();
    await tester.pump();
  }

  // The countdown timer must be disposed before the test ends.
  Future<void> disposeScreen(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  testWidgets(
    'onSendCode resolving true moves to the verify stage',
    (tester) async {
      await tester.pumpWidget(wrap(screen()));

      await reachVerifyStage(tester);

      expect(find.text('Verification code'), findsOneWidget);

      await disposeScreen(tester);
    },
  );

  testWidgets(
    'onSendCode resolving false stays on the identifier stage '
    '(regression: a failed send must not show a countdown for a code that '
    'was never sent, or "Resend code" later fails)',
    (tester) async {
      await tester.pumpWidget(wrap(screen(onSendCode: (_, _) async => false)));

      await reachVerifyStage(tester);

      expect(find.text('Verification code'), findsNothing);
      expect(find.textContaining('Resend code'), findsNothing);
    },
  );
}
