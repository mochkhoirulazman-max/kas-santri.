import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'backup_service.dart';

class CloudBackupMeta {
  final String backupKey;
  final DateTime? lastUploadedAt;
  final int sizeBytes;

  const CloudBackupMeta({
    required this.backupKey,
    this.lastUploadedAt,
    this.sizeBytes = 0,
  });
}

class CloudBackupUploadResult {
  final bool success;
  final String backupKey;
  final int sizeBytes;
  final DateTime? updatedAt;
  final String message;

  const CloudBackupUploadResult({
    required this.success,
    this.backupKey = '',
    this.sizeBytes = 0,
    this.updatedAt,
    required this.message,
  });
}

class CloudBackupDownloadResult {
  final bool success;
  final String backupKey;
  final String namaPondok;
  final DateTime? updatedAt;
  final BackupValidationResult? validation;
  final String message;

  const CloudBackupDownloadResult({
    required this.success,
    this.backupKey = '',
    this.namaPondok = '',
    this.updatedAt,
    this.validation,
    required this.message,
  });
}

/// Layanan Cloud Backup Online Resmi Kas-Santri (Supabase Cloud Vault).
///
/// Seluruh data dienkripsi di sisi perangkat dengan AES-256-GCM (`BackupService.encryptBackupToKsbak`)
/// menggunakan password pilihan bendahara sebelum diunggah ke cloud, sehingga server
/// maupun pihak lain tidak pernah dapat membaca isi data keuangan pondok.
class CloudBackupService {
  static final CloudBackupService instance = CloudBackupService._init();
  CloudBackupService._init();

  static const String _prefBackupKey = 'ks_v43_cloud_backup_key';
  static const String _prefBackupAt = 'ks_v43_cloud_backup_at';
  static const String _prefBackupSize = 'ks_v43_cloud_backup_size';

