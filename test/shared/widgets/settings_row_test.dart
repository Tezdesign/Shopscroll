import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/shared/widgets/app_icon.dart';
import 'package:marketplace_app/shared/widgets/settings_row.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
  }

  testWidgets('renders the given label', (tester) async {
    await tester.pumpWidget(wrap(const SettingsRow(label: 'Delivery addresses')));

    expect(find.text('Delivery addresses'), findsOneWidget);
  });

  testWidgets('defaults to a forward chevron trailing icon', (tester) async {
    await tester.pumpWidget(wrap(const SettingsRow(label: 'Payments')));

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('renders no trailing icon when trailingIcon is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const SettingsRow(label: 'Log out', trailingIcon: null)),
    );

    expect(find.byType(AppIcon), findsNothing);
  });

  testWidgets('renders the given trailing icon glyph', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SettingsRow(
          label: 'Privacy policy',
          trailingIcon: AppIconGlyph.openExternal,
        ),
      ),
    );

    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });

  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(SettingsRow(label: 'Log out', onTap: () => tapped = true)),
    );

    await tester.tap(find.text('Log out'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('applies labelColor to both the text and the trailing icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SettingsRow(
          label: 'Delete account',
          trailingIcon: AppIconGlyph.delete,
          labelColor: AppColors.error400,
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Delete account'));
    expect(text.style?.color, AppColors.error400);

    final icon = tester.widget<Icon>(find.byIcon(Icons.delete_outline));
    expect(icon.color, AppColors.error400);
  });

  testWidgets('does nothing when tapped with no onTap handler', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const SettingsRow(label: 'Language')));

    await tester.tap(find.text('Language'));
    await tester.pump();

    expect(find.text('Language'), findsOneWidget);
  });
}
