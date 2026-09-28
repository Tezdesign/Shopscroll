import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/features/onboarding/email_address_screen.dart';

void main() {
  Widget wrap(EmailAddressScreen screen) =>
      MaterialApp(theme: AppTheme.light, home: screen);

  EmailAddressScreen screen({
    Future<bool> Function(String)? onSendCode,
    void Function(String, String)? onVerify,
    void Function(String)? onResendCode,
    VoidCallback? onUsePhoneInstead,
    Duration resendCooldown = const Duration(seconds: 30),
  }) => EmailAddressScreen(
    onSendCode: onSendCode ?? (_) async => true,
    onVerify: onVerify ?? (_, _) {},
    onResendCode: onResendCode ?? (_) {},
    onUsePhoneInstead: onUsePhoneInstead ?? () {},
    resendCooldown: resendCooldown,
  );

  Future<void> reachVerifyStage(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'jane@example.com');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump();
  }

  // The countdown timer must be disposed before the test ends.
  Future<void> disposeScreen(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  group('enter address stage', () {
    testWidgets('renders the heading, field, and use phone link', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(screen()));

      expect(find.text('Email address'), findsNWidgets(2)); // heading + hint
      expect(find.text('Use phone number instead'), findsOneWidget);
      expect(find.text('Verification code'), findsNothing);
    });

    testWidgets('an invalid address shows the error state, sends nothing', (
      tester,
    ) async {
      var sent = false;
      await tester.pumpWidget(
        wrap(
          screen(
            onSendCode: (_) async {
              sent = true;
              return true;
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(sent, isFalse);
      expect(find.text('Verification code'), findsNothing);
    });

    testWidgets('typing a valid address clears a shown error', (tester) async {
      await tester.pumpWidget(wrap(screen()));

      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Please enter a valid email address.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'jane@example.com');
      await tester.pump();

      expect(find.text('Please enter a valid email address.'), findsNothing);
    });

    testWidgets('tapping Use phone number instead invokes the callback', (
      tester,
    ) async {
      var called = false;
      await tester.pumpWidget(
        wrap(screen(onUsePhoneInstead: () => called = true)),
      );

      await tester.tap(find.text('Use phone number instead'));
      await tester.pump();

      expect(called, isTrue);
    });
  });

  group('verify stage', () {
    testWidgets('a valid address sends it trimmed and reveals the code '
        'field with a countdown', (tester) async {
      String? sentTo;
      await tester.pumpWidget(
        wrap(
          screen(
            onSendCode: (e) async {
              sentTo = e;
              return true;
            },
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField).first,
        '  jane@example.com  ',
      );
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump();

      expect(sentTo, 'jane@example.com');
      expect(find.text('Verification code'), findsOneWidget);
      expect(find.text('Resend code in 0:30'), findsOneWidget);
      // Use phone number instead stays in both stages.
      expect(find.text('Use phone number instead'), findsOneWidget);

      await disposeScreen(tester);
    });

    testWidgets('onSendCode resolving false stays on the enter address stage '
        '(regression: a failed send must not show a countdown for a code '
        'that was never sent, or "Resend code" later fails)', (tester) async {
      await tester.pumpWidget(wrap(screen(onSendCode: (_) async => false)));

      await tester.enterText(find.byType(TextField), 'jane@example.com');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Verification code'), findsNothing);
      expect(find.textContaining('Resend code'), findsNothing);
    });

    testWidgets('the address stays editable, as in the Figma frame', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(screen()));
      await reachVerifyStage(tester);

      final email = tester.widget<TextField>(find.byType(TextField).first);
      expect(email.enabled, isTrue);

      await disposeScreen(tester);
    });

    testWidgets('editing the address returns to the first stage', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(screen()));
      await reachVerifyStage(tester);

      await tester.enterText(find.byType(TextField).first, 'other@example.com');
      await tester.pump();

      expect(find.text('Verification code'), findsNothing);
      expect(find.textContaining('Resend code'), findsNothing);

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

      await tester.pump(const Duration(seconds: 3));
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
            onResendCode: (e) => resentTo = e,
          ),
        ),
      );
      await reachVerifyStage(tester);
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Resend code'));
      await tester.pump();

      expect(resentTo, 'jane@example.com');
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

    testWidgets('a valid code calls onVerify with the address and digits', (
      tester,
    ) async {
      String? email;
      String? code;
      await tester.pumpWidget(
        wrap(
          screen(
            onVerify: (e, c) {
              email = e;
              code = c;
            },
          ),
        ),
      );
      await reachVerifyStage(tester);

      await tester.enterText(find.byType(TextField).last, '123 454');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(email, 'jane@example.com');
      expect(code, '123454');

      await disposeScreen(tester);
    });

    testWidgets('the back arrow returns to the first stage', (tester) async {
      await tester.pumpWidget(wrap(screen()));
      await reachVerifyStage(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      expect(find.text('Verification code'), findsNothing);
      expect(find.textContaining('Resend code'), findsNothing);

      await disposeScreen(tester);
    });
  });
}
