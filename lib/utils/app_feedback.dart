import 'package:flutter/services.dart';

class AppFeedback {
  /// Suara sentuhan lembut (soft click) tanpa getaran
  static void tap() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Suara sentuhan konfirmasi tanpa getaran
  static void success() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Suara peringatan tanpa getaran
  static void alert() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}
