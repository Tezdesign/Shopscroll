import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:marketplace_app/features/onboarding/interests_screen.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

  InterestsScreen screen({void Function(List<Interest>)? onStart}) =>
      InterestsScreen(onStart: onStart ?? (_) {});

  BoxDecoration decorationOf(WidgetTester tester, String category) {
    final card = find.ancestor(
      of: find.text(category),
      matching: find.byType(DecoratedBox),
    );
    return tester.widget<DecoratedBox>(card.first).decoration as BoxDecoration;
  }

  testWidgets('renders the title, heading and a card per interest', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(screen()));

    expect(find.text('Set up Your profile'), findsOneWidget);
    expect(find.text('What are you interest in the most?'), findsOneWidget);
    expect(find.text("Let's start"), findsOneWidget);
    for (final interest in interests) {
      expect(find.text(interest.category), findsOneWidget);
      expect(find.text(interest.example), findsOneWidget);
    }
  });

  testWidgets('cards start unselected, with no border', (tester) async {
    await tester.pumpWidget(wrap(screen()));

    expect(decorationOf(tester, interests.first.category).border, isNull);
  });

  testWidgets('tapping a card selects it, tapping again clears it', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(screen()));
    final category = interests.first.category;

    await tester.tap(find.text(category));
    await tester.pump();

    final border = decorationOf(tester, category).border! as Border;
    expect(border.top.color, AppColors.success500);

    await tester.tap(find.text(category));
    await tester.pump();

    expect(decorationOf(tester, category).border, isNull);
  });

  testWidgets("Let's start reports the selection in list order", (
    tester,
  ) async {
    List<Interest>? started;
    await tester.pumpWidget(wrap(screen(onStart: (s) => started = s)));

    // Tapped back to front; the callback still reports them in list order.
    await tester.tap(find.text(interests[2].category));
    await tester.tap(find.text(interests[0].category));
    await tester.pump();
    await tester.tap(find.text("Let's start"));

    expect(started, [interests[0], interests[2]]);
  });

  testWidgets("Let's start works with nothing selected", (tester) async {
    List<Interest>? started;
    await tester.pumpWidget(wrap(screen(onStart: (s) => started = s)));

    await tester.tap(find.text("Let's start"));

    expect(started, isEmpty);
  });

  testWidgets('the back arrow calls onBack', (tester) async {
    var backs = 0;
    await tester.pumpWidget(
      wrap(InterestsScreen(onStart: (_) {}, onBack: () => backs++)),
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(backs, 1);
  });

  testWidgets('lays out at phone size without overflowing', (tester) async {
    // The frame is an iPhone 14/15 Pro, 393 x 852.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(screen()));
    await tester.pump();

    // Three cards across, as in the frame.
    final firstRowTop = tester.getTopLeft(find.text(interests[0].category)).dy;
    expect(tester.getTopLeft(find.text(interests[2].category)).dy, firstRowTop);
    expect(
      tester.getTopLeft(find.text(interests[3].category)).dy,
      greaterThan(firstRowTop),
    );
  });

  test('every interest names a committed image and a distinct category', () {
    expect(
      interests.map((interest) => interest.category).toSet(),
      hasLength(interests.length),
    );
    for (final interest in interests) {
      expect(interest.image, startsWith('assets/interests/'));
      expect(interest.image, endsWith('.png'));
    }
  });
}
