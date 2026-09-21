import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/clerk_config.dart';

/// The full name and username collected on `GetStartedScreen`, kept until a
/// later step has an email address or phone number to create the Clerk sign
/// up with in one call (spec 0004, AC-14). Nothing reaches Clerk before that,
/// so leaving the flow early still creates no account (AC-9).
final signUpDraftProvider =
    StateProvider<({String fullName, String username})?>((ref) => null);

/// Splits a single "Full name" field into the first/last name pair Clerk's
/// sign up takes: everything before the first space is the first name, the
/// rest (if any) is the last name.
({String? firstName, String? lastName}) splitFullName(String? fullName) {
  final parts = (fullName ?? '').trim().split(RegExp(r'\s+'))
    ..removeWhere((part) => part.isEmpty);
  if (parts.isEmpty) return (firstName: null, lastName: null);
  return (
    firstName: parts.first,
    lastName: parts.length > 1 ? parts.skip(1).join(' ') : null,
  );
}

/// Turns the field names Clerk reports as missing or unverified on a sign up
/// (`phone_number`, `email_address`, ...) into the words a person reads in
/// the error, with no duplicates and in the order given.
String describeOutstandingFields(Iterable<String> fieldNames) =>
    fieldNames.toSet().map((name) => name.replaceAll('_', ' ')).join(', ');

/// Backs the send/verify/resend callbacks of `EmailAddressScreen` and
/// `PhoneNumberScreen` with Clerk's `emailCode` and `phoneCode` sign up
/// (spec 0004, AC-2; task 12 of its build plan). `app_router.dart` builds one
/// per route visit and hands the screen its three methods, so the screens
/// themselves stay Clerk free and keep taking plain callbacks.
///
/// [clerk.Auth.attemptSignUp] is progressive: the first call (with the name,
/// username and identifier) creates the sign up and makes Clerk send the
/// code, the second (with the code) verifies it and completes sign up.
/// Completing it signs the user in, which [AuthSessionController] picks up on
/// its own (anonymous merge, buyer profile upsert) — nothing here does that.
///
/// Errors go through `safelyCall`, so a rejected code, a taken username, an
/// unsupported country or a dropped connection surfaces in the app wide
/// `ClerkErrorListener` snack bar (AC-12) rather than in the screen's own UI.
class SignUpVerification {
  SignUpVerification._(
    this._strategy,
    this._authState,
    this._ref,
    this._context,
  );

  /// For `EmailAddressScreen`; its value is an email address.
  static SignUpVerification? email(BuildContext context, Ref ref) =>
      _maybe(clerk.Strategy.emailCode, context, ref);

  /// For `PhoneNumberScreen`; its value is an E.164 number, country code
  /// included, which is what the screen's own country picker produces.
  static SignUpVerification? phone(BuildContext context, Ref ref) =>
      _maybe(clerk.Strategy.phoneCode, context, ref);

  /// Null when Clerk isn't configured: there is no `ClerkAuth` ancestor to
  /// read, so the screen runs as UI only, the way it did before it was wired.
  static SignUpVerification? _maybe(
    clerk.Strategy strategy,
    BuildContext context,
    Ref ref,
  ) => ClerkConfig.isConfigured
      ? SignUpVerification._(
          strategy,
          ClerkAuth.of(context, listen: false),
          ref,
          context,
        )
      : null;

  final clerk.Strategy _strategy;
  final ClerkAuthState _authState;
  final Ref _ref;
  final BuildContext _context;

  bool get _isPhone => _strategy == clerk.Strategy.phoneCode;

  /// Creates the sign up from the draft plus [value] (an email address, or
  /// an E.164 number), which makes Clerk send the verification code.
  Future<void> sendCode(String value) async {
    // Switching channels mid flow ("Use email instead" and back) leaves the
    // abandoned identifier on Clerk's pending sign up, where it stays
    // unverified and blocks completion. Start that sign up over instead.
    final pending = _authState.signUp;
    final abandoned = _isPhone ? pending?.emailAddress : pending?.phoneNumber;
    if (abandoned != null) {
      await _authState.safelyCall(_context, _authState.resetClient);
      if (!_context.mounted) return;
    }

    final draft = _ref.read(signUpDraftProvider);
    final name = splitFullName(draft?.fullName);
    await _authState.safelyCall(
      _context,
      () => _authState.attemptSignUp(
        strategy: _strategy,
        emailAddress: _isPhone ? null : value,
        phoneNumber: _isPhone ? value : null,
        username: draft?.username,
        firstName: name.firstName,
        lastName: name.lastName,
      ),
    );
  }

  /// Verifies [code] against the pending sign up. On success the user is
  /// signed in and moves on to the interests step.
  ///
  /// Clerk rejects a second attempt on an identifier it has already verified
  /// ("This verification has already been verified"), so the attempt only
  /// runs while the identifier is still unverified. Pressing Continue again
  /// after the code went through re-reads the sign up instead of resubmitting
  /// it, which is what produced that error: a code can verify without the
  /// sign up completing, if Clerk is still waiting on another field.
  Future<void> verify(String value, String code) async {
    final field = _isPhone ? clerk.Field.phoneNumber : clerk.Field.emailAddress;

    if (_authState.signUp?.unverified(field) ?? true) {
      await _authState.safelyCall(
        _context,
        () => _authState.attemptSignUp(strategy: _strategy, code: code),
      );
      if (!_context.mounted) return;
    }

    if (_authState.isSignedIn) {
      _ref.read(signUpDraftProvider.notifier).state = null;
      _context.go('/sign-up/interests');
      return;
    }

    // Verified, but Clerk still will not finish the sign up. Say what it is
    // holding out for; otherwise Continue silently does nothing and the only
    // way forward looks like pressing it again.
    final pending = _authState.signUp;
    if (pending != null && pending.unverified(field) == false) {
      final outstanding = describeOutstandingFields([
        ...pending.missingFields.map((field) => field.name),
        ...pending.unverifiedFields.map((field) => field.name),
      ]);
      _authState.handleError(
        clerk.ClerkError.clientAppError(
          message: outstanding.isEmpty
              ? 'That code was accepted, but the account could not be created.'
              : 'That code was accepted, but the account still needs: '
                    '$outstanding.',
        ),
      );
    }
  }

  /// Asks Clerk for a fresh code for the same pending sign up.
  Future<void> resendCode(String value) async {
    await _authState.safelyCall(
      _context,
      () => _authState.resendCode(_strategy),
    );
  }
}
