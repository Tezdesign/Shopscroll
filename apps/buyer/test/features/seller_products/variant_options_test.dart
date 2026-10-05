import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/features/seller_products/variant_options.dart';
import 'package:shopscroll_shared/models/product_draft.dart';

void main() {
  const black = ColorOption('Black', 0xFF000000);
  const red = ColorOption('Red', 0xFFD62828);

  // Spec 0015, AC-4.
  test('2 colors by 3 sizes makes 6 rows, colors first', () {
    final rows = buildVariants(existing: const [], colors: [black, red], sizes: ['S', 'M', 'L'], defaultPrice: '89.000');

    expect(rows.length, 6);
    expect(rows.map(variantLabel), ['Black / S', 'Black / M', 'Black / L', 'Red / S', 'Red / M', 'Red / L']);
    expect(rows.every((r) => r.price == '89.000' && r.stock == 0), isTrue);
    expect(rows.map((r) => r.id).toSet().length, 6);
  });

  test('adding a size keeps the rows that exist, with their typed price and stock', () {
    final first = buildVariants(existing: const [], colors: [black], sizes: ['S']);
    final typed = [first.single.copyWith(price: '70', stock: 5)];

    final again = buildVariants(existing: typed, colors: [black], sizes: ['S', 'M'], defaultPrice: '99');

    expect(again.first.id, typed.single.id);
    expect(again.first.price, '70');
    expect(again.first.stock, 5);
    expect(again.last.price, '99');
  });

  test('no colors and no sizes is one plain row that inherits the first old row', () {
    final rows = buildVariants(existing: const [], colors: [black], sizes: ['S']);
    final typed = [rows.single.copyWith(price: '55', stock: 3)];

    final plain = buildVariants(existing: typed, colors: const [], sizes: const []);

    expect(plain.single.colorValue, isNull);
    expect(plain.single.size, isNull);
    expect(plain.single.price, '55');
    expect(plain.single.stock, 3);
    expect(variantLabel(plain.single), 'Standard');
  });

  test('colorsOf and sizesOf list each value once, in order', () {
    final rows = buildVariants(existing: const [], colors: [red, black], sizes: ['M', 'S']);

    expect(colorsOf(rows).map((c) => c.name), ['Red', 'Black']);
    expect(sizesOf(rows), ['M', 'S']);
  });

  test('rows built here pass the duplicate check of the draft', () {
    final rows = buildVariants(existing: const [], colors: [black, red], sizes: ['S', 'M'], defaultPrice: '10');
    final data = ProductDraftData(title: 'Dress', category: 'Fashion', photos: const ['p'], variants: rows);

    expect(data.issues(), isEmpty);
  });
}
