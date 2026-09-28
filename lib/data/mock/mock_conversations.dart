import '../models/conversation.dart';

/// Three mocked store conversations, newest first. The first is unread. The
/// dates are fixed, so "today" only reads as a time when a test or the run
/// happens to land on it, which is fine for placeholder data.
final List<Conversation> mockConversations = [
  Conversation(
    id: 'conversation-001',
    storeId: 'seller-nike',
    storeName: 'Nike',
    storeAvatarUrl: 'https://picsum.photos/seed/nike-avatar/100/100',
    lastMessage: 'Your size 42 is back in stock, want us to hold a pair?',
    sentAt: DateTime(2026, 9, 25, 16, 25),
    isUnread: true,
  ),
  Conversation(
    id: 'conversation-002',
    storeId: 'seller-bershka',
    storeName: 'Bershka',
    storeAvatarUrl: 'https://picsum.photos/seed/bershka-avatar/100/100',
    lastMessage: 'Thanks for your order, it ships tomorrow morning.',
    sentAt: DateTime(2026, 9, 18, 10, 5),
  ),
  Conversation(
    id: 'conversation-003',
    storeId: 'seller-glossier',
    storeName: 'Glossier',
    storeAvatarUrl: 'https://picsum.photos/seed/glossier-avatar/100/100',
    lastMessage: 'Yes, the blush comes in two more shades next month.',
    sentAt: DateTime(2026, 2, 27, 9, 40),
  ),
];
