import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/store_policies.dart';
import '../repositories/repository_providers.dart';

/// The store's policies as if fetched from `GET /store/policies`. No
/// automatic retry: a failed load shows its own "Try again".
final storePoliciesProvider = FutureProvider.autoDispose<StorePolicies>(
  (ref) => ref.watch(storePoliciesRepositoryProvider).get(),
  retry: (retryCount, error) => null,
);

/// Saves the policies as if sent to `PUT /store/policies` and refreshes
/// [storePoliciesProvider]. Throws when the save fails.
final saveStorePoliciesProvider =
    Provider<Future<void> Function(StorePolicies)>((ref) {
      return (policies) async {
        await ref.read(storePoliciesRepositoryProvider).save(policies);
        ref.invalidate(storePoliciesProvider);
      };
    });
