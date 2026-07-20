import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/notification_time_label.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
  }

  testWidgets('renders the given text', (tester) async {
    await tester.pumpWidget(
      wrap(const NotificationTimeLabel(text: 'Now')),
    );

    expect(find.text('Now'), findsOneWidget);
  });

  testWidgets('uses neutral500 when not checked', (tester) async {
    await tester.pumpWidget(
      wrap(const NotificationTimeLabel(text: 'Now')),
    );

    final text = tester.widget<Text>(find.text('Now'));
    expect(text.style?.color, AppColors.neutral500);
  });

  testWidgets('uses neutral1000 when checked', (tester) async {
    await tester.pumpWidget(
      wrap(const NotificationTimeLabel(text: '2h', checked: true)),
    );

    final text = tester.widget<Text>(find.text('2h'));
    expect(text.style?.color, AppColors.neutral1000);
  });
}
