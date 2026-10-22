import 'package:shopscroll_shared/models/chat_message.dart';
import 'package:shopscroll_shared/models/chat_thread_info.dart';

/// Why a chat call failed (spec 0011, AC-13, AC-14). The screen turns each
/// into a message. [failed] is any other failure, like no network.
enum ChatFailure {
  noSession,
  notFound,
  notAllowed,
  blocked,
  tooLong,
  empty,
  rateLimited,
  failed,
}

class ChatException implements Exception {
  const ChatException(this.reason);

  final ChatFailure reason;

  @override
  String toString() => 'ChatException($reason)';
}

/// What a chat function's reason means for the app. The functions raise their
/// reason as the whole error message. Public so a test can pin each mapping.
ChatFailure chatFailureFor(String message) {
  const known = {
    'no_session': ChatFailure.noSession,
    'no_profile': ChatFailure.noSession,
    'not_found': ChatFailure.notFound,
    'not_allowed': ChatFailure.notAllowed,
    'blocked': ChatFailure.blocked,
    'too_long': ChatFailure.tooLong,
    'empty': ChatFailure.empty,
    'rate_limited': ChatFailure.rateLimited,
  };
  for (final entry in known.entries) {
    if (message.contains(entry.key)) return entry.value;
  }
  return ChatFailure.failed;
}

/// The buyer's chat threads with stores (spec 0011). See
/// product_repository.dart for the mock/Supabase swap pattern. Every call
/// names a thread by its [conversationId], or a store by its [storeId] while
/// no thread exists yet. Failures are thrown as a [ChatException].
abstract class ChatRepository {
  /// As if fetched from `GET /chats/info`. The store's name, avatar and
  /// followers, and the thread's id and block flags (null id and false flags
  /// when the pair has not written yet). Nothing is stored by asking.
  Future<ChatThreadInfo> getThreadInfo({
    String? conversationId,
    String? storeId,
  });

  /// As if fetched from `GET /chats/:id/messages`, newest first. [before] is
  /// the oldest message already on screen, so the next page starts after it.
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    ChatMessage? before,
    int limit = 30,
  });

  /// New messages of one thread as they are stored, from either side.
  Stream<ChatMessage> watchMessages(String conversationId);

  /// As if sent to `POST /chats/messages`. The first message creates the
  /// thread. Sending the same [messageId] again returns the stored message.
  Future<ChatMessage> sendMessage({
    required String messageId,
    String? conversationId,
    String? storeId,
    required String body,
  });
}
