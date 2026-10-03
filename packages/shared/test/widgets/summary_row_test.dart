import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/summary_row.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  TextStyle style(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!;

  testWidgets('shows the label and value, muted by default', (tester) async {
    await tester.pumpWidget(
      wrap(const SummaryRow(label: 'Order subtotal', value: r'$45')),
    );

    expect(find.text('Order subtotal'), findsOneWidget);
    expect(find.text(r'$45'), findsOneWidget);
    expect(style(tester, 'Order subtotal').color, AppColors.neutral500);
    expect(style(tester, 'Order subtotal').fontWeight, FontWeight.w600);
  });

  testWidgets('emphasized is bold and darker', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SummaryRow(
          label: 'Price to pay',
          value: r'$55',
          emphasized: true,
        ),
      ),
    );

    expect(style(tester, 'Price to pay').color, AppColors.neutral1000);
    expect(style(tester, r'$55').fontWeight, FontWeight.w700);
  });

  testWidgets('the label and value are one spoken line', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(const SummaryRow(label: 'Delivery', value: r'$10')),
    );

    expect(find.bySemanticsLabel(RegExp(r'Delivery\s+\$10')), findsOneWidget);
    handle.dispose();
  });
}
