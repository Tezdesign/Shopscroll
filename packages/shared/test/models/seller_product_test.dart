import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/product_draft.dart';
import 'package:shopscroll_shared/models/product_variant.dart';

Product _product({String currency = 'USD', List<ProductVariant> variants = const []}) =>
    Product(
      id: 'p1',
      title: 'Dress',
      description: 'd',
      price: 40,
      category: 'Fashion',
      storeId: 's',
      storeName: 'S',
      createdAt: DateTime(2026),
      currency: currency,
      variants: variants,
    );

DraftVariant _variant(String id, {String price = '10', int stock = 1, int? color, String? size}) =>
    DraftVariant(id: id, price: price, stock: stock, colorValue: color, size: size);

void main() {
  group('Money (spec 0015, AC-9)', () {
    test('formats each currency', () {
      expect(Money.format(40, 'USD'), '\$40');
      expect(Money.format(89, 'TND'), '89.000 TND');
      expect(Money.format(12.5, 'EUR'), '12.50 EUR');
    });

    test('toWire always has 3 decimals', () {
      expect(Money.toWire(89), '89.000');
      expect(Money.toWire(70.25), '70.250');
    });

    test('tryParse accepts up to 3 decimals and a comma', () {
      expect(Money.tryParse('89'), 89);
      expect(Money.tryParse(' 89,5 '), 89.5);
      expect(Money.tryParse('89.125'), 89.125);
      expect(Money.tryParse('89.1234'), isNull);
      expect(Money.tryParse('-5'), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse(''), isNull);
    });
  });

  group('Product variants', () {
    final blackL = ProductVariant(id: 'v1', colorValue: 1, size: 'L', price: 99, stock: 2);
    final plain = ProductVariant(id: 'v2', price: 55, stock: 1);

    test('variantFor matches color and size, a missing choice matches a missing option', () {
      final p = _product(variants: [blackL, plain]);
      expect(p.variantFor(color: 1, size: 'L')?.id, 'v1');
      expect(p.variantFor()?.id, 'v2');
      expect(p.variantFor(color: 1), isNull);
    });

    test('priceFor falls back to the product price', () {
      final p = _product(variants: [blackL]);
      expect(p.priceFor(color: 1, size: 'L'), 99);
      expect(p.priceFor(color: 9, size: 'S'), 40);
    });

    test('priceLabel uses the product currency', () {
      expect(_product().priceLabel, '\$40');
      expect(_product(currency: 'TND').priceLabel, '40.000 TND');
    });

    test('json round trip keeps currency, status and variants', () {
      final p = _product(currency: 'TND', variants: [blackL]).copyWith(status: ProductStatus.archived);
      final again = Product.fromJson(p.toJson());
      expect(again.currency, 'TND');
      expect(again.status, ProductStatus.archived);
      expect(again.variants.single.size, 'L');
    });
  });

  group('ProductDraftData.issues (mirrors save_product)', () {
    ProductDraftData ok() => ProductDraftData(
          title: 'Wrap dress',
          category: 'Fashion',
          photos: const ['u/d/a.jpg'],
          variants: [_variant('a')],
        );

    List<String> codes(ProductDraftData d) => d.issues().map((i) => i.code).toList();

    test('a complete draft has no issues', () {
      expect(ok().issues(), isEmpty);
    });

    test('reports each missing piece with the server code', () {
      expect(codes(const ProductDraftData()), containsAll(['bad_title', 'bad_category', 'no_photo', 'no_variants']));
      expect(codes(ok().copyWith(title: 'x')), ['bad_title']);
      expect(codes(ok().copyWith(category: '')), ['bad_category']);
      expect(codes(ok().copyWith(photos: [])), ['no_photo']);
    });

    test('names the variant with a bad price or stock', () {
      final d = ok().copyWith(variants: [_variant('a', price: ''), _variant('b', stock: -1, size: 'M')]);
      final issues = d.issues();
      expect(issues.where((i) => i.code == 'missing_price').single.variantId, 'a');
      expect(issues.where((i) => i.code == 'bad_stock').single.variantId, 'b');
    });

    test('a price with 4 decimals or 0 is refused', () {
      expect(codes(ok().copyWith(variants: [_variant('a', price: '1.2345')])), ['missing_price']);
      expect(codes(ok().copyWith(variants: [_variant('a', price: '0')])), ['missing_price']);
    });

    test('two rows with the same color and size are duplicates', () {
      final d = ok().copyWith(variants: [_variant('a', color: 1, size: 'S'), _variant('b', color: 1, size: 'S')]);
      expect(codes(d), ['duplicate_variant']);
    });

    test('more than 100 variants is too many', () {
      final many = [for (var i = 0; i < 101; i++) _variant('v$i', size: 'S$i')];
      expect(codes(ok().copyWith(variants: many)), ['too_many_variants']);
    });

    test('lowestPrice and totalStock', () {
      final d = ok().copyWith(variants: [_variant('a', price: '89.5', stock: 4), _variant('b', price: '70', stock: 6, size: 'M')]);
      expect(d.lowestPrice, 70);
      expect(d.totalStock, 10);
    });

    test('json round trip keeps the payload keys save_product reads', () {
      final json = ok().toJson();
      expect(json.keys, containsAll(['title', 'description', 'category', 'attributes', 'originalPrice', 'photos', 'variants']));
      final again = ProductDraftData.fromJson(json);
      expect(again.variants.single.id, 'a');
      expect(again.photos, ['u/d/a.jpg']);
    });
  });

  group('SellerProductException.fromMessage', () {
    test('reads a plain code', () {
      expect(SellerProductException.fromMessage('out_of_stock').code, 'out_of_stock');
    });

    test('reads a code with a variant id', () {
      final e = SellerProductException.fromMessage('missing_price:11111111-2222-3333-4444-555555555555');
      expect(e.code, 'missing_price');
      expect(e.variantId, '11111111-2222-3333-4444-555555555555');
    });
  });
}
