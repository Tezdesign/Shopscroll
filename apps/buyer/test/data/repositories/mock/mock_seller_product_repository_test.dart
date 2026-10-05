import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/repositories/mock/mock_seller_product_repository.dart';
import 'package:marketplace_app/data/repositories/seller_product_repository.dart';
import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/product_draft.dart';

ProductDraftData _data({List<DraftVariant>? variants}) => ProductDraftData(
      title: 'Wrap dress',
      category: 'Fashion',
      photos: const ['mock_seller/d1/a.jpg'],
      variants: variants ??
          const [
            DraftVariant(id: 'v1', colorValue: 1, size: 'S', price: '89.000', stock: 4, stockSet: true),
            DraftVariant(id: 'v2', colorValue: 1, size: 'M', price: '95.5', stock: 6, stockSet: true),
          ],
    );

void main() {
  late MockSellerProductRepository repo;
  setUp(() => repo = MockSellerProductRepository());

  // Spec 0015, AC-6, AC-7, AC-11, AC-12, AC-14, AC-18.
  test('a draft publishes into a live product with the lowest variant price', () async {
    await repo.createDraft(id: 'd1', data: _data());

    final id = await repo.publish('d1');

    expect(id, 'd1');
    final live = await repo.listProducts(SellerProductTab.live);
    expect(live.single.price, 89);
    expect(live.single.currency, 'TND');
    expect(live.single.variants.length, 2);
    expect(await repo.getDraft('d1'), isNull);
  });

  test('an incomplete draft is refused with the first reason and stays a draft', () async {
    await repo.createDraft(id: 'd1', data: _data(variants: const [DraftVariant(id: 'v1', price: '')]));

    await expectLater(
      repo.publish('d1'),
      throwsA(isA<SellerProductException>()
          .having((e) => e.code, 'code', 'missing_price')
          .having((e) => e.variantId, 'variantId', 'v1')),
    );
    expect(await repo.getDraft('d1'), isNotNull);
    expect(await repo.listProducts(SellerProductTab.live), isEmpty);
  });

  test('saveDraft keeps the step and fields, and listDrafts shows it', () async {
    final draft = await repo.createDraft(id: 'd1');
    await repo.saveDraft(draft.copyWith(step: 2, data: _data()));

    final drafts = await repo.listDrafts();
    expect(drafts.single.step, 2);
    expect(drafts.single.data.title, 'Wrap dress');
  });

  test('editing a live product keeps the real stock of a variant not set on purpose', () async {
    await repo.createDraft(id: 'd1', data: _data());
    await repo.publish('d1');
    await repo.updateVariantQuick('v1', price: 89, stock: 1);

    final edit = await repo.startEdit('d1');
    final untouched = edit.data.variants.first.copyWith(stock: 100); // stockSet stays false
    await repo.saveDraft(edit.copyWith(data: edit.data.copyWith(
      title: 'Renamed',
      variants: [untouched, edit.data.variants.last],
    )));
    await repo.publish(edit.id);

    final product = (await repo.listProducts(SellerProductTab.live)).single;
    expect(product.title, 'Renamed');
    expect(product.variants.firstWhere((v) => v.id == 'v1').stock, 1);
  });

  test('quick edit changes price and stock and moves the product to Out of stock', () async {
    await repo.createDraft(id: 'd1', data: _data());
    await repo.publish('d1');

    await repo.updateVariantQuick('v1', price: 70.25, stock: 0);
    await repo.updateVariantQuick('v2', price: 95.5, stock: 0);

    final out = await repo.listProducts(SellerProductTab.outOfStock);
    expect(out.single.price, 70.25);
    await expectLater(repo.updateVariantQuick('v1', price: 0, stock: 1), throwsA(isA<SellerProductException>()));
    await expectLater(repo.updateVariantQuick('v1', price: 1, stock: -1), throwsA(isA<SellerProductException>()));
  });

  test('archive, restore, and delete only when archived', () async {
    await repo.createDraft(id: 'd1', data: _data());
    await repo.publish('d1');

    await expectLater(repo.deleteProduct('d1'), throwsA(isA<SellerProductException>()));
    await repo.setArchived('d1', true);
    expect(await repo.listProducts(SellerProductTab.live), isEmpty);
    expect((await repo.listProducts(SellerProductTab.archived)).single.status, ProductStatus.archived);

    await repo.setArchived('d1', false);
    expect(await repo.listProducts(SellerProductTab.live), hasLength(1));

    await repo.setArchived('d1', true);
    await repo.deleteProduct('d1');
    expect(await repo.listProducts(SellerProductTab.archived), isEmpty);
  });

  test('create similar copies the words and variants, sets stock to 0, drops photos', () async {
    await repo.createDraft(id: 'd1', data: _data());
    await repo.publish('d1');

    final similar = await repo.createSimilar('d1');

    expect(similar.id, isNot('d1'));
    expect(similar.data.title, 'Wrap dress');
    expect(similar.data.photos, isEmpty);
    expect(similar.data.variants.map((v) => v.stock), [0, 0]);
    expect(similar.data.variants.map((v) => v.id), isNot(contains('v1')));
    expect(similar.data.variants.first.price, '89.000');
  });

  test('uploadPhoto returns a path in the draft folder', () async {
    final path = await repo.uploadPhoto('d1', Uint8List(3));
    expect(path, startsWith('mock_seller/d1/'));
  });
}
