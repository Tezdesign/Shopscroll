import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/repositories/order_repository.dart';
import 'package:marketplace_app/data/repositories/supabase/supabase_order_repository.dart';
import 'package:marketplace_app/features/checkout/checkout_logic.dart';

void main() {
  // Spec 0015, AC-10 and AC-19: each reason of place_order has one meaning.
  test('place_order reasons map to the failures the screens handle', () {
    expect(placeOrderFailureFor('cart_empty'), PlaceOrderFailure.cartEmpty);
    expect(placeOrderFailureFor('out_of_stock:11111111-2222-3333-4444-555555555555'), PlaceOrderFailure.outOfStock);
    expect(placeOrderFailureFor('mixed_currency'), PlaceOrderFailure.mixedCurrency);
    expect(placeOrderFailureFor('product_unavailable'), PlaceOrderFailure.itemsChanged);
    expect(placeOrderFailureFor('price_changed'), PlaceOrderFailure.itemsChanged);
    expect(placeOrderFailureFor('invalid_field'), PlaceOrderFailure.invalid);
    expect(placeOrderFailureFor('no_session'), PlaceOrderFailure.invalid);
    expect(placeOrderFailureFor('something else'), PlaceOrderFailure.failed);
  });

  test('every failure has a message a shopper can read', () {
    for (final reason in PlaceOrderFailure.values) {
      expect(placeOrderFailureMessage(reason), isNotEmpty);
    }
    expect(placeOrderFailureMessage(PlaceOrderFailure.outOfStock), contains('sold out'));
  });
}
