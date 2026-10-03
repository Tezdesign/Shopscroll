import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// On sign in, makes the signed in person a seller (spec 0012, AC-7): creates
/// their `user_profiles` row if it is missing, then calls `become_seller()`.
///
/// The seller app has no anonymous Supabase session at all, only the Clerk
/// backed client, so there is nothing to merge or switch.
///
/// Also runs once at launch when Clerk restored a session from disk. Both
/// steps are safe to repeat (the insert ignores an existing row, and a second
/// `become_seller()` changes nothing), and it retries a first attempt that
/// failed, for example while offline.
class SellerSessionController {
  SellerSessionController({required this.clerkAuth, required this.client}) {
    _wasSignedIn = clerkAuth.isSignedIn;
    clerkAuth.addListener(_onClerkAuthChanged);
    if (_wasSignedIn) _becomeSeller();
  }

  final ClerkAuthState clerkAuth;
  final SupabaseClient client;

  late bool _wasSignedIn;
  bool _isRunning = false;

  void _onClerkAuthChanged() {
    final isSignedIn = clerkAuth.isSignedIn;
    if (isSignedIn == _wasSignedIn) return;
    _wasSignedIn = isSignedIn;
    if (isSignedIn) _becomeSeller();
  }

  Future<void> _becomeSeller() async {
    if (_isRunning) return;
    _isRunning = true;
    try {
      final user = clerkAuth.user;
      if (user == null) return;

      final name = [
        user.firstName,
        user.lastName,
      ].whereType<String>().where((part) => part.isNotEmpty).join(' ');

      // No `role`: the column default is 'buyer' and clients cannot write it.
      // become_seller() below is the only way it changes. email and phone are
      // sent here and cleared by become_seller(), same as for a buyer who
      // switches, so they never become public.
      await client.from('user_profiles').upsert({
        'id': user.id,
        'name': name.isEmpty ? (user.username ?? 'Seller') : name,
        'username': user.username ?? user.id,
        'email': user.email,
        'phone': user.phoneNumber,
      }, ignoreDuplicates: true);

      await client.rpc('become_seller');
    } catch (error) {
      // No screen reads the result yet (this wires sign in only). A failure
      // leaves the person a buyer, and the next launch or sign in retries.
      debugPrint('[seller] could not become a seller: $error');
    } finally {
      _isRunning = false;
    }
  }

  void dispose() {
    clerkAuth.removeListener(_onClerkAuthChanged);
  }
}
