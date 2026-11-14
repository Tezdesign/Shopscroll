import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_app/core/area/app_area.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/repositories/chat_repository.dart';
import 'package:marketplace_app/data/repositories/mock/mock_chat_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/providers/user_profile_providers.dart';
import 'package:marketplace_app/features/chat/chat_bubble.dart';
import 'package:marketplace_app/features/chat/chat_thread_screen.dart';
import 'package:marketplace_app/features/seller_activity/store_order_detail_screen.dart';
import 'package:marketplace_app/features/seller_chat/seller_inbox_screen.dart';
import 'package:shopscroll_shared/models/chat_message.dart';
import 'package:shopscroll_shared/models/conversation.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

class _EmptyInbox extends MockChatRepository {
  _EmptyInbox() : super(replyDelay: null);

  @override
  Future<List<Conversation>> listConversations({
    required ChatRole role,
    Conversation? before,
    int limit = 20,
  }) async => const [];
}

class _Refuses extends MockChatRepository {
  _Refuses() : super(replyDelay: null);

  @override
  Future<ChatMessage> sendMessage({
    required String messageId,
    String? conversationId,
    String? storeId,
    String? orderId,
    ChatRole role = ChatRole.buyer,
    required String body,
  }) async => throw const ChatException(ChatFailure.notAllowed);
}

Widget _app(
  Widget home, {
  List<Override> overrides = const [],
  List<GoRoute> extra = const [],
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => home),
      ...extra,
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(mockNetworkDelay);
  await tester.pump(mockNetworkDelay);
}

GoRoute _marker(String path) => GoRoute(
  path: path,
  builder: (context, state) => Scaffold(body: Text('AT ${state.uri}')),
);

Finder _bubbles() => find.byType(ChatBubble);

void main() {
  testWidgets('AC-1 the inbox lists customers newest first, unread in dark', (
    tester,
  ) async {
    final repo = MockChatRepository(replyDelay: null);
    await tester.pumpWidget(
      _app(
        const SellerInboxScreen(),
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await _settle(tester);

    final names = [
      for (final name in ['Amel Trabelsi', 'Yassine Gharbi', 'Moetez ben attia'])
        tester.getTopLeft(find.text(name)).dy,
    ];
    expect(names, orderedEquals([...names]..sort()));

    Color? color(String text) =>
        tester.widget<Text>(find.text(text)).style?.color;
    expect(color('Is the wrap dress still in stock in M?'), AppColors.neutral1100);
    expect(color('Thanks, I received it today!'), AppColors.neutral600);
    // No photo for a customer? The first letter shows instead (AC-1).
    expect(find.text('A'), findsNothing); // these have photos in the mock
  });

  testWidgets('AC-1 the search field filters by name or last message', (
    tester,
  ) async {
    final repo = MockChatRepository(replyDelay: null);
    await tester.pumpWidget(
      _app(
        const SellerInboxScreen(),
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'yass');
    await tester.pump();
    expect(find.text('Yassine Gharbi'), findsOneWidget);
    expect(find.text('Amel Trabelsi'), findsNothing);

    await tester.enterText(find.byType(TextField), 'wrap dress');
    await tester.pump();
    expect(find.text('Amel Trabelsi'), findsOneWidget);
    expect(find.text('Yassine Gharbi'), findsNothing);
  });

  testWidgets('AC-3 a row opens the thread under /store/messages', (
    tester,
  ) async {
    final repo = MockChatRepository(replyDelay: null);
    await tester.pumpWidget(
      _app(
        const SellerInboxScreen(),
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
        extra: [_marker('/store/messages/:id')],
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Yassine Gharbi'));
    await tester.pumpAndSettle();

    expect(find.text('AT /store/messages/store-conversation-002'), findsOneWidget);
  });

  testWidgets('AC-9 an empty inbox says so', (tester) async {
    await tester.pumpWidget(
      _app(
        const SellerInboxScreen(),
        overrides: [chatRepositoryProvider.overrideWithValue(_EmptyInbox())],
      ),
    );
    await _settle(tester);

    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.textContaining('When a customer writes to your store'), findsOneWidget);
  });

  testWidgets('AC-3 opening a thread acts as the store and marks it read', (
    tester,
  ) async {
    final repo = MockChatRepository(replyDelay: null);
    expect(await repo.unreadCount(ChatRole.store), 1);
    await tester.pumpWidget(
      _app(
        const ChatThreadScreen(
          conversationId: 'store-conversation-001',
          role: ChatRole.store,
        ),
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await _settle(tester);

    // The customer's message is on the left, and the name is no link.
    final bubble = tester.widget<ChatBubble>(_bubbles());
    expect(bubble.message.body, 'Is the wrap dress still in stock in M?');
    expect(bubble.mine, isFalse);
    expect(find.text('Amel Trabelsi'), findsWidgets);
    expect(await repo.unreadCount(ChatRole.store), 0);
  });

  testWidgets('AC-5 a new thread from an order says hello, and the first '
      'message creates it, shown as the seller\'s own', (tester) async {
    final repo = MockChatRepository(replyDelay: null);
    await tester.pumpWidget(
      _app(
        const ChatThreadScreen(orderId: 'mock-order-002540', role: ChatRole.store),
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await _settle(tester);

    expect(find.text('Say hello to Customer'), findsOneWidget);
    expect(find.textContaining('followers'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Your order ships today');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await _settle(tester);

    final bubble = tester.widget<ChatBubble>(_bubbles());
    expect(bubble.message.body, 'Your order ships today');
    expect(bubble.mine, isTrue);
    final rows = await tester.runAsync(
      () => repo.listConversations(role: ChatRole.store),
    );
    expect(rows!.first.lastMessage, 'Your order ships today');
  });

  testWidgets('AC-6 a refusal to start is worded for a store', (tester) async {
    await tester.pumpWidget(
      _app(
        const ChatThreadScreen(orderId: 'mock-order-002540', role: ChatRole.store),
        overrides: [chatRepositoryProvider.overrideWithValue(_Refuses())],
      ),
    );
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await _settle(tester);

    expect(find.text("You can't start new conversations"), findsOneWidget);
  });

  testWidgets('AC-6 an order that is not the store\'s is not found', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const ChatThreadScreen(orderId: 'someone-elses', role: ChatRole.store),
        overrides: [
          chatRepositoryProvider.overrideWithValue(
            MockChatRepository(replyDelay: null),
          ),
        ],
      ),
    );
    await _settle(tester);

    expect(find.text("Couldn't load this chat."), findsOneWidget);
    expect(find.text('Say hello to Customer'), findsNothing);
  });

  testWidgets('AC-5, AC-8 Message customer opens the order\'s thread, no '
      'customer id in the route', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        const StoreOrderDetailScreen(orderId: 'mock-order-002545'),
        overrides: [
          signedInUserIdProvider.overrideWith((ref) => 'seller'),
          userProfileByIdProvider.overrideWith(
            (ref, id) async => const UserProfile(
              id: 'seller',
              name: 'Bershka',
              username: 'bershka',
              role: UserRole.seller,
            ),
          ),
        ],
        extra: [_marker('/store/messages/order/:orderId')],
      ),
    );
    await _settle(tester);
    await tester.pump();

    await tester.tap(find.text('Message customer'));
    await tester.pumpAndSettle();

    expect(
      find.text('AT /store/messages/order/mock-order-002545'),
      findsOneWidget,
    );
  });
}
