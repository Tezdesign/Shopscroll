import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/providers/chat_providers.dart';
import 'package:marketplace_app/data/repositories/chat_repository.dart';
import 'package:marketplace_app/data/repositories/mock/mock_chat_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:shopscroll_shared/models/conversation.dart';

/// 45 threads, newest first, with no delay. [fail] makes the next page fail.
class _Many extends MockChatRepository {
  _Many() : super(replyDelay: null);

  bool fail = false;
  final changes = StreamController<void>.broadcast();
  final List<Conversation> all = [
    for (var i = 0; i < 45; i++)
      Conversation(
        id: 'c${(100 - i).toString().padLeft(3, '0')}',
        storeId: 's$i',
        storeName: 'Store $i',
        lastMessage: 'm$i',
        sentAt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
      ),
  ];

  @override
  Future<List<Conversation>> listConversations({
    required ChatRole role,
    Conversation? before,
    int limit = 20,
  }) async {
    if (fail && before != null) throw const ChatException(ChatFailure.failed);
    final start = before == null
        ? 0
        : all.indexWhere((c) => c.id == before.id) + 1;
    return all.skip(start).take(limit).toList();
  }

  @override
  Stream<void> watchInbox() => changes.stream;
}

void main() {
  late _Many repo;
  late ProviderContainer container;

  setUp(() {
    repo = _Many();
    container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  Future<ChatInboxState> load() async {
    container.listen(chatInboxProvider, (_, _) {});
    return container.read(chatInboxProvider.future);
  }

  test('the first page is 20 and loadMore adds 20 more, then the rest', () async {
    final first = await load();
    expect(first.conversations.length, 20);
    expect(first.hasMore, isTrue);

    final notifier = container.read(chatInboxProvider.notifier);
    await notifier.loadMore();
    expect(container.read(chatInboxProvider).value!.conversations.length, 40);

    await notifier.loadMore();
    final last = container.read(chatInboxProvider).value!;
    expect(last.conversations.length, 45);
    expect(last.hasMore, isFalse);
    expect({for (final c in last.conversations) c.id}.length, 45);
  });

  test('a failed next page keeps the rows and offers a retry', () async {
    await load();
    repo.fail = true;

    await container.read(chatInboxProvider.notifier).loadMore();

    final state = container.read(chatInboxProvider).value!;
    expect(state.conversations.length, 20);
    expect(state.loadMoreFailed, isTrue);
    expect(state.loadingMore, isFalse);
  });

  test('a change reloads the rows without dropping what is shown', () async {
    await load();
    await container.read(chatInboxProvider.notifier).loadMore();
    repo.all[0] = repo.all[0].copyWith(lastMessage: 'new text');

    repo.changes.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(chatInboxProvider).value!;
    expect(state.conversations.length, 40);
    expect(state.conversations.first.lastMessage, 'new text');
  });

  test('the unread count reloads when a thread is read', () async {
    container.listen(chatUnreadCountProvider, (_, _) {});
    expect(await container.read(chatUnreadCountProvider.future), 1);

    await repo.markRead('conversation-001');
    repo.changes.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(await container.read(chatUnreadCountProvider.future), 0);
  });
}
