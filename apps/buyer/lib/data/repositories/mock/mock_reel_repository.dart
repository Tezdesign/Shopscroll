import '../../mock/mock_reels.dart';
import 'package:shopscroll_shared/models/reel.dart';
import '../../models/saved_reel.dart';
import '../../providers/network_delay.dart';
import '../reel_repository.dart';

class MockReelRepository implements ReelRepository {
  // The reels the mock data marks as saved start saved, one day apart, so
  // My collection has an order to show. Writes last for the run of the app.
  final Map<String, SavedReel> _saved = {
    for (final (i, reel) in mockReels.where((r) => r.isSaved).indexed)
      reel.id: SavedReel(
        reel,
        DateTime(2026, 9, 20).subtract(Duration(days: i)),
      ),
  };

  @override
  Future<List<Reel>> getReels() async {
    await Future.delayed(mockNetworkDelay);
    return mockReels;
  }

  @override
  Future<Reel?> getReelById(String id) async {
    await Future.delayed(mockNetworkDelay);
    for (final reel in mockReels) {
      if (reel.id == id) return reel;
    }
    return null;
  }

  @override
  Future<List<Reel>> getReelsByStore(String storeId) async {
    await Future.delayed(mockNetworkDelay);
    return mockReels.where((r) => r.storeId == storeId).toList();
  }

  @override
  Future<List<SavedReel>> getSavedReels() async {
    await Future.delayed(mockNetworkDelay);
    return _saved.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  @override
  Future<SavedReel> saveReel(Reel reel, {DateTime? savedAt}) async {
    await Future.delayed(mockNetworkDelay);
    return _saved.putIfAbsent(
      reel.id,
      () => SavedReel(reel, savedAt ?? DateTime.now()),
    );
  }

  @override
  Future<void> unsaveReel(String reelId) async {
    await Future.delayed(mockNetworkDelay);
    _saved.remove(reelId);
  }
}
