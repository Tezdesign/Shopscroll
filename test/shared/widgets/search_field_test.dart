import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/search_field.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
  }

  testWidgets('renders the default hint text', (tester) async {
    await tester.pumpWidget(wrap(const SearchField()));

    expect(find.text('Search for anything'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('renders a custom hint text', (tester) async {
    await tester.pumpWidget(wrap(const SearchField(hintText: 'Find a shop')));

    expect(find.text('Find a shop'), findsOneWidget);
  });

  testWidgets('invokes onChanged when text is entered', (tester) async {
    String? changed;
    await tester.pumpWidget(
      wrap(SearchField(onChanged: (value) => changed = value)),
    );

    await tester.enterText(find.byType(TextField), 'sneakers');

    expect(changed, 'sneakers');
  });

  testWidgets('invokes onTap when readOnly and tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(SearchField(readOnly: true, onTap: () => tapped = true)),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
