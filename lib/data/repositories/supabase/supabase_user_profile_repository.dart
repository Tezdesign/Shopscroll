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
}
