import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/shared/widgets/app_icon.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders the mapped Material icon for a glyph', (tester) async {
    await tester.pumpWidget(wrap(const AppIcon(AppIconGlyph.search)));

    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('renders every glyph without throwing', (tester) async {
    for (final glyph in AppIconGlyph.values) {
      await tester.pumpWidget(wrap(AppIcon(glyph)));
      expect(find.byType(Icon), findsOneWidget);
    }
  });

  testWidgets('applies the given size and color', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppIcon(
          AppIconGlyph.saveFilled,
          size: 32,
          color: Colors.red,
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.size, 32);
    expect(icon.color, Colors.red);
  });

  testWidgets('save and saveFilled map to distinct icons', (tester) async {
    await tester.pumpWidget(wrap(const AppIcon(AppIconGlyph.save)));
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

    await tester.pumpWidget(wrap(const AppIcon(AppIconGlyph.saveFilled)));
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('logout maps to the logout icon', (tester) async {
    await tester.pumpWidget(wrap(const AppIcon(AppIconGlyph.logout)));
    expect(find.byIcon(Icons.logout), findsOneWidget);
  });

  testWidgets('openExternal maps to the open-in-new icon', (tester) async {
    await tester.pumpWidget(wrap(const AppIcon(AppIconGlyph.openExternal)));
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });

  testWidgets('delete maps to the delete outline icon', (tester) async {
    await tester.pumpWidget(wrap(const AppIcon(AppIconGlyph.delete)));
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
