import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ClockTamperCheckResult {
  final bool isTampered;
  final String? reason;
  final String message;
  final DateTime effectiveNow;
  final int driftMinutes;

  const ClockTamperCheckResult({
    required this.isTampered,
    this.reason,
    required this.message,
    required this.effectiveNow,
    this.driftMinutes = 0,
  });
}

class AppIntegrityReport {
  final bool isReleaseBuild;
  final bool isDebuggable;
  final bool hasTestKeys;
  final bool hasRootBinary;
  final bool isEmulator;
  final String signingCertSha256;
  final List<String> warnings;

  const AppIntegrityReport({
    required this.isReleaseBuild,
    required this.isDebuggable,
    required this.hasTestKeys,
    required this.hasRootBinary,
    required this.isEmulator,
    required this.signingCertSha256,
    required this.warnings,
  });

  bool get hasRiskSignals =>
      (isReleaseBuild && isDebuggable) || hasTestKeys || hasRootBinary;

  String get statusLabel {
    if (!hasRiskSignals) {
      return isReleaseBuild
          ? 'Terlindungi (Release Hardened)'
          : 'Mode Pengembangan (Debug Build)';
    }
    return 'Perlu Perhatian (${warnings.length} indikator)';
  }
}

/// Penjaga Keamanan v3.3:
/// 1. Anti-Clock Tampering (Monotonic timestamp di SecureStorage + HTTP Date sync)
/// 2. Mode Privasi Layar / Blokir Screenshot (`FLAG_SECURE` Android)
/// 3. Pemeriksaan integritas build/perangkat saat startup
class SecurityGuardService {
  static final SecurityGuardService instance = SecurityGuardService._init();
  SecurityGuardService._init();

  static const String _keyLastKnownTsMs = 'last_known_timestamp';
  static const String _keyScreenPrivacy = 'ks_v33_screen_privacy';
  static const MethodChannel _channel =
      MethodChannel('com.pondok.kassantri/security');

