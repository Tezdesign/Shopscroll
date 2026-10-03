import 'package:shopscroll_shared/models/conversation.dart';

/// Read access to the buyer's store conversations (spec 0008). The mock
/// version holds a few placeholders. The Supabase version returns an empty
/// list until a chat feature designs a conversations table.
abstract class ConversationRepository {
  /// As if fetched from `GET /conversations`. Newest first.
  Future<List<Conversation>> getConversations();
}
