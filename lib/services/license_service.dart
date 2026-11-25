import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseVerificationResult {
  final bool isValid;
  final bool isExpired;
  final String? planKey; // MONTHLY, YEARLY, LIFETIME
  final String? tipe; // M1, Y1, LT
  final String? deviceId;
  final DateTime? expiryDate;
  final String message;

  const LicenseVerificationResult({
    required this.isValid,
    this.isExpired = false,
    this.planKey,
    this.tipe,
    this.deviceId,
    this.expiryDate,
    required this.message,
  });
}

/// Layanan Verifikasi Lisensi PRO Offline berbasis Kriptografi Asimetris Ed25519 (Anti-Keygen).
///
/// KEAMANAN v3.3:
/// - APK HANYA menyimpan Public Key Ed25519 (32-byte raw public key Base64).
/// - Private Key TIDAK PERNAH ada di folder lib/ atau assets/.
/// - Format kode lisensi: KSPRO-<PAYLOAD_BASE32>-<SIGNATURE_BASE32>
///   dengan payload UTF-8: <DEVICE_ID>|<TIER>|<EXPIRY_EPOCH_SEC>
class LicenseService {
  static final LicenseService instance = LicenseService._init();
  LicenseService._init();

  /// Public Key Ed25519 (32-byte raw Base64) untuk memverifikasi tanda tangan lisensi.
  /// GANTI nilai placeholder valid RFC 8032 ini dengan PUBLIC KEY hasil:
  /// `dart run tool/generate_keypair.dart --generate-keys`
  static const String defaultPublicKeyBase64 =
      '11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo=';

  static const String _keyDeviceId = 'ks_device_id';
  static const String _keyLicenseCode = 'ks_pro_license_code';
  static const String _b32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static final Ed25519 _ed25519 = Ed25519();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> _readSecureOrPref(String key) async {
    try {
      final secVal = await _secureStorage.read(key: key);
      if (secVal != null && secVal.isNotEmpty) return secVal;
    } catch (_) {
      // Fallback di unit test / environment tanpa channel native
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> _writeSecureAndClearLegacyPref(String key, String value) async {
    bool savedToSecure = false;
    try {
      await _secureStorage.write(key: key, value: value);
      savedToSecure = true;
    } catch (_) {
      savedToSecure = false;
    }
    final prefs = await SharedPreferences.getInstance();
    if (savedToSecure) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  Future<void> _deleteSecureAndPref(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static String normalizeLicenseCode(String raw) => raw
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'\s+'), '');

  static String planKeyFromTipe(String tipe) {
    switch (tipe.toUpperCase()) {
      case 'M1':
      case 'MONTHLY':
        return 'MONTHLY';
      case 'LT':
      case 'LIFETIME':
        return 'LIFETIME';
      case 'Y1':
      case 'YEARLY':
      default:
        return 'YEARLY';
    }
  }

  static String tipeFromTier(String tier) {
    switch (tier.toUpperCase()) {
      case 'MONTHLY':
      case 'M1':
        return 'M1';
      case 'LIFETIME':
      case 'LT':
        return 'LT';
      case 'YEARLY':
      case 'Y1':
      default:
        return 'Y1';
    }
  }

  static Uint8List decodeBase32(String input) {
    final clean = input.trim().toUpperCase().replaceAll('=', '');
    if (clean.isEmpty) {
      throw const FormatException('Base32 kosong.');
    }
    final bytes = <int>[];
    var buffer = 0;
    var bitsLeft = 0;
    for (var i = 0; i < clean.length; i++) {
      final idx = _b32Alphabet.indexOf(clean[i]);
      if (idx < 0) {
        throw FormatException('Karakter Base32 tidak valid: ${clean[i]}');
      }
      buffer = (buffer << 5) | idx;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bytes.add((buffer >> (bitsLeft - 8)) & 0xff);
        bitsLeft -= 8;
      }
    }
    return Uint8List.fromList(bytes);
  }

  /// Verifikasi murni berbasis Ed25519 Public Key.
  /// Format yang sah: `KSPRO-<PAYLOAD_B32>-<SIGNATURE_B32>`
  /// dengan payload UTF-8: `<DEVICE_ID>|<TIER>|<EXPIRY_EPOCH_SEC>`
  static Future<LicenseVerificationResult> verifyCodeAsync({
    required String code,
    required String deviceId,
    DateTime? now,
    String? publicKeyBase64Override,
  }) async {
    final normalizedCode = normalizeLicenseCode(code);
    final parts = normalizedCode.split('-');
    if (parts.length != 3 ||
        parts[0] != 'KSPRO' ||
        parts[1].isEmpty ||
        parts[2].isEmpty) {
      return const LicenseVerificationResult(
        isValid: false,
        message: 'Format kode lisensi tidak valid. Gunakan kode resmi KSPRO-....',
      );
    }

    final Uint8List payloadBytes;
    final Uint8List signatureBytes;
    try {
      payloadBytes = decodeBase32(parts[1]);
      signatureBytes = decodeBase32(parts[2]);
    } catch (_) {
      return const LicenseVerificationResult(
        isValid: false,
        message: 'Kode lisensi rusak atau mengandung karakter tidak sah.',
      );
    }

    if (signatureBytes.length != 64) {
      return const LicenseVerificationResult(
        isValid: false,
        message: 'Tanda tangan digital lisensi tidak valid.',
      );
    }

    final pubB64 = (publicKeyBase64Override ?? defaultPublicKeyBase64).trim();
    late final SimplePublicKey publicKey;
    try {
      final pubBytes = base64Decode(pubB64);
      if (pubBytes.length != 32) {
        return const LicenseVerificationResult(
          isValid: false,
          message: 'Konfigurasi public key verifikasi tidak valid.',
        );
      }
      publicKey = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);
    } catch (_) {
      return const LicenseVerificationResult(
        isValid: false,
        message: 'Konfigurasi public key verifikasi tidak valid.',
      );
    }

    final verified = await _ed25519.verify(
      payloadBytes,
      signature: Signature(signatureBytes, publicKey: publicKey),
    );
    if (!verified) {
      return const LicenseVerificationResult(
        isValid: false,
        message: 'Tanda tangan digital tidak cocok. Kode bukan lisensi resmi.',
      );
    }

    final String payloadStr;
    try {
      payloadStr = utf8.decode(payloadBytes);
    } catch (_) {
      return const LicenseVerificationResult(
        isValid: false,
        message: 'Isi payload lisensi tidak dapat dibaca.',
      );
    }

    final fields = payloadStr.split('|');
    if (fields.length != 3) {
      return const LicenseVerificationResult(
        isValid: false,
        message: 'Struktur payload lisensi tidak valid.',
      );
    }

    final tokenDevice = fields[0].trim().toUpperCase();
    final tier = fields[1].trim().toUpperCase();
    final expiryEpochSec = int.tryParse(fields[2].trim());
    if (expiryEpochSec == null ||
        (tier != 'MONTHLY' && tier != 'YEARLY' && tier != 'LIFETIME')) {
      return const LicenseVerificationResult(
        isValid: false,
        message: 'Data paket atau masa berlaku lisensi tidak valid.',
      );
    }

    final currentDevice = deviceId.trim().toUpperCase();
    if (tokenDevice != currentDevice) {
      return LicenseVerificationResult(
        isValid: false,
        deviceId: tokenDevice,
        message:
            'Kode lisensi ini terdaftar untuk perangkat lain ($tokenDevice).',
      );
    }

    final tipe = tipeFromTier(tier);
    final planKey = planKeyFromTipe(tier);
    if (tier == 'LIFETIME' || expiryEpochSec == 0) {
      return LicenseVerificationResult(
        isValid: true,
        planKey: planKey,
        tipe: tipe,
        deviceId: tokenDevice,
        message: 'Lisensi Kas-Santri PRO Lifetime (Selamanya) aktif.',
      );
    }

    final expiry = DateTime.fromMillisecondsSinceEpoch(
      expiryEpochSec * 1000,
      isUtc: true,
    ).toLocal();
    final refNow = now ?? DateTime.now();
    if (refNow.isAfter(expiry)) {
      return LicenseVerificationResult(
        isValid: false,
        isExpired: true,
        planKey: planKey,
        tipe: tipe,
        deviceId: tokenDevice,
        expiryDate: expiry,
        message: 'Masa aktif lisensi PRO sudah berakhir. Silakan perpanjang.',
      );
    }

    return LicenseVerificationResult(
      isValid: true,
      planKey: planKey,
      tipe: tipe,
      deviceId: tokenDevice,
      expiryDate: expiry,
      message: 'Lisensi Kas-Santri PRO ($planKey) aktif terverifikasi Ed25519.',
    );
  }

