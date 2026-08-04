import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reel.dart';
import '../repositories/repository_providers.dart';

/// All reels, as if fetched from a `GET /reels` endpoint.
final reelsProvider = FutureProvider<List<Reel>>((ref) {
  return ref.watch(reelRepositoryProvider).getReels();
});

/// A single reel by id, as if fetched from `GET /reels/:id`.
final reelByIdProvider = FutureProvider.family<Reel?, String>((ref, id) {
  return ref.watch(reelRepositoryProvider).getReelById(id);
});

/// Reels posted by a given store, as if fetched from
/// `GET /reels?storeId=:storeId`.
final reelsByStoreProvider = FutureProvider.family<List<Reel>, String>((
  ref,
  storeId,
) {
  return ref.watch(reelRepositoryProvider).getReelsByStore(storeId);
});
