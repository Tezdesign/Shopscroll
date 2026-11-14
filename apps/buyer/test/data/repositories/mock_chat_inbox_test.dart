import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/repositories/chat_repository.dart';
import 'package:marketplace_app/data/repositories/mock/mock_chat_repository.dart';

void main() {
  test('the inbox lists threads newest first, one of them unread', () async {
    final repo = MockChatRepository(replyDelay: null);

    final rows = await repo.listConversations(role: ChatRole.buyer);

    expect(rows.map((c) => c.storeName), ['Nike', 'Bershka', 'Glossier']);
    expect(rows.where((c) => c.isUnread).map((c) => c.storeName), ['Nike']);
    expect(await repo.unreadCount(ChatRole.buyer), 1);
  });

  test('paging starts after the last row on screen', () async {
    final repo = MockChatRepository(replyDelay: null);

    final first = await repo.listConversations(role: ChatRole.buyer, limit: 2);
    final next = await repo.listConversations(
      role: ChatRole.buyer,
      before: first.last,
      limit: 2,
    );

    expect(first.map((c) => c.storeName), ['Nike', 'Bershka']);
    expect(next.map((c) => c.storeName), ['Glossier']);
  });

  test('marking a thread read clears it and tells the inbox', () async {
    final repo = MockChatRepository(replyDelay: null);
    final unread =
        (await repo.listConversations(role: ChatRole.buyer)).firstWhere(
          (c) => c.isUnread,
        );
    final changed = repo.watchInbox().first;

    await repo.markRead(unread.id);
    await changed;

    expect(await repo.unreadCount(ChatRole.buyer), 0);
  });

  test('sending a message moves the thread to the top, read', () async {
    final repo = MockChatRepository(replyDelay: null);
    final glossier = (await repo.listConversations(
      role: ChatRole.buyer,
    )).last;

    await repo.sendMessage(
      messageId: '00000000-0000-4000-8000-000000000001',
      conversationId: glossier.id,
      body: 'Hello again',
    );

    final rows = await repo.listConversations(role: ChatRole.buyer);
    expect(rows.first.storeName, 'Glossier');
    expect(rows.first.lastMessage, 'Hello again');
    expect(rows.first.isUnread, isFalse);
  });

  test('the store inbox lists three customers, Amel unread', () async {
    final repo = MockChatRepository(replyDelay: null);

    final rows = await repo.listConversations(role: ChatRole.store);

    expect(rows.map((c) => c.storeName), [
      'Amel Trabelsi',
      'Yassine Gharbi',
      'Moetez ben attia',
    ]);
    expect(rows.where((c) => c.isUnread).map((c) => c.storeName), [
      'Amel Trabelsi',
    ]);
    expect(await repo.unreadCount(ChatRole.store), 1);
    // The two roles never see each other's threads or counts.
    expect(await repo.unreadCount(ChatRole.buyer), 1);
    expect(rows.every((c) => c.storeId.isEmpty), isTrue);
  });

  test('message customer finds the thread of an order, or starts one', () async {
    final repo = MockChatRepository(replyDelay: null);

    // Order 2543 is Amel's, who already wrote.
    final amel = await repo.getThreadInfo(
      role: ChatRole.store,
      orderId: 'mock-order-002543',
    );
    expect(amel.otherName, 'Amel Trabelsi');
    expect(amel.conversationId, isNotNull);
    expect(amel.otherId, isNull);

    // Order 2541 is Yassine's, who has a thread too. A name with no thread
    // (the order with no contact) starts one on the first message.
    final none = await repo.getThreadInfo(
      role: ChatRole.store,
      orderId: 'mock-order-002540',
    );
    expect(none.otherName, 'Customer');
    expect(none.conversationId, isNull);

    final sent = await repo.sendMessage(
      messageId: '00000000-0000-4000-8000-000000000002',
      orderId: 'mock-order-002540',
      role: ChatRole.store,
      body: 'Hello!',
    );
    final after = await repo.getThreadInfo(
      role: ChatRole.store,
      orderId: 'mock-order-002540',
    );
    expect(after.conversationId, sent.conversationId);
  });

  test('an unknown order or a buyer thread id is not found for a store', () async {
    final repo = MockChatRepository(replyDelay: null);

    expect(
      () => repo.getThreadInfo(role: ChatRole.store, orderId: 'nope'),
      throwsA(isA<ChatException>()),
    );
    expect(
      () => repo.getThreadInfo(
        role: ChatRole.store,
        conversationId: 'conversation-001',
      ),
      throwsA(isA<ChatException>()),
    );
  });

  test('a store reading its inbox clears it, and answering moves it up', () async {
    final repo = MockChatRepository(replyDelay: null);
    final amel =
        (await repo.listConversations(role: ChatRole.store)).first;

    await repo.markRead(amel.id);
    expect(await repo.unreadCount(ChatRole.store), 0);

    final yassine = (await repo.listConversations(role: ChatRole.store))[1];
    await repo.sendMessage(
      messageId: '00000000-0000-4000-8000-000000000003',
      conversationId: yassine.id,
      role: ChatRole.store,
      body: 'You are welcome',
    );
    final rows = await repo.listConversations(role: ChatRole.store);
    expect(rows.first.storeName, 'Yassine Gharbi');
    expect(rows.first.lastMessage, 'You are welcome');
  });
}
