import 'package:flutter/foundation.dart';
import 'package:shopscroll_shared/models/ids.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/product_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../seller_product_repository.dart';
import 'row_mappers.dart';
import 'session_user_id.dart';

/// Talks to Supabase for a seller's products (spec 0015). Drafts are plain
/// rows in `product_drafts` that the app writes as the seller types. Every
/// change to the catalog goes through a database function (`save_product`,
/// `set_product_archived`, `update_variant_quick`), because clients have no
/// direct write rights on `products` or `product_variants`
/// (`supabase/migrations/0008_seller_products.sql`).
class SupabaseSellerProductRepository implements SellerProductRepository {
  SupabaseSellerProductRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'product-images';

  Future<String> get _userId async {
    final id = await currentSessionUserId(_client);
    if (id == null) throw const SellerProductException('no_session');
    return id;
  }

  /// Runs a call and turns the server's refusal into a typed exception. The
  /// functions raise their reason as the whole message.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (error) {
      throw SellerProductException.fromMessage(error.message);
    }
  }

  @override
  Future<List<String>> categories() async {
    final rows = await _client
        .from('product_categories')
        .select('slug')
        .order('position');
    return rows.map((r) => r['slug'] as String).toList();
  }

  @override
  Future<List<Product>> listProducts(
    SellerProductTab tab, {
    int offset = 0,
    int limit = 20,
  }) async {
    final userId = await _userId;
    var query = _client
        .from('products')
        .select(productWithVariantsSelect)
        .eq('store_id', userId);
    query = switch (tab) {
      SellerProductTab.live => query.eq('status', 'live'),
      SellerProductTab.outOfStock => query
          .eq('status', 'live')
          .eq('in_stock', false),
      SellerProductTab.archived => query.eq('status', 'archived'),
    };
    final rows = await _guard(
      () => query
          .order('updated_at', ascending: false)
          .range(offset, offset + limit - 1),
    );
    return rows.map((r) => productFromRow(r)).toList();
  }

  @override
  Future<List<ProductDraft>> listDrafts({int offset = 0, int limit = 20}) async {
    final userId = await _userId;
    final rows = await _client
        .from('product_drafts')
        .select()
        .eq('store_id', userId)
        .order('updated_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map(_draftFromRow).toList();
  }

  @override
  Future<ProductDraft?> getDraft(String id) async {
    final row = await _client
        .from('product_drafts')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _draftFromRow(row);
  }

  @override
  Future<ProductDraft> createDraft({
    required String id,
    String? sourceProductId,
    ProductDraftData data = const ProductDraftData(),
  }) async {
    final userId = await _userId;
    final row = await _guard(
      () => _client
          .from('product_drafts')
          .insert({
            'id': id,
            'store_id': userId,
            'source_product_id': sourceProductId,
            'step': 1,
            'payload': data.toJson(),
          })
          .select()
          .single(),
    );
    return _draftFromRow(row);
  }

  @override
  Future<void> saveDraft(ProductDraft draft) async {
    await _guard(
      () => _client
          .from('product_drafts')
          .update({'step': draft.step, 'payload': draft.data.toJson()})
          .eq('id', draft.id),
    );
  }

  @override
  Future<void> deleteDraft(String id) async {
    final userId = await _userId;
    final draft = await getDraft(id);
    await _client.from('product_drafts').delete().eq('id', id);
    // Only photos in the draft's own folder go. An edit draft also lists the
    // live product's photos, which belong to the product.
    if (draft != null) {
      final own = '$userId/$id/';
      await _removeFiles(draft.data.photos.where((p) => p.startsWith(own)));
    }
  }

  @override
  Future<String> uploadPhoto(String draftId, Uint8List jpegBytes) async {
    final userId = await _userId;
    final path = '$userId/$draftId/${newUuid()}.jpg';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          jpegBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return path;
  }

  @override
  Future<void> deletePhoto(String path) => _removeFiles([path]);

  Future<void> _removeFiles(Iterable<String> paths) async {
    final list = paths.toList();
    if (list.isEmpty) return;
    try {
      await _client.storage.from(_bucket).remove(list);
    } catch (error) {
      // A file left behind is cleaned up later, it must not block the seller.
      debugPrint('product photo remove failed: $error');
    }
  }

  @override
  Future<String> publish(String draftId) async {
    final id = await _guard(
      () => _client.rpc('save_product', params: {'p_draft_id': draftId}),
    );
    return id as String;
  }

  @override
  Future<void> setArchived(String productId, bool archived) async {
    await _guard(
      () => _client.rpc(
        'set_product_archived',
        params: {'p_id': productId, 'p_archived': archived},
      ),
    );
  }

  @override
  Future<void> updateVariantQuick(
    String variantId, {
    required double price,
    required int stock,
  }) async {
    await _guard(
      () => _client.rpc(
        'update_variant_quick',
        params: {
          'p_variant_id': variantId,
          'p_price': double.parse(Money.toWire(price)),
          'p_stock': stock,
        },
      ),
    );
  }

  @override
  Future<void> deleteProduct(String productId) async {
    final row = await _client
        .from('products')
        .select('image_urls, status')
        .eq('id', productId)
        .maybeSingle();
    if (row == null) throw const SellerProductException('not_found');
    final deleted = await _guard(
      () => _client
          .from('products')
          .delete()
          .eq('id', productId)
          .select('id'),
    );
    // The database refuses a live product by returning no row.
    if (deleted.isEmpty) throw const SellerProductException('not_archived');
    await _removeFiles(_photoPaths(row['image_urls']));
  }

  @override
  Future<ProductDraft> startEdit(String productId) async {
    final data = await _dataFromProduct(productId);
    return createDraft(
      id: newUuid(),
      sourceProductId: productId,
      data: data,
    );
  }

  @override
  Future<ProductDraft> createSimilar(String productId) async {
    final data = await _dataFromProduct(productId);
    return createDraft(id: newUuid(), data: data.asSimilar());
  }

  @override
  Future<AutofillSuggestion> autofill(String draftId) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'autofill-product',
        body: {'draft_id': draftId},
      );
    } on FunctionException catch (error) {
      // The function answers with {"error": "<reason>"} and a status.
      final details = error.details;
      final reason = details is Map ? details['error'] as String? : null;
      throw SellerProductException(reason ?? 'unknown');
    }
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const SellerProductException('bad_answer');
    }
    return AutofillSuggestion.fromJson(data);
  }

  Future<ProductDraftData> _dataFromProduct(String productId) async {
    final row = await _client
        .from('products')
        .select(productWithVariantsSelect)
        .eq('id', productId)
        .maybeSingle();
    if (row == null) throw const SellerProductException('not_found');
    final product = productFromRow(row);
    return ProductDraftData(
      title: product.title,
      description: product.description,
      category: product.category,
      attributes: product.attributes,
      originalPrice: product.originalPrice == null
          ? null
          : Money.toWire(product.originalPrice!),
      photos: _photoPaths(row['image_urls']).toList(),
      variants: [
        for (final v in product.variants)
          DraftVariant(
            id: v.id,
            colorName: v.colorName,
            colorValue: v.colorValue,
            size: v.size,
            price: Money.toWire(v.price),
            stock: v.stock,
            sku: v.sku,
            imagePath: v.imagePath,
          ),
      ],
    );
  }

  /// The storage paths (without the bucket) among a product's `image_urls`.
  /// Seed products keep full web addresses, which are not ours to edit or
  /// remove, so they are left out.
  Iterable<String> _photoPaths(dynamic imageUrls) sync* {
    const prefix = '$_bucket/';
    for (final value in (imageUrls as List<dynamic>? ?? const [])) {
      final text = value as String;
      if (text.startsWith(prefix)) yield text.substring(prefix.length);
    }
  }

  ProductDraft _draftFromRow(Map<String, dynamic> row) {
    return ProductDraft(
      id: row['id'] as String,
      storeId: row['store_id'] as String,
      sourceProductId: row['source_product_id'] as String?,
      step: (row['step'] as num?)?.toInt() ?? 1,
      data: ProductDraftData.fromJson(
        row['payload'] as Map<String, dynamic>? ?? const {},
      ),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
