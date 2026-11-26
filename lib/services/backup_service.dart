import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute;

class BackupValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int santriCount;
  final int setoranCount;
  final int transaksiCount;
  final int tunggakanLogCount;
  final int mutasiDompetCount;
  final int cashOpnameCount;
  final int infakCount;
  final int serahTerimaInfakCount;
  final String? exportedAt;
  final Map<String, dynamic>? parsedData;

  const BackupValidationResult({
    required this.isValid,
    this.errorMessage,
    this.santriCount = 0,
    this.setoranCount = 0,
    this.transaksiCount = 0,
    this.tunggakanLogCount = 0,
    this.mutasiDompetCount = 0,
    this.cashOpnameCount = 0,
    this.infakCount = 0,
    this.serahTerimaInfakCount = 0,
    this.exportedAt,
    this.parsedData,
  });

  factory BackupValidationResult.invalid(String message) {
    return BackupValidationResult(
      isValid: false,
      errorMessage: message,
    );
  }
}

class BackupService {
  static const List<String> requiredTables = [
    'santri',
    'setoran_bulanan',
    'transaksi_harian',
    'tunggakan_log',
    'mutasi_dompet',
    'cash_opname_logs',
    'pengaturan_aplikasi',
  ];

  static const List<String> optionalV3Tables = [
    'infak_santri',
    'serah_terima_infak',
    'audit_log',
  ];

