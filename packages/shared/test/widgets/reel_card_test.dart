import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/models/reel.dart';
import 'package:shopscroll_shared/widgets/reel_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  final reel = Reel(
    id: 'reel-001',
    videoUrl: 'https://example.test/reel-001.mp4',
    thumbnailUrl: 'https://picsum.photos/seed/reel-001/400/700',
    storeId: 'seller-bershka',
    storeName: 'Bershka',
    caption: 'Layering the oversized blazer dress for a night out',
    createdAt: DateTime(2026, 6, 29),
  );
  final unavailable = reel.copyWith(isAvailable: false);

  testWidgets(
    'shows no bookmark by default, so the Reels grid is unchanged (AC-15)',
    (tester) async {
      await tester.pumpWidget(wrap(ReelCard(reel: reel)));
      expect(find.byIcon(Icons.bookmark), findsNothing);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
    },
  );

  testWidgets(
    'shows a filled bookmark that calls onSaveTap, 44 tall (AC-6, AC-14)',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(ReelCard(reel: reel, saved: true, onSaveTap: () => tapped = true)),
      );
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      final area = find.ancestor(
        of: find.byIcon(Icons.bookmark),
        matching: find.byType(SizedBox),
      );
      expect(tester.getSize(area.first).height, 44);
      await tester.tap(find.byIcon(Icons.bookmark));
      expect(tapped, isTrue);
    },
  );

  testWidgets(
    'an unavailable reel cannot open but its bookmark still works (AC-6)',
    (tester) async {
      var opened = false;
      var cleared = false;
      await tester.pumpWidget(
        wrap(
          ReelCard(
            reel: unavailable,
            saved: true,
            onTap: () => opened = true,
            onSaveTap: () => cleared = true,
          ),
        ),
      );
      expect(find.text('No longer available'), findsOneWidget);
      await tester.tap(find.text('No longer available'), warnIfMissed: false);
      await tester.tap(find.byIcon(Icons.bookmark));
      expect(opened, isFalse);
      expect(cleared, isTrue);
    },
  );
}
