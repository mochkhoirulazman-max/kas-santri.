import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan status Onboarding awal instal & Guided Spotlight Tour halaman utama.
class TutorialService {
  static final TutorialService instance = TutorialService._init();
  TutorialService._init();

  static const String keyHasSeenOnboarding = 'has_seen_onboarding';
  static const String keyHasSeenWalkthrough = 'has_seen_walkthrough';

  Future<bool> hasSeenOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyHasSeenOnboarding) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markOnboardingSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyHasSeenOnboarding, true);
    } catch (_) {}
  }

  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyHasSeenOnboarding, false);
    } catch (_) {}
  }

  Future<bool> hasSeenWalkthrough() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyHasSeenWalkthrough) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markWalkthroughSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyHasSeenWalkthrough, true);
    } catch (_) {}
  }

  Future<void> resetWalkthrough() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyHasSeenWalkthrough, false);
    } catch (_) {}
  }
}
