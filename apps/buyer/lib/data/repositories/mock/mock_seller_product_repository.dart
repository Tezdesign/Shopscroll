import 'dart:typed_data';

import 'package:shopscroll_shared/models/ids.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/product_draft.dart';
import 'package:shopscroll_shared/models/product_variant.dart';

import '../../providers/network_delay.dart';
import '../seller_product_repository.dart';

/// Keeps a seller's products and drafts in memory, so the whole flow runs with
/// no backend (spec 0015, AC-18). It applies the same publish rules as
/// `save_product` through [ProductDraftData.issues]. Products made here do not
/// show in the mock buyer catalog (that list is a constant).
///
/// Only the calls a screen waits on for real (lists, publish) wait
/// [mockNetworkDelay]. Saving a draft and uploading a photo answer at once,
/// because autosave would otherwise be slow to test.
class MockSellerProductRepository implements SellerProductRepository {
  MockSellerProductRepository({this.sellerId = 'mock_seller'});

  final String sellerId;

  final Map<String, Product> _products = {};
  final Map<String, ProductDraft> _drafts = {};
  int _photoCounter = 0;

  static const _categories = ['Fashion', 'Tech', 'Sports', 'Makeup'];

  @override
  Future<List<String>> categories() async => _categories;

  @override
  Future<List<Product>> listProducts(
    SellerProductTab tab, {
    int offset = 0,
    int limit = 20,
  }) async {
    await Future.delayed(mockNetworkDelay);
    final all =
        _products.values.where((p) {
          return switch (tab) {
            SellerProductTab.live => p.status == ProductStatus.live,
            SellerProductTab.outOfStock =>
              p.status == ProductStatus.live && !p.inStock,
            SellerProductTab.archived => p.status == ProductStatus.archived,
          };
        }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.skip(offset).take(limit).toList();
  }

  @override
  Future<List<ProductDraft>> listDrafts({int offset = 0, int limit = 20}) async {
    await Future.delayed(mockNetworkDelay);
    final all = _drafts.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all.skip(offset).take(limit).toList();
  }

  @override
  Future<ProductDraft?> getDraft(String id) async => _drafts[id];

  @override
  Future<ProductDraft> createDraft({
    required String id,
    String? sourceProductId,
    ProductDraftData data = const ProductDraftData(),
  }) async {
    final draft = ProductDraft(
      id: id,
      storeId: sellerId,
      sourceProductId: sourceProductId,
      data: data,
      updatedAt: DateTime.now(),
    );
    _drafts[id] = draft;
    return draft;
  }

  @override
  Future<void> saveDraft(ProductDraft draft) async {
    // Like an UPDATE with no matching row: a draft that is gone stays gone.
    if (!_drafts.containsKey(draft.id)) return;
    _drafts[draft.id] = draft.copyWith(updatedAt: DateTime.now());
  }

  @override
  Future<void> deleteDraft(String id) async {
    _drafts.remove(id);
  }

  @override
  Future<String> uploadPhoto(String draftId, Uint8List jpegBytes) async {
    _photoCounter++;
    return '$sellerId/$draftId/photo$_photoCounter.jpg';
  }

  @override
  Future<void> deletePhoto(String path) async {}

  @override
  Future<String> publish(String draftId) async {
    await Future.delayed(mockNetworkDelay);
    final draft = _drafts[draftId];
    if (draft == null) {
      throw const SellerProductException('not_found');
    }
    final issues = draft.data.issues();
    if (issues.isNotEmpty) {
      throw SellerProductException(issues.first.code, issues.first.variantId);
    }
    final data = draft.data;
    final id = draft.sourceProductId ?? draft.id;
    final existing = _products[id];
    final variants = [
      for (var i = 0; i < data.variants.length; i++)
        _variantFrom(data.variants[i], i, existing),
    ];
    final lowest = variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
    _products[id] = Product(
      id: id,
      title: data.title.trim(),
      description: data.description.trim(),
      price: lowest,
      originalPrice: data.originalPrice == null
          ? null
          : Money.tryParse(data.originalPrice!),
      category: data.category,
      storeId: sellerId,
      storeName: 'My store',
      imageUrl: data.photos.first,
      imageUrls: data.photos,
      colorOptions: {
        for (final v in variants)
          if (v.colorValue != null) v.colorValue!,
      }.toList(),
      sizes: {
        for (final v in variants)
          if (v.size != null) v.size!,
      }.toList(),
      inStock: variants.any((v) => v.stock > 0),
      createdAt: existing?.createdAt ?? DateTime.now(),
      currency: 'TND',
      status: existing?.status ?? ProductStatus.live,
      attributes: data.attributes,
      variants: variants,
    );
    _drafts.remove(draftId);
    return id;
  }

  /// An edit keeps the real stock of a variant the seller did not set on
  /// purpose, like `save_product` does.
  ProductVariant _variantFrom(DraftVariant v, int index, Product? existing) {
    final previous = existing?.variants.where((e) => e.id == v.id).firstOrNull;
    return ProductVariant(
      id: v.id,
      colorName: v.colorName,
      colorValue: v.colorValue,
      size: v.size,
      price: Money.tryParse(v.price)!,
      stock: (previous != null && !v.stockSet) ? previous.stock : v.stock,
      sku: v.sku,
      imagePath: v.imagePath,
      position: index,
    );
  }

  @override
  Future<void> setArchived(String productId, bool archived) async {
    final product = _products[productId];
    if (product == null) throw const SellerProductException('not_found');
    _products[productId] = product.copyWith(
      status: archived ? ProductStatus.archived : ProductStatus.live,
    );
  }

  @override
  Future<void> updateVariantQuick(
    String variantId, {
    required double price,
    required int stock,
  }) async {
    if (price <= 0) throw const SellerProductException('missing_price');
    if (stock < 0) throw const SellerProductException('bad_stock');
    for (final product in _products.values) {
      if (!product.variants.any((v) => v.id == variantId)) continue;
      final variants = [
        for (final v in product.variants)
          v.id == variantId ? v.copyWith(price: price, stock: stock) : v,
      ];
      _products[product.id] = product.copyWith(
        variants: variants,
        price: variants.map((v) => v.price).reduce((a, b) => a < b ? a : b),
        inStock: variants.any((v) => v.stock > 0),
      );
      return;
    }
    throw const SellerProductException('not_found');
  }

  @override
  Future<void> deleteProduct(String productId) async {
    final product = _products[productId];
    if (product == null) throw const SellerProductException('not_found');
    if (product.status != ProductStatus.archived) {
      throw const SellerProductException('not_archived');
    }
    _products.remove(productId);
  }

  @override
  Future<ProductDraft> startEdit(String productId) async {
    final product = _products[productId];
    if (product == null) throw const SellerProductException('not_found');
    return createDraft(
      id: newUuid(),
      sourceProductId: productId,
      data: _dataFrom(product),
    );
  }

  @override
  Future<ProductDraft> createSimilar(String productId) async {
    final product = _products[productId];
    if (product == null) throw const SellerProductException('not_found');
    return createDraft(id: newUuid(), data: _dataFrom(product).asSimilar());
  }

  /// One fixed sample, so the button can be tried with no backend (AC-18).
  @override
  Future<AutofillSuggestion> autofill(String draftId) async {
    final draft = _drafts[draftId];
    if (draft == null || draft.data.photos.isEmpty) {
      throw const SellerProductException('no_photos');
    }
    return const AutofillSuggestion(
      title: 'Long-sleeve wrap dress',
      description:
          'A soft wrap dress with a V-neckline and an adjustable waist tie. An easy fit for everyday wear.',
      category: 'Fashion',
      colors: ['Burgundy', 'Black'],
      material: 'Polyester',
      remaining: 29,
    );
  }

  ProductDraftData _dataFrom(Product product) {
    return ProductDraftData(
      title: product.title,
      description: product.description,
      category: product.category,
      attributes: product.attributes,
      originalPrice: product.originalPrice == null
          ? null
          : Money.toWire(product.originalPrice!),
      photos: product.imageUrls,
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
}
