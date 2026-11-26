import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../models/pengaturan.dart';
import 'backup_service.dart';
import 'subscription_service.dart';

class GoogleAuthFriendlyException implements Exception {
  final String title;
  final String message;
  final bool isSha1ConfigError;
  final bool isCanceled;

  const GoogleAuthFriendlyException({
    required this.title,
    required this.message,
    this.isSha1ConfigError = false,
    this.isCanceled = false,
  });

  @override
  String toString() => message;
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

class GoogleDriveBackupService {
  static final GoogleDriveBackupService instance =
      GoogleDriveBackupService._init();
  GoogleDriveBackupService._init();

  static const String backupFileName = 'kas_santri_cloud_backup.json';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  static GoogleAuthFriendlyException mapAuthError(Object error) {
    if (error is GoogleAuthFriendlyException) return error;

    if (error is PlatformException) {
      final raw =
          '${error.code} ${error.message ?? ''} ${error.details ?? ''}'
              .toLowerCase();
      if (error.code == 'sign_in_canceled' || raw.contains('canceled')) {
        return const GoogleAuthFriendlyException(
          title: 'Login Google Dibatalkan',
          message:
              'Pemilihan akun Google dibatalkan. Anda tetap dapat memakai Mode Bendahara Lokal atau Backup Lokal (.JSON / .KSBAK) kapan saja.',
          isCanceled: true,
        );
      }
      if (raw.contains('apiexception: 10') ||
          raw.contains(' 10:') ||
          raw.contains(', 10,') ||
          raw.contains('developer_error') ||
          error.code == 'sign_in_failed') {
        return const GoogleAuthFriendlyException(
          title: 'OAuth Google Belum Aktif di Build Rilis Ini',
          message:
              'Google Sign-In memerlukan pendaftaran sertifikat SHA-1 Android (paket com.pondok.kassantri) pada Google Cloud Console untuk APK rilis.\n\nData kas pondok Anda tetap 100% aman di perangkat. Silakan gunakan tombol alternatif instan di bawah ini:',
          isSha1ConfigError: true,
        );
      }
      if (error.code == 'network_error' || raw.contains('network')) {
        return const GoogleAuthFriendlyException(
          title: 'Koneksi Internet Belum Stabil',
          message:
              'Tidak dapat menghubungi layanan Google saat ini. Pastikan internet aktif atau gunakan Backup Lokal (.JSON / .KSBAK) / Mode Bendahara Lokal.',
        );
      }
    }

    if (error is TimeoutException) {
      return const GoogleAuthFriendlyException(
        title: 'Waktu Sambungan Habis',
        message:
            'Koneksi ke Google memerlukan waktu terlalu lama. Anda dapat langsung menggunakan Backup Lokal (.JSON / .KSBAK) atau Mode Bendahara Lokal.',
      );
    }

    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('apiexception: 10') ||
        lower.contains('developer_error') ||
        lower.contains('sign_in_failed')) {
      return const GoogleAuthFriendlyException(
        title: 'OAuth Google Belum Aktif di Build Rilis Ini',
        message:
            'Google Sign-In memerlukan pendaftaran sertifikat SHA-1 Android (paket com.pondok.kassantri) pada Google Cloud Console untuk APK rilis.\n\nSilakan gunakan Backup Lokal (.JSON / .KSBAK) atau Mode Bendahara Lokal.',
        isSha1ConfigError: true,
      );
    }

    return const GoogleAuthFriendlyException(
      title: 'Belum Dapat Terhubung ke Google',
      message:
          'Layanan Google belum dapat diakses pada perangkat ini. Pastikan koneksi internet aktif, atau gunakan fitur Backup Lokal (.JSON / .KSBAK) & Mode Bendahara Lokal.',
    );
  }