  static String normalizeBackupKey(String raw) {
    return raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_\-]'), '');
  }

  Future<CloudBackupMeta?> getLastMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_prefBackupKey) ?? '';
      if (key.isEmpty) return null;
      final atRaw = prefs.getString(_prefBackupAt);
      final size = prefs.getInt(_prefBackupSize) ?? 0;
      return CloudBackupMeta(
        backupKey: key,
        lastUploadedAt: atRaw != null ? DateTime.tryParse(atRaw) : null,
        sizeBytes: size,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveMeta({
    required String backupKey,
    required DateTime updatedAt,
    required int sizeBytes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefBackupKey, backupKey);
      await prefs.setString(_prefBackupAt, updatedAt.toIso8601String());
      await prefs.setInt(_prefBackupSize, sizeBytes);
    } catch (_) {}
  }

  Future<CloudBackupUploadResult> uploadEncryptedBackup({
    required String backupKey,
    required String password,
    required String deviceId,
    required String namaPondok,
    required Map<String, dynamic> backupData,
    http.Client? client,
  }) async {
    final cleanKey = normalizeBackupKey(backupKey);
    if (cleanKey.length < 4 || cleanKey.length > 48) {
      return const CloudBackupUploadResult(
        success: false,
        message: 'Kode Backup Pondok wajib 4–48 karakter (huruf, angka, - atau _).',
      );
    }
    if (password.trim().length < 4) {
      return const CloudBackupUploadResult(
        success: false,
        message: 'Password enkripsi minimal 4 karakter.',
      );
    }
    if (!AppConfig.isSupabaseConfigured) {
      return const CloudBackupUploadResult(
        success: false,
        message:
            'Server Cloud Vault Online belum dikonfigurasi pada build aplikasi ini. Gunakan Simpan ke Memori HP atau Bagikan File (.KSBAK / .JSON).',
      );
    }

    final httpClient = client ?? http.Client();
    final shouldClose = client == null;
    try {
      final encryptedBytes = await BackupService.encryptBackupToKsbak(
        backupData: backupData,
        password: password,
      );
      final payloadB64 = base64Encode(encryptedBytes);

      final uri = Uri.parse(
        '${AppConfig.supabaseUrl.trim()}/rest/v1/rpc/upsert_cloud_backup',
      );
      final response = await httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'apikey': AppConfig.supabaseAnonKey.trim(),
              'Authorization': 'Bearer ${AppConfig.supabaseAnonKey.trim()}',
            },
            body: jsonEncode({
              'p_backup_key': cleanKey,
              'p_device_id': deviceId,
              'p_nama_pondok': namaPondok,
              'p_payload_encrypted': payloadB64,
              'p_app_version': AppConfig.appVersion,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return CloudBackupUploadResult(
          success: false,
          backupKey: cleanKey,
          message: 'Gagal mengunggah ke Cloud Online (HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      final now = DateTime.now();
      DateTime updatedAt = now;
      int sizeBytes = encryptedBytes.length;
      if (decoded is Map) {
        if (decoded['updated_at'] != null) {
          updatedAt = DateTime.tryParse(decoded['updated_at'].toString())?.toLocal() ?? now;
        }
        if (decoded['size_bytes'] != null) {
          sizeBytes = (decoded['size_bytes'] as num?)?.toInt() ?? encryptedBytes.length;
        }
      }

      await _saveMeta(
        backupKey: cleanKey,
        updatedAt: updatedAt,
        sizeBytes: sizeBytes,
      );

      return CloudBackupUploadResult(
        success: true,
        backupKey: cleanKey,
        sizeBytes: sizeBytes,
        updatedAt: updatedAt,
        message: 'Cadangan terenkripsi berhasil diunggah ke Cloud Online.',
      );
    } catch (e) {
      return CloudBackupUploadResult(
        success: false,
        backupKey: cleanKey,
        message: 'Koneksi internet / Cloud Online bermasalah ($e).',
      );
    } finally {
      if (shouldClose) httpClient.close();
    }
  }

  Future<CloudBackupDownloadResult> downloadAndDecryptBackup({
    required String backupKey,
    required String password,
    http.Client? client,
  }) async {
    final cleanKey = normalizeBackupKey(backupKey);
    if (cleanKey.length < 4 || cleanKey.length > 48) {
      return const CloudBackupDownloadResult(
        success: false,
        message: 'Masukkan Kode Backup Pondok yang valid (min. 4 karakter).',
      );
    }
    if (password.isEmpty) {
      return const CloudBackupDownloadResult(
        success: false,
        message: 'Masukkan Password Enkripsi cadangan Anda.',
      );
    }
    if (!AppConfig.isSupabaseConfigured) {
      return const CloudBackupDownloadResult(
        success: false,
        message:
            'Server Cloud Vault Online belum dikonfigurasi pada build aplikasi ini. Gunakan Pulihkan File Lokal (.JSON / .KSBAK).',
      );
    }

    final httpClient = client ?? http.Client();
    final shouldClose = client == null;
    try {
      final uri = Uri.parse(
        '${AppConfig.supabaseUrl.trim()}/rest/v1/rpc/fetch_cloud_backup',
      );
      final response = await httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'apikey': AppConfig.supabaseAnonKey.trim(),
              'Authorization': 'Bearer ${AppConfig.supabaseAnonKey.trim()}',
            },
            body: jsonEncode({'p_backup_key': cleanKey}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return CloudBackupDownloadResult(
          success: false,
          backupKey: cleanKey,
          message: 'Gagal mengunduh dari Cloud Online (HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['found'] != true) {
        return CloudBackupDownloadResult(
          success: false,
          backupKey: cleanKey,
          message: 'Kode Backup "$cleanKey" tidak ditemukan di Cloud Online.',
        );
      }

      final payloadB64 = decoded['payload_encrypted']?.toString() ?? '';
      if (payloadB64.isEmpty) {
        return CloudBackupDownloadResult(
          success: false,
          backupKey: cleanKey,
          message: 'Data cadangan cloud kosong atau rusak.',
        );
      }

      final encryptedBytes = base64Decode(payloadB64);
      final validation = await BackupService.decryptAndValidateKsbak(
        bytes: encryptedBytes,
        password: password,
      );

      if (!validation.isValid) {
        return CloudBackupDownloadResult(
          success: false,
          backupKey: cleanKey,
          validation: validation,
          message: validation.errorMessage ??
              'Password salah atau data cadangan cloud tidak valid.',
        );
      }

      final updatedAt = decoded['updated_at'] != null
          ? DateTime.tryParse(decoded['updated_at'].toString())?.toLocal()
          : null;

      return CloudBackupDownloadResult(
        success: true,
        backupKey: cleanKey,
        namaPondok: decoded['nama_pondok']?.toString() ?? '',
        updatedAt: updatedAt,
        validation: validation,
        message: 'Cadangan cloud berhasil dibuka & diverifikasi.',
      );
    } catch (e) {
      return CloudBackupDownloadResult(
        success: false,
        backupKey: cleanKey,
        message: 'Gagal terhubung ke Cloud Online ($e).',
      );
    } finally {
      if (shouldClose) httpClient.close();
    }
  }
}