  static const Duration defaultTolerance = Duration(minutes: 15);
  static const String clockTamperWarningMessage =
      'Jam perangkat tidak sinkron. Aktifkan Tanggal & Waktu Otomatis untuk melanjutkan.';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> _readSecureOrPref(String key) async {
    try {
      final sec = await _secureStorage.read(key: key);
      if (sec != null && sec.isNotEmpty) return sec;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> _writeSecureAndClearPref(String key, String value) async {
    bool written = false;
    try {
      await _secureStorage.write(key: key, value: value);
      written = true;
    } catch (_) {
      written = false;
    }
    final prefs = await SharedPreferences.getInstance();
    if (written) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  /// Fungsi murni (unit-testable) untuk mendeteksi manipulasi jam perangkat.
  static ClockTamperCheckResult evaluateClockTamper({
    required DateTime currentNow,
    required int? lastKnownEpochMs,
    DateTime? networkNow,
    Duration tolerance = defaultTolerance,
  }) {
    final currentMs = currentNow.millisecondsSinceEpoch;
    final tolMs = tolerance.inMilliseconds;

    if (lastKnownEpochMs != null && currentMs < lastKnownEpochMs - tolMs) {
      final diffMin = ((lastKnownEpochMs - currentMs) / 60000).ceil();
      return ClockTamperCheckResult(
        isTampered: true,
        reason: 'CLOCK_REWIND',
        message: clockTamperWarningMessage,
        effectiveNow: DateTime.fromMillisecondsSinceEpoch(lastKnownEpochMs),
        driftMinutes: diffMin,
      );
    }

    if (networkNow != null) {
      final diffMs = (currentMs - networkNow.millisecondsSinceEpoch).abs();
      if (diffMs > tolMs) {
        final diffMin = (diffMs / 60000).ceil();
        return ClockTamperCheckResult(
          isTampered: true,
          reason: 'NETWORK_DRIFT',
          message: clockTamperWarningMessage,
          effectiveNow: networkNow.toLocal(),
          driftMinutes: diffMin,
        );
      }
    }

    return ClockTamperCheckResult(
      isTampered: false,
      message: 'Waktu perangkat sinkron.',
      effectiveNow: currentNow,
      driftMinutes: 0,
    );
  }

  /// Cek jam perangkat terhadap monotonic timestamp & optional network time,
  /// lalu memajukan `last_known_timestamp` secara aman (tidak pernah mundur).
  Future<ClockTamperCheckResult> checkAndAdvanceClock({
    DateTime? nowOverride,
    DateTime? networkNowOverride,
    bool allowNetworkSync = false,
  }) async {
    final currentNow = nowOverride ?? DateTime.now();
    final rawLast = await _readSecureOrPref(_keyLastKnownTsMs);
    final lastMs = rawLast != null ? int.tryParse(rawLast) : null;

    DateTime? netNow = networkNowOverride;
    if (netNow == null && allowNetworkSync) {
      netNow = await syncTrustedTimeFromNetwork();
    }

    final result = evaluateClockTamper(
      currentNow: currentNow,
      lastKnownEpochMs: lastMs,
      networkNow: netNow,
    );

    if (!result.isTampered) {
      final candidates = <int>[
        currentNow.millisecondsSinceEpoch,
        if (lastMs != null) lastMs,
        if (netNow != null) netNow.millisecondsSinceEpoch,
      ];
      final maxEpochMs = candidates.reduce((a, b) => a > b ? a : b);
      await _writeSecureAndClearPref(_keyLastKnownTsMs, maxEpochMs.toString());
    } else if (netNow != null) {
      // Saat terdeteksi mundur namun punya waktu jaringan yang lebih baru, tetap kunci batas minimum ke network time.
      final floorMs = [
        if (lastMs != null) lastMs,
        netNow.millisecondsSinceEpoch,
      ].reduce((a, b) => a > b ? a : b);
      await _writeSecureAndClearPref(_keyLastKnownTsMs, floorMs.toString());
    }

    return result;
  }

  /// Sinkronisasi waktu pasif melalui HTTP header `Date` (hanya berjalan jika online, gagal sunyi saat offline).
  Future<DateTime?> syncTrustedTimeFromNetwork({
    http.Client? client,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final httpClient = client ?? http.Client();
    const urls = [
      'https://www.google.com/generate_204',
      'https://cloudflare.com/cdn-cgi/trace',
    ];
    try {
      for (final rawUrl in urls) {
        try {
          final resp = await httpClient
              .head(Uri.parse(rawUrl))
              .timeout(timeout);
          final dateHeader = resp.headers['date'];
          if (dateHeader != null && dateHeader.trim().isNotEmpty) {
            return HttpDate.parse(dateHeader.trim()).toUtc();
          }
        } catch (_) {
          // Lanjutkan kandidat endpoint berikutnya atau kembali offline secara sunyi
        }
      }
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  Future<bool> getScreenPrivacyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyScreenPrivacy) ?? false;
  }

  Future<void> setScreenPrivacyEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyScreenPrivacy, enabled);
    await _applyFlagSecureNative(enabled);
  }

  Future<void> applySavedScreenPrivacy() async {
    final enabled = await getScreenPrivacyEnabled();
    await _applyFlagSecureNative(enabled);
  }

  Future<void> _applyFlagSecureNative(bool enabled) async {
    try {
      await _channel.invokeMethod<bool>('setSecureScreen', {
        'enabled': enabled,
      });
    } catch (_) {
      // Aman di platform non-Android / unit test
    }
  }

  Future<AppIntegrityReport> checkAppIntegrity() async {
    bool isDebuggable = kDebugMode;
    bool hasTestKeys = false;
    bool hasRootBinary = false;
    bool isEmulator = false;
    String signingCert = '';

    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>('checkDeviceIntegrity');
      if (raw != null) {
        isDebuggable = (raw['isDebuggable'] as bool?) ?? isDebuggable;
        hasTestKeys = (raw['hasTestKeys'] as bool?) ?? false;
        hasRootBinary = (raw['hasRootBinary'] as bool?) ?? false;
        isEmulator = (raw['isEmulator'] as bool?) ?? false;
        signingCert = (raw['signingCertSha256'] as String?) ?? '';
      }
    } catch (_) {
      // Tidak memblokir jika channel belum tersedia
    }

    final warnings = <String>[];
    if (kReleaseMode && isDebuggable) {
      warnings.add('Build rilis memiliki flag debuggable aktif');
    }
    if (hasTestKeys) {
      warnings.add('Sistem Android menggunakan test-keys');
    }
    if (hasRootBinary) {
      warnings.add('Terdeteksi biner su/root pada sistem');
    }

    return AppIntegrityReport(
      isReleaseBuild: kReleaseMode,
      isDebuggable: isDebuggable,
      hasTestKeys: hasTestKeys,
      hasRootBinary: hasRootBinary,
      isEmulator: isEmulator,
      signingCertSha256: signingCert,
      warnings: warnings,
    );
  }
}
