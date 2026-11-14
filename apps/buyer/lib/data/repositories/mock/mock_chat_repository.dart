import 'dart:async';

import 'package:shopscroll_shared/models/chat_message.dart';
import 'package:shopscroll_shared/models/chat_thread_info.dart';
import 'package:shopscroll_shared/models/conversation.dart';
import 'package:shopscroll_shared/models/ids.dart';

import '../../mock/mock_conversations.dart';
import '../../mock/mock_sellers.dart';
import '../../providers/network_delay.dart';
import '../chat_repository.dart';

/// In memory chat for the app without Supabase (spec 0011, AC-21; spec 0020,
/// AC-10). Starts with one buyer thread per mock conversation and three
/// customer threads for the store (one unread). After the caller's first
/// message in a thread the other side answers once with a short canned text,
/// so both bubble styles can be seen. Pass `replyDelay: null` to turn the
/// answer off.
class MockChatRepository implements ChatRepository {
  MockChatRepository({this.replyDelay = const Duration(seconds: 2)}) {
    for (final c in mockConversations) {
      _threads.add(
        _Thread(
          id: c.id,
          role: ChatRole.buyer,
          otherId: c.storeId,
          otherName: c.storeName,
          otherAvatarUrl: c.storeAvatarUrl,
        )
          ..unread = c.isUnread
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
    final now = DateTime.now();
    for (final (index, c) in _customers.indexed) {
      final id = 'store-conversation-00${index + 1}';
      _threads.add(
        _Thread(
          id: id,
          role: ChatRole.store,
          otherId: c.id,
          otherName: c.name,
          otherAvatarUrl: 'https://picsum.photos/seed/${c.id}/100/100',
        )
          ..unread = c.unread
          ..messages.add(
            ChatMessage(
              id: newUuid(),
              conversationId: id,
              senderId: c.id,
              body: c.message,
              createdAt: now.subtract(c.ago),
            ),
          ),
      );
    }
  }

  /// The three customers who have written to the mock store. Amel's message is
  /// the newest and unread.
  static final List<({String id, String name, String message, Duration ago, bool unread})>
  _customers = [
    (
      id: 'mock-customer-amel',
      name: 'Amel Trabelsi',
      message: 'Is the wrap dress still in stock in M?',
      ago: const Duration(minutes: 25),
      unread: true,
    ),
    (
      id: 'mock-customer-yassine',
      name: 'Yassine Gharbi',
      message: 'Thanks, I received it today!',
      ago: const Duration(days: 1),
      unread: false,
    ),
    (
      id: 'mock-customer-moetez',
      name: 'Moetez ben attia',
      message: 'cbn inajem inwaselha, merci',
      ago: const Duration(days: 3),
      unread: false,
    ),
  ];

  /// The customer name of each mock store order, by the order's number (the
  /// same names `MockStoreActivityRepository` seeds), so "Message customer"
  /// opens a thread with the person the order detail shows.
  static const List<String?> _orderNames = [
    'Moetez ben attia',
    'Moetez ben attia',
    'Amel Trabelsi',
    'Moetez ben attia',
    'Yassine Gharbi',
    null,
  ];

  final Duration? replyDelay;
  final List<_Thread> _threads = [];
  final StreamController<void> _inbox = StreamController.broadcast();
  static const String _me = 'mock-buyer';
  static const String _meStore = 'mock-seller';

  String _self(ChatRole role) => role == ChatRole.buyer ? _me : _meStore;

  _Thread? _byId(String? id, ChatRole role) => _threads
      .where((t) => t.id == id && t.role == role)
      .firstOrNull;

  _Thread? _byStore(String? storeId) => _threads
      .where((t) => t.role == ChatRole.buyer && t.otherId == storeId)
      .firstOrNull;

  /// The store role's thread for an order, and the customer's name. Null name
  /// when the order is unknown.
  (_Thread?, String?) _byOrder(String orderId) {
    final number = int.tryParse(orderId.split('-').last);
    if (!orderId.startsWith('mock-order-') || number == null) return (null, null);
    final name = _orderNames[(2545 - number) % _orderNames.length] ?? 'Customer';
    final thread = _threads
        .where((t) => t.role == ChatRole.store && t.otherName == name)
        .firstOrNull;
    return (thread, name);
  }

  @override
  Future<ChatThreadInfo> getThreadInfo({
    String? conversationId,
    String? storeId,
    String? orderId,
    ChatRole role = ChatRole.buyer,
  }) async {
    await Future<void>.delayed(mockNetworkDelay);
    if (role == ChatRole.store) {
      _Thread? thread;
      String? name;
      if (orderId != null) {
        (thread, name) = _byOrder(orderId);
      } else {
        thread = _byId(conversationId, role);
        name = thread?.otherName;
      }
      if (name == null) throw const ChatException(ChatFailure.notFound);
      return ChatThreadInfo(
        conversationId: thread?.id,
        otherName: name,
        otherAvatarUrl: thread?.otherAvatarUrl,
        selfId: _meStore,
      );
    }
    final thread = conversationId != null
        ? _byId(conversationId, role)
        : _byStore(storeId);
    final id = thread?.otherId ?? storeId;
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
      selfId: _me,
    );
  }

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    ChatMessage? before,
    int limit = 30,
  }) async {
    await Future<void>.delayed(mockNetworkDelay);
    final thread = _threads.where((t) => t.id == conversationId).firstOrNull;
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
    final thread = _threads.where((t) => t.id == conversationId).firstOrNull;
    if (thread == null) return const Stream.empty();
    return thread.live.stream;
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
    await Future<void>.delayed(mockNetworkDelay);
    for (final t in _threads) {
      final stored = t.messages.where((m) => m.id == messageId).firstOrNull;
      if (stored != null) return stored;
    }
    final text = body.trim();
    if (text.isEmpty) throw const ChatException(ChatFailure.empty);
    if (text.length > 2000) throw const ChatException(ChatFailure.tooLong);

    var thread = conversationId != null
        ? _byId(conversationId, role)
        : role == ChatRole.buyer
        ? _byStore(storeId)
        : (orderId == null ? null : _byOrder(orderId).$1);
    if (thread == null) {
      if (conversationId != null) {
        throw const ChatException(ChatFailure.notFound);
      }
      if (role == ChatRole.buyer) {
        if (storeId == null || !mockSellers.any((s) => s.id == storeId)) {
          throw const ChatException(ChatFailure.notFound);
        }
        final store = mockSellers.firstWhere((s) => s.id == storeId);
        thread = _Thread(
          id: newUuid(),
          role: role,
          otherId: storeId,
          otherName: store.name,
          otherAvatarUrl: store.avatarUrl,
        );
      } else {
        final name = orderId == null ? null : _byOrder(orderId).$2;
        if (name == null) throw const ChatException(ChatFailure.notFound);
        thread = _Thread(
          id: newUuid(),
          role: role,
          otherId: 'mock-customer-${name.hashCode.abs()}',
          otherName: name,
        );
      }
      _threads.add(thread);
    }
    final message = ChatMessage(
      id: messageId,
      conversationId: thread.id,
      senderId: _self(role),
      body: text,
      createdAt: DateTime.now(),
    );
    thread.unread = false;
    thread.add(message);
    _inbox.add(null);

    final delay = replyDelay;
    if (delay != null && !thread.replied) {
      thread.replied = true;
      final target = thread;
      Timer(delay, () {
        target.unread = true;
        target.add(
          ChatMessage(
            id: newUuid(),
            conversationId: target.id,
            senderId: target.otherId,
            body: role == ChatRole.buyer
                ? 'Thanks for your message! We will get back to you shortly.'
                : 'Thank you for getting back to me!',
            createdAt: DateTime.now(),
          ),
        );
        _inbox.add(null);
      });
    }
    return message;
  }

  @override
  Future<List<Conversation>> listConversations({
    required ChatRole role,
    Conversation? before,
    int limit = 20,
  }) async {
    await Future<void>.delayed(mockNetworkDelay);
    final rows = [
      for (final t in _threads)
        if (t.role == role && t.messages.isNotEmpty)
          Conversation(
            id: t.id,
            storeId: role == ChatRole.buyer ? t.otherId : '',
            storeName: t.otherName,
            storeAvatarUrl: t.otherAvatarUrl,
            lastMessage: t.messages.last.body ?? '',
            sentAt: t.messages.last.createdAt,
            isUnread: t.unread,
          ),
    ]..sort((a, b) {
        final byTime = b.sentAt.compareTo(a.sentAt);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    final older = before == null
        ? rows
        : rows.where((c) {
            final byTime = c.sentAt.compareTo(before.sentAt);
            return byTime < 0 || (byTime == 0 && c.id.compareTo(before.id) < 0);
          }).toList();
    return older.take(limit).toList();
  }

  @override
  Future<int> unreadCount(ChatRole role) async {
    // No simulated delay: the dot on the tab bar is read by every screen
    // that shows the bar, and a pending timer would outlive widget tests.
    return _threads.where((t) => t.role == role && t.unread).length;
  }

  @override
  Future<void> markRead(String conversationId) async {
    final thread = _threads.where((t) => t.id == conversationId).firstOrNull;
    if (thread == null || !thread.unread) return;
    thread.unread = false;
    _inbox.add(null);
  }

  @override
  Stream<void> watchInbox() => _inbox.stream;
}

class _Thread {
  _Thread({
    required this.id,
    required this.role,
    required this.otherId,
    required this.otherName,
    this.otherAvatarUrl,
  });

  final String id;
  final ChatRole role;

  /// The store's id for a buyer thread, the customer's for a store thread.
  final String otherId;
  final String otherName;
  final String? otherAvatarUrl;

  /// Unread for the person who owns the thread (the buyer, or the store).
  bool unread = false;
  final List<ChatMessage> messages = [];
  final StreamController<ChatMessage> live = StreamController.broadcast();
  bool replied = false;

  void add(ChatMessage message) {
    messages.add(message);
    live.add(message);
  }
}
