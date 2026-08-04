import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cart_repository.dart';
import 'mock/mock_cart_repository.dart';
import 'mock/mock_order_repository.dart';
import 'mock/mock_product_repository.dart';
import 'mock/mock_reel_repository.dart';
import 'mock/mock_user_profile_repository.dart';
import 'order_repository.dart';
import 'product_repository.dart';
import 'reel_repository.dart';
import 'user_profile_repository.dart';

/// Every provider here defaults to its mock implementation, so the app,
/// its widget tests, and `flutter run` with no --dart-define all keep
/// working exactly as before with zero setup. `main.dart` overrides these
/// with the Supabase-backed implementations once it has a real session.
final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => MockProductRepository(),
);

final reelRepositoryProvider = Provider<ReelRepository>(
  (ref) => MockReelRepository(),
);

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => MockUserProfileRepository(),
);

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => MockCartRepository(),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => MockOrderRepository(),
);
