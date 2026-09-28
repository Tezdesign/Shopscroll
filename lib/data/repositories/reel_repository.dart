import '../models/reel.dart';
import '../models/saved_reel.dart';

/// Access to reels, and to the ones the buyer saved. See [ProductRepository]
/// for the swap pattern. The save writes stand in for the REST calls named
/// on each method (spec 0008) and throw when they fail, so the caller can
/// undo what it showed. Saving twice is not an error, and neither is
/// removing a reel that is not saved.
abstract class ReelRepository {
  Future<List<Reel>> getReels();
  Future<Reel?> getReelById(String id);
  Future<List<Reel>> getReelsByStore(String storeId);

  /// As if fetched from `GET /saved-reels`. Newest saved first, and
  /// unavailable reels are included.
  Future<List<SavedReel>> getSavedReels();

  /// As if sent to `PUT /saved-reels/:reelId`. [savedAt] is only for Undo.
  Future<SavedReel> saveReel(Reel reel, {DateTime? savedAt});

  /// As if sent to `DELETE /saved-reels/:reelId`.
  Future<void> unsaveReel(String reelId);
}
