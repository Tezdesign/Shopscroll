import '../models/user_profile.dart';

/// Read and update access to seller/user profiles. See
/// product_repository.dart for the mock/Supabase swap pattern.
abstract class UserProfileRepository {
  Future<List<UserProfile>> getSellers();
  Future<UserProfile?> getUserProfileById(String id);

  /// Updates the caller's own profile row (name, username, bio). Throws
  /// [UsernameTakenException] when `username` is already used by a
  /// different profile (spec 0005, AC-6).
  Future<void> updateUserProfile(
    String id, {
    required String name,
    required String username,
    String? bio,
  });
}

/// Thrown by [UserProfileRepository.updateUserProfile] when `username` is
/// already taken by a different profile.
class UsernameTakenException implements Exception {
  const UsernameTakenException(this.username);

  final String username;
}
