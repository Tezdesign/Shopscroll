import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:marketplace_app/features/onboarding/log_in_screen.dart';
import 'package:marketplace_app/shared/widgets/account_type_toggle.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';

void main() {
  Widget wrap(LogInScreen screen) =>
      MaterialApp(theme: AppTheme.light, home: screen);

  LogInScreen screen({
    Future<bool> Function(LogInChannel, String)? onSendCode,
    Future<void> Function(LogInChannel, String, String, AccountType)? onVerify,
    Future<void> Function(LogInChannel, String)? onResendCode,
    VoidCallback? onSignUp,
    VoidCallback? onApplyNow,
  }) => LogInScreen(
    onSendCode: onSendCode ?? (_, _) async => true,
    onVerify: onVerify ?? (_, _, _, _) async {},
    onResendCode: onResendCode ?? (_, _) async {},
    onSignUp: onSignUp ?? () {},
    onApplyNow: onApplyNow ?? () {},
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

  testWidgets('onSendCode resolving true moves to the verify stage', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(screen()));

    await reachVerifyStage(tester);

    expect(find.text('Verification code'), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets('onSendCode resolving false stays on the identifier stage '
      '(regression: a failed send must not show a countdown for a code that '
      'was never sent, or "Resend code" later fails)', (tester) async {
    await tester.pumpWidget(wrap(screen(onSendCode: (_, _) async => false)));

    await reachVerifyStage(tester);

    expect(find.text('Verification code'), findsNothing);
    expect(find.textContaining('Resend code'), findsNothing);
  });

  testWidgets(
    'onVerify receives the Buyer or Store owner choice (spec 0014, AC-1)',
    (tester) async {
      AccountType? received;
      await tester.pumpWidget(
        wrap(screen(onVerify: (_, _, _, type) async => received = type)),
      );

      await tester.tap(find.text('Store owner'));
      await tester.pump();
      await reachVerifyStage(tester);
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(received, AccountType.storeOwner);
      await disposeScreen(tester);
    },
  );

  testWidgets('the choice defaults to Buyer', (tester) async {
    AccountType? received;
    await tester.pumpWidget(
      wrap(screen(onVerify: (_, _, _, type) async => received = type)),
    );

    await reachVerifyStage(tester);
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.byType(AppButton));
    await tester.pump();

    expect(received, AccountType.buyer);
    await disposeScreen(tester);
  });

  testWidgets('Apply now invokes onApplyNow (spec 0014, AC-7)', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(screen(onApplyNow: () => tapped = true)));

    await tester.tap(find.textContaining('Apply now'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
