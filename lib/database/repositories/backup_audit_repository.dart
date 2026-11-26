import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/audit_log.dart';
import '../../models/pengaturan.dart';
import '../../models/santri.dart';
import '../../models/transaksi.dart';
import '../../services/backup_service.dart';
import '../../utils/date_formatter.dart';
import '../../utils/time_category_helper.dart';
import '../schema_migrator.dart';

class BackupAuditRepository {
  final Future<Database> Function() _getDb;
  final SchemaMigrator _migrator;

  const BackupAuditRepository(this._getDb, this._migrator);

  Future<Map<String, dynamic>> dumpBackupJson() async {
    final db = await _getDb();
    final santriList = await db.query('santri');
    final setoranList = await db.query('setoran_bulanan');
    final transaksiList = await db.query('transaksi_harian');
    final tunggakanLogList = await db.query('tunggakan_log');
    final mutasiDompetList = await db.query('mutasi_dompet');
    final cashOpnameList = await db.query('cash_opname_logs');
    final infakSantriList = await db.query('infak_santri');
    final serahTerimaInfakList = await db.query('serah_terima_infak');
    List<Map<String, Object?>> tabunganList = const [];
    try {
      tabunganList = await db.query('transaksi_tabungan');
    } catch (_) {}
    List<Map<String, Object?>> auditLogList = const [];
    try {
      auditLogList = await db.query(
        'audit_log',
        orderBy: 'created_at ASC, rowid ASC',
      );
    } catch (_) {}
    final pengaturanList = await db.query('pengaturan_aplikasi');

    return {
      'version': 33,
      'exported_at': DateTime.now().toIso8601String(),
      'santri': santriList,
      'setoran_bulanan': setoranList,
      'transaksi_harian': transaksiList,
      'tunggakan_log': tunggakanLogList,
      'mutasi_dompet': mutasiDompetList,
      'cash_opname_logs': cashOpnameList,
      'infak_santri': infakSantriList,
      'serah_terima_infak': serahTerimaInfakList,
      'transaksi_tabungan': tabunganList,
      'audit_log': auditLogList,
      'pengaturan_aplikasi': pengaturanList,
    };
  }

  Future<Set<String>> _getTableColumns(
    Transaction txn,
    String tableName,
  ) async {
    final info = await txn.rawQuery('PRAGMA table_info($tableName)');
    return info.map((e) => e['name'].toString()).toSet();
  }

  Map<String, dynamic> _filterRowColumns(
    Map<String, dynamic> row,
    Set<String> allowedCols,
  ) {
    final filtered = <String, dynamic>{};
    for (final entry in row.entries) {
      if (allowedCols.contains(entry.key)) {
        filtered[entry.key] = entry.value;
      }
    }
    return filtered;
  }

