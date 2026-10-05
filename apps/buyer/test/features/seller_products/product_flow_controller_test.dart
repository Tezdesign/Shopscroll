import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/repositories/mock/mock_seller_product_repository.dart';
import 'package:marketplace_app/features/seller_products/product_flow_controller.dart';
import 'package:marketplace_app/features/seller_products/variant_options.dart';
import 'package:shopscroll_shared/models/product_draft.dart';

/// A repository whose photo uploads wait for the test, and that counts calls.
class _Repo extends MockSellerProductRepository {
  final uploads = <Completer<String>>[];
  final deletedPhotos = <String>[];
  var createCalls = 0;
  var saveCalls = 0;
  var publishCalls = 0;
  var failSaves = false;

  @override
  Future<String> uploadPhoto(String draftId, Uint8List jpegBytes) {
    final c = Completer<String>();
    uploads.add(c);
    return c.future;
  }

  @override
  Future<void> deletePhoto(String path) async => deletedPhotos.add(path);

  @override
  Future<ProductDraft> createDraft({
    required String id,
    String? sourceProductId,
    ProductDraftData data = const ProductDraftData(),
  }) {
    createCalls++;
    if (failSaves) throw Exception('offline');
    return super.createDraft(id: id, sourceProductId: sourceProductId, data: data);
  }

  @override
  Future<void> saveDraft(ProductDraft draft) {
    saveCalls++;
    if (failSaves) throw Exception('offline');
    return super.saveDraft(draft);
  }

  @override
  Future<String> publish(String draftId) {
    publishCalls++;
    return super.publish(draftId);
  }
}

ProductDraft _blank() => ProductDraft(id: 'd1', storeId: '', updatedAt: DateTime(2026));

ProductFlowController _controller(_Repo repo, {ProductDraft? draft, bool persisted = false}) =>
    ProductFlowController(
      repository: repo,
      draft: draft ?? _blank(),
      persisted: persisted,
      autosaveDelay: const Duration(milliseconds: 20),
    );

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 60));

void _fillBasics(ProductFlowController c) {
  c
    ..setTitle('Wrap dress')
    ..setCategory('Fashion')
    ..setDefaultPrice('89.000');
}

