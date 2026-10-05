import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopscroll_shared/models/seller_application.dart';

import '../../core/area/seller_claim.dart';
import '../repositories/repository_providers.dart';

/// The signed in person's own seller applications, newest first, as if
/// fetched from `GET /seller-applications` (spec 0013, AC-8). Auto disposed,
/// so opening the screen again reads the list again, and no automatic retry,
/// so a failed load reaches the screen as an error with its own "Try again".
///
/// Loading it first asks the claim function to turn an approved visitor
/// application into a seller (spec 0014, AC-13), so opening or refreshing the
/// Seller application screen retries a claim that failed earlier. The claim
/// never throws and does nothing for a seller or a visitor.
final sellerApplicationsProvider =
    FutureProvider.autoDispose<List<SellerApplication>>((ref) async {
      // Watched before the await: a provider may only watch while it builds.
      final repository = ref.watch(sellerApplicationRepositoryProvider);
      await ref.read(sellerClaimProvider).claim();
      return repository.getMyApplications();
    }, retry: (retryCount, error) => null);