  Future<void> restoreFromJson(Map<String, dynamic> data) async {
    final validation = BackupService.validateBackupMap(data);
    if (!validation.isValid) {
      throw FormatException(
        validation.errorMessage ?? 'Struktur backup JSON tidak valid.',
      );
    }

    List<AuditLogEntry> verifiedAuditEntries = const [];
    if (data['audit_log'] is List && (data['audit_log'] as List).isNotEmpty) {
      verifiedAuditEntries = (data['audit_log'] as List)
          .whereType<Map>()
          .map((m) => AuditLogEntry.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      final chainCheck = AuditLogEntry.verifyChain(verifiedAuditEntries);
      if (!chainCheck.isValid) {
        throw FormatException(
          'Jejak Audit pada file backup tidak valid atau telah dimodifikasi (baris ke-${(chainCheck.brokenIndex ?? 0) + 1}). Pemulihan dibatalkan demi keamanan.',
        );
      }
    }

    final db = await _getDb();
    await db.transaction((txn) async {
      final origPengRows = await txn.query(
        'pengaturan_aplikasi',
        where: 'id = 1',
      );
      final origPeng = origPengRows.isNotEmpty ? origPengRows.first : null;
      final int origIsPro = (origPeng?['is_pro'] as num?)?.toInt() ?? 0;
      final Object? origProPlan = origPeng?['pro_plan'];
      final Object? origTrialStarted = origPeng?['trial_started_at'];
      final Object? origTrialExpires = origPeng?['trial_expires_at'];
      final int origHasUsedTrial =
          (origPeng?['has_used_trial'] as num?)?.toInt() ?? 0;

      try {
        await txn.delete('transaksi_tabungan');
      } catch (_) {}
      await txn.delete('infak_santri');
      await txn.delete('serah_terima_infak');
      await txn.delete('tunggakan_log');
      await txn.delete('mutasi_dompet');
      await txn.delete('cash_opname_logs');
      await txn.delete('transaksi_harian');
      await txn.delete('setoran_bulanan');
      await txn.delete('santri');
      await txn.delete('pengaturan_aplikasi');

      final santriCols = await _getTableColumns(txn, 'santri');
      for (var row in (data['santri'] as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = map['id']?.toString() ?? '';
        if (id.isNotEmpty &&
            (map['qr_code'] == null ||
                map['qr_code'].toString().trim().isEmpty)) {
          map['qr_code'] = Santri.generateQrCode(id);
        }
        await txn.insert(
          'santri',
          _filterRowColumns(map, santriCols),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final setoranCols = await _getTableColumns(txn, 'setoran_bulanan');
      for (var row in (data['setoran_bulanan'] as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        await txn.insert(
          'setoran_bulanan',
          _filterRowColumns(map, setoranCols),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final txCols = await _getTableColumns(txn, 'transaksi_harian');
      for (var row in (data['transaksi_harian'] as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        if (map.containsKey('is_voided') && !map.containsKey('is_void')) {
          map['is_void'] = map['is_voided'];
          map.remove('is_voided');
        }
        await txn.insert(
          'transaksi_harian',
          _filterRowColumns(map, txCols),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final tunggakanCols = await _getTableColumns(txn, 'tunggakan_log');
      for (var row in (data['tunggakan_log'] as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        await txn.insert(
          'tunggakan_log',
          _filterRowColumns(map, tunggakanCols),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final dompetCols = await _getTableColumns(txn, 'mutasi_dompet');
      for (var row in (data['mutasi_dompet'] as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        await txn.insert(
          'mutasi_dompet',
          _filterRowColumns(map, dompetCols),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final opnameCols = await _getTableColumns(txn, 'cash_opname_logs');
      for (var row in (data['cash_opname_logs'] as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        await txn.insert(
          'cash_opname_logs',
          _filterRowColumns(map, opnameCols),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (data['infak_santri'] is List) {
        final infakCols = await _getTableColumns(txn, 'infak_santri');
        for (var row in (data['infak_santri'] as List)) {
          final map = Map<String, dynamic>.from(row as Map);
          await txn.insert(
            'infak_santri',
            _filterRowColumns(map, infakCols),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      if (data['serah_terima_infak'] is List) {
        final serahCols = await _getTableColumns(txn, 'serah_terima_infak');
        for (var row in (data['serah_terima_infak'] as List)) {
          final map = Map<String, dynamic>.from(row as Map);
          await txn.insert(
            'serah_terima_infak',
            _filterRowColumns(map, serahCols),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      if (data['transaksi_tabungan'] is List) {
        final tabCols = await _getTableColumns(txn, 'transaksi_tabungan');
        if (tabCols.isNotEmpty) {
          for (var row in (data['transaksi_tabungan'] as List)) {
            final map = Map<String, dynamic>.from(row as Map);
            await txn.insert(
              'transaksi_tabungan',
              _filterRowColumns(map, tabCols),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }

      if (verifiedAuditEntries.isNotEmpty) {
        await txn.delete('audit_log');
        final auditCols = await _getTableColumns(txn, 'audit_log');
        for (final entry in verifiedAuditEntries) {
          await txn.insert(
            'audit_log',
            _filterRowColumns(entry.toMap(), auditCols),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      final pengCols = await _getTableColumns(txn, 'pengaturan_aplikasi');
      final pengList = data['pengaturan_aplikasi'] as List;
      if (pengList.isEmpty) {
        final fallbackMap = PengaturanAplikasi(onboardingDone: true).toMap();
        fallbackMap['is_pro'] = origIsPro;
        fallbackMap['pro_plan'] = origProPlan;
        fallbackMap['trial_started_at'] = origTrialStarted;
        fallbackMap['trial_expires_at'] = origTrialExpires;
        fallbackMap['has_used_trial'] = origHasUsedTrial;
        await txn.insert('pengaturan_aplikasi', fallbackMap);
      } else {
        for (var row in pengList) {
          final map = Map<String, dynamic>.from(row as Map);
          map['onboarding_done'] = map['onboarding_done'] ?? 1;
          map['is_pro'] = origIsPro;
          map['pro_plan'] = origProPlan;
          map['trial_started_at'] = origTrialStarted;
          map['trial_expires_at'] = origTrialExpires;
          final importedUsedTrial =
              (map['has_used_trial'] as num?)?.toInt() ?? 0;
          map['has_used_trial'] =
              (origHasUsedTrial == 1 || importedUsedTrial == 1) ? 1 : 0;
          await txn.insert(
            'pengaturan_aplikasi',
            _filterRowColumns(map, pengCols),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
    await _migrator.backfillQrCodes(db);
  }

  Future<void> resetToInitialDemoData(
    PengaturanAplikasi currentPengaturan,
  ) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      try {
        await txn.delete('transaksi_tabungan');
      } catch (_) {}
      await txn.delete('infak_santri');
      await txn.delete('serah_terima_infak');
      await txn.delete('tunggakan_log');
      await txn.delete('mutasi_dompet');
      await txn.delete('cash_opname_logs');
      await txn.delete('transaksi_harian');
      await txn.delete('setoran_bulanan');
      await txn.delete('santri');
      await txn.delete('pengaturan_aplikasi');
    });

    await db.insert('pengaturan_aplikasi', {
      'id': 1,
      'nama_pondok': currentPengaturan.namaPondok.trim().isNotEmpty
          ? currentPengaturan.namaPondok.trim()
          : 'Nama Pondok',
      'nama_pengurus': 'Pengurus Kas & Keuangan',
      'kontak_pengurus': '081234567890',
      'default_jatah_harian': 10000,
      'default_durasi_hari': 30,
      'mode_sisa_harian': 'KETAT',
      'pin_keamanan': null,
      'is_biometric_enabled': 0,
      'auto_lock_minutes': 1,
      'logo_path': null,
      'is_two_col_grid': 1,
      'hide_balance': 0,
      'pembulatan_jatah': 500,
      'is_pro': currentPengaturan.isPro ? 1 : 0,
      'pro_plan': currentPengaturan.proPlan,
      'onboarding_done': 1,
      'last_drive_backup_at': currentPengaturan.lastDriveBackupAt,
      'auto_drive_backup': currentPengaturan.autoDriveBackup ? 1 : 0,
      'drive_account_email': currentPengaturan.driveAccountEmail,
      'trial_started_at': currentPengaturan.trialStartedAt,
      'trial_expires_at': currentPengaturan.trialExpiresAt,
      'has_used_trial': currentPengaturan.hasUsedTrial ? 1 : 0,
      'tahun_ajaran': currentPengaturan.tahunAjaran,
      'default_infak_masak': currentPengaturan.defaultInfakMasak,
      'default_infak_listrik': currentPengaturan.defaultInfakListrik,
      'default_infak_beras_liter': currentPengaturan.defaultInfakBerasLiter,
      'default_infak_beras_uang': currentPengaturan.defaultInfakBerasUang,
    });

    await seedDemoData(force: true);
  }

  Future<void> seedDemoData({bool force = false}) async {
    final db = await _getDb();
    if (!force) {
      final existing = await db.query('santri');
      if (existing.isNotEmpty) return;
    }

    final santriDemo = [
      Santri(
        id: 's1',
        namaLengkap: 'Ahmad Fauzi',
        namaPanggilan: 'Ahmad',
        kamar: 'Kamar 1',
        noWaWali: '628123456701',
        saldoTotal: 243000,
        jatahHarian: 10000,
        setoranAwal: 300000,
        tunggakan: 50000,
        catatanTunggakan: 'Kurang Setoran Bulanan',
      ),
      Santri(
        id: 's2',
        namaLengkap: 'Zaidan Alfarizi',
        namaPanggilan: 'Zaidan',
        kamar: 'Kamar 1',
        noWaWali: '628123456702',
        saldoTotal: 280000,
        jatahHarian: 10000,
        setoranAwal: 300000,
        tunggakan: 0,
        catatanTunggakan: '',
      ),
      Santri(
        id: 's3',
        namaLengkap: 'M. Rizky Pratama',
        namaPanggilan: 'Rizky',
        kamar: 'Kamar 2',
        noWaWali: '628123456703',
        saldoTotal: 190000,
        jatahHarian: 10000,
        setoranAwal: 300000,
        tunggakan: 120000,
        catatanTunggakan: 'Tunggakan Syahriyah & Kasbon Obat',
      ),
      Santri(
        id: 's4',
        namaLengkap: 'Bilal Ramadhan',
        namaPanggilan: 'Bilal',
        kamar: 'Kamar 2',
        noWaWali: '628123456704',
        saldoTotal: 387000,
        jatahHarian: 15000,
        setoranAwal: 450000,
        tunggakan: 0,
        catatanTunggakan: '',
      ),
      Santri(
        id: 's5',
        namaLengkap: 'Naufal Syauqi',
        namaPanggilan: 'Naufal',
        kamar: 'Kamar 3',
        noWaWali: '628123456705',
        saldoTotal: 266000,
        jatahHarian: 10000,
        setoranAwal: 300000,
        tunggakan: 75000,
        catatanTunggakan: 'Belum Lunas Uang Makan',
      ),
      Santri(
        id: 's6',
        namaLengkap: 'Farhan Maulana',
        namaPanggilan: 'Farhan',
        kamar: 'Kamar 3',
        noWaWali: '628123456706',
        saldoTotal: 300000,
        jatahHarian: 10000,
        setoranAwal: 300000,
        tunggakan: 0,
        catatanTunggakan: '',
      ),
    ];

    for (var s in santriDemo) {
      await db.insert(
        'santri',
        s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final today = DateFormatter.toLocalDateString(DateTime.now());
    final now = DateTime.now();

    final demoTxs = [
      TransaksiHarian(
        id: 'tx_demo_1',
        santriId: 's1',
        nominal: 2000,
        waktuAmbil: DateTime(now.year, now.month, now.day, 7, 15),
        tanggalLokal: today,
        kategoriWaktu: TimeCategory.pagi,
        catatan: 'Jajan Pagi / Sarapan',
        saldoSetelahTransaksi: 248000,
      ),
      TransaksiHarian(
        id: 'tx_demo_2',
        santriId: 's1',
        nominal: 5000,
        waktuAmbil: DateTime(now.year, now.month, now.day, 12, 40),
        tanggalLokal: today,
        kategoriWaktu: TimeCategory.siang,
        catatan: 'Jajan Siang',
        saldoSetelahTransaksi: 243000,
      ),
      TransaksiHarian(
        id: 'tx_demo_3',
        santriId: 's3',
        nominal: 5000,
        waktuAmbil: DateTime(now.year, now.month, now.day, 7, 30),
        tanggalLokal: today,
        kategoriWaktu: TimeCategory.pagi,
        catatan: 'Jajan Harian',
        saldoSetelahTransaksi: 195000,
      ),
      TransaksiHarian(
        id: 'tx_demo_4',
        santriId: 's3',
        nominal: 5000,
        waktuAmbil: DateTime(now.year, now.month, now.day, 13, 10),
        tanggalLokal: today,
        kategoriWaktu: TimeCategory.siang,
        catatan: 'Beli Sabun/Cuci',
        saldoSetelahTransaksi: 190000,
      ),
      TransaksiHarian(
        id: 'tx_demo_5',
        santriId: 's4',
        nominal: 3000,
        waktuAmbil: DateTime(now.year, now.month, now.day, 8, 0),
        tanggalLokal: today,
        kategoriWaktu: TimeCategory.pagi,
        catatan: 'Jajan Harian',
        saldoSetelahTransaksi: 387000,
      ),
      TransaksiHarian(
        id: 'tx_demo_6',
        santriId: 's5',
        nominal: 4000,
        waktuAmbil: DateTime(now.year, now.month, now.day, 9, 20),
        tanggalLokal: today,
        kategoriWaktu: TimeCategory.pagi,
        catatan: 'Jajan Harian',
        saldoSetelahTransaksi: 266000,
      ),
    ];

    for (var tx in demoTxs) {
      await db.insert(
        'transaksi_harian',
        tx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await db.delete('mutasi_dompet');
    await db.insert('mutasi_dompet', {
      'id': 'dompet_demo_tunai',
      'jenis_dompet': 'TUNAI',
      'tipe': 'MASUK',
      'nominal': 666000,
      'referensi_id': 'SEED',
      'catatan': 'Saldo Awal Kas Laci Tunai',
      'tanggal_lokal': today,
      'created_at': now.toIso8601String(),
    });
    await db.insert('mutasi_dompet', {
      'id': 'dompet_demo_rekening',
      'jenis_dompet': 'REKENING',
      'tipe': 'MASUK',
      'nominal': 1000000,
      'referensi_id': 'SEED',
      'catatan': 'Saldo Awal Rekening Bank (BSI/BRI)',
      'tanggal_lokal': today,
      'created_at': now.toIso8601String(),
    });
  }

  Future<AuditLogEntry> insertAuditLog({
    required String actor,
    required String action,
    String? targetId,
    required String summary,
    DateTime? timestamp,
  }) async {
    final db = await _getDb();
    return db.transaction((txn) async {
      final latestRows = await txn.query(
        'audit_log',
        columns: ['entry_hash'],
        orderBy: 'created_at DESC, rowid DESC',
        limit: 1,
      );
      final prevHash = latestRows.isNotEmpty
          ? (latestRows.first['entry_hash']?.toString() ??
              AuditLogEntry.genesisHash)
          : AuditLogEntry.genesisHash;

      final id = const Uuid().v4();
      final createdAt = (timestamp ?? DateTime.now()).toIso8601String();
      final cleanActor = actor.trim().isNotEmpty ? actor.trim() : 'Bendahara';
      final cleanAction = action.trim().toUpperCase();
      final entryHash = AuditLogEntry.computeChainHash(
        id: id,
        createdAt: createdAt,
        actor: cleanActor,
        action: cleanAction,
        targetId: targetId,
        summary: summary,
        prevHash: prevHash,
      );

      final entry = AuditLogEntry(
        id: id,
        createdAt: createdAt,
        actor: cleanActor,
        action: cleanAction,
        targetId: targetId,
        summary: summary,
        prevHash: prevHash,
        entryHash: entryHash,
      );

      await txn.insert('audit_log', entry.toMap());
      return entry;
    });
  }

  Future<List<AuditLogEntry>> getAuditLogs({
    int limit = 200,
    String? actionFilter,
  }) async {
    final db = await _getDb();
    final rows = await db.query(
      'audit_log',
      where: (actionFilter != null && actionFilter.trim().isNotEmpty)
          ? 'action = ?'
          : null,
      whereArgs: (actionFilter != null && actionFilter.trim().isNotEmpty)
          ? [actionFilter.trim().toUpperCase()]
          : null,
      orderBy: 'created_at DESC, rowid DESC',
      limit: limit,
    );
    return rows.map(AuditLogEntry.fromMap).toList();
  }

  Future<AuditLogVerificationResult> verifyAuditLogIntegrity() async {
    final db = await _getDb();
    final rows = await db.query(
      'audit_log',
      orderBy: 'created_at ASC, rowid ASC',
    );
    final entries = rows.map(AuditLogEntry.fromMap).toList();
    return AuditLogEntry.verifyChain(entries);
  }
}
