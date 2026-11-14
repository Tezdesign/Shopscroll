import 'dart:async';

import 'package:shopscroll_shared/models/chat_message.dart';
import 'package:shopscroll_shared/models/chat_thread_info.dart';
import 'package:shopscroll_shared/models/conversation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../chat_repository.dart';

/// The real chat backend (spec 0011): every write goes through the
/// `send_message` function (migration `0018_chat.sql`), reads go through
/// `chat_thread_info` and a select on `messages` (row level security limits it
/// to the caller's own threads), and new messages arrive over Realtime.
class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ChatThreadInfo> getThreadInfo({
    String? conversationId,
    String? storeId,
    String? orderId,
    ChatRole role = ChatRole.buyer,
  }) async {
    try {
      final rows = await _client.rpc(
        'chat_thread_info',
        params: {
          'p_as': role.wire,
          'p_conversation_id': ?conversationId,
          'p_peer_id': ?storeId,
          'p_order_id': ?orderId,
        },
      );
      final list = rows as List;
      if (list.isEmpty) throw const ChatException(ChatFailure.notFound);
      return ChatThreadInfo.fromJson(list.first as Map<String, dynamic>);
    } on ChatException {
      rethrow;
    } on PostgrestException catch (error) {
      throw ChatException(chatFailureFor(error.message));
    } catch (_) {
      throw const ChatException(ChatFailure.failed);
    }
  }

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    ChatMessage? before,
    int limit = 30,
  }) async {
    try {
      var query = _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId);
      if (before != null) {
        final at = before.createdAt.toUtc().toIso8601String();
        query = query.or(
          'created_at.lt.$at,and(created_at.eq.$at,id.lt.${before.id})',
        );
      }
      final rows = await query
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);
      return [for (final row in rows) ChatMessage.fromJson(row)];
    } catch (_) {
      throw const ChatException(ChatFailure.failed);
    }
  }

  @override
  Stream<ChatMessage> watchMessages(String conversationId) {
    late final StreamController<ChatMessage> controller;
    RealtimeChannel? channel;
    controller = StreamController<ChatMessage>(
      onListen: () {
        channel = _client
            .channel('chat-messages-$conversationId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: conversationId,
              ),
              callback: (payload) =>
                  controller.add(ChatMessage.fromJson(payload.newRecord)),
            )
            .subscribe();
      },
      onCancel: () async {
        final open = channel;
        if (open != null) await _client.removeChannel(open);
      },
    );
    return controller.stream;
  }

  @override
  Future<ChatMessage> sendMessage({
    required String messageId,
    String? conversationId,
    String? storeId,
    String? orderId,
    ChatRole role = ChatRole.buyer,
    required String body,
  }) async {
    try {
      final row = await _client.rpc(
        'send_message',
        params: {
          'p_message_id': messageId,
          'p_as': role.wire,
          'p_conversation_id': ?conversationId,
          'p_peer_id': ?storeId,
          'p_order_id': ?orderId,
          'p_body': body,
        },
      );
      return ChatMessage.fromJson(row as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw ChatException(chatFailureFor(error.message));
    } catch (_) {
      throw const ChatException(ChatFailure.failed);
    }
  }

  @override
  Future<List<Conversation>> listConversations({
    required ChatRole role,
    Conversation? before,
    int limit = 20,
  }) async {
    try {
      final rows = await _client.rpc(
        'chat_conversations_list',
        params: {
          'p_as': role.wire,
          'p_limit': limit,
          if (before != null) ...{
            'p_before_at': before.sentAt.toUtc().toIso8601String(),
            'p_before_id': before.id,
          },
        },
      );
      return [
        for (final row in rows as List)
          Conversation(
            id: row['conversation_id'] as String,
            storeId: row['other_id'] as String? ?? '',
            storeName: row['other_name'] as String,
            storeAvatarUrl: row['other_avatar_url'] as String?,
            lastMessage: row['last_message_preview'] as String? ?? '',
            sentAt: DateTime.parse(row['last_message_at'] as String),
            isUnread: row['unread'] as bool? ?? false,
          ),
      ];
    } on PostgrestException catch (error) {
      final failure = chatFailureFor(error.message);
      if (failure == ChatFailure.noSession) return const [];
      throw ChatException(failure);
    } catch (_) {
      throw const ChatException(ChatFailure.failed);
    }
  }

  @override
  Future<int> unreadCount(ChatRole role) async {
    try {
      final count = await _client.rpc(
        'chat_unread_count',
        params: {'p_as': role.wire},
      );
      return count as int;
    } on PostgrestException catch (error) {
      final failure = chatFailureFor(error.message);
      if (failure == ChatFailure.noSession) return 0;
      throw ChatException(failure);
    } catch (_) {
      throw const ChatException(ChatFailure.failed);
    }
  }

  @override
  Future<void> markRead(String conversationId) async {
    try {
      await _client.rpc(
        'mark_conversation_read',
        params: {'p_conversation_id': conversationId},
      );
    } catch (_) {
      // Not worth telling the person: the thread is read on the next open.
    }
  }

  @override
  Stream<void> watchInbox() {
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>(
      onListen: () {
        channel = _client
            .channel('chat-inbox')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'conversations',
              callback: (payload) => controller.add(null),
            )
            .subscribe();
      },
      onCancel: () async {
        final open = channel;
        if (open != null) await _client.removeChannel(open);
      },
    );
    return controller.stream;
  }
}
