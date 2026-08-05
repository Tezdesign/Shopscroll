import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the first launch welcome screen (spec 0004, Figma node
/// 561:5267) has already been shown on this device. Set the moment Sign
/// up, Log in, or Skip is chosen, never unset by the app, so the screen
/// only ever appears once per install.
class OnboardingPrefs {
  OnboardingPrefs(this._prefs);

  static const _seenWelcomeKey = 'seen_welcome_screen';

  final SharedPreferences _prefs;

  bool get hasSeenWelcome => _prefs.getBool(_seenWelcomeKey) ?? false;

  Future<void> markWelcomeSeen() => _prefs.setBool(_seenWelcomeKey, true);
}

/// Overridden in `main.dart` with the real, already loaded
/// [SharedPreferences] instance.
final onboardingPrefsProvider = Provider<OnboardingPrefs>((ref) {
  throw UnimplementedError(
    'onboardingPrefsProvider must be overridden in main.dart before use',
  );
});
