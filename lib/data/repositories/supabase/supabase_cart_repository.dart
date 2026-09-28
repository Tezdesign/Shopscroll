import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/cart/cart_logic.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../cart_repository.dart';
import 'row_mappers.dart';
import 'session_user_id.dart';

class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository(this._client);

  final SupabaseClient _client;

  static const _select = '*, product:products(*)';

  /// Row level security already limits every call below to the caller's own
  /// rows (spec 0004), and `user_id` is only ever read from the session.
  Future<String?> get _userId => currentSessionUserId(_client);

  @override
  Future<List<CartItem>> getCartItems() async {
    final userId = await _userId;
    // No session yet (auth bootstrap hasn't run): nothing is owned yet.
    if (userId == null) return const [];

    final rows = await _client
        .from('cart_items')
        .select(_select)
        .eq('user_id', userId);

    return rows.map(_fromRow).toList();
  }

  @override
  Future<CartItem> addItem(
    Product product,
    int quantity, {
    String? size,
    int? color,
  }) async {
    final userId = await _userId;
    if (userId == null) throw StateError('No session to add to a cart');

    var match = _client
        .from('cart_items')
        .select(_select)
        .eq('user_id', userId)
        .eq('product_id', product.id);
    match = size == null
        ? match.isFilter('selected_size', null)
        : match.eq('selected_size', size);
    match = color == null
        ? match.isFilter('selected_color', null)
        : match.eq('selected_color', color);
    final existing = await match.limit(1).maybeSingle();

    if (existing != null) {
      final row = await _client
          .from('cart_items')
          .update({
            'quantity': clampQuantity((existing['quantity'] as int) + quantity),
          })
          .eq('id', existing['id'] as String)
          .select(_select)
          .single();
      return _fromRow(row);
    }

    final row = await _client
        .from('cart_items')
        .insert({
          'user_id': userId,
          'product_id': product.id,
          'quantity': clampQuantity(quantity),
          'selected_size': size,
          'selected_color': color,
        })
        .select(_select)
        .single();
    return _fromRow(row);
  }

  @override
  Future<CartItem> setQuantity(String itemId, int quantity) async {
    final row = await _client
        .from('cart_items')
        .update({'quantity': clampQuantity(quantity)})
        .eq('id', itemId)
        .select(_select)
        .single();
    return _fromRow(row);
  }

  @override
  Future<void> removeItem(String itemId) async {
    await _client.from('cart_items').delete().eq('id', itemId);
  }

  CartItem _fromRow(Map<String, dynamic> row) {
    return CartItem(
      id: row['id'] as String,
      product: productFromRow(row['product'] as Map<String, dynamic>),
      quantity: row['quantity'] as int? ?? 1,
      selectedSize: row['selected_size'] as String?,
      selectedColor: (row['selected_color'] as num?)?.toInt(),
      addedAt: DateTime.parse(row['added_at'] as String),
    );
  }
}
