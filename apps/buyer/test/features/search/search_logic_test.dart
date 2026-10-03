import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:marketplace_app/features/search/search_logic.dart';

Product _product({
  required String id,
  required String title,
  required String category,
  String storeId = 'store-1',
  String storeName = 'Nike',
  bool isDeal = false,
}) {
  return Product(
    id: id,
    title: title,
    description: '',
    price: 10,
    category: category,
    storeId: storeId,
    storeName: storeName,
    isDeal: isDeal,
    createdAt: DateTime(2026, 1, 1),
  );
}

UserProfile _seller(String id, String name) {
  return UserProfile(id: id, name: name, username: '@$id');
}

void main() {
  final airMax = _product(
    id: 'p1',
    title: 'Air Max 270 Sneakers',
    category: 'Sports',
  );
  final airPods = _product(
    id: 'p2',
    title: 'AirPods Pro',
    category: 'Tech',
    storeId: 'store-2',
    storeName: 'Apple',
  );
  final hoodie = _product(
    id: 'p3',
    title: 'Graphic Print Hoodie',
    category: 'Fashion',
  );
  final deal = _product(
    id: 'p4',
    title: 'Windrunner Jacket',
    category: 'Fashion',
    isDeal: true,
  );

  final products = [airMax, airPods, hoodie, deal];
  final sellers = [_seller('store-1', 'Nike'), _seller('store-2', 'Apple')];

  group('matchesPhrase', () {
    test('matches on title, store name or category, ignoring case', () {
      expect(matchesPhrase(airMax, 'air max'), isTrue);
      expect(matchesPhrase(airPods, 'apple'), isTrue);
      expect(matchesPhrase(hoodie, 'fashion'), isTrue);
      expect(matchesPhrase(hoodie, 'nope'), isFalse);
    });

    test('a blank phrase matches nothing', () {
      expect(matchesPhrase(airMax, '   '), isFalse);
    });
  });

  group('popularCategories', () {
    test('orders by count, then alphabetically', () {
      final result = popularCategories(products);

      expect(result, [
        (category: 'Fashion', count: 2),
        (category: 'Sports', count: 1),
        (category: 'Tech', count: 1),
      ]);
    });
  });

  group('suggestionsFor', () {
    test('builds a phrase from the matching title, up to 3 words', () {
      final result = suggestionsFor(products, 'air');

      expect(result, [
        (text: 'Air Max 270', category: 'Sports'),
        (text: 'AirPods Pro', category: 'Tech'),
      ]);
    });

    test('falls back to titles when no title word starts with the query', () {
      // "apple" only matches AirPods Pro by store name, not by title word.
      final result = suggestionsFor(products, 'apple');

      expect(result, [(text: 'AirPods Pro', category: 'Tech')]);
    });

    test('caps at 8 and returns nothing for a blank query', () {
      expect(suggestionsFor(products, ''), isEmpty);
    });
  });

  group('storesMatching', () {
    test('matches by name, ignoring case, and is empty for a blank query', () {
      expect(storesMatching(sellers, 'app'), [sellers[1]]);
      expect(storesMatching(sellers, ''), isEmpty);
    });
  });

  group('resultsFor', () {
    test('matches by phrase and keeps source order', () {
      expect(resultsFor(products, phrase: 'fashion'), [hoodie, deal]);
    });

    test('narrows a phrase match by category and deals', () {
      expect(resultsFor(products, phrase: 'fashion', dealsOnly: true), [deal]);
    });

    test('a storeId ignores the phrase and lists that store only', () {
      expect(resultsFor(products, storeId: 'store-2'), [airPods]);
    });
  });
}
