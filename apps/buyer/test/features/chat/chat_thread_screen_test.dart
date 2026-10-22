import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/models/chat_message.dart';
import 'package:shopscroll_shared/models/chat_thread_info.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';

import 'package:marketplace_app/data/providers/chat_providers.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/repositories/chat_repository.dart';
import 'package:marketplace_app/data/repositories/mock/mock_chat_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/features/chat/chat_thread_screen.dart';

/// A repository whose sends fail with [failure] until it is set to null.
class _Flaky extends MockChatRepository {
  _Flaky() : super(replyDelay: null);

  ChatFailure? failure = ChatFailure.failed;
  final sentIds = <String>[];

  @override
  Future<ChatMessage> sendMessage({
    required String messageId,
    String? conversationId,
    String? storeId,
    required String body,
  }) async {
    sentIds.add(messageId);
    final reason = failure;
    if (reason != null) throw ChatException(reason);
    return super.sendMessage(
      messageId: messageId,
      conversationId: conversationId,
      storeId: storeId,
      body: body,
    );
  }
}

class _OwnStore extends MockChatRepository {
  _OwnStore() : super(replyDelay: null);

  @override
  Future<ChatThreadInfo> getThreadInfo({
    String? conversationId,
    String? storeId,
  }) => throw const ChatException(ChatFailure.notAllowed);
}

// A store with no mock conversation, so its thread does not exist yet.
const _newStore = 'seller-pullandbear';
const _askText = 'Ask Pull&Bear about anything you want';

Widget _wrap(Widget screen, {List<Override> overrides = const []}) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (context, state) => screen)],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

Future<void> _open(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump(mockNetworkDelay);
  await tester.pump(mockNetworkDelay);
}

Finder _sendButton() => find.byIcon(Icons.send_rounded);

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(_sendButton());
  await tester.pump();
}

void main() {
  testWidgets('AC-3 a store with no thread shows the empty state', (
    tester,
  ) async {
    final repo = MockChatRepository(replyDelay: null);
    await _open(
      tester,
      _wrap(
        const ChatThreadScreen(storeId: _newStore),
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    expect(find.text(_askText), findsOneWidget);
    expect(find.textContaining('followers'), findsOneWidget);
    expect(find.text('Type your message'), findsOneWidget);
  });

  testWidgets('the composer field has no grey fill of its own', (tester) async {
    final repo = MockChatRepository(replyDelay: null);
    await _open(
      tester,
      _wrap(
        const ChatThreadScreen(storeId: _newStore),
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.filled, isFalse);
    final context = tester.element(find.byType(TextField));
    final effective = field.decoration!.applyDefaults(
      Theme.of(context).inputDecorationTheme,
    );
    expect(effective.filled, isFalse);
  });

  testWidgets('AC-4 send adds a bubble and the first message makes the thread', (
    tester,
  ) async {
    final repo = MockChatRepository(replyDelay: null);
    await _open(
      tester,
      _wrap(
        const ChatThreadScreen(storeId: _newStore),
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    // Send is off while the field is empty.
    await tester.tap(_sendButton());
    await tester.pump();
    expect(find.text(_askText), findsOneWidget);

    await _type(tester, '  hello there ');
    expect(find.text('hello there'), findsOneWidget);
    expect(find.text(_askText), findsNothing);

    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(find.text('hello there'), findsOneWidget);
    final info = await tester.runAsync(
      () => repo.getThreadInfo(storeId: _newStore),
    );
    expect(info!.conversationId, isNotNull);
  });

  testWidgets('AC-19 a failed send keeps its text and a retry reuses the id', (
    tester,
  ) async {
    final repo = _Flaky();
    await _open(
      tester,
      _wrap(
        const ChatThreadScreen(storeId: _newStore),
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await _type(tester, 'are you open?');
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(find.text('are you open?'), findsOneWidget);
    expect(find.text('Not sent. Tap to retry'), findsOneWidget);

    repo.failure = null;
    await tester.tap(find.text('Not sent. Tap to retry'));
    await tester.pump();
    await tester.pump(mockNetworkDelay);
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(find.text('Not sent. Tap to retry'), findsNothing);
    expect(find.text('are you open?'), findsOneWidget);
    expect(repo.sentIds.length, 2);
    expect(repo.sentIds.toSet().length, 1);
  });

  testWidgets('AC-13 a rate limit says Slow down and keeps the bubble', (
    tester,
  ) async {
    final repo = _Flaky()..failure = ChatFailure.rateLimited;
    await _open(
      tester,
      _wrap(
        const ChatThreadScreen(storeId: _newStore),
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await _type(tester, 'hi');
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    expect(find.text('Slow down'), findsOneWidget);
    expect(find.text('hi'), findsOneWidget);
  });

  testWidgets('AC-6 a message from the store appears once', (tester) async {
    final repo = MockChatRepository(replyDelay: const Duration(seconds: 1));
    await _open(
      tester,
      _wrap(
        const ChatThreadScreen(conversationId: 'conversation-002'),
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    expect(
      find.text('Thanks for your order, it ships tomorrow morning.'),
      findsOneWidget,
    );
    await _type(tester, 'ok great');
    await tester.pump(mockNetworkDelay);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(
      find.text('Thanks for your message! We will get back to you shortly.'),
      findsOneWidget,
    );
    expect(find.text('ok great'), findsOneWidget);
  });

  testWidgets('AC-1 a visitor sees a Log in prompt', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ChatThreadScreen(storeId: _newStore),
        overrides: [chatVisitorProvider.overrideWithValue(true)],
      ),
    );
    expect(find.text('Log in to message this store'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets("AC-1 the person's own store says so", (tester) async {
    await _open(
      tester,
      _wrap(
        const ChatThreadScreen(storeId: _newStore),
        overrides: [chatRepositoryProvider.overrideWithValue(_OwnStore())],
      ),
    );
    expect(find.text("You can't message your own store"), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
