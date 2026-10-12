import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/repositories/mock/mock_store_policies_repository.dart';

void main() {
  test('save persists, and copyWith can clear an optional amount', () async {
    final repo = MockStorePoliciesRepository();
    final before = await repo.get();
    expect(before.freeDeliveryOver, 150);

    await repo.save(
      before.copyWith(deliveryFee: 9, freeDeliveryOver: () => null),
    );

    final after = await repo.get();
    expect(after.deliveryFee, 9);
    expect(after.freeDeliveryOver, isNull);
    expect(after.paymentMethod, before.paymentMethod);
  });
}
