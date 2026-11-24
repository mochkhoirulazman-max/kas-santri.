import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../models/pengaturan.dart';
import 'backup_service.dart';

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
  static final GoogleDriveBackupService instance = GoogleDriveBackupService._init();
  GoogleDriveBackupService._init();

  static const String backupFileName = 'kas_santri_cloud_backup.json';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[drive.DriveApi.driveAppdataScope],
  );

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
      return account;
    } catch (e) {
      throw Exception(
        'Gagal menautkan akun Google. Pastikan perangkat terhubung internet & Google Play Services aktif ($e).',
      );
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
      throw Exception('Login akun Google dibatalkan atau belum terhubung.');
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
    } on Exception {
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<({BackupValidationResult validation, DateTime? modifiedTime})>
      downloadAndValidateBackup() async {
    var account = await getCurrentOrSilentAccount();
    account ??= await signInInteractive();
    if (account == null) {
      throw Exception('Login akun Google dibatalkan atau belum terhubung.');
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
        throw Exception(
          'Belum ada file cadangan Kas-Santri di Google Drive akun ${account.email}.',
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
        throw Exception('Gagal mengunduh isi file backup dari Google Drive.');
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
    } finally {
      client.close();
    }
  }

  /// Menjalankan auto-backup harian secara senyap saat aplikasi aktif & terhubung internet
  Future<DateTime?> runDailyAutoBackupIfDue({
    required PengaturanAplikasi settings,
    required Future<Map<String, dynamic>> Function() dumpPayload,
  }) async {
    if (!settings.isPro || !settings.autoDriveBackup) return null;
    if (settings.driveAccountEmail == null || settings.driveAccountEmail!.isEmpty) {
      return null;
    }

    if (settings.lastDriveBackupAt != null) {
      final last = DateTime.tryParse(settings.lastDriveBackupAt!);
      if (last != null && DateTime.now().difference(last) < const Duration(hours: 24)) {
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
