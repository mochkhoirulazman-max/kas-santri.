import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AppRemoteConfig {
  final String latestVersion;
  final String minVersion;
  final String announcementTitle;
  final String announcementBody;
  final bool promoBannerActive;
  final String updateUrl;

  const AppRemoteConfig({
    this.latestVersion = AppConfig.appVersion,
    this.minVersion = '3.0.0',
    this.announcementTitle = '',
    this.announcementBody = '',
    this.promoBannerActive = false,
    this.updateUrl = '',
  });

  bool isUpdateAvailable(String currentVersion) =>
      CustomerSyncService.compareSemver(latestVersion, currentVersion) > 0;

  bool get hasBannerContent =>
      isUpdateAvailable(AppConfig.appVersion) ||
      (promoBannerActive &&
          (announcementTitle.trim().isNotEmpty ||
              announcementBody.trim().isNotEmpty));

  factory AppRemoteConfig.fromJson(Map<String, dynamic> map) {
    return AppRemoteConfig(
      latestVersion:
          (map['latest_version']?.toString().trim().isNotEmpty == true)
              ? map['latest_version'].toString().trim()
              : AppConfig.appVersion,
      minVersion: (map['min_version']?.toString().trim().isNotEmpty == true)
          ? map['min_version'].toString().trim()
          : '3.0.0',
      announcementTitle: map['announcement_title']?.toString().trim() ?? '',
      announcementBody: map['announcement_body']?.toString().trim() ?? '',
      promoBannerActive: map['promo_banner_active'] == true,
      updateUrl: map['update_url']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'latest_version': latestVersion,
        'min_version': minVersion,
        'announcement_title': announcementTitle,
        'announcement_body': announcementBody,
        'promo_banner_active': promoBannerActive,
        'update_url': updateUrl,
      };
}

class CustomerSyncResult {
  final bool synced;
  final bool isRevoked;
  final AppRemoteConfig? remoteConfig;
  final String? message;

  const CustomerSyncResult({
    required this.synced,
    this.isRevoked = false,
    this.remoteConfig,
    this.message,
  });
}

/// Sinkronisasi Telemetri Non-Sensitif & Remote Revoke (Privacy-First).
///
/// PRIVASI KETAT PESANTREN:
/// - HANYA mengirim metadata lisensi perangkat (`device_id`, `nama_pondok`,
///   `nama_bendahara`, `no_wa`, `tier`, `expiry_date`, `app_version`, `payment_channel`).
/// - TIDAK PERNAH mengirim data santri, saldo, transaksi, mutasi dompet, maupun infak.
/// - Berjalan pasif di background saat online dengan timeout singkat (5 detik).
class CustomerSyncService {
  static final CustomerSyncService instance = CustomerSyncService._init();
  CustomerSyncService._init();

  static const String _keyRevoked = 'ks_v34_license_revoked';
  static const String _keyRemoteConfig = 'ks_v34_remote_config';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static int compareSemver(String a, String b) {
    List<int> parseParts(String raw) {
      final clean = raw.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first.split('-').first;
      return clean
          .split('.')
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .toList();
    }

    final pa = parseParts(a);
    final pb = parseParts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va > vb) return 1;
      if (va < vb) return -1;
    }
    return 0;
  }

  /// Membangun payload telemetri non-sensitif yang terjamin bebas data santri/saldo.
  static Map<String, dynamic> buildTelemetryPayload({
    required String deviceId,
    required String namaPondok,
    required String namaBendahara,
    required String noWaPengurus,
    required String tier,
    DateTime? expiryDate,
    String appVersion = AppConfig.appVersion,
    String paymentChannel = 'FREE',
  }) {
    return {
      'p_device_id': deviceId.trim().toUpperCase(),
      'p_nama_pondok': namaPondok.trim(),
      'p_nama_bendahara': namaBendahara.trim(),
      'p_no_wa': noWaPengurus.trim(),
      'p_tier': tier.trim().toUpperCase(),
      'p_expiry_date': expiryDate?.toUtc().toIso8601String(),
      'p_app_version': appVersion.trim(),
      'p_payment_channel': paymentChannel.trim().toUpperCase(),
    };
  }

  Future<bool> getCachedRevokedStatus() async {
    try {
      final sec = await _secureStorage.read(key: _keyRevoked);
      if (sec != null) return sec == '1';
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyRevoked) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setCachedRevokedStatus(bool revoked) async {
    bool savedSecure = false;
    try {
      await _secureStorage.write(key: _keyRevoked, value: revoked ? '1' : '0');
      savedSecure = true;
    } catch (_) {
      savedSecure = false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (savedSecure) {
        await prefs.remove(_keyRevoked);
      } else {
        await prefs.setBool(_keyRevoked, revoked);
      }
    } catch (_) {}
  }

  Future<AppRemoteConfig?> getCachedRemoteConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyRemoteConfig);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppRemoteConfig.fromJson(decoded);
      }
      if (decoded is Map) {
        return AppRemoteConfig.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveCachedRemoteConfig(AppRemoteConfig cfg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRemoteConfig, jsonEncode(cfg.toJson()));
    } catch (_) {}
  }

  Future<CustomerSyncResult> syncDeviceInBackground({
    required String deviceId,
    required String namaPondok,
    required String namaBendahara,
    required String noWaPengurus,
    required String tier,
    DateTime? expiryDate,
    String appVersion = AppConfig.appVersion,
    String paymentChannel = 'FREE',
    http.Client? client,
    String? supabaseUrlOverride,
    String? supabaseAnonKeyOverride,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final baseUrl =
        (supabaseUrlOverride ?? AppConfig.supabaseUrl).trim().replaceAll(RegExp(r'/+$'), '');
    final anonKey = (supabaseAnonKeyOverride ?? AppConfig.supabaseAnonKey).trim();

    if (!baseUrl.startsWith('https://') || anonKey.length <= 20) {
      return const CustomerSyncResult(
        synced: false,
        message: 'Supabase remote sync belum dikonfigurasi (Mode Offline murni).',
      );
    }

    final httpClient = client ?? http.Client();
    try {
      final payload = buildTelemetryPayload(
        deviceId: deviceId,
        namaPondok: namaPondok,
        namaBendahara: namaBendahara,
        noWaPengurus: noWaPengurus,
        tier: tier,
        expiryDate: expiryDate,
        appVersion: appVersion,
        paymentChannel: paymentChannel,
      );

      final uri = Uri.parse('$baseUrl/rest/v1/rpc/sync_device_telemetry');
      final response = await httpClient
          .post(
            uri,
            headers: {
              'apikey': anonKey,
              'Authorization': 'Bearer $anonKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return CustomerSyncResult(
          synced: false,
          message: 'Server merespons HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return const CustomerSyncResult(
          synced: false,
          message: 'Respons RPC tidak valid.',
        );
      }

      final data = Map<String, dynamic>.from(decoded);
      final isRevoked = data['is_revoked'] == true;
      await setCachedRevokedStatus(isRevoked);

      AppRemoteConfig? remoteCfg;
      if (data['remote_config'] is Map) {
        remoteCfg = AppRemoteConfig.fromJson(
          Map<String, dynamic>.from(data['remote_config'] as Map),
        );
        await _saveCachedRemoteConfig(remoteCfg);
      }

      return CustomerSyncResult(
        synced: true,
        isRevoked: isRevoked,
        remoteConfig: remoteCfg,
      );
    } catch (e) {
      return CustomerSyncResult(
        synced: false,
        message: 'Mode offline / gagal sinkronisasi: $e',
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
