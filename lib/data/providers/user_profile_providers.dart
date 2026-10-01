import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../repositories/repository_providers.dart';

/// All seller profiles, as if fetched from a `GET /sellers` endpoint.
final sellersProvider = FutureProvider<List<UserProfile>>((ref) {
  return ref.watch(userProfileRepositoryProvider).getSellers();
});

/// A single user/seller profile by id, as if fetched from
/// `GET /users/:id`. No automatic retry, so a failed load reaches the Store
/// Page (and checkout's prefill) as an error with its own "Try again",
/// matching `order_providers.dart`'s reasoning.
final userProfileByIdProvider = FutureProvider.family<UserProfile?, String>((
  ref,
  id,
) {
  return ref.watch(userProfileRepositoryProvider).getUserProfileById(id);
}, retry: (retryCount, error) => null);