  Future<GoogleSignInAccount?> getCurrentOrSilentAccount() async {
    try {
      if (_googleSignIn.currentUser != null) {
        return _googleSignIn.currentUser;
      }
      return await _googleSignIn.signInSilently().timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );
    } catch (_) {
      return null;
    }
  }

  Future<GoogleSignInAccount?> signInInteractive() async {
    try {
      final account = await _googleSignIn.signIn().timeout(
            const Duration(seconds: 30),
          );
      if (account == null) {
        throw const GoogleAuthFriendlyException(
          title: 'Login Google Dibatalkan',
          message:
              'Pemilihan akun Google dibatalkan. Anda dapat langsung melanjutkan dengan Mode Bendahara Lokal atau Backup Lokal (.JSON / .KSBAK).',
          isCanceled: true,
        );
      }
      return account;
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<DateTime> uploadBackupJson(Map<String, dynamic> payload) async {
    var account = await getCurrentOrSilentAccount();
    account ??= await signInInteractive();
    if (account == null) {
      throw const GoogleAuthFriendlyException(
        title: 'Akun Google Belum Terhubung',
        message:
            'Silakan tautkan akun Google terlebih dahulu atau gunakan Backup Lokal (.JSON / .KSBAK).',
        isCanceled: true,
      );
    }

    final authHeaders = await account.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    try {
      final driveApi = drive.DriveApi(client);
      final existingList = await driveApi.files
          .list(
            spaces: 'appDataFolder',
            q: "name = '$backupFileName' and trashed = false",
            $fields: 'files(id, name, modifiedTime)',
          )
          .timeout(const Duration(seconds: 20));

      final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
      final bytes = utf8.encode(jsonStr);
      final media = drive.Media(Stream.value(bytes), bytes.length);

      if (existingList.files != null && existingList.files!.isNotEmpty) {
        final existingId = existingList.files!.first.id!;
        await driveApi.files
            .update(
              drive.File()..name = backupFileName,
              existingId,
              uploadMedia: media,
            )
            .timeout(const Duration(seconds: 30));
      } else {
        final fileMeta = drive.File()
          ..name = backupFileName
          ..parents = <String>['appDataFolder'];
        await driveApi.files
            .create(fileMeta, uploadMedia: media)
            .timeout(const Duration(seconds: 30));
      }

      return DateTime.now();
    } on GoogleAuthFriendlyException {
      rethrow;
    } catch (e) {
      throw mapAuthError(e);
    } finally {
      client.close();
    }
  }

  Future<({BackupValidationResult validation, DateTime? modifiedTime})>
      downloadAndValidateBackup() async {
    var account = await getCurrentOrSilentAccount();
    account ??= await signInInteractive();
    if (account == null) {
      throw const GoogleAuthFriendlyException(
        title: 'Akun Google Belum Terhubung',
        message:
            'Silakan tautkan akun Google terlebih dahulu atau pulihkan dari file Backup Lokal (.JSON / .KSBAK).',
        isCanceled: true,
      );
    }

    final authHeaders = await account.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    try {
      final driveApi = drive.DriveApi(client);
      final existingList = await driveApi.files
          .list(
            spaces: 'appDataFolder',
            q: "name = '$backupFileName' and trashed = false",
            $fields: 'files(id, name, modifiedTime)',
          )
          .timeout(const Duration(seconds: 20));

      if (existingList.files == null || existingList.files!.isEmpty) {
        throw GoogleAuthFriendlyException(
          title: 'Belum Ada Cadangan di Drive',
          message:
              'Belum ditemukan file cadangan Kas-Santri pada Google Drive akun ${account.email}. Anda juga dapat memulihkan dari file lokal (.JSON / .KSBAK).',
        );
      }

      final targetFile = existingList.files!.first;
      final dynamic downloaded = await driveApi.files
          .get(
            targetFile.id!,
            downloadOptions: drive.DownloadOptions.fullMedia,
          )
          .timeout(const Duration(seconds: 30));

      if (downloaded is! drive.Media) {
        throw const GoogleAuthFriendlyException(
          title: 'Unduhan Cadangan Gagal',
          message: 'Gagal mengunduh isi file backup dari Google Drive.',
        );
      }

      final chunks = <int>[];
      await for (final chunk in downloaded.stream) {
        chunks.addAll(chunk);
      }
      final rawJson = utf8.decode(chunks);
      final validation = BackupService.validateJsonString(rawJson);
      if (!validation.isValid) {
        throw FormatException(
          validation.errorMessage ?? 'File backup di Google Drive tidak valid.',
        );
      }

      return (
        validation: validation,
        modifiedTime: targetFile.modifiedTime?.toLocal(),
      );
    } on GoogleAuthFriendlyException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (e) {
      throw mapAuthError(e);
    } finally {
      client.close();
    }
  }

  /// Menjalankan auto-backup harian secara senyap saat aplikasi aktif & terhubung internet
  Future<DateTime?> runDailyAutoBackupIfDue({
    required PengaturanAplikasi settings,
    required Future<Map<String, dynamic>> Function() dumpPayload,
  }) async {
    if (!SubscriptionService.instance.hasProAccess || !settings.autoDriveBackup) {
      return null;
    }
    if (settings.driveAccountEmail == null ||
        settings.driveAccountEmail!.isEmpty) {
      return null;
    }

    if (settings.lastDriveBackupAt != null) {
      final last = DateTime.tryParse(settings.lastDriveBackupAt!);
      if (last != null &&
          DateTime.now().difference(last) < const Duration(hours: 24)) {
        return null;
      }
    }

    try {
      final account = await getCurrentOrSilentAccount();
      if (account == null) return null;
      final payload = await dumpPayload();
      return await uploadBackupJson(payload);
    } catch (_) {
      return null;
    }
  }
}
