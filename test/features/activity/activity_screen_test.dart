import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/data/mock/mock_conversations.dart';
import 'package:marketplace_app/data/mock/mock_reels.dart';
import 'package:marketplace_app/data/mock/mock_saved_products.dart';
import 'package:marketplace_app/data/models/conversation.dart';
import 'package:marketplace_app/data/models/saved_product.dart';
import 'package:marketplace_app/data/models/saved_reel.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/repositories/conversation_repository.dart';
import 'package:marketplace_app/data/repositories/mock/mock_reel_repository.dart';
import 'package:marketplace_app/data/repositories/mock/mock_saved_product_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/features/activity/activity_screen.dart';
import 'package:marketplace_app/shared/widgets/coming_soon_screen.dart';
import 'package:marketplace_app/shared/widgets/item_card.dart';

class _FlakyProducts extends MockSavedProductRepository {
  bool failWrites = false;
  bool failLoad = false;

  @override
  Future<List<SavedProduct>> getSavedProducts() async {
    if (failLoad) throw Exception('no network');
    return super.getSavedProducts();
  }

  @override
  Future<void> unsaveProduct(String productId) async {
    if (failWrites) throw Exception('boom');
    return super.unsaveProduct(productId);
  }
}

/// Saved reels that include an unavailable one.
class _ReelsWithUnavailable extends MockReelRepository {
  @override
  Future<List<SavedReel>> getSavedReels() async {
    final saved = await super.getSavedReels();
    final gone = mockReels.firstWhere((r) => !r.isAvailable);
    return [...saved, SavedReel(gone, DateTime(2026, 1, 1))];
  }
}

class _NoConversations implements ConversationRepository {
  @override
  Future<List<Conversation>> getConversations() async => const [];
}

class _BrokenConversations implements ConversationRepository {
  @override
  Future<List<Conversation>> getConversations() async =>
      throw Exception('no network');
}

