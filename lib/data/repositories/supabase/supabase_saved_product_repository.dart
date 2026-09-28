import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/product.dart';
import '../../models/saved_product.dart';
import '../saved_product_repository.dart';
import 'row_mappers.dart';
import 'session_user_id.dart';

class SupabaseSavedProductRepository implements SavedProductRepository {
  SupabaseSavedProductRepository(this._client);

  final SupabaseClient _client;

  /// Row level security already limits every call below to the caller's own
  /// rows (spec 0008), and `user_id` is only ever read from the session.
  Future<String?> get _userId => currentSessionUserId(_client);

  @override
  Future<List<SavedProduct>> getSavedProducts() async {
    final userId = await _userId;
    // No session yet (auth bootstrap hasn't run): nothing is owned yet.
    if (userId == null) return const [];

    final rows = await _client
        .from('product_saves')
        .select('created_at, product:products(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return rows
        .map(
          (row) => SavedProduct(
            productFromRow(row['product'] as Map<String, dynamic>),
            DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<SavedProduct> saveProduct(Product product, {DateTime? savedAt}) async {
    final userId = await _userId;
    if (userId == null) throw StateError('No session to save a product');

    final at = savedAt ?? DateTime.now();
    // Idempotent: a repeat save of the same product changes nothing.
    await _client
        .from('product_saves')
        .upsert(
          {
            'user_id': userId,
            'product_id': product.id,
            'created_at': at.toUtc().toIso8601String(),
          },
          onConflict: 'user_id,product_id',
          ignoreDuplicates: true,
        );
    return SavedProduct(product, at);
  }

  @override
  Future<void> unsaveProduct(String productId) async {
    final userId = await _userId;
    if (userId == null) throw StateError('No session to unsave a product');

    await _client
        .from('product_saves')
        .delete()
        .eq('user_id', userId)
        .eq('product_id', productId);
  }
}
