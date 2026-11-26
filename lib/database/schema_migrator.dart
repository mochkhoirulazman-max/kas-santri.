import 'package:sqflite/sqflite.dart';
import '../models/santri.dart';

class SchemaMigrator {
  const SchemaMigrator();

  Future<void> configureDatabase(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<Set<String>> getExistingColumns(
    DatabaseExecutor db,
    String table,
  ) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return info.map((e) => e['name'].toString()).toSet();
    } catch (_) {
      return const <String>{};
    }
  }

  Future<void> addColumnIfNotExists(
    Database db,
    String table,
    String columnDef, {
    Set<String>? existingColumns,
  }) async {
    final colName = columnDef.trim().split(RegExp(r'\s+')).first;
    final cols = existingColumns ?? await getExistingColumns(db, table);
    if (cols.contains(colName)) return;
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDef;');
    } catch (_) {}
  }

  Future<void> ensureColumnsAndIndexes(Database db) async {
    final santriCols = await getExistingColumns(db, 'santri');
    await addColumnIfNotExists(
      db,
      'santri',
      'foto_path TEXT',
      existingColumns: santriCols,
    );
    await addColumnIfNotExists(
      db,
      'santri',
      'qr_code TEXT',
      existingColumns: santriCols,
    );
    await addColumnIfNotExists(
      db,
      'santri',
      "kategori_santri TEXT NOT NULL DEFAULT 'SANTRIYIN'",
      existingColumns: santriCols,
    );
    await addColumnIfNotExists(
      db,
      'santri',
      "status_santri TEXT NOT NULL DEFAULT 'AKTIF'",
      existingColumns: santriCols,
    );
    await addColumnIfNotExists(
      db,
      'santri',
      'saldo_tabungan INTEGER NOT NULL DEFAULT 0',
      existingColumns: santriCols,
    );

    final setoranCols = await getExistingColumns(db, 'setoran_bulanan');
    await addColumnIfNotExists(
      db,
      'setoran_bulanan',
      "metode_bayar TEXT NOT NULL DEFAULT 'TUNAI'",
      existingColumns: setoranCols,
    );
    await addColumnIfNotExists(
      db,
      'setoran_bulanan',
      'potong_tunggakan INTEGER NOT NULL DEFAULT 0',
      existingColumns: setoranCols,
    );
    await addColumnIfNotExists(
      db,
      'setoran_bulanan',
      'nominal_potong_tunggakan INTEGER NOT NULL DEFAULT 0',
      existingColumns: setoranCols,
    );

    final txCols = await getExistingColumns(db, 'transaksi_harian');
    await addColumnIfNotExists(
      db,
      'transaksi_harian',
      'is_void INTEGER NOT NULL DEFAULT 0',
      existingColumns: txCols,
    );
    await addColumnIfNotExists(
      db,
      'transaksi_harian',
      "sumber_dompet TEXT NOT NULL DEFAULT 'TUNAI'",
      existingColumns: txCols,
    );

    final pengCols = await getExistingColumns(db, 'pengaturan_aplikasi');
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'pembulatan_jatah INTEGER NOT NULL DEFAULT 500',
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'is_pro INTEGER NOT NULL DEFAULT 0',
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'pro_plan TEXT',
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'onboarding_done INTEGER NOT NULL DEFAULT 0',
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'last_drive_backup_at TEXT',
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'auto_drive_backup INTEGER NOT NULL DEFAULT 0',
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'drive_account_email TEXT',
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'trial_started_at TEXT',
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'trial_expires_at TEXT',
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'has_used_trial INTEGER NOT NULL DEFAULT 0',
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      "tahun_ajaran TEXT NOT NULL DEFAULT '2026/2027 M / 1448 H'",
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'default_infak_masak INTEGER NOT NULL DEFAULT 130000',
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'default_infak_listrik INTEGER NOT NULL DEFAULT 20000',
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'default_infak_beras_liter REAL NOT NULL DEFAULT 15.0',
      existingColumns: pengCols,
    );
    await addColumnIfNotExists(
      db,
      'pengaturan_aplikasi',
      'default_infak_beras_uang INTEGER NOT NULL DEFAULT 150000',
      existingColumns: pengCols,
    );

    await createV3InfakTablesAndIndexes(db);
    await createV33AuditTableAndIndex(db);
    await createV43TabunganTableAndIndex(db);

    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_santri_tgl ON transaksi_harian (santri_id, tanggal_lokal, is_void);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_santri_qr ON santri (qr_code);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mutasi_dompet_jenis_tipe ON mutasi_dompet (jenis_dompet, tipe);',
      );
    } catch (_) {}
    await backfillQrCodes(db);
  }

  Future<void> createV3InfakTablesAndIndexes(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS infak_santri (
        id TEXT PRIMARY KEY,
        santri_id TEXT NOT NULL,
        periode_bulan TEXT NOT NULL,
        tahun_ajaran TEXT NOT NULL DEFAULT '2026/2027 M / 1448 H',
        nominal_masak INTEGER NOT NULL DEFAULT 0,
        is_masak_bebas INTEGER NOT NULL DEFAULT 0,
        nominal_listrik INTEGER NOT NULL DEFAULT 0,
        is_listrik_bebas INTEGER NOT NULL DEFAULT 0,
        jenis_beras TEXT NOT NULL DEFAULT 'BELUM',
        beras_liter REAL NOT NULL DEFAULT 0.0,
        beras_uang INTEGER NOT NULL DEFAULT 0,
        tgl_masuk TEXT NOT NULL,
        tgl_habis TEXT NOT NULL,
        status_lunas TEXT NOT NULL DEFAULT 'BELUM',
        sumber_dompet TEXT NOT NULL DEFAULT 'TUNAI',
        setoran_id TEXT,
        catatan TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (santri_id) REFERENCES santri (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS serah_terima_infak (
        id TEXT PRIMARY KEY,
        tanggal_serah TEXT NOT NULL,
        periode_bulan TEXT NOT NULL,
        pos_infak TEXT NOT NULL DEFAULT 'GABUNGAN',
        sumber_dompet TEXT NOT NULL DEFAULT 'TUNAI',
        nominal_uang INTEGER NOT NULL DEFAULT 0,
        jumlah_beras_liter REAL NOT NULL DEFAULT 0.0,
        penerima TEXT NOT NULL,
        catatan TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_infak_periode_santri ON infak_santri (periode_bulan, santri_id);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_serah_terima_periode ON serah_terima_infak (periode_bulan, tanggal_serah);',
      );
    } catch (_) {}
  }

  Future<void> createV33AuditTableAndIndex(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        actor TEXT NOT NULL,
        action TEXT NOT NULL,
        target_id TEXT,
        summary TEXT NOT NULL,
        prev_hash TEXT NOT NULL,
        entry_hash TEXT NOT NULL
      )
    ''');
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_log_created ON audit_log (created_at);',
      );
    } catch (_) {}
  }

  Future<void> createV43TabunganTableAndIndex(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transaksi_tabungan (
        id TEXT PRIMARY KEY,
        santri_id TEXT NOT NULL,
        tipe TEXT NOT NULL,
        nominal INTEGER NOT NULL,
        sumber_dompet TEXT NOT NULL DEFAULT 'TUNAI',
        saldo_tabungan_setelah INTEGER NOT NULL DEFAULT 0,
        tanggal_lokal TEXT NOT NULL,
        catatan TEXT,
        is_void INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (santri_id) REFERENCES santri (id) ON DELETE CASCADE
      )
    ''');
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_tabungan_santri ON transaksi_tabungan (santri_id, tanggal_lokal, is_void);',
      );
    } catch (_) {}
  }

  Future<void> backfillQrCodes(Database db) async {
    try {
      final rows = await db.query(
        'santri',
        columns: ['id', 'qr_code'],
        where: "qr_code IS NULL OR TRIM(qr_code) = ''",
      );
      for (final row in rows) {
        final id = row['id'] as String?;
        if (id != null && id.isNotEmpty) {
          await db.update(
            'santri',
            {'qr_code': Santri.generateQrCode(id)},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    } catch (_) {}
  }

  Future<void> upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await addColumnIfNotExists(db, 'santri', 'foto_path TEXT');
      await addColumnIfNotExists(db, 'santri', 'qr_code TEXT');
      await addColumnIfNotExists(
        db,
        'setoran_bulanan',
        "metode_bayar TEXT NOT NULL DEFAULT 'TUNAI'",
      );
      await addColumnIfNotExists(
        db,
        'setoran_bulanan',
        'potong_tunggakan INTEGER NOT NULL DEFAULT 0',
      );
      await addColumnIfNotExists(
        db,
        'setoran_bulanan',
        'nominal_potong_tunggakan INTEGER NOT NULL DEFAULT 0',
      );

      await addColumnIfNotExists(
        db,
        'transaksi_harian',
        'is_void INTEGER NOT NULL DEFAULT 0',
      );
      await addColumnIfNotExists(
        db,
        'transaksi_harian',
        "sumber_dompet TEXT NOT NULL DEFAULT 'TUNAI'",
      );
      try {
        await db.execute(
          'UPDATE transaksi_harian SET is_void = is_voided WHERE is_voided IS NOT NULL;',
        );
      } catch (_) {}

      await db.execute('''
        CREATE TABLE IF NOT EXISTS tunggakan_log (
          id TEXT PRIMARY KEY,
          santri_id TEXT NOT NULL,
          tipe TEXT NOT NULL,
          nominal INTEGER NOT NULL,
          saldo_tunggakan_setelah INTEGER NOT NULL DEFAULT 0,
          catatan TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (santri_id) REFERENCES santri (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS mutasi_dompet (
          id TEXT PRIMARY KEY,
          jenis_dompet TEXT NOT NULL DEFAULT 'TUNAI',
          tipe TEXT NOT NULL,
          nominal INTEGER NOT NULL,
          referensi_id TEXT,
          catatan TEXT,
          tanggal_lokal TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS cash_opname_logs (
          id TEXT PRIMARY KEY,
          tanggal_lokal TEXT NOT NULL,
          total_sistem INTEGER NOT NULL DEFAULT 0,
          total_fisik INTEGER NOT NULL DEFAULT 0,
          selisih INTEGER NOT NULL DEFAULT 0,
          rincian_pecahan_json TEXT,
          catatan TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      await addColumnIfNotExists(
        db,
        'pengaturan_aplikasi',
        'pembulatan_jatah INTEGER NOT NULL DEFAULT 500',
      );
      await addColumnIfNotExists(
        db,
        'pengaturan_aplikasi',
        'is_pro INTEGER NOT NULL DEFAULT 0',
      );
      await addColumnIfNotExists(db, 'pengaturan_aplikasi', 'pro_plan TEXT');
      await addColumnIfNotExists(
        db,
        'pengaturan_aplikasi',
        'onboarding_done INTEGER NOT NULL DEFAULT 0',
      );
      await addColumnIfNotExists(
        db,
        'pengaturan_aplikasi',
        'last_drive_backup_at TEXT',
      );
      await addColumnIfNotExists(
        db,
        'pengaturan_aplikasi',
        'auto_drive_backup INTEGER NOT NULL DEFAULT 0',
      );
      await addColumnIfNotExists(
        db,
        'pengaturan_aplikasi',
        'drive_account_email TEXT',
      );

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_santri_tgl ON transaksi_harian (santri_id, tanggal_lokal, is_void);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tunggakan_log_santri ON tunggakan_log (santri_id);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mutasi_dompet_tanggal ON mutasi_dompet (tanggal_lokal);',
      );

      try {
        final existing = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM santri',
        );
        final count = (existing.first['cnt'] as num?)?.toInt() ?? 0;
        if (count > 0) {
          await db.execute(
            'UPDATE pengaturan_aplikasi SET onboarding_done = 1 WHERE id = 1;',
          );
        }
      } catch (_) {}
    }

    if (oldVersion < 3) {
      await addColumnIfNotExists(
        db,
        'santri',
        "kategori_santri TEXT NOT NULL DEFAULT 'SANTRIYIN'",
      );
      await addColumnIfNotExists(
        db,
        'santri',
        "status_santri TEXT NOT NULL DEFAULT 'AKTIF'",
      );
      await addColumnIfNotExists(
        db,
        'pengaturan_aplikasi',
        "tahun_ajaran TEXT NOT NULL DEFAULT '2026/2027 M / 1448 H'",
      );
      await addColumnIfNotExists(
        db,
        'pengaturan_aplikasi',
        'default_infak_masak INTEGER NOT NULL DEFAULT 130000',
      );
      await addColumnIfNotExists(
        db,
        'pengaturan_aplikasi',
        'default_infak_listrik INTEGER NOT NULL DEFAULT 20000',
      );
      await addColumnIfNotExists(
        db,
        'pengaturan_aplikasi',
        'default_infak_beras_liter REAL NOT NULL DEFAULT 15.0',
      );
      await addColumnIfNotExists(
        db,
        'pengaturan_aplikasi',
        'default_infak_beras_uang INTEGER NOT NULL DEFAULT 150000',
      );
      await createV3InfakTablesAndIndexes(db);
    }

    if (oldVersion < 4) {
      await createV33AuditTableAndIndex(db);
    }

    if (oldVersion < 5) {
      await addColumnIfNotExists(
        db,
        'santri',
        'saldo_tabungan INTEGER NOT NULL DEFAULT 0',
      );
      await createV43TabunganTableAndIndex(db);
    }
  }

  Future<void> createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE santri (
        id TEXT PRIMARY KEY,
        nama_lengkap TEXT NOT NULL,
        nama_panggilan TEXT,
        kategori_santri TEXT NOT NULL DEFAULT 'SANTRIYIN',
        status_santri TEXT NOT NULL DEFAULT 'AKTIF',
        kamar TEXT NOT NULL,
        no_wa_wali TEXT,
        saldo_total INTEGER NOT NULL DEFAULT 0,
        saldo_tabungan INTEGER NOT NULL DEFAULT 0,
        jatah_harian INTEGER NOT NULL DEFAULT 10000,
        setoran_awal INTEGER NOT NULL DEFAULT 300000,
        tunggakan INTEGER NOT NULL DEFAULT 0,
        catatan_tunggakan TEXT DEFAULT '',
        foto_path TEXT,
        qr_code TEXT,
        status_aktif INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE setoran_bulanan (
        id TEXT PRIMARY KEY,
        santri_id TEXT NOT NULL,
        nominal_setoran INTEGER NOT NULL,
        durasi_hari INTEGER NOT NULL,
        jatah_harian_hitung INTEGER NOT NULL,
        tipe_setoran TEXT NOT NULL,
        tanggal_setor TEXT NOT NULL,
        catatan TEXT,
        perlakuan_sisa TEXT,
        metode_bayar TEXT NOT NULL DEFAULT 'TUNAI',
        potong_tunggakan INTEGER NOT NULL DEFAULT 0,
        nominal_potong_tunggakan INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (santri_id) REFERENCES santri (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE transaksi_harian (
        id TEXT PRIMARY KEY,
        santri_id TEXT NOT NULL,
        nominal INTEGER NOT NULL,
        waktu_ambil TEXT NOT NULL,
        tanggal_lokal TEXT NOT NULL,
        kategori_waktu TEXT NOT NULL,
        is_overlimit INTEGER NOT NULL DEFAULT 0,
        catatan TEXT,
        is_void INTEGER NOT NULL DEFAULT 0,
        overlimit_handling TEXT,
        saldo_setelah_transaksi INTEGER NOT NULL DEFAULT 0,
        tipe TEXT NOT NULL DEFAULT 'PENGAMBILAN',
        sumber_dompet TEXT NOT NULL DEFAULT 'TUNAI',
        FOREIGN KEY (santri_id) REFERENCES santri (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tunggakan_log (
        id TEXT PRIMARY KEY,
        santri_id TEXT NOT NULL,
        tipe TEXT NOT NULL,
        nominal INTEGER NOT NULL,
        saldo_tunggakan_setelah INTEGER NOT NULL DEFAULT 0,
        catatan TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (santri_id) REFERENCES santri (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE mutasi_dompet (
        id TEXT PRIMARY KEY,
        jenis_dompet TEXT NOT NULL DEFAULT 'TUNAI',
        tipe TEXT NOT NULL,
        nominal INTEGER NOT NULL,
        referensi_id TEXT,
        catatan TEXT,
        tanggal_lokal TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cash_opname_logs (
        id TEXT PRIMARY KEY,
        tanggal_lokal TEXT NOT NULL,
        total_sistem INTEGER NOT NULL DEFAULT 0,
        total_fisik INTEGER NOT NULL DEFAULT 0,
        selisih INTEGER NOT NULL DEFAULT 0,
        rincian_pecahan_json TEXT,
        catatan TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pengaturan_aplikasi (
        id INTEGER PRIMARY KEY,
        nama_pondok TEXT NOT NULL,
        nama_pengurus TEXT NOT NULL,
        kontak_pengurus TEXT,
        default_jatah_harian INTEGER NOT NULL DEFAULT 10000,
        default_durasi_hari INTEGER NOT NULL DEFAULT 30,
        mode_sisa_harian TEXT NOT NULL DEFAULT 'KETAT',
        pin_keamanan TEXT,
        is_biometric_enabled INTEGER NOT NULL DEFAULT 0,
        auto_lock_minutes INTEGER NOT NULL DEFAULT 1,
        logo_path TEXT,
        is_two_col_grid INTEGER NOT NULL DEFAULT 1,
        hide_balance INTEGER NOT NULL DEFAULT 0,
        pembulatan_jatah INTEGER NOT NULL DEFAULT 500,
        is_pro INTEGER NOT NULL DEFAULT 0,
        pro_plan TEXT,
        onboarding_done INTEGER NOT NULL DEFAULT 0,
        last_drive_backup_at TEXT,
        auto_drive_backup INTEGER NOT NULL DEFAULT 0,
        drive_account_email TEXT,
        trial_started_at TEXT,
        trial_expires_at TEXT,
        has_used_trial INTEGER NOT NULL DEFAULT 0,
        tahun_ajaran TEXT NOT NULL DEFAULT '2026/2027 M / 1448 H',
        default_infak_masak INTEGER NOT NULL DEFAULT 130000,
        default_infak_listrik INTEGER NOT NULL DEFAULT 20000,
        default_infak_beras_liter REAL NOT NULL DEFAULT 15.0,
        default_infak_beras_uang INTEGER NOT NULL DEFAULT 150000
      )
    ''');

    await createV3InfakTablesAndIndexes(db);
    await createV33AuditTableAndIndex(db);
    await createV43TabunganTableAndIndex(db);

    await db.execute(
      'CREATE INDEX idx_tx_santri_tgl ON transaksi_harian (santri_id, tanggal_lokal, is_void);',
    );
    await db.execute(
      'CREATE INDEX idx_transaksi_tanggal ON transaksi_harian (tanggal_lokal);',
    );
    await db.execute(
      'CREATE INDEX idx_transaksi_waktu ON transaksi_harian (waktu_ambil);',
    );
    await db.execute(
      'CREATE INDEX idx_santri_kamar ON santri (kamar);',
    );
    await db.execute(
      'CREATE INDEX idx_santri_aktif ON santri (status_aktif);',
    );
    await db.execute(
      'CREATE INDEX idx_setoran_santri ON setoran_bulanan (santri_id);',
    );
    await db.execute(
      'CREATE INDEX idx_tunggakan_log_santri ON tunggakan_log (santri_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mutasi_dompet_tanggal ON mutasi_dompet (tanggal_lokal);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mutasi_dompet_jenis_tipe ON mutasi_dompet (jenis_dompet, tipe);',
    );

    await db.insert('pengaturan_aplikasi', {
      'id': 1,
      'nama_pondok': 'Nama Pondok',
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
      'is_pro': 0,
      'pro_plan': null,
      'onboarding_done': 0,
      'last_drive_backup_at': null,
      'auto_drive_backup': 0,
      'drive_account_email': null,
      'trial_started_at': null,
      'trial_expires_at': null,
      'has_used_trial': 0,
      'tahun_ajaran': '2026/2027 M / 1448 H',
      'default_infak_masak': 130000,
      'default_infak_listrik': 20000,
      'default_infak_beras_liter': 15.0,
      'default_infak_beras_uang': 150000,
    });
  }
}
