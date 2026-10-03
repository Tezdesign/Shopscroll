import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/mock/mock_cart_items.dart';
import 'package:marketplace_app/data/mock/mock_products.dart';
import 'package:marketplace_app/data/models/cart_item.dart';
import 'package:marketplace_app/features/cart/cart_logic.dart';

void main() {
  final blazer = mockProducts[0];
  final line = mockCartItems[0]; // blazer, size M, one colour

  test(
    'cartTotal sums price times quantity and the label is whole dollars',
    () {
      final items = [
        line.copyWith(quantity: 2),
        line.copyWith(id: 'x', quantity: 1),
      ];
      expect(cartTotal(items), blazer.price * 3);
      expect(
        cartTotalLabel(items),
        '\$${(blazer.price * 3).toStringAsFixed(0)}',
      );
      expect(cartTotal(const []), 0);
    },
  );

  test('sortedByAddedAt puts the oldest first without touching the input', () {
    final older = line.copyWith(id: 'a', addedAt: DateTime(2026, 1, 1));
    final newer = line.copyWith(id: 'b', addedAt: DateTime(2026, 2, 1));
    final input = [newer, older];
    expect(sortedByAddedAt(input).map((i) => i.id), ['a', 'b']);
    expect(input.first.id, 'b');
  });

  test('findLine matches product, size and colour, empty equals empty', () {
    final items = [
      line,
      CartItem(id: 'plain', product: blazer, addedAt: DateTime(2026, 1, 1)),
    ];
    expect(
      findLine(items, blazer.id, line.selectedSize, line.selectedColor)?.id,
      line.id,
    );
    expect(findLine(items, blazer.id, null, null)?.id, 'plain');
    expect(findLine(items, blazer.id, 'XL', line.selectedColor), isNull);
    expect(findLine(items, 'other', null, null), isNull);
  });

  test('hasProduct is true for any variant of the product', () {
    expect(hasProduct([line], blazer.id), isTrue);
    expect(hasProduct([line], 'other'), isFalse);
  });

  test('clampQuantity keeps 1 to 99', () {
    expect(clampQuantity(0), 1);
    expect(clampQuantity(50), 50);
    expect(clampQuantity(500), maxCartQuantity);
  });

  test('firstSize and firstColor pick the first, or null when none', () {
    expect(firstSize(blazer), blazer.sizes.first);
    expect(firstColor(blazer), blazer.colorOptions.first);
    final bare = mockProducts.firstWhere(
      (p) => p.sizes.isEmpty && p.colorOptions.isEmpty,
      orElse: () => blazer,
    );
    if (bare != blazer) {
      expect(firstSize(bare), isNull);
      expect(firstColor(bare), isNull);
    }
  });
}
