import 'dart:async';

import 'package:shopscroll_shared/models/chat_message.dart';
import 'package:shopscroll_shared/models/chat_thread_info.dart';
import 'package:shopscroll_shared/models/ids.dart';

import '../../mock/mock_conversations.dart';
import '../../mock/mock_sellers.dart';
import '../../providers/network_delay.dart';
import '../chat_repository.dart';

/// In memory chat for the app without Supabase (spec 0011, AC-21). Starts with
/// one thread per mock conversation. After the buyer's first message in a
/// thread the mock store answers once with a short canned text, so both
/// bubble styles can be seen. Pass `replyDelay: null` to turn the answer off.
class MockChatRepository implements ChatRepository {
  MockChatRepository({this.replyDelay = const Duration(seconds: 2)}) {
    for (final c in mockConversations) {
      _threads.add(
        _Thread(c.id, c.storeId)
          ..messages.add(
            ChatMessage(
              id: newUuid(),
              conversationId: c.id,
              senderId: c.storeId,
              body: c.lastMessage,
              createdAt: c.sentAt,
            ),
          ),
      );
    }
  }

  final Duration? replyDelay;
  final List<_Thread> _threads = [];
  static const String _me = 'mock-buyer';

  _Thread? _byId(String? id) =>
      _threads.where((t) => t.id == id).firstOrNull;

  _Thread? _byStore(String? storeId) =>
      _threads.where((t) => t.storeId == storeId).firstOrNull;

  @override
  Future<ChatThreadInfo> getThreadInfo({
    String? conversationId,
    String? storeId,
  }) async {
    await Future<void>.delayed(mockNetworkDelay);
    final thread = conversationId != null
        ? _byId(conversationId)
        : _byStore(storeId);
    final id = thread?.storeId ?? storeId;
    final store = mockSellers.where((s) => s.id == id).firstOrNull;
    if (id == null || (store == null && thread == null)) {
      throw const ChatException(ChatFailure.notFound);
    }
    final conversation = mockConversations
        .where((c) => c.storeId == id)
        .firstOrNull;
    return ChatThreadInfo(
      conversationId: thread?.id,
      otherId: id,
      otherName: store?.name ?? conversation?.storeName ?? 'Store',
      otherAvatarUrl: store?.avatarUrl ?? conversation?.storeAvatarUrl,
      otherFollowerCount: store?.followerCount ?? 0,
    );
  }

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    ChatMessage? before,
    int limit = 30,
  }) async {
    await Future<void>.delayed(mockNetworkDelay);
    final thread = _byId(conversationId);
    if (thread == null) throw const ChatException(ChatFailure.notFound);
    final newestFirst = [...thread.messages]
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    final older = before == null
        ? newestFirst
        : newestFirst.where((m) {
            final byTime = m.createdAt.compareTo(before.createdAt);
            return byTime < 0 || (byTime == 0 && m.id.compareTo(before.id) < 0);
          }).toList();
    return older.take(limit).toList();
  }

  @override
  Stream<ChatMessage> watchMessages(String conversationId) {
    final thread = _byId(conversationId);
    if (thread == null) return const Stream.empty();
    return thread.live.stream;
  }

  @override
  Future<ChatMessage> sendMessage({
    required String messageId,
    String? conversationId,
    String? storeId,
    required String body,
  }) async {
    await Future<void>.delayed(mockNetworkDelay);
    for (final t in _threads) {
      final stored = t.messages.where((m) => m.id == messageId).firstOrNull;
      if (stored != null) return stored;
    }
    final text = body.trim();
    if (text.isEmpty) throw const ChatException(ChatFailure.empty);
    if (text.length > 2000) throw const ChatException(ChatFailure.tooLong);

    var thread = conversationId != null ? _byId(conversationId) : _byStore(storeId);
    if (thread == null) {
      if (conversationId != null || storeId == null) {
        throw const ChatException(ChatFailure.notFound);
      }
      if (!mockSellers.any((s) => s.id == storeId)) {
        throw const ChatException(ChatFailure.notFound);
      }
      thread = _Thread(newUuid(), storeId);
      _threads.add(thread);
    }
    final message = ChatMessage(
      id: messageId,
      conversationId: thread.id,
      senderId: _me,
      body: text,
      createdAt: DateTime.now(),
    );
    thread.add(message);

    final delay = replyDelay;
    if (delay != null && !thread.replied) {
      thread.replied = true;
      final target = thread;
      Timer(delay, () {
        target.add(
          ChatMessage(
            id: newUuid(),
            conversationId: target.id,
            senderId: target.storeId,
            body: 'Thanks for your message! We will get back to you shortly.',
            createdAt: DateTime.now(),
          ),
        );
      });
    }
    return message;
  }
}

class _Thread {
  _Thread(this.id, this.storeId);

  final String id;
  final String storeId;
  final List<ChatMessage> messages = [];
  final StreamController<ChatMessage> live = StreamController.broadcast();
  bool replied = false;

  void add(ChatMessage message) {
    messages.add(message);
    live.add(message);
  }
}
