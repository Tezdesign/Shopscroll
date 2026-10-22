import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopscroll_shared/models/chat_message.dart';
import 'package:shopscroll_shared/models/chat_thread_info.dart';
import 'package:shopscroll_shared/models/ids.dart';

import '../../core/area/app_area.dart';
import '../../core/config/clerk_config.dart';
import '../../features/chat/chat_logic.dart';
import '../repositories/chat_repository.dart';
import '../repositories/repository_providers.dart';

/// True for a visitor who must log in before chatting (spec 0011, AC-1). The
/// app without Clerk configured has no accounts at all, and chats there run on
/// the in memory mock, so nobody is a visitor.
final chatVisitorProvider = Provider<bool>(
  (ref) => ClerkConfig.isConfigured && ref.watch(signedInUserIdProvider) == null,
);

/// Which thread a screen shows: an existing one by [conversationId], or a
/// store by [storeId] that may not have one yet. Exactly one is set.
typedef ChatTarget = ({String? conversationId, String? storeId});

/// The sender of a message the server has not stored yet. The screen tells own
/// messages from the store's by comparing the sender with the store's id, so
/// any value that is not the store's works.
const String _pendingSender = 'me';

class ChatThreadState {
  const ChatThreadState({
    required this.info,
    this.messages = const [],
    this.pending = const [],
    this.hasMore = false,
    this.loadingMore = false,
  });

  final ChatThreadInfo info;

  /// Stored messages, oldest first.
  final List<ChatMessage> messages;

  /// Messages still sending or failed, in the order they were typed. They stay
  /// at the bottom whatever the phone's clock says (AC-18).
  final List<ChatMessage> pending;
  final bool hasMore;
  final bool loadingMore;

  List<ChatMessage> get all => [...messages, ...pending];

  ChatThreadState copyWith({
    ChatThreadInfo? info,
    List<ChatMessage>? messages,
    List<ChatMessage>? pending,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return ChatThreadState(
      info: info ?? this.info,
      messages: messages ?? this.messages,
      pending: pending ?? this.pending,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// One chat thread, as if fetched from `GET /chats/:id` (spec 0011). Sending
/// is optimistic: the bubble is added at once as sending, and settles when the
/// server answers, or stays as failed with its text so a retry (the same
/// message id) loses nothing (AC-4, AC-5, AC-19).
///
/// No automatic retry, so a failed load reaches the screen as an error with
/// its own "Try again" button (AC-20).
final chatThreadProvider = AsyncNotifierProvider.autoDispose
    .family<ChatThreadNotifier, ChatThreadState, ChatTarget>(
      ChatThreadNotifier.new,
      retry: (retryCount, error) => null,
    );

class ChatThreadNotifier extends AsyncNotifier<ChatThreadState> {
  ChatThreadNotifier(this.target);

  final ChatTarget target;

  StreamSubscription<ChatMessage>? _live;
  // Sends run one after another, so the server stores them in typed order.
  Future<void> _tail = Future.value();

  @override
  Future<ChatThreadState> build() async {
    ref.onDispose(() => _live?.cancel());
    final repository = ref.watch(chatRepositoryProvider);
    final info = await repository.getThreadInfo(
      conversationId: target.conversationId,
      storeId: target.storeId,
    );
    final id = info.conversationId;
    if (id == null) return ChatThreadState(info: info);

    _watch(id);
    final page = await repository.getMessages(id, limit: chatPageSize);
    return ChatThreadState(
      info: info,
      messages: mergeChatMessages(const [], page),
      hasMore: page.length == chatPageSize,
    );
  }

  void _watch(String conversationId) {
    _live?.cancel();
    _live = ref
        .read(chatRepositoryProvider)
        .watchMessages(conversationId)
        .listen(_onLive);
  }

  /// A message from either side: it replaces its own pending copy, and one
  /// that is already stored is not added twice (AC-6).
  void _onLive(ChatMessage message) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        messages: mergeChatMessages(current.messages, [message]),
        pending: [
          for (final p in current.pending)
            if (p.id != message.id) p,
        ],
      ),
    );
  }

  /// Adds the bubble at once and sends it. Returns why the send failed, or
  /// null when it worked, so the screen can say "Slow down" (AC-13).
  Future<ChatFailure?> send(String text) {
    final current = state.value;
    if (current == null || !canSendChat(text)) return Future.value();
    final message = ChatMessage(
      id: newUuid(),
      conversationId: current.info.conversationId ?? '',
      senderId: _pendingSender,
      body: text.trim(),
      createdAt: DateTime.now(),
      status: ChatMessageStatus.sending,
    );
    state = AsyncData(current.copyWith(pending: [...current.pending, message]));
    return _deliver(message.id);
  }

  /// Tries a failed message again with the same id (AC-5, AC-19).
  Future<ChatFailure?> retry(String messageId) {
    _setStatus(messageId, ChatMessageStatus.sending);
    return _deliver(messageId);
  }

  /// Drops a failed message from the thread (AC-19).
  void remove(String messageId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        pending: [
          for (final p in current.pending)
            if (p.id != messageId) p,
        ],
      ),
    );
  }

  /// The next 30 older messages, when the person scrolls to the top (AC-3).
  Future<void> loadOlder() async {
    final current = state.value;
    final id = current?.info.conversationId;
    if (current == null ||
        id == null ||
        !current.hasMore ||
        current.loadingMore ||
        current.messages.isEmpty) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .getMessages(id, before: current.messages.first, limit: chatPageSize);
      if (!ref.mounted) return;
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          messages: mergeChatMessages(latest.messages, page),
          hasMore: page.length == chatPageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData((state.value ?? current).copyWith(loadingMore: false));
    }
  }

  Future<ChatFailure?> _deliver(String messageId) {
    final done = Completer<ChatFailure?>();
    _tail = _tail.then((_) async {
      done.complete(await _sendOne(messageId));
    });
    return done.future;
  }

  Future<ChatFailure?> _sendOne(String messageId) async {
    final message = _pendingMessage(messageId);
    if (message == null) return null;
    final repository = ref.read(chatRepositoryProvider);
    final id = state.value?.info.conversationId;
    try {
      final stored = await repository.sendMessage(
        messageId: messageId,
        conversationId: id,
        storeId: id == null ? target.storeId : null,
        body: message.body ?? '',
      );
      if (!ref.mounted) return null;
      final current = state.value;
      if (current == null) return null;
      final created = current.info.conversationId == null;
      state = AsyncData(
        current.copyWith(
          info: created
              ? current.info.copyWith(conversationId: stored.conversationId)
              : null,
          messages: mergeChatMessages(current.messages, [stored]),
          pending: [
            for (final p in current.pending)
              if (p.id != messageId) p,
          ],
        ),
      );
      if (created) _watch(stored.conversationId);
      return null;
    } on ChatException catch (error) {
      if (ref.mounted) _setStatus(messageId, ChatMessageStatus.failed);
      return error.reason;
    } catch (_) {
      if (ref.mounted) _setStatus(messageId, ChatMessageStatus.failed);
      return ChatFailure.failed;
    }
  }

  ChatMessage? _pendingMessage(String messageId) {
    final pending = state.value?.pending ?? const [];
    for (final p in pending) {
      if (p.id == messageId) return p;
    }
    return null;
  }

  void _setStatus(String messageId, ChatMessageStatus status) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        pending: [
          for (final p in current.pending)
            if (p.id == messageId) p.copyWith(status: status) else p,
        ],
      ),
    );
  }
}
