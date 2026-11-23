import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

class AuthService {
  static final AuthService instance = AuthService._init();
  final LocalAuthentication _localAuth = LocalAuthentication();

  AuthService._init();

  static const String keyLastActive = 'auth_last_active_time';
  static const String keyIsUnlocked = 'auth_is_session_unlocked';

  /// Hash PIN 4-6 digit dengan SHA-256
  String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifikasi kecocokan input PIN dengan hash di database
  Future<bool> verifyPin(String pin) async {
    final settings = await DatabaseHelper.instance.getPengaturan();
    if (settings.pinKeamanan == null || settings.pinKeamanan!.isEmpty) {
      return true; // Jika belum pasang PIN, loloskan
    }
    final hashed = hashPin(pin);
    return hashed == settings.pinKeamanan;
  }

  /// Simpan atau ubah PIN baru
  Future<void> setPin(String? newPin) async {
    final settings = await DatabaseHelper.instance.getPengaturan();
    final updated = settings.copyWith(
      pinKeamanan: (newPin != null && newPin.isNotEmpty) ? hashPin(newPin) : null,
    );
    await DatabaseHelper.instance.updatePengaturan(updated);
  }

  /// Periksa ketersediaan biometrik di perangkat
  Future<bool> isBiometricsAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  /// Autentikasi menggunakan biometrik
  Future<bool> authenticateWithBiometrics() async {
    try {
      final isAvailable = await isBiometricsAvailable();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Buka Kunci Aplikasi Kas Santri',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Cek apakah sesi saat ini terkunci berdasarkan autoLockMinutes
  Future<bool> shouldLockApp() async {
    final settings = await DatabaseHelper.instance.getPengaturan();
    if (settings.pinKeamanan == null || settings.pinKeamanan!.isEmpty) {
      return false; // Tanpa PIN tidak perlu dikunci
    }

    final prefs = await SharedPreferences.getInstance();
    final isUnlocked = prefs.getBool(keyIsUnlocked) ?? false;
    if (!isUnlocked) return true;

    final lastActiveStr = prefs.getString(keyLastActive);
    if (lastActiveStr == null) return true;

    final lastActive = DateTime.tryParse(lastActiveStr);
    if (lastActive == null) return true;

    final lockDuration = Duration(minutes: settings.autoLockMinutes);
    final isExpired = DateTime.now().difference(lastActive) > lockDuration;
    return isExpired;
  }

  /// Perbarui waktu aktif terakhir
  Future<void> updateLastActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLastActive, DateTime.now().toIso8601String());
    await prefs.setBool(keyIsUnlocked, true);
  }

  /// Kunci aplikasi secara manual
  Future<void> lockSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsUnlocked, false);
  }
}
