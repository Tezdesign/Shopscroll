import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_profile.dart';
import '../user_profile_repository.dart';
import 'row_mappers.dart';

class SupabaseUserProfileRepository implements UserProfileRepository {
  SupabaseUserProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<UserProfile>> getSellers() async {
    final rows = await _client
        .from('user_profiles')
        .select()
        .eq('role', 'seller');
    return rows.map(userProfileFromRow).toList();
  }

  @override
  Future<UserProfile?> getUserProfileById(String id) async {
    final row = await _client
        .from('user_profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : userProfileFromRow(row);
  }

  @override
  Future<void> updateUserProfile(
    String id, {
    required String name,
    required String username,
    String? bio,
  }) async {
    try {
      await _client
          .from('user_profiles')
          .update({'name': name, 'username': username, 'bio': bio})
          .eq('id', id);
    } on PostgrestException catch (error) {
      // 23505: Postgres unique_violation, the username column's constraint.
      if (error.code == '23505') throw UsernameTakenException(username);
      rethrow;
    }
  }
}
