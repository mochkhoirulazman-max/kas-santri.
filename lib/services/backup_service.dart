import 'dart:convert';

class BackupValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int santriCount;
  final int setoranCount;
  final int transaksiCount;
  final int tunggakanLogCount;
  final int mutasiDompetCount;
  final int cashOpnameCount;
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

    final santriList = data['santri'] as List;
    final setoranList = data['setoran_bulanan'] as List;
    final txList = data['transaksi_harian'] as List;
    final tunggakanList = data['tunggakan_log'] as List;
    final dompetList = data['mutasi_dompet'] as List;
    final opnameList = data['cash_opname_logs'] as List;

    return BackupValidationResult(
      isValid: true,
      santriCount: santriList.length,
      setoranCount: setoranList.length,
      transaksiCount: txList.length,
      tunggakanLogCount: tunggakanList.length,
      mutasiDompetCount: dompetList.length,
      cashOpnameCount: opnameList.length,
      exportedAt: data['exported_at']?.toString(),
      parsedData: data,
    );
  }
}