  static BackupValidationResult validateJsonString(String rawJson) {
    if (rawJson.trim().isEmpty) {
      return BackupValidationResult.invalid('File backup kosong.');
    }
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        return BackupValidationResult.invalid(
          'Format JSON tidak valid: root harus berupa objek backup Kas-Santri.',
        );
      }
      final map = Map<String, dynamic>.from(decoded);
      return validateBackupMap(map);
    } catch (e) {
      return BackupValidationResult.invalid('File JSON rusak atau tidak dapat dibaca ($e).');
    }
  }

  static BackupValidationResult validateBackupMap(Map<String, dynamic> data) {
    for (final table in requiredTables) {
      if (!data.containsKey(table)) {
        return BackupValidationResult.invalid(
          'Struktur backup tidak lengkap: tabel "$table" tidak ditemukan.',
        );
      }
      final rows = data[table];
      if (rows is! List) {
        return BackupValidationResult.invalid(
          'Struktur backup tidak valid: tabel "$table" harus berupa daftar/array.',
        );
      }
      for (int i = 0; i < rows.length; i++) {
        if (rows[i] is! Map) {
          return BackupValidationResult.invalid(
            'Baris ke-${i + 1} pada tabel "$table" bukan objek data yang valid.',
          );
        }
      }
    }

    for (final table in optionalV3Tables) {
      if (!data.containsKey(table) || data[table] == null) continue;
      final rows = data[table];
      if (rows is! List) {
        return BackupValidationResult.invalid(
          'Struktur backup tidak valid: tabel "$table" harus berupa daftar/array.',
        );
      }
      for (int i = 0; i < rows.length; i++) {
        if (rows[i] is! Map) {
          return BackupValidationResult.invalid(
            'Baris ke-${i + 1} pada tabel "$table" bukan objek data yang valid.',
          );
        }
      }
    }

    final santriList = data['santri'] as List;
    final setoranList = data['setoran_bulanan'] as List;
    final txList = data['transaksi_harian'] as List;
    final tunggakanList = data['tunggakan_log'] as List;
    final dompetList = data['mutasi_dompet'] as List;
    final opnameList = data['cash_opname_logs'] as List;
    final infakList = (data['infak_santri'] as List?) ?? const [];
    final serahTerimaList = (data['serah_terima_infak'] as List?) ?? const [];

    return BackupValidationResult(
      isValid: true,
      santriCount: santriList.length,
      setoranCount: setoranList.length,
      transaksiCount: txList.length,
      tunggakanLogCount: tunggakanList.length,
      mutasiDompetCount: dompetList.length,
      cashOpnameCount: opnameList.length,
      infakCount: infakList.length,
      serahTerimaInfakCount: serahTerimaList.length,
      exportedAt: data['exported_at']?.toString(),
      parsedData: data,
    );
  }

  static const String ksbakMagic = 'KSBAK1';
  static const int _pbkdf2Iterations = 60000;

  static bool isEncryptedKsbakBytes(List<int> bytes) {
    if (bytes.length > ksbakMagic.length) {
      final header = utf8.decode(bytes.sublist(0, ksbakMagic.length), allowMalformed: true);
      if (header == ksbakMagic) return true;
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map && decoded['format'] == ksbakMagic;
    } catch (_) {
      return false;
    }
  }

  static Future<SecretKey> _deriveBackupKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
  }

  /// Mengenkripsi payload JSON backup menggunakan PBKDF2-HMAC-SHA256 + AES-256-GCM
  /// menjadi format portabel `.ksbak` (UTF-8 JSON envelope terenkripsi) di background isolate.
  static Future<Uint8List> encryptBackupToKsbak({
    required Map<String, dynamic> backupData,
    required String password,
  }) async {
    if (password.trim().length < 4) {
      throw const FormatException('Password enkripsi backup minimal 4 karakter.');
    }
    return compute<Map<String, dynamic>, Uint8List>(
      _encryptBackupToKsbakIsolate,
      <String, dynamic>{
        'backupData': backupData,
        'password': password,
      },
    );
  }

  static Future<Uint8List> _encryptBackupToKsbakIsolate(
    Map<String, dynamic> request,
  ) async {
    final backupData = request['backupData'] as Map<String, dynamic>;
    final password = request['password'] as String;
    final rng = Random.secure();
    final salt = List<int>.generate(16, (_) => rng.nextInt(256));
    final key = await _deriveBackupKey(password, salt);

    final aesGcm = AesGcm.with256bits();
    final nonce = aesGcm.newNonce();
    final plainBytes = utf8.encode(jsonEncode(backupData));
    final secretBox = await aesGcm.encrypt(
      plainBytes,
      secretKey: key,
      nonce: nonce,
    );

    final envelope = <String, dynamic>{
      'format': ksbakMagic,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _pbkdf2Iterations,
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'ciphertext': base64Encode(secretBox.cipherText),
      'created_at': DateTime.now().toIso8601String(),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  /// Mendekripsi file `.ksbak` dengan password lalu memvalidasi struktur tabel Kas-Santri
  /// di background isolate agar UI tidak pernah freeze.
  static Future<BackupValidationResult> decryptAndValidateKsbak({
    required Uint8List bytes,
    required String password,
  }) async {
    if (password.isEmpty) {
      return BackupValidationResult.invalid('Password dekripsi wajib diisi.');
    }
    return compute<Map<String, dynamic>, BackupValidationResult>(
      _decryptAndValidateKsbakIsolate,
      <String, dynamic>{
        'bytes': bytes,
        'password': password,
      },
    );
  }

  static Future<BackupValidationResult> _decryptAndValidateKsbakIsolate(
    Map<String, dynamic> request,
  ) async {
    final bytes = request['bytes'] as Uint8List;
    final password = request['password'] as String;
    try {
      final rawStr = utf8.decode(bytes);
      final envelope = jsonDecode(rawStr);
      if (envelope is! Map || envelope['format'] != ksbakMagic) {
        return BackupValidationResult.invalid('Format file .ksbak tidak dikenali.');
      }

      final salt = base64Decode(envelope['salt'].toString());
      final nonce = base64Decode(envelope['nonce'].toString());
      final macBytes = base64Decode(envelope['mac'].toString());
      final cipherText = base64Decode(envelope['ciphertext'].toString());
      final iterations = (envelope['iterations'] as num?)?.toInt() ?? _pbkdf2Iterations;

      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      );
      final key = await pbkdf2.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );

      final aesGcm = AesGcm.with256bits();
      final clearBytes = await aesGcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: key,
      );
      final jsonStr = utf8.decode(clearBytes);
      return validateJsonString(jsonStr);
    } on SecretBoxAuthenticationError {
      return BackupValidationResult.invalid(
        'Password salah atau file backup .ksbak telah dimodifikasi/rusak.',
      );
    } catch (e) {
      return BackupValidationResult.invalid(
        'Gagal membuka file backup terenkripsi .ksbak ($e).',
      );
    }
  }
}
