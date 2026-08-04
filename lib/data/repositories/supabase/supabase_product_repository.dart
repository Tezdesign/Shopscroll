import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/product.dart';
import '../product_repository.dart';
import 'row_mappers.dart';

class SupabaseProductRepository implements ProductRepository {
  SupabaseProductRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Product>> getProducts() async {
    final rows = await _client.from('products').select();
    return rows.map(productFromRow).toList();
  }

  @override
  Future<Product?> getProductById(String id) async {
    final row = await _client
        .from('products')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : productFromRow(row);
  }

  @override
  Future<List<Product>> getProductsByCategory(String category) async {
    final rows = await _client
        .from('products')
        .select()
        .eq('category', category);
    return rows.map(productFromRow).toList();
  }

  @override
  Future<List<Product>> getDealsProducts() async {
    final rows = await _client.from('products').select().eq('is_deal', true);
    return rows.map(productFromRow).toList();
  }
}
