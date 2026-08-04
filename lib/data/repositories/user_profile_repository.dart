import '../models/user_profile.dart';

/// Read access to seller/user profiles. See product_repository.dart for the
/// mock/Supabase swap pattern.
abstract class UserProfileRepository {
  Future<List<UserProfile>> getSellers();
  Future<UserProfile?> getUserProfileById(String id);
}