/// The Semantics widget with this spoken label. Not `bySemanticsLabel`, which
/// needs the semantics tree switched on.
Finder labelled(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

void main() {
  final firstSaved = mockSavedProducts.first.product;
  final reelCaption = mockReels.firstWhere((r) => r.isSaved).caption;

  Widget wrap({List<Override> overrides = const []}) {
    final router = GoRouter(
      initialLocation: '/activity',
      routes: [
        GoRoute(
          path: '/activity',
          builder: (context, state) => const ActivityScreen(),
          routes: [
            GoRoute(
              path: 'orders/:id',
              builder: (context, state) => const ComingSoonScreen(
                label: 'Order details',
                icon: Icons.receipt_long_outlined,
              ),
            ),
            GoRoute(
              path: 'chat/:id',
              builder: (context, state) => const ComingSoonScreen(
                label: 'Chat',
                icon: Icons.chat_bubble_outline,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/product/:id',
          builder: (context, state) =>
              Scaffold(body: Text('Product ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/reels/:id',
          builder: (context, state) => Scaffold(
            body: Text(
              'Reel ${state.pathParameters['id']} of ${(state.extra as List).length}',
            ),
          ),
        ),
      ],
    );
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
  }

  Future<void> open(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(wrap(overrides: overrides));
    await tester.pump(mockNetworkDelay);
    await tester.pump();
  }

  /// A new tab builds on the first frame, and only then starts its mock
  /// network delay, so it takes a frame, the delay, and one more frame.
  Future<void> load(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(mockNetworkDelay);
    await tester.pump();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await load(tester);
  }

  testWidgets(
    'opens on Purchases with a search field and three tabs (AC-1, AC-3)',
    (tester) async {
      await open(tester);
      expect(find.byType(TextField), findsOneWidget);
      for (final tab in ['Purchases', 'My collection', 'Messages']) {
        expect(find.text(tab), findsOneWidget);
      }
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Canceled'), findsOneWidget);
    },
  );

  testWidgets('tapping a purchase opens the coming soon page (AC-4)', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('In progress'));
    await tester.pumpAndSettle();
    expect(find.text('Order details coming soon'), findsOneWidget);
  });

  testWidgets(
    'My collection lists saved products; a row opens the product (AC-5)',
    (tester) async {
      await open(tester);
      await openTab(tester, 'My collection');
      expect(find.text(firstSaved.title), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      await tester.tap(find.text(firstSaved.title));
      await tester.pumpAndSettle();
      expect(find.text('Product ${firstSaved.id}'), findsOneWidget);
    },
  );

  testWidgets(
    'removing shows the Undo snack bar, and Undo restores the row (AC-7)',
    (tester) async {
      await open(tester);
      await openTab(tester, 'My collection');
      await tester.tap(labelled('Remove from saved').first);
      await tester.pump();
      expect(find.text(firstSaved.title), findsNothing);
      expect(find.text('Removed from saved'), findsOneWidget);

      // Let the snack bar finish sliding in before tapping its action.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Undo'));
      await tester.pump(mockNetworkDelay);
      await tester.pump();
      // Back in its old place: first in the list again.
      expect(find.text(firstSaved.title), findsOneWidget);
      final first = tester.getTopLeft(find.text(firstSaved.title)).dy;
      final second = tester
          .getTopLeft(find.text(mockSavedProducts[1].product.title))
          .dy;
      expect(first, lessThan(second));
      // Let the snack bar time out so no timer is left pending.
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('a failed unsave brings the row back with a message (AC-10)', (
    tester,
  ) async {
    final repo = _FlakyProducts();
    await open(
      tester,
      overrides: [savedProductRepositoryProvider.overrideWithValue(repo)],
    );
    await openTab(tester, 'My collection');
    repo.failWrites = true;
    await tester.tap(labelled('Remove from saved').first);
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(find.text(firstSaved.title), findsOneWidget);
    expect(
      find.text("Couldn't update your saved items. Try again."),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the Reels pill lists saved reels and opens the player (AC-6)', (
    tester,
  ) async {
    await open(tester);
    await openTab(tester, 'My collection');
    await tester.tap(find.text('Reels'));
    await load(tester);
    expect(find.text(reelCaption), findsOneWidget);
    await tester.tap(find.text(reelCaption));
    await tester.pumpAndSettle();
    expect(find.textContaining('Reel reel-'), findsOneWidget);
  });

  testWidgets(
    'an unavailable saved reel is dimmed, closed, and can be cleared (AC-6)',
    (tester) async {
      await open(
        tester,
        overrides: [
          reelRepositoryProvider.overrideWithValue(_ReelsWithUnavailable()),
        ],
      );
      await openTab(tester, 'My collection');
      await tester.tap(find.text('Reels'));
      await load(tester);
      expect(find.text('No longer available'), findsOneWidget);
      await tester.tap(find.text('No longer available'), warnIfMissed: false);
      await tester.pump();
      expect(find.textContaining('Reel reel-'), findsNothing);

      final before = labelled('Remove from saved').evaluate().length;
      await tester.tap(labelled('Remove from saved').last);
      await tester.pump();
      expect(find.text('No longer available'), findsNothing);
      expect(labelled('Remove from saved').evaluate().length, before - 1);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'search narrows the list, keeps its text across tabs, and says when nothing matches (AC-2)',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), '  ZZZZ ');
      await tester.pump();
      expect(find.text('No results found for “ZZZZ”'), findsOneWidget);

      await openTab(tester, 'My collection');
      expect(find.text('No results found for “ZZZZ”'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '  ZZZZ ',
      );

      await tester.enterText(find.byType(TextField), firstSaved.title);
      await tester.pump();
      expect(find.byType(ItemCard), findsOneWidget);
      expect(find.text(mockSavedProducts[1].product.title), findsNothing);
    },
  );

  testWidgets(
    'Messages lists conversations; an unread one opens chat (AC-11)',
    (tester) async {
      await open(tester);
      await openTab(tester, 'Messages');
      for (final c in mockConversations) {
        expect(find.text(c.storeName), findsOneWidget);
      }
      final unread = mockConversations.firstWhere((c) => c.isUnread);
      final read = mockConversations.firstWhere((c) => !c.isUnread);
      Color? color(String text) =>
          tester.widget<Text>(find.text(text)).style?.color;
      expect(color(unread.lastMessage), AppColors.neutral1100);
      expect(color(read.lastMessage), AppColors.neutral600);

      await tester.tap(find.text(unread.storeName));
      await tester.pumpAndSettle();
      expect(find.text('Chat coming soon'), findsOneWidget);
    },
  );

  testWidgets('empty lists say so (AC-12, AC-13)', (tester) async {
    await open(
      tester,
      overrides: [
        conversationRepositoryProvider.overrideWithValue(_NoConversations()),
      ],
    );
    await openTab(tester, 'Messages');
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('a failed load shows the message and Try again (AC-12)', (
    tester,
  ) async {
    await open(
      tester,
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _BrokenConversations(),
        ),
        savedProductRepositoryProvider.overrideWithValue(
          _FlakyProducts()..failLoad = true,
        ),
      ],
    );
    await openTab(tester, 'Messages');
    expect(find.text("Couldn't load your messages."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await openTab(tester, 'My collection');
    expect(find.text("Couldn't load your collection."), findsOneWidget);
  });

  testWidgets('loading shows a spinner (AC-12)', (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(mockNetworkDelay);
    await tester.pump();
  });

  testWidgets(
    'tabs, search field, bookmarks and rows are labelled with a 44 tap area (AC-14)',
    (tester) async {
      await open(tester);
      expect(
        tester.getSize(find.byType(TextField).hitTestable()).height,
        greaterThan(0),
      );
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.byType(TextField),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .height,
        greaterThanOrEqualTo(44),
      );
      for (final tab in ['Purchases', 'My collection', 'Messages']) {
        expect(labelled(tab), findsOneWidget);
        final box = find
            .ancestor(of: find.text(tab), matching: find.byType(Container))
            .first;
        expect(tester.getSize(box).height, greaterThanOrEqualTo(44));
      }
      await openTab(tester, 'My collection');
      final bookmark = labelled('Remove from saved').first;
      expect(tester.getSize(bookmark).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(bookmark).height, greaterThanOrEqualTo(44));
    },
  );
}
