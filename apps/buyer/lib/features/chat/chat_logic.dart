import 'package:shopscroll_shared/models/chat_message.dart';

import '../../data/repositories/chat_repository.dart';

/// Plain rules for the chat screens, with no Flutter code so they are easy to
/// test (spec 0011).

/// The most characters a message can hold (AC-4, AC-13).
const int maxChatBody = 2000;

/// The page size for messages (AC-3).
const int chatPageSize = 30;

/// The send button is on only when the trimmed text is not empty (AC-4).
bool canSendChat(String text) => text.trim().isNotEmpty;

/// Puts [incoming] into [have] by id (a message that is already there is
/// replaced, never repeated) and orders the result by `createdAt`, then `id`
/// (AC-4, AC-6).
List<ChatMessage> mergeChatMessages(
  List<ChatMessage> have,
  Iterable<ChatMessage> incoming,
) {
  final byId = {for (final m in have) m.id: m};
  for (final m in incoming) {
    byId[m.id] = m;
  }
  return byId.values.toList()..sort((a, b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });
}

/// What the screen says for a failed chat call (AC-1, AC-13).
String chatFailureText(ChatFailure failure) => switch (failure) {
  ChatFailure.rateLimited => 'Slow down',
  ChatFailure.notAllowed => "You can't message your own store",
  ChatFailure.blocked => "You can't reply to this conversation",
  ChatFailure.notFound => "This conversation isn't available",
  ChatFailure.noSession => 'Log in to send messages',
  ChatFailure.tooLong || ChatFailure.empty => "That message can't be sent",
  ChatFailure.failed => "Couldn't send the message. Try again.",
};
