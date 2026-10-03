import 'package:shopscroll_shared/models/conversation.dart';
import '../conversation_repository.dart';

/// No conversations table exists yet (spec 0008, AC-13): a chat feature will
/// design one and replace this. Until then the Messages tab is empty on the
/// real backend.
class SupabaseConversationRepository implements ConversationRepository {
  @override
  Future<List<Conversation>> getConversations() async => const [];
}
