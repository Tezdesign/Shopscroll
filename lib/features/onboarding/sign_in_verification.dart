import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/clerk_config.dart';
import 'log_in_screen.dart';

/// Backs the send, verify and resend callbacks of [LogInScreen] with Clerk's
/// `emailCode` and `phoneCode` sign in, the returning half of the passwordless
/// decision in spec 0004. `app_router.dart` builds one per route visit and
/// hands the screen its three methods, so the screen itself stays Clerk free
/// and keeps taking plain callbacks, exactly as `SignUpVerification` does for
/// the sign up screens.
///
/// [clerk.Auth.attemptSignIn] is progressive in the same way
/// [clerk.Auth.attemptSignUp] is: the first call (with the identifier)
/// creates the sign in and makes Clerk send the code, the second (with the
/// code) attempts it. A successful attempt signs the user in, which
/// `AuthSessionController` picks up on its own (anonymous merge per AC-3,
/// buyer profile upsert per AC-4), so nothing here does that.
///
/// Unlike sign up, one object serves both channels: the screen switches
/// between email and phone in place without changing route, so the strategy
/// is chosen per call from the [LogInChannel] the screen passes.
///
/// Errors go through `safelyCall`, so an identifier with no account, a
/// rejected or expired code, or a dropped connection surfaces in the app wide
/// `ClerkErrorListener` snack bar (AC-12) rather than in the screen's own UI.
/// That means someone who types an address with no account gets a message and
/// stays put; sending them to `/sign-up` with the identifier carried across
/// would be friendlier, and is an open decision rather than something this
/// wiring should invent.
class SignInVerification {
  SignInVerification._(this._authState, this._context);

  /// Null when Clerk is not configured: there is no `ClerkAuth` ancestor to
  /// read, so [LogInScreen] runs as UI only, advancing through its stages
  /// against no backend.
  static SignInVerification? maybe(BuildContext context, Ref ref) =>
      ClerkConfig.isConfigured
      ? SignInVerification._(ClerkAuth.of(context, listen: false), context)
      : null;

  final ClerkAuthState _authState;
  final BuildContext _context;

  clerk.Strategy _strategyFor(LogInChannel channel) =>
      channel == LogInChannel.phone
      ? clerk.Strategy.phoneCode
      : clerk.Strategy.emailCode;

  /// Creates the sign in for [identifier] (an email address, or an E.164
  /// number), which makes Clerk send the verification code.
  ///
  /// Returns whether a code actually went out. `safelyCall` swallows any
  /// Clerk error into the app wide snackbar rather than rethrowing it, so
  /// the caller can't tell success from failure just by awaiting this — it
  /// has to check the pending sign in afterward. Without this, the screen
  /// would move to its "enter the code" stage even when nothing was sent,
  /// and "Resend code" would then fail with Clerk's own "No initial code
  /// has been set up to resend".
  Future<bool> sendCode(LogInChannel channel, String identifier) async {
    // Clerk refuses a new sign in while a session exists ("already signed
    // in"). Debug builds always open on the welcome screen (see main.dart),
    // so a session left from an earlier run gets here; release builds only
    // reach this screen signed out. Starting a sign in means switching
    // account, so end the old session first.
    if (_authState.isSignedIn) {
      await _authState.signOut();
      if (!_context.mounted) return false;
    }
    final strategy = _strategyFor(channel);
    await _authState.safelyCall(
      _context,
      () => _authState.attemptSignIn(
        strategy: strategy,
        identifier: identifier,
      ),
    );
    final signIn = _authState.signIn;
    return signIn != null &&
        clerk.Stage.values.any((stage) => signIn.isVerifying(stage, strategy));
  }

  /// Attempts [code] against the pending sign in. On success the person is
  /// signed in and lands on the home screen.
  ///
  /// Sign in goes straight home rather than through the sign up tail
  /// (interests, notifications, setting up): a returning person has already
  /// answered those, and "Setting up your account" is the wrong thing to say
  /// to someone who already has one.
  Future<void> verify(
    LogInChannel channel,
    String identifier,
    String code,
  ) async {
    await _authState.safelyCall(
      _context,
      () => _authState.attemptSignIn(
        strategy: _strategyFor(channel),
        code: code,
      ),
    );
    if (!_context.mounted) return;

    if (_authState.isSignedIn) {
      _context.go('/');
      return;
    }

    // The code went through but Clerk still will not finish the sign in,
    // which normally means it wants another factor. Say so, otherwise Log in
    // silently does nothing and pressing it again looks like the only option.
    if (_authState.signIn != null) {
      _authState.handleError(
        clerk.ClerkError.clientAppError(
          message:
              'That code was accepted, but the sign in could not be completed.',
        ),
      );
    }
  }

  /// Asks Clerk for a fresh code for the same pending sign in.
  /// [clerk.Auth.resendCode] covers sign in as well as sign up, picking the
  /// stage that is currently verifying.
  Future<void> resendCode(LogInChannel channel, String identifier) async {
    await _authState.safelyCall(
      _context,
      () => _authState.resendCode(_strategyFor(channel)),
    );
  }
}
