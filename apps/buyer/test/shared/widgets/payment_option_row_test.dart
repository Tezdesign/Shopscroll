import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/payment_option_row.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  testWidgets('shows the label, icon and footer, and reports taps (AC-9)', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        PaymentOptionRow(
          label: 'Pay by Credit Card',
          icon: Icons.lock_outline,
          selected: false,
          onTap: () => taps++,
          footer: const Text('logos'),
        ),
      ),
    );

    expect(find.text('Pay by Credit Card'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('logos'), findsOneWidget);
    await tester.tap(find.text('logos'));
    expect(taps, 1);
  });

  testWidgets('has no icon or footer when none is given', (tester) async {
    await tester.pumpWidget(
      wrap(
        PaymentOptionRow(
          label: 'Pay on delivery',
          selected: false,
          onTap: () {},
        ),
      ),
    );

    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('the row is at least 44 high (AC-23)', (tester) async {
    await tester.pumpWidget(
      wrap(
        PaymentOptionRow(
          label: 'Pay on delivery',
          selected: false,
          onTap: () {},
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(PaymentOptionRow)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('announces its label and selected state (AC-23)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        PaymentOptionRow(
          label: 'Pay on delivery',
          selected: true,
          onTap: () {},
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(PaymentOptionRow)),
      matchesSemantics(
        label: 'Pay on delivery',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    handle.dispose();
  });
}
