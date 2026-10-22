import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/models/chat_message.dart';

import 'package:marketplace_app/data/repositories/chat_repository.dart';
import 'package:marketplace_app/features/chat/chat_logic.dart';

ChatMessage _m(String id, int minute, {String body = 'x'}) => ChatMessage(
  id: id,
  conversationId: 'c',
  senderId: 's',
  body: body,
  createdAt: DateTime(2026, 10, 12, 10, minute),
);

void main() {
  test('AC-4 the send button needs a non empty trimmed text', () {
    expect(canSendChat(''), isFalse);
    expect(canSendChat('   \n'), isFalse);
    expect(canSendChat(' hi '), isTrue);
  });

  test('AC-4, AC-6 merging orders by time then id and never repeats', () {
    final merged = mergeChatMessages(
      [_m('b', 2), _m('a', 1)],
      [_m('c', 2), _m('a', 1, body: 'again')],
    );
    expect([for (final m in merged) m.id], ['a', 'b', 'c']);
    expect(merged.first.body, 'again');
  });

  test('AC-13 each server reason maps to a failure', () {
    expect(chatFailureFor('rate_limited'), ChatFailure.rateLimited);
    expect(chatFailureFor('blocked'), ChatFailure.blocked);
    expect(chatFailureFor('not_allowed'), ChatFailure.notAllowed);
    expect(chatFailureFor('not_found'), ChatFailure.notFound);
    expect(chatFailureFor('no_session'), ChatFailure.noSession);
    expect(chatFailureFor('no_profile'), ChatFailure.noSession);
    expect(chatFailureFor('too_long'), ChatFailure.tooLong);
    expect(chatFailureFor('empty'), ChatFailure.empty);
    expect(chatFailureFor('network down'), ChatFailure.failed);
  });

  test('AC-13 a rate limit says Slow down', () {
    expect(chatFailureText(ChatFailure.rateLimited), 'Slow down');
  });
}
