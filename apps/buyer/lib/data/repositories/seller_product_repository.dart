import 'dart:typed_data';

import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/product_draft.dart';

/// Which products the seller's Products list shows (spec 0015, AC-11). Drafts
/// are listed on their own with [SellerProductRepository.listDrafts].
enum SellerProductTab { live, outOfStock, archived }

/// What a seller can do with their own products and drafts (spec 0015). One
/// implementation keeps everything in memory
/// ([lib/data/repositories/mock/mock_seller_product_repository.dart]), the
/// other talks to Supabase
/// ([lib/data/repositories/supabase/supabase_seller_product_repository.dart]);
/// the app swaps between them through [sellerProductRepositoryProvider].
///
/// Refusals from the server are thrown as [SellerProductException] with the
/// server's reason code.
abstract class SellerProductRepository {
  /// The category names a product may use, in display order.
  Future<List<String>> categories();

  /// The seller's own products for one tab, newest change first.
  Future<List<Product>> listProducts(
    SellerProductTab tab, {
    int offset = 0,
    int limit = 20,
  });

  /// The seller's unfinished work, newest first.
  Future<List<ProductDraft>> listDrafts({int offset = 0, int limit = 20});

  Future<ProductDraft?> getDraft(String id);

  /// Makes a new empty draft with an id made on the phone. [sourceProductId]
  /// is set for a working copy of a live product.
  Future<ProductDraft> createDraft({
    required String id,
    String? sourceProductId,
    ProductDraftData data = const ProductDraftData(),
  });

  /// Saves the step and the fields as the seller types (autosave).
  Future<void> saveDraft(ProductDraft draft);

  /// Deletes the draft and the photos it added itself.
  Future<void> deleteDraft(String id);

  /// Uploads one already shrunk JPEG for a draft and returns its storage
  /// path (the bucket name is not part of it).
  Future<String> uploadPhoto(String draftId, Uint8List jpegBytes);

  /// Removes one uploaded photo. Best effort, never throws.
  Future<void> deletePhoto(String path);

  /// Turns the draft into a live product (or applies an edit) and returns the
  /// product id. Throws [SellerProductException].
  Future<String> publish(String draftId);

  Future<void> setArchived(String productId, bool archived);

  /// Changes one variant's price and stock without opening the flow.
  Future<void> updateVariantQuick(
    String variantId, {
    required double price,
    required int stock,
  });

  /// Deletes an archived product and its photos.
  Future<void> deleteProduct(String productId);

  /// Opens a working copy of a live product as a new draft.
  Future<ProductDraft> startEdit(String productId);

  /// Makes a new draft from an existing product (AC-14).
  Future<ProductDraft> createSimilar(String productId);

  /// "Fill from photos" (AC-13): asks for a suggestion made from the photos of
  /// the draft. Saves nothing. Throws [SellerProductException] with
  /// `quota_exceeded`, `no_photos`, `timeout`, `model_failed` or `bad_answer`.
  Future<AutofillSuggestion> autofill(String draftId);
}
