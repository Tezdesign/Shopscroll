import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/app_icon.dart';
import 'package:marketplace_app/shared/widgets/info_row.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
  }

  testWidgets('renders the icon and text', (tester) async {
    await tester.pumpWidget(
      wrap(
        const InfoRow(
          icon: AppIconGlyph.delivery,
          text: 'Fast delivery in 1-2 days',
        ),
      ),
    );

    expect(find.text('Fast delivery in 1-2 days'), findsOneWidget);
    expect(find.byType(AppIcon), findsOneWidget);
  });

  testWidgets('is not wrapped in a tappable when onTap is omitted', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const InfoRow(icon: AppIconGlyph.web, text: 'Go to website')),
    );

    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('invokes onTap when provided and tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        InfoRow(
          icon: AppIconGlyph.web,
          text: 'Go to website',
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Go to website'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
