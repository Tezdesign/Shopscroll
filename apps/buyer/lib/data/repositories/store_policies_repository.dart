import '../models/store_policies.dart';

/// The seller's store policies. Implemented by
/// `mock/mock_store_policies_repository.dart` (in memory); a Supabase
/// implementation follows once the backend has a policies table.
abstract class StorePoliciesRepository {
  /// As if fetched from `GET /store/policies`.
  Future<StorePolicies> get();

  /// As if sent to `PUT /store/policies`. Returns what was stored.
  Future<StorePolicies> save(StorePolicies policies);
}
