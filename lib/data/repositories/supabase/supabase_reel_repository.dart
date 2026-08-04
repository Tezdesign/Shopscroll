import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/reel.dart';
import '../reel_repository.dart';

class SupabaseReelRepository implements ReelRepository {
  SupabaseReelRepository(this._client);

  final SupabaseClient _client;

  static const _selectWithProducts = '*, reel_products(product_id)';

  /// The reel ids the signed in user has saved, so [_fromRow] can set
  /// [Reel.isSaved]. reel_saves has no row at all until someone saves a
  /// reel, so this is a plain lookup set, not a join with a default.
  Future<Set<String>> _savedReelIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const {};
    final rows = await _client
        .from('reel_saves')
        .select('reel_id')
        .eq('user_id', userId);
    return rows.map((r) => r['reel_id'] as String).toSet();
  }

  Reel _fromRow(Map<String, dynamic> row, Set<String> savedReelIds) {
    final productIds = (row['reel_products'] as List<dynamic>? ?? const [])
        .map((e) => (e as Map<String, dynamic>)['product_id'] as String)
        .toList();
    return Reel(
      id: row['id'] as String,
      videoUrl: row['video_url'] as String,
      thumbnailUrl: row['thumbnail_url'] as String,
      storeId: row['store_id'] as String,
      storeName: row['store_name'] as String,
      storeAvatarUrl: row['store_avatar_url'] as String?,
      caption: row['caption'] as String,
      likeCount: row['like_count'] as int? ?? 0,
      commentCount: row['comment_count'] as int? ?? 0,
      productIds: productIds,
      isAvailable: row['is_available'] as bool? ?? true,
      isSaved: savedReelIds.contains(row['id'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  Future<List<Reel>> getReels() async {
    final saved = await _savedReelIds();
    final rows = await _client.from('reels').select(_selectWithProducts);
    return rows.map((r) => _fromRow(r, saved)).toList();
  }

  @override
  Future<Reel?> getReelById(String id) async {
    final saved = await _savedReelIds();
    final row = await _client
        .from('reels')
        .select(_selectWithProducts)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _fromRow(row, saved);
  }

  @override
  Future<List<Reel>> getReelsByStore(String storeId) async {
    final saved = await _savedReelIds();
    final rows = await _client
        .from('reels')
        .select(_selectWithProducts)
        .eq('store_id', storeId);
    return rows.map((r) => _fromRow(r, saved)).toList();
  }
}
