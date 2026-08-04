import '../models/reel.dart';

/// Read access to reels. See [ProductRepository] for the swap pattern.
abstract class ReelRepository {
  Future<List<Reel>> getReels();
  Future<Reel?> getReelById(String id);
  Future<List<Reel>> getReelsByStore(String storeId);
}
