import '../../models/store_policies.dart';
import '../../providers/network_delay.dart';
import '../store_policies_repository.dart';

/// Keeps the store policies in memory, seeded with the values drawn in the
/// Figma Store policies frames.
class MockStorePoliciesRepository implements StorePoliciesRepository {
  StorePolicies _policies = const StorePolicies(
    deliveryArea: 'Tunisia (all governorates)',
    deliveryTime: '1–2 days',
    deliveryFee: 7,
    freeDeliveryOver: 150,
    paymentMethod: 'Cash on delivery',
    paymentMessage: 'Paid to the courier when the order arrives',
    maxCodOrder: 1000,
    returnWindowDays: 14,
    returnCondition: 'Unworn',
    returnShipping: 'Buyer pays',
    refundMethod: 'Original payment method',
  );

  @override
  Future<StorePolicies> get() async {
    await Future.delayed(mockNetworkDelay);
    return _policies;
  }

  @override
  Future<StorePolicies> save(StorePolicies policies) async {
    await Future.delayed(mockNetworkDelay);
    return _policies = policies;
  }
}
