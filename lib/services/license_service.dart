import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseVerificationResult {
  final bool isValid;
  final bool isExpired;
  final String? planKey; // MONTHLY, YEARLY, LIFETIME
  final String? tipe; // M1, Y1, LT
  final String? expiryYyyymmdd;
  final DateTime? expiresAt;
  final String? code;
  final String message;

  const LicenseVerificationResult({
    required this.isValid,
    this.isExpired = false,
    this.planKey,
    this.tipe,
    this.expiryYyyymmdd,
    this.expiresAt,
    this.code,
    required this.message,
  });
}

class LicenseService {
  static final LicenseService instance = LicenseService._init();
  LicenseService._init();

  static const String secretSalt = 'KS-MKA-2026-PRO-SALT-082130678956-AMANAH';
  static const String _deviceIdAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const String _keyDeviceId = 'kas_santri_device_id_v1';
  static const String _keyLicenseCode = 'kas_santri_pro_license_code_v1';

  static final RegExp _codeRegex =
      RegExp(r'^KSPRO-(M1|Y1|LT)-(\d{8})-([A-F0-9]{8})$');

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cachedDeviceId;

  static String normalizeDeviceId(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static String normalizeLicenseCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static String planKeyFromTipe(String tipe) {
    switch (tipe.toUpperCase()) {
      case 'M1':
        return 'MONTHLY';
      case 'LT':
        return 'LIFETIME';
      case 'Y1':
      default:
        return 'YEARLY';
    }
  }

  static String computeChecksum8({
    required String deviceId,
    required String tipe,
    required String expiryYyyymmdd,
  }) {
    final payload =
        '${normalizeDeviceId(deviceId)}|${tipe.trim().toUpperCase()}|${expiryYyyymmdd.trim()}|$secretSalt';
    final digest = sha256.convert(utf8.encode(payload)).toString().toUpperCase();
    return digest.substring(0, 8);
  }

  static String generateLicenseCode({
    required String deviceId,
    required String tipe,
    required String expiryYyyymmdd,
  }) {
    final normDevice = normalizeDeviceId(deviceId);
    final normTipe = tipe.trim().toUpperCase();
    final normDate = normTipe == 'LT' ? '99991231' : expiryYyyymmdd.trim();
    final checksum8 = computeChecksum8(
      deviceId: normDevice,
      tipe: normTipe,
      expiryYyyymmdd: normDate,
    );
    return 'KSPRO-$normTipe-$normDate-$checksum8';
  }

  static DateTime? _parseExpiryEndOfDay(String yyyymmdd) {
    if (yyyymmdd.length != 8) return null;
    final y = int.tryParse(yyyymmdd.substring(0, 4));
    final m = int.tryParse(yyyymmdd.substring(4, 6));
    final d = int.tryParse(yyyymmdd.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final parsed = DateTime(y, m, d, 23, 59, 59);
    if (parsed.year != y || parsed.month != m || parsed.day != d) return null;
    return parsed;
  }

  static LicenseVerificationResult verifyCodePure({
    required String code,
    required String deviceId,
    DateTime? now,
  }) {
    final normalizedCode = normalizeLicenseCode(code);
    final normalizedDevice = normalizeDeviceId(deviceId);

    if (normalizedCode.isEmpty) {
      return const LicenseVerificationResult(
        isValid: false,
        message: 'Masukkan kode aktivasi PRO terlebih dahulu.',
      );
    }

    final match = _codeRegex.firstMatch(normalizedCode);
    if (match == null) {
      return const LicenseVerificationResult(
        isValid: false,
        message:
            'Format kode tidak dikenali. Contoh format: KSPRO-Y1-20271125-XXXXXXXX',
      );
    }

    final tipe = match.group(1)!;
    final expiryStr = match.group(2)!;
    final providedChecksum = match.group(3)!;

    if (tipe == 'LT' && expiryStr != '99991231') {
      return const LicenseVerificationResult(
        isValid: false,
        message: 'Kode Lifetime tidak valid (format tanggal harus 99991231).',
      );
    }

    final expectedChecksum = computeChecksum8(
      deviceId: normalizedDevice,
      tipe: tipe,
      expiryYyyymmdd: expiryStr,
    );

    if (providedChecksum != expectedChecksum) {
      return LicenseVerificationResult(
        isValid: false,
        message:
            'Kode lisensi tidak cocok dengan ID Perangkat ($normalizedDevice) atau ada huruf yang salah ketik.',
      );
    }

    DateTime? expiresAt;
    if (tipe != 'LT') {
      expiresAt = _parseExpiryEndOfDay(expiryStr);
      if (expiresAt == null) {
        return const LicenseVerificationResult(
          isValid: false,
          message: 'Tanggal masa aktif pada kode lisensi tidak valid.',
        );
      }
      final refNow = now ?? DateTime.now();
      if (refNow.isAfter(expiresAt)) {
        return LicenseVerificationResult(
          isValid: false,
          isExpired: true,
          planKey: planKeyFromTipe(tipe),
          tipe: tipe,
          expiryYyyymmdd: expiryStr,
          expiresAt: expiresAt,
          code: normalizedCode,
          message:
              'Masa aktif kode lisensi ini telah berakhir pada $expiryStr. Silakan perpanjang paket.',
        );
      }
    }

    final planKey = planKeyFromTipe(tipe);
    return LicenseVerificationResult(
      isValid: true,
      isExpired: false,
      planKey: planKey,
      tipe: tipe,
      expiryYyyymmdd: expiryStr,
      expiresAt: expiresAt,
      code: normalizedCode,
      message: tipe == 'LT'
          ? 'Alhamdulillah! Lisensi Kas-Santri PRO Selamanya (Lifetime) aktif!'
          : 'Alhamdulillah! Lisensi Kas-Santri PRO aktif hingga ${expiryStr.substring(6, 8)}/${expiryStr.substring(4, 6)}/${expiryStr.substring(0, 4)}.',
    );
  }

  String _generateRandomDeviceId() {
    Random rnd;
    try {
      rnd = Random.secure();
    } catch (_) {
      rnd = Random();
    }
    String part(int len) => List.generate(
          len,
          (_) => _deviceIdAlphabet[rnd.nextInt(_deviceIdAlphabet.length)],
        ).join();
    return 'KS-${part(4)}-${part(4)}';
  }

  Future<String> getOrCreateDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }

    String? existing;
    try {
      existing = await _secureStorage.read(key: _keyDeviceId);
    } catch (_) {}

    if (existing == null || existing.trim().isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        existing = prefs.getString(_keyDeviceId);
      } catch (_) {}
    }

