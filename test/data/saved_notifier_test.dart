import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/mock/mock_products.dart';
import 'package:marketplace_app/data/mock/mock_reels.dart';
import 'package:marketplace_app/data/models/product.dart';
import 'package:marketplace_app/data/models/saved_product.dart';
import 'package:marketplace_app/data/providers/saved_providers.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/data/repositories/saved_product_repository.dart';

/// In memory repository with no delay, and a switch to make writes fail.
class _FakeRepo implements SavedProductRepository {
  final saved = <String, SavedProduct>{};
  bool fail = false;

  @override
  Future<List<SavedProduct>> getSavedProducts() async =>
      saved.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));

  @override
  Future<SavedProduct> saveProduct(Product product, {DateTime? savedAt}) async {
    if (fail) throw Exception('boom');
    return saved[product.id] = SavedProduct(product, savedAt ?? DateTime.now());
  }

  @override
  Future<void> unsaveProduct(String productId) async {
    if (fail) throw Exception('boom');
    saved.remove(productId);
  }
}

void main() {
  late _FakeRepo repo;
  late ProviderContainer container;
  final blazer = mockProducts[0];
  final hoodie = mockProducts[3];

  Future<SavedProductsNotifier> open() async {
    await container.read(savedProductsProvider.future);
    return container.read(savedProductsProvider.notifier);
  }

  List<String> ids() => container
      .read(savedProductsProvider)
      .requireValue
      .map((s) => s.product.id)
      .toList();

  setUp(() {
    repo = _FakeRepo();
    container = ProviderContainer(
      overrides: [savedProductRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  test('a save shows at once, newest first, and is stored (AC-8)', () async {
    final saved = await open();
    final first = saved.save(blazer, savedAt: DateTime(2026, 1, 1));
    final second = saved.save(hoodie, savedAt: DateTime(2026, 2, 1));
    expect(ids(), [hoodie.id, blazer.id]);
    await Future.wait([first, second]);
    expect(repo.saved.keys, containsAll([blazer.id, hoodie.id]));
  });

  test('saving the same product twice keeps one row', () async {
    final saved = await open();
    await saved.save(blazer);
    await saved.save(blazer);
    expect(ids(), [blazer.id]);
  });

  test('toggle saves, then unsaves, going by the current state', () async {
    final saved = await open();
    await saved.toggle(blazer);
    expect(saved.isSaved(blazer.id), isTrue);
    await saved.toggle(blazer);
    expect(saved.isSaved(blazer.id), isFalse);
    expect(repo.saved, isEmpty);
  });

  test('Undo puts an item back at its old place (AC-7)', () async {
    final saved = await open();
    await saved.save(blazer, savedAt: DateTime(2026, 1, 1));
    await saved.save(hoodie, savedAt: DateTime(2026, 2, 1));
    await saved.unsave(hoodie.id);
    expect(ids(), [blazer.id]);
    await saved.save(hoodie, savedAt: DateTime(2026, 2, 1));
    expect(ids(), [hoodie.id, blazer.id]);
  });

  test('a failed unsave puts the item back and rethrows (AC-10)', () async {
    final saved = await open();
    await saved.save(blazer);
    repo.fail = true;
    await expectLater(saved.unsave(blazer.id), throwsException);
    expect(ids(), [blazer.id]);
  });

  test('a failed save takes the item out again and rethrows (AC-10)', () async {
    final saved = await open();
    repo.fail = true;
    await expectLater(saved.save(blazer), throwsException);
    expect(ids(), isEmpty);
  });

  test('saved reels start from the ones the mock data marks saved', () async {
    final reels = await container.read(savedReelsProvider.future);
    // The default repository is the mock one, which seeds two saved reels.
    expect(
      reels.map((s) => s.reel.id).toSet(),
      mockReels.where((r) => r.isSaved).map((r) => r.id).toSet(),
    );
    final notifier = container.read(savedReelsProvider.notifier);
    await notifier.toggle(mockReels.first);
    expect(notifier.isSaved(mockReels.first.id), isTrue);
    await notifier.toggle(mockReels.first);
    expect(notifier.isSaved(mockReels.first.id), isFalse);
  });
}
