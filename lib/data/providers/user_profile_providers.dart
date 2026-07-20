import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_sellers.dart';
import '../models/user_profile.dart';
import 'network_delay.dart';

/// All seller profiles, as if fetched from a `GET /sellers` endpoint.
final sellersProvider = FutureProvider<List<UserProfile>>((ref) async {
  await Future.delayed(mockNetworkDelay);
  return mockSellers;
});

/// A single user/seller profile by id, as if fetched from
/// `GET /users/:id`.
final userProfileByIdProvider = FutureProvider.family<UserProfile?, String>((
  ref,
  id,
) async {
  await Future.delayed(mockNetworkDelay);
  for (final profile in mockSellers) {
    if (profile.id == id) return profile;
  }
  return null;
});