void main() {
  late _Repo repo;
  setUp(() => repo = _Repo());

  group('autosave (spec 0015, AC-6)', () {
    test('nothing is saved until the seller changes something', () async {
      final c = _controller(repo);
      await _settle();
      expect(repo.createCalls + repo.saveCalls, 0);
      c.dispose();
    });

    test('typing is saved once after a pause: the first save makes the draft row', () async {
      final c = _controller(repo);
      c.setTitle('W');
      c.setTitle('Wr');
      c.setTitle('Wrap dress');
      await _settle();

      expect(repo.createCalls, 1);
      expect((await repo.getDraft('d1'))!.data.title, 'Wrap dress');
      expect(c.saveStatus, SaveStatus.saved);

      final savesBefore = repo.saveCalls;
      c.setCategory('Fashion');
      await _settle();
      expect(repo.saveCalls, savesBefore + 1);
      c.dispose();
    });

    test('the step is saved with the draft', () async {
      final c = _controller(repo)..setStep(2);
      await _settle();
      expect((await repo.getDraft('d1'))!.step, 2);
      c.dispose();
    });

    test('a failed save is kept and retried by the next flush', () async {
      repo.failSaves = true;
      final c = _controller(repo)..setTitle('Dress');
      await _settle();
      expect(c.saveStatus, SaveStatus.failed);

      repo.failSaves = false;
      await c.flush();
      expect(c.saveStatus, SaveStatus.saved);
      expect((await repo.getDraft('d1'))!.data.title, 'Dress');
      c.dispose();
    });

    test('a change not yet saved is sent when the screen closes', () async {
      final c = _controller(repo)..setTitle('Dress');
      c.dispose();
      await _settle();
      expect((await repo.getDraft('d1'))?.data.title, 'Dress');
    });
  });

  group('photos (AC-5)', () {
    test('a photo uploads in the background and its path joins the draft', () async {
      final c = _controller(repo);
      c.addPhotos([Uint8List(1)]);
      expect(c.uploadingCount, 1);
      expect(c.data.photos, isEmpty);

      repo.uploads.single.complete('u/d1/a.jpg');
      await _settle();

      expect(c.uploadingCount, 0);
      expect(c.data.photos, ['u/d1/a.jpg']);
      c.dispose();
    });

    test('a failed upload keeps the others, and Retry uploads it again', () async {
      final c = _controller(repo);
      c.addPhotos([Uint8List(1), Uint8List(2)]);
      repo.uploads[0].complete('u/d1/a.jpg');
      repo.uploads[1].completeError(Exception('dropped'));
      await _settle();

      expect(c.hasFailedPhoto, isTrue);
      expect(c.data.photos, ['u/d1/a.jpg']);

      c.retryPhoto(c.photos.last.id);
      expect(c.uploadingCount, 1);
      repo.uploads.last.complete('u/d1/b.jpg');
      await _settle();
      expect(c.data.photos, ['u/d1/a.jpg', 'u/d1/b.jpg']);
      expect(c.hasFailedPhoto, isFalse);
      c.dispose();
    });

    test('no more than 8 photos, the rest are counted as left out', () {
      final c = _controller(repo);
      final left = c.addPhotos([for (var i = 0; i < 10; i++) Uint8List(1)]);
      expect(left, 2);
      expect(c.photos.length, 8);
      c.dispose();
    });

    test('the first photo is the cover, and a photo can be made the cover or moved', () async {
      final c = _controller(repo);
      c.addPhotos([Uint8List(1), Uint8List(2), Uint8List(3)]);
      for (var i = 0; i < 3; i++) {
        repo.uploads[i].complete('u/d1/$i.jpg');
      }
      await _settle();

      c.setCover(2);
      expect(c.data.photos, ['u/d1/2.jpg', 'u/d1/0.jpg', 'u/d1/1.jpg']);
      c.movePhoto(0, 2);
      expect(c.data.photos, ['u/d1/0.jpg', 'u/d1/1.jpg', 'u/d1/2.jpg']);
      c.dispose();
    });

    test('removing a photo deletes its own file and clears color links to it', () async {
      final c = _controller(repo);
      _fillBasics(c);
      c.addPhotos([Uint8List(1)]);
      repo.uploads.single.complete('u/d1/a.jpg');
      await _settle();
      c.setOptionsEnabled(true);
      c.addColor(colorPalette.first);
      c.setColorPhoto(colorPalette.first.value, 'u/d1/a.jpg');
      expect(c.colorPhoto(colorPalette.first.value), 'u/d1/a.jpg');

      c.removePhoto(c.photos.single.id);

      expect(repo.deletedPhotos, ['u/d1/a.jpg']);
      expect(c.data.photos, isEmpty);
      expect(c.colorPhoto(colorPalette.first.value), isNull);
      c.dispose();
    });

    test('a live product\'s own photo is not deleted from storage when removed from an edit', () async {
      final draft = ProductDraft(
        id: 'd9',
        storeId: 'u',
        sourceProductId: 'p1',
        updatedAt: DateTime(2026),
        data: const ProductDraftData(photos: ['u/p1/old.jpg']),
      );
      final c = _controller(repo, draft: draft, persisted: true);

      c.removePhoto(c.photos.single.id);

      expect(repo.deletedPhotos, isEmpty);
      c.dispose();
    });
  });

  group('options and rows (AC-4)', () {
    test('a plain product has one row and the default price fills it', () {
      final c = _controller(repo)..setOptionsEnabled(false);
      c.setDefaultPrice('89');
      expect(c.variants.length, 1);
      expect(c.variants.single.price, '89');
      c.dispose();
    });

    test('colors and sizes build the grid, and the default price reaches new rows only where unchanged', () {
      final c = _controller(repo)..setDefaultPrice('50');
      c.setOptionsEnabled(true);
      c.addColor(colorPalette[0]);
      c.addColor(colorPalette[1]);
      c.toggleSize('S');
      c.toggleSize('M');
      expect(c.variants.length, 4);

      c.setVariantPrice(c.variants.first.id, '70');
      c.setDefaultPrice('60');

      expect(c.variants.first.price, '70');
      expect(c.variants.skip(1).every((v) => v.price == '60'), isTrue);
      c.dispose();
    });

    test('removing a size drops its rows, and a custom size is checked', () {
      final c = _controller(repo)..setDefaultPrice('50');
      c.toggleSize('S');
      c.toggleSize('M');
      c.toggleSize('S');
      expect(c.sizes, ['M']);
      expect(c.addCustomSize(''), isFalse);
      expect(c.addCustomSize('M'), isFalse);
      expect(c.addCustomSize('One size'), isTrue);
      expect(c.sizes, ['M', 'One size']);
      c.dispose();
    });

    test('set all and copy down', () {
      final c = _controller(repo)..setDefaultPrice('50');
      c.toggleSize('S');
      c.toggleSize('M');
      c.toggleSize('L');
      c.setVariantPrice(c.variants[0].id, '10');
      c.copyDown(0, price: true);
      expect(c.variants.map((v) => v.price), ['10', '10', '10']);

      c.setVariantStock(c.variants[1].id, 7);
      c.copyDown(1, price: false);
      expect(c.variants.map((v) => v.stock), [0, 7, 7]);

      c.setAllStock(3);
      c.setAllPrices('99.5');
      expect(c.variants.every((v) => v.stock == 3 && v.price == '99.5'), isTrue);
      c.dispose();
    });

    test('a stock typed on purpose is marked so an edit overwrites it', () {
      final c = _controller(repo)..setDefaultPrice('50');
      c.setVariantStock(c.variants.single.id, 4);
      expect(c.variants.single.stockSet, isTrue);
      c.dispose();
    });
  });

  group('steps and what is missing (AC-7)', () {
    test('Continue is refused with the missing pieces, and the step starts showing them', () {
      final c = _controller(repo);
      expect(c.attempted(1), isFalse);

      expect(c.tryContinue(1), isFalse);

      expect(c.attempted(1), isTrue);
      expect(c.issuesFor(1).map((i) => i.code), containsAll(['bad_title', 'bad_category', 'no_photo']));
      c.dispose();
    });

    test('photos still uploading do not block Continue', () async {
      final c = _controller(repo);
      _fillBasics(c);
      c.addPhotos([Uint8List(1)]);
      repo.uploads.single.complete('u/d1/a.jpg');
      await _settle();
      c.addPhotos([Uint8List(2)]);

      expect(c.tryContinue(1), isTrue);
      c.dispose();
    });

    test('a failed photo blocks Continue until retried or removed', () async {
      final c = _controller(repo);
      _fillBasics(c);
      c.addPhotos([Uint8List(1)]);
      repo.uploads.single.completeError(Exception('x'));
      await _settle();

      expect(c.tryContinue(1), isFalse);
      c.removePhoto(c.photos.single.id);
      c.addPhotos([Uint8List(1)]);
      repo.uploads.last.complete('u/d1/a.jpg');
      await _settle();
      expect(c.tryContinue(1), isTrue);
      c.dispose();
    });
  });

  group('publishing (AC-7, AC-8)', () {
    Future<ProductFlowController> ready() async {
      final c = _controller(repo);
      _fillBasics(c);
      c.addPhotos([Uint8List(1)]);
      repo.uploads.single.complete('mock_seller/d1/a.jpg');
      await _settle();
      c.setVariantStock(c.variants.single.id, 5);
      return c;
    }

    test('publishes a complete draft', () async {
      final c = await ready();

      final result = await c.publish();

      expect(result, isA<Published>());
      expect((result as Published).productId, 'd1');
      expect(repo.publishCalls, 1);
      expect(await repo.getDraft('d1'), isNull);
      c.dispose();
    });

    test('an incomplete draft is refused here and never reaches the server', () async {
      final c = _controller(repo);

      final result = await c.publish();

      expect(result, isA<PublishRefused>());
      expect(repo.publishCalls, 0);
      c.dispose();
    });

    test('Publish waits for photos still uploading, then publishes by itself', () async {
      final c = _controller(repo);
      _fillBasics(c);
      c.addPhotos([Uint8List(1)]);

      final future = c.publish();
      await _settle();
      expect(c.publishing, isTrue);
      expect(c.uploadingCount, 1);
      expect(repo.publishCalls, 0);

      repo.uploads.single.complete('mock_seller/d1/a.jpg');
      final result = await future;

      expect(result, isA<Published>());
      c.dispose();
    });

    test('a failed photo stops Publish with a clear result', () async {
      final c = _controller(repo);
      _fillBasics(c);
      c.addPhotos([Uint8List(1)]);
      final future = c.publish();
      repo.uploads.single.completeError(Exception('x'));

      expect(await future, isA<PublishPhotoFailed>());
      expect(repo.publishCalls, 0);
      c.dispose();
    });

    test('leaving while it waits cancels it: nothing is published', () async {
      final c = _controller(repo);
      _fillBasics(c);
      c.addPhotos([Uint8List(1)]);
      final future = c.publish();
      await _settle();

      c.dispose();

      expect(await future, isA<PublishCancelled>());
      expect(repo.publishCalls, 0);
    });

    test('a save that cannot reach the server is reported, and the draft is kept', () async {
      final c = await ready();
      repo.failSaves = true;
      c.setTitle('Wrap dress 2');

      expect(await c.publish(), isA<PublishNetworkFailed>());
      expect(repo.publishCalls, 0);
      c.dispose();
    });

    test('a server refusal comes back with its code', () async {
      final c = await ready();
      // The draft row disappears behind the phone's back (deleted on another
      // phone): the server answers not_found and the phone keeps working.
      await repo.deleteDraft('d1');

      final result = await c.publish();

      expect(result, isA<PublishRefused>());
      expect((result as PublishRefused).issues.single.code, 'not_found');
      c.dispose();
    });
  });
}
