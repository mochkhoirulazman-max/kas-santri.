import 'package:flutter/services.dart';

class AppFeedback {
  /// Efek getar lembut dan suara klik taktil saat tombol/kartu disentuh
  static void tap() {
    try {
      HapticFeedback.selectionClick();
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Efek getar dan konfirmasi suara sukses
  static void success() {
    try {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Efek getar peringatan untuk overlimit atau pembatalan
  static void alert() {
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }
}
