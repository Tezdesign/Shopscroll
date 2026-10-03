import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/pill_tabs.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  testWidgets('the active pill is light blue with blue text', (tester) async {
    await tester.pumpWidget(
      wrap(
        PillTabs(
          labels: const ['Products', 'Reels'],
          activeIndex: 0,
          onChanged: (_) {},
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Products')).style?.color,
      AppColors.primary400,
    );
    expect(
      tester.widget<Text>(find.text('Reels')).style?.color,
      AppColors.neutral600,
    );
  });

  testWidgets('tapping a pill reports its index, from a 44 tall tap area', (
    tester,
  ) async {
    int? tapped;
    await tester.pumpWidget(
      wrap(
        PillTabs(
          labels: const ['Products', 'Reels'],
          activeIndex: 0,
          onChanged: (index) => tapped = index,
        ),
      ),
    );

    final area = find.ancestor(
      of: find.text('Reels'),
      matching: find.byType(SizedBox),
    );
    expect(tester.getSize(area.first).height, 44);
    await tester.tap(find.text('Reels'));
    expect(tapped, 1);
  });
}
