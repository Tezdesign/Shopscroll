import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shopscroll_shared/models/seller_application.dart';
import 'package:shopscroll_shared/models/user_profile.dart';

import '../../data/providers/user_profile_providers.dart';

/// The two areas of the one app (spec 0014): the buyer area every person
/// has, and the store area only an approved seller can enter.
enum AppArea { buyer, store }

/// The id of the real (Clerk) account signed in, or null for a visitor.
/// Set by `AuthSessionController` on sign in and sign out, so providers can
/// read it without a widget tree.
final signedInUserIdProvider = StateProvider<String?>((ref) => null);

/// Whether the signed in profile has `role = 'seller'`. False while the
/// profile loads, when it fails, and for a visitor. Routing to the store area
/// is only a convenience: the server rules still check the role on every
/// write (spec 0014, key invariants).
final isSellerProvider = Provider<bool>((ref) {
  final id = ref.watch(signedInUserIdProvider);
  if (id == null) return false;
  return ref.watch(userProfileByIdProvider(id)).value?.role == UserRole.seller;
});

/// Completes when the work a sign in starts has finished: the anonymous merge
/// that attaches a visitor's application, the switch to the account's client,
/// the profile row, and the claim of an approved application (AC-2, AC-13).
/// Routing after Log in awaits this, so an approved applicant who signs in as
/// Store owner reaches the store area in one pass. Already complete when no
/// sign in is running.
final signInSettledProvider = StateProvider<Future<void>>(
  (ref) => Future<void>.value(),
);

/// What the buyer area tells someone who chose Store owner but is not a
/// seller (AC-1). `none` is no application at all.
enum AreaNoticeKind { none, reviewing, rejected, approved }

class AreaNotice {
  const AreaNotice(this.kind, {this.reason});

  final AreaNoticeKind kind;

  /// Why a rejected application was rejected.
  final String? reason;

  String get message => switch (kind) {
    AreaNoticeKind.none =>
      'You are not a store owner yet. Apply from Settings, Seller application.',
    AreaNoticeKind.reviewing => 'Your application is being reviewed.',
    AreaNoticeKind.rejected =>
      (reason == null || reason!.trim().isEmpty)
          ? 'Your application was rejected.'
          : 'Your application was rejected: ${reason!.trim()}.',
    // Not in the spec's list: approved but the claim has not made the person
    // a seller (it failed, for example while offline). Opening the Seller
    // application screen retries the claim (AC-13).
    AreaNoticeKind.approved =>
      'Your application was approved. Open Seller application to finish '
          'opening your store.',
  };
}

/// The notice to show for [applications] (newest first, as the repository
/// returns them): one under review wins, then the newest decision.
AreaNotice areaNoticeFor(List<SellerApplication> applications) {
  if (applications.any((a) => a.status == SellerApplicationStatus.reviewing)) {
    return const AreaNotice(AreaNoticeKind.reviewing);
  }
  if (applications.isEmpty) return const AreaNotice(AreaNoticeKind.none);
  final latest = applications.first;
  return switch (latest.status) {
    SellerApplicationStatus.rejected => AreaNotice(
      AreaNoticeKind.rejected,
      reason: latest.rejectionReason,
    ),
    _ => const AreaNotice(AreaNoticeKind.approved),
  };
}

/// Set after Log in when a non seller chose Store owner. The shell shows it
/// once (as a snack bar with an action to the Seller application screen) and
/// clears it.
final areaNoticeProvider = StateProvider<AreaNotice?>((ref) => null);
