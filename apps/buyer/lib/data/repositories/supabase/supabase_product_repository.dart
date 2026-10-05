import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopscroll_shared/models/product.dart';
import '../product_repository.dart';
import 'row_mappers.dart';

class SupabaseProductRepository implements ProductRepository {
  SupabaseProductRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Product>> getProducts() async {
    final rows = await _client.from('products').select().eq('status', 'live');
    return rows.map((r) => productFromRow(r)).toList();
  }

  @override
  Future<Product?> getProductById(String id) async {
    final row = await _client
        .from('products')
        .select(productWithVariantsSelect)
        .eq('id', id)
        .eq('status', 'live')
        .maybeSingle();
    return row == null ? null : productFromRow(row);
  }

  @override
  Future<List<Product>> getProductsByCategory(String category) async {
    final rows = await _client
        .from('products')
        .select()
        .eq('status', 'live')
        .eq('category', category);
    return rows.map((r) => productFromRow(r)).toList();
  }

  @override
  Future<List<Product>> getProductsByStore(String storeId) async {
    final rows = await _client
        .from('products')
        .select()
        .eq('status', 'live')
        .eq('store_id', storeId);
    return rows.map((r) => productFromRow(r)).toList();
  }

  @override
  Future<List<Product>> getDealsProducts() async {
    final rows = await _client
        .from('products')
        .select()
        .eq('status', 'live')
        .eq('is_deal', true);
    return rows.map((r) => productFromRow(r)).toList();
  }
}
