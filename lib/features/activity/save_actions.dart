import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../data/models/reel.dart';
import '../../data/models/saved_product.dart';
import '../../data/models/saved_reel.dart';
import '../../data/providers/saved_providers.dart';
import '../cart/add_to_cart.dart' show showCartSnackBar;

/// The one place every bookmark (product detail, the Reels player, and the
/// cards in My collection) goes through, so a failed write and Undo behave
/// the same everywhere (spec 0008, AC-7, AC-10). The saved notifiers have
/// already put the list back by the time a failure message shows.
const saveFailureMessage = "Couldn't update your saved items. Try again.";

/// Saves the product, or unsaves it when it is already saved. [onSaved] runs
/// at once when this call saves it (product detail uses it for its toast).
Future<void> toggleProductSave(
  BuildContext context,
  Product product, {
  VoidCallback? onSaved,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ProviderScope.containerOf(
    context,
  ).read(savedProductsProvider.notifier);
  await _guard(messenger, () async {
    await ProviderScope.containerOf(context).read(savedProductsProvider.future);
    final saved = notifier.isSaved(product.id);
    final write = saved ? notifier.unsave(product.id) : notifier.save(product);
    if (!saved) onSaved?.call();
    await write;
  });
}

/// Saves the reel, or unsaves it when it is already saved.
Future<void> toggleReelSave(BuildContext context, Reel reel) async {
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context);
  final notifier = container.read(savedReelsProvider.notifier);
  await _guard(messenger, () async {
    await container.read(savedReelsProvider.future);
    await (notifier.isSaved(reel.id)
        ? notifier.unsave(reel.id)
        : notifier.save(reel));
  });
}

/// Removes a saved product at once and offers Undo, which puts it back at
/// its old place in the list (AC-7).
Future<void> removeSavedProduct(BuildContext context, SavedProduct saved) {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ProviderScope.containerOf(
    context,
  ).read(savedProductsProvider.notifier);
  final write = notifier.unsave(saved.product.id);
  _showUndo(
    messenger,
    () => _guard(
      messenger,
      () => notifier.save(saved.product, savedAt: saved.savedAt),
    ),
  );
  return _guard(messenger, () => write);
}

/// Same as [removeSavedProduct], for a saved reel.
Future<void> removeSavedReel(BuildContext context, SavedReel saved) {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ProviderScope.containerOf(
    context,
  ).read(savedReelsProvider.notifier);
  final write = notifier.unsave(saved.reel.id);
  _showUndo(
    messenger,
    () => _guard(
      messenger,
      () => notifier.save(saved.reel, savedAt: saved.savedAt),
    ),
  );
  return _guard(messenger, () => write);
}

void _showUndo(ScaffoldMessengerState messenger, VoidCallback onUndo) {
  showCartSnackBar(
    messenger,
    'Removed from saved',
    action: SnackBarAction(
      label: 'Undo',
      textColor: AppColors.primary400,
      onPressed: onUndo,
    ),
  );
}

Future<void> _guard(
  ScaffoldMessengerState messenger,
  Future<void> Function() write,
) async {
  try {
    await write();
  } catch (_) {
    showCartSnackBar(messenger, saveFailureMessage);
  }
}
