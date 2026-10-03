import '../../mock/mock_conversations.dart';
import 'package:shopscroll_shared/models/conversation.dart';
import '../../providers/network_delay.dart';
import '../conversation_repository.dart';

class MockConversationRepository implements ConversationRepository {
  @override
  Future<List<Conversation>> getConversations() async {
    await Future.delayed(mockNetworkDelay);
    return List.of(mockConversations);
  }
}
