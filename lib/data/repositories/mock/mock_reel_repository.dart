import '../../mock/mock_reels.dart';
import '../../models/reel.dart';
import '../../providers/network_delay.dart';
import '../reel_repository.dart';

class MockReelRepository implements ReelRepository {
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
}