    if (existing != null && existing.trim().isNotEmpty) {
      _cachedDeviceId = normalizeDeviceId(existing);
      try {
        await _secureStorage.write(key: _keyDeviceId, value: _cachedDeviceId!);
      } catch (_) {}
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyDeviceId, _cachedDeviceId!);
      } catch (_) {}
      return _cachedDeviceId!;
    }

    final generated = _generateRandomDeviceId();
    _cachedDeviceId = generated;
    try {
      await _secureStorage.write(key: _keyDeviceId, value: generated);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDeviceId, generated);
    } catch (_) {}
    return generated;
  }

  Future<LicenseVerificationResult> activateLicense(String rawCode) async {
    final deviceId = await getOrCreateDeviceId();
    final res = verifyCodePure(code: rawCode, deviceId: deviceId);
    if (!res.isValid || res.code == null) return res;

    try {
      await _secureStorage.write(key: _keyLicenseCode, value: res.code!);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLicenseCode, res.code!);
    } catch (_) {}
    return res;
  }

  Future<LicenseVerificationResult?> checkSavedLicense({DateTime? now}) async {
    String? savedCode;
    try {
      savedCode = await _secureStorage.read(key: _keyLicenseCode);
    } catch (_) {}

    if (savedCode == null || savedCode.trim().isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        savedCode = prefs.getString(_keyLicenseCode);
      } catch (_) {}
    }

    if (savedCode == null || savedCode.trim().isEmpty) {
      return null;
    }

    final deviceId = await getOrCreateDeviceId();
    return verifyCodePure(code: savedCode, deviceId: deviceId, now: now);
  }

  Future<void> clearSavedLicense() async {
    try {
      await _secureStorage.delete(key: _keyLicenseCode);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLicenseCode);
    } catch (_) {}
  }
}
