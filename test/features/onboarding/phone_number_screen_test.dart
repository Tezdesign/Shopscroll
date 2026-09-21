import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/features/onboarding/phone_number_screen.dart';

void main() {
  Widget wrap(PhoneNumberScreen screen) =>
      MaterialApp(theme: AppTheme.light, home: screen);

  PhoneNumberScreen screen({
    void Function(String)? onSendCode,
    void Function(String, String)? onVerify,
    void Function(String)? onResendCode,
    VoidCallback? onUseEmailInstead,
    Duration resendCooldown = const Duration(seconds: 30),
  }) => PhoneNumberScreen(
    onSendCode: onSendCode ?? (_) {},
    onVerify: onVerify ?? (_, _) {},
    onResendCode: onResendCode ?? (_) {},
    onUseEmailInstead: onUseEmailInstead ?? () {},
    resendCooldown: resendCooldown,
  );

  // Enter a valid number and tap Continue, moving to the verify stage.
  Future<void> reachVerifyStage(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '5551234567');
    await tester.tap(find.text('Continue'));
    await tester.pump();
  }

  // The countdown timer must be disposed before the test ends.
  Future<void> disposeScreen(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  group('enter number stage', () {
    testWidgets('renders the heading, field, and use email link', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(screen()));

      expect(find.text('Phone number'), findsOneWidget);
      expect(find.text('Enter your phone number'), findsOneWidget);
      expect(find.text('Use email instead'), findsOneWidget);
      expect(find.text('Verification code'), findsNothing);
    });

    testWidgets('a short number shows the error state and sends nothing', (
      tester,
    ) async {
      var sent = false;
      await tester.pumpWidget(wrap(screen(onSendCode: (_) => sent = true)));

      await tester.enterText(find.byType(TextField), '123');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Please enter a valid phone number.'), findsOneWidget);
      expect(sent, isFalse);
      expect(find.text('Verification code'), findsNothing);
    });

    testWidgets('typing a valid number clears a shown error', (tester) async {
      await tester.pumpWidget(wrap(screen()));

      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Please enter a valid phone number.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '5551234567');
      await tester.pump();

      expect(find.text('Please enter a valid phone number.'), findsNothing);
    });

    testWidgets('tapping Use email instead invokes the callback', (
      tester,
    ) async {
      var called = false;
      await tester.pumpWidget(
        wrap(screen(onUseEmailInstead: () => called = true)),
      );

      await tester.tap(find.text('Use email instead'));
      await tester.pump();

      expect(called, isTrue);
    });
  });

  group('verify stage', () {
    testWidgets('a valid number sends it in E.164 and reveals the code '
        'field with a countdown', (tester) async {
      String? sentTo;
      await tester.pumpWidget(wrap(screen(onSendCode: (n) => sentTo = n)));

      await tester.enterText(find.byType(TextField).first, '(555) 123-4567');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(sentTo, '+15551234567');
      expect(find.text('Verification code'), findsOneWidget);
      expect(find.text('Resend code in 0:30'), findsOneWidget);
      // Use email instead stays in both stages.
      expect(find.text('Use email instead'), findsOneWidget);

      await disposeScreen(tester);
    });

    testWidgets('the phone number locks once the code is sent', (tester) async {
      await tester.pumpWidget(wrap(screen()));
      await reachVerifyStage(tester);

      final phone = tester.widget<TextField>(find.byType(TextField).first);
      expect(phone.enabled, isFalse);

      await disposeScreen(tester);
    });

    testWidgets('the countdown ticks down, then becomes a Resend code link', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(screen(resendCooldown: const Duration(seconds: 3))),
      );
      await reachVerifyStage(tester);
      expect(find.text('Resend code in 0:03'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Resend code in 0:02'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('Resend code in'), findsNothing);
      expect(find.text('Resend code'), findsOneWidget);

      await disposeScreen(tester);
    });

    testWidgets('tapping Resend code calls back and restarts the countdown', (
      tester,
    ) async {
      String? resentTo;
      await tester.pumpWidget(
        wrap(
          screen(
            resendCooldown: const Duration(seconds: 2),
            onResendCode: (n) => resentTo = n,
          ),
        ),
      );
      await reachVerifyStage(tester);
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Resend code'));
      await tester.pump();

      expect(resentTo, '+15551234567');
      expect(find.text('Resend code in 0:02'), findsOneWidget);

      await disposeScreen(tester);
    });

    testWidgets('a short code shows the error state and verifies nothing', (
      tester,
    ) async {
      var verified = false;
      await tester.pumpWidget(
        wrap(screen(onVerify: (_, _) => verified = true)),
      );
      await reachVerifyStage(tester);

      await tester.enterText(find.byType(TextField).last, '123');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Please enter the 6 digit code.'), findsOneWidget);
      expect(verified, isFalse);

      await disposeScreen(tester);
    });

    testWidgets('typing a full code clears a shown error', (tester) async {
      await tester.pumpWidget(wrap(screen()));
      await reachVerifyStage(tester);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Please enter the 6 digit code.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '123454');
      await tester.pump();

      expect(find.text('Please enter the 6 digit code.'), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('a valid code calls onVerify with the number and digits', (
      tester,
    ) async {
      String? number;
      String? code;
      await tester.pumpWidget(
        wrap(
          screen(
            onVerify: (n, c) {
              number = n;
              code = c;
            },
          ),
        ),
      );
      await reachVerifyStage(tester);

      await tester.enterText(find.byType(TextField).last, '123 454');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(number, '+15551234567');
      expect(code, '123454');

      await disposeScreen(tester);
    });

    testWidgets('the back arrow returns to the number stage and unlocks it', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(screen()));
      await reachVerifyStage(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      expect(find.text('Verification code'), findsNothing);
      expect(find.textContaining('Resend code'), findsNothing);
      final phone = tester.widget<TextField>(find.byType(TextField).first);
      expect(phone.enabled, isTrue);

      await disposeScreen(tester);
    });
  });
}