  /// Menghasilkan ID perangkat stabil seperti KS-9F4A2B1C (disimpan di SecureStorage)
  Future<String> getOrCreateDeviceId() async {
    final existing = await _readSecureOrPref(_keyDeviceId);
    if (existing != null && existing.trim().isNotEmpty) {
      final clean = existing.trim().toUpperCase();
      // Pastikan migrasi dari pref lama ke secure storage berjalan mulus
      await _writeSecureAndClearLegacyPref(_keyDeviceId, clean);
      return clean;
    }

    final rng = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buf = StringBuffer('KS-');
    for (int i = 0; i < 8; i++) {
      buf.write(chars[rng.nextInt(chars.length)]);
    }
    final generated = buf.toString();
    await _writeSecureAndClearLegacyPref(_keyDeviceId, generated);
    return generated;
  }

  Future<LicenseVerificationResult> activateLicense(
    String rawCode, {
    DateTime? now,
  }) async {
    final deviceId = await getOrCreateDeviceId();
    final res = await verifyCodeAsync(
      code: rawCode,
      deviceId: deviceId,
      now: now,
    );
    if (res.isValid) {
      await _writeSecureAndClearLegacyPref(
        _keyLicenseCode,
        normalizeLicenseCode(rawCode),
      );
    }
    return res;
  }

  Future<LicenseVerificationResult?> checkSavedLicense({DateTime? now}) async {
    final savedCode = await _readSecureOrPref(_keyLicenseCode);
    if (savedCode == null || savedCode.trim().isEmpty) return null;

    // Migrasi aman jika sebelumnya tersimpan di SharedPreferences
    await _writeSecureAndClearLegacyPref(
      _keyLicenseCode,
      normalizeLicenseCode(savedCode),
    );

    final deviceId = await getOrCreateDeviceId();
    return verifyCodeAsync(
      code: savedCode,
      deviceId: deviceId,
      now: now,
    );
  }

  Future<void> clearLicense() async {
    await _deleteSecureAndPref(_keyLicenseCode);
  }
}
