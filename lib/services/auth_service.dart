import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

class AuthService {
  static final AuthService instance = AuthService._init();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  AuthService._init();

  static const String keyLastActive = 'auth_last_active_time';
  static const String keyIsUnlocked = 'auth_is_session_unlocked';
  static const String keySecurePinHash = 'kas_santri_secure_pin_hash';

  /// Validasi format PIN harus 4–6 digit angka
  static bool isValidPinFormat(String pin) {
    return RegExp(r'^\d{4,6}$').hasMatch(pin);
  }

  static String _generateSalt16Base64() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Hash PIN 4-6 digit dengan random 16-byte salt per perangkat (`v33:<salt>:<sha256>`)
  String hashPin(String pin, {String? salt}) {
    final s = salt ?? _generateSalt16Base64();
    final bytes = utf8.encode('ks_v33_pin:$s:$pin');
    final digest = sha256.convert(bytes);
    return 'v33:$s:$digest';
  }

  /// Hash kompatibilitas v2.5–v3.2 (fixed salt)
  String hashLegacyV25Pin(String pin) {
    final bytes = utf8.encode('ks_v25_pin:$pin');
    return sha256.convert(bytes).toString();
  }

  /// Hash kompatibilitas versi lama (unsalted SHA-256)
  String hashLegacyPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  bool verifyPinAgainstStored(String pin, String stored) {
    if (stored.startsWith('v33:')) {
      final parts = stored.split(':');
      if (parts.length != 3 || parts[1].isEmpty) return false;
      return hashPin(pin, salt: parts[1]) == stored;
    }
    return stored == hashLegacyV25Pin(pin) ||
        stored == hashLegacyPin(pin) ||
        stored == pin;
  }

  Future<String?> _readSecurePinHash() async {
    try {
      final val = await _secureStorage.read(key: keySecurePinHash);
      if (val != null && val.trim().isNotEmpty) return val.trim();
    } catch (_) {}
    return null;
  }

  Future<void> _writeSecurePinHash(String? hash) async {
    try {
      if (hash == null || hash.isEmpty) {
        await _secureStorage.delete(key: keySecurePinHash);
      } else {
        await _secureStorage.write(key: keySecurePinHash, value: hash);
      }
    } catch (_) {}
  }

  /// Sinkronkan hash PIN hasil restore ke flutter_secure_storage
  Future<void> syncRestoredPinToSecureStorage(String? restoredPinHash) async {
    await _writeSecurePinHash(restoredPinHash);
  }

  /// Cek apakah kunci PIN aktif di secure storage atau database
  Future<bool> hasPin() async {
    final secureHash = await _readSecurePinHash();
    if (secureHash != null && secureHash.isNotEmpty) return true;
    final settings = await DatabaseHelper.instance.getPengaturan();
    return settings.pinKeamanan != null && settings.pinKeamanan!.isNotEmpty;
  }

  /// Verifikasi kecocokan input PIN dengan hash di flutter_secure_storage / DB
  Future<bool> verifyPin(String pin) async {
    final secureHash = await _readSecurePinHash();
    final settings = await DatabaseHelper.instance.getPengaturan();
    final stored = secureHash ?? settings.pinKeamanan;

    if (stored == null || stored.isEmpty) {
      return true;
    }

    final matched = verifyPinAgainstStored(pin, stored);

    // Auto-upgrade hash PIN lama / belum ada di secure storage ke random-salted v3.3
    if (matched && (secureHash == null || !stored.startsWith('v33:'))) {
      final upgradedHash = hashPin(pin);
      await _writeSecurePinHash(upgradedHash);
      await DatabaseHelper.instance.updatePengaturan(
        settings.copyWith(pinKeamanan: upgradedHash),
      );
    }
    return matched;
  }

  /// Simpan atau ubah PIN baru (null untuk menonaktifkan kunci PIN)
  Future<void> setPin(String? newPin) async {
    final settings = await DatabaseHelper.instance.getPengaturan();
    if (newPin != null && newPin.isNotEmpty) {
      if (!isValidPinFormat(newPin)) {
        throw const FormatException('PIN harus berupa 4–6 digit angka.');
      }
      final hashed = hashPin(newPin);
      await _writeSecurePinHash(hashed);
      await DatabaseHelper.instance.updatePengaturan(
        settings.copyWith(pinKeamanan: hashed),
      );
    } else {
      await _writeSecurePinHash(null);
      await DatabaseHelper.instance.updatePengaturan(
        settings.copyWith(clearPin: true, isBiometricEnabled: false),
      );
    }
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
    final pinActive = await hasPin();
    if (!pinActive) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final isUnlocked = prefs.getBool(keyIsUnlocked) ?? false;
    if (!isUnlocked) return true;

    final settings = await DatabaseHelper.instance.getPengaturan();
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
