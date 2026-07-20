import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_reels.dart';
import '../models/reel.dart';
import 'network_delay.dart';

/// All reels, as if fetched from a `GET /reels` endpoint.
final reelsProvider = FutureProvider<List<Reel>>((ref) async {
  await Future.delayed(mockNetworkDelay);
  return mockReels;
});

/// A single reel by id, as if fetched from `GET /reels/:id`.
final reelByIdProvider = FutureProvider.family<Reel?, String>((
  ref,
  id,
) async {
  await Future.delayed(mockNetworkDelay);
  for (final reel in mockReels) {
    if (reel.id == id) return reel;
  }
  return null;
});

/// Reels posted by a given store, as if fetched from
/// `GET /reels?storeId=:storeId`.
final reelsByStoreProvider = FutureProvider.family<List<Reel>, String>((
  ref,
  storeId,
) async {
  await Future.delayed(mockNetworkDelay);
  return mockReels.where((r) => r.storeId == storeId).toList();
});
