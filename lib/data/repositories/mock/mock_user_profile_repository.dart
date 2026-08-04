import '../../mock/mock_sellers.dart';
import '../../models/user_profile.dart';
import '../../providers/network_delay.dart';
import '../user_profile_repository.dart';

class MockUserProfileRepository implements UserProfileRepository {
  @override
  Future<List<UserProfile>> getSellers() async {
    await Future.delayed(mockNetworkDelay);
    return mockSellers;
  }

  @override
  Future<UserProfile?> getUserProfileById(String id) async {
    await Future.delayed(mockNetworkDelay);
    for (final profile in mockSellers) {
      if (profile.id == id) return profile;
    }
    return null;
  }
}
