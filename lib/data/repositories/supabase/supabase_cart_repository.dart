import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/cart_item.dart';
import '../cart_repository.dart';
import 'row_mappers.dart';

class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CartItem>> getCartItems() async {
    final userId = _client.auth.currentUser?.id;
    // No session yet (auth bootstrap hasn't run): nothing is owned yet.
    if (userId == null) return const [];

    final rows = await _client
        .from('cart_items')
        .select('*, product:products(*)')
        .eq('user_id', userId);

    return rows.map((row) {
      return CartItem(
        id: row['id'] as String,
        product: productFromRow(row['product'] as Map<String, dynamic>),
        quantity: row['quantity'] as int? ?? 1,
        selectedSize: row['selected_size'] as String?,
        selectedColor: (row['selected_color'] as num?)?.toInt(),
        addedAt: DateTime.parse(row['added_at'] as String),
      );
    }).toList();
  }
}
