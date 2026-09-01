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

  @override
  Future<void> updateUserProfile(
    String id, {
    required String name,
    required String username,
    String? bio,
  }) async {
    await Future.delayed(mockNetworkDelay);
    final takenByOther = mockSellers.any(
      (profile) => profile.username == username && profile.id != id,
    );
    if (takenByOther) throw UsernameTakenException(username);

    final index = mockSellers.indexWhere((profile) => profile.id == id);
    if (index == -1) {
      mockSellers.add(
        UserProfile(
          id: id,
          name: name,
          username: username,
          bio: bio,
          role: UserRole.buyer,
        ),
      );
      return;
    }
    mockSellers[index] = mockSellers[index].copyWith(
      name: name,
      username: username,
      bio: bio,
    );
  }
}
