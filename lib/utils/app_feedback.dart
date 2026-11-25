import 'package:flutter/services.dart';

class AppFeedback {
  static bool hapticEnabled = true;

  /// Suara sentuhan lembut + opsional getar haptik ringan
  static void tap() {
    try {
      SystemSound.play(SystemSoundType.click);
      if (hapticEnabled) {
        HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  /// Suara & haptik konfirmasi berhasil
  static void success() {
    try {
      SystemSound.play(SystemSoundType.click);
      if (hapticEnabled) {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// Suara & haptik peringatan
  static void alert() {
    try {
      SystemSound.play(SystemSoundType.click);
      if (hapticEnabled) {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }
}
