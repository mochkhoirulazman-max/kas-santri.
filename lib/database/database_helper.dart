import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/santri.dart';
import '../models/setoran.dart';
import '../models/transaksi.dart';
import '../models/pengaturan.dart';
import '../models/cash_opname_log.dart';
import '../models/infak_santri.dart';
import '../models/serah_terima_infak.dart';
import '../models/audit_log.dart';
import '../utils/time_category_helper.dart';
import '../utils/date_formatter.dart';
import '../utils/currency_formatter.dart';
import '../services/backup_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kas_santri_v2.db');
    return _database!;
  }

  void setDatabaseForTesting(Database? db) {
    _database = db;
  }

  Future<void> createSchemaForTesting(Database db) => _createDB(db, 4);

  Future<void> upgradeSchemaForTesting(Database db, int oldVersion, int newVersion) =>
      _upgradeDB(db, oldVersion, newVersion);

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: (db) async {
        await _ensureColumnsAndIndexes(db);
      },
    );
  }

  Future<Set<String>> _getExistingColumns(DatabaseExecutor db, String table) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return info.map((e) => e['name'].toString()).toSet();
    } catch (_) {
      return const <String>{};
    }
  }

  Future<void> _addColumnIfNotExists(
    Database db,
    String table,
    String columnDef, {
    Set<String>? existingColumns,
  }) async {
    final colName = columnDef.trim().split(RegExp(r'\s+')).first;
    final cols = existingColumns ?? await _getExistingColumns(db, table);
    if (cols.contains(colName)) return;
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDef;');
    } catch (_) {}
  }

  Future<void> _ensureColumnsAndIndexes(Database db) async {
    final santriCols = await _getExistingColumns(db, 'santri');
    await _addColumnIfNotExists(db, 'santri', 'foto_path TEXT', existingColumns: santriCols);
    await _addColumnIfNotExists(db, 'santri', 'qr_code TEXT', existingColumns: santriCols);
    await _addColumnIfNotExists(db, 'santri', "kategori_santri TEXT NOT NULL DEFAULT 'SANTRIYIN'", existingColumns: santriCols);
    await _addColumnIfNotExists(db, 'santri', "status_santri TEXT NOT NULL DEFAULT 'AKTIF'", existingColumns: santriCols);

    final setoranCols = await _getExistingColumns(db, 'setoran_bulanan');
    await _addColumnIfNotExists(db, 'setoran_bulanan', "metode_bayar TEXT NOT NULL DEFAULT 'TUNAI'", existingColumns: setoranCols);
    await _addColumnIfNotExists(db, 'setoran_bulanan', 'potong_tunggakan INTEGER NOT NULL DEFAULT 0', existingColumns: setoranCols);
    await _addColumnIfNotExists(db, 'setoran_bulanan', 'nominal_potong_tunggakan INTEGER NOT NULL DEFAULT 0', existingColumns: setoranCols);

    final txCols = await _getExistingColumns(db, 'transaksi_harian');
    await _addColumnIfNotExists(db, 'transaksi_harian', 'is_void INTEGER NOT NULL DEFAULT 0', existingColumns: txCols);
    await _addColumnIfNotExists(db, 'transaksi_harian', "sumber_dompet TEXT NOT NULL DEFAULT 'TUNAI'", existingColumns: txCols);

    final pengCols = await _getExistingColumns(db, 'pengaturan_aplikasi');
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'pembulatan_jatah INTEGER NOT NULL DEFAULT 500', existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'is_pro INTEGER NOT NULL DEFAULT 0', existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'pro_plan TEXT', existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'onboarding_done INTEGER NOT NULL DEFAULT 0', existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'last_drive_backup_at TEXT', existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'auto_drive_backup INTEGER NOT NULL DEFAULT 0', existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'drive_account_email TEXT', existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'trial_started_at TEXT', existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'trial_expires_at TEXT', existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'has_used_trial INTEGER NOT NULL DEFAULT 0', existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', "tahun_ajaran TEXT NOT NULL DEFAULT '2026/2027 M / 1448 H'", existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'default_infak_masak INTEGER NOT NULL DEFAULT 130000', existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'default_infak_listrik INTEGER NOT NULL DEFAULT 20000', existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'default_infak_beras_liter REAL NOT NULL DEFAULT 15.0', existingColumns: pengCols);
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'default_infak_beras_uang INTEGER NOT NULL DEFAULT 150000', existingColumns: pengCols);

    await _createV3InfakTablesAndIndexes(db);
    await _createV33AuditTableAndIndex(db);

    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_santri_tgl ON transaksi_harian (santri_id, tanggal_lokal, is_void);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_santri_qr ON santri (qr_code);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_mutasi_dompet_jenis_tipe ON mutasi_dompet (jenis_dompet, tipe);');
    } catch (_) {}
    await _backfillQrCodes(db);
  }

  Future<void> _createV3InfakTablesAndIndexes(Database db) async {
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_infak_periode_santri ON infak_santri (periode_bulan, santri_id);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_serah_terima_periode ON serah_terima_infak (periode_bulan, tanggal_serah);');
    } catch (_) {}
  }

  Future<void> _createV33AuditTableAndIndex(Database db) async {
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_audit_log_created ON audit_log (created_at);');
    } catch (_) {}
  }

  Future<void> _backfillQrCodes(Database db) async {
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

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfNotExists(db, 'santri', 'foto_path TEXT');
      await _addColumnIfNotExists(db, 'santri', 'qr_code TEXT');
      await _addColumnIfNotExists(db, 'setoran_bulanan', "metode_bayar TEXT NOT NULL DEFAULT 'TUNAI'");
      await _addColumnIfNotExists(db, 'setoran_bulanan', 'potong_tunggakan INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfNotExists(db, 'setoran_bulanan', 'nominal_potong_tunggakan INTEGER NOT NULL DEFAULT 0');

      await _addColumnIfNotExists(db, 'transaksi_harian', 'is_void INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfNotExists(db, 'transaksi_harian', "sumber_dompet TEXT NOT NULL DEFAULT 'TUNAI'");
      try {
        await db.execute('UPDATE transaksi_harian SET is_void = is_voided WHERE is_voided IS NOT NULL;');
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

      await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'pembulatan_jatah INTEGER NOT NULL DEFAULT 500');
      await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'is_pro INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'pro_plan TEXT');
      await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'onboarding_done INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'last_drive_backup_at TEXT');
      await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'auto_drive_backup INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'drive_account_email TEXT');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_santri_tgl ON transaksi_harian (santri_id, tanggal_lokal, is_void);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tunggakan_log_santri ON tunggakan_log (santri_id);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_mutasi_dompet_tanggal ON mutasi_dompet (tanggal_lokal);');

      // Jika pengguna sudah memiliki data santri dari v1, langsung tandai onboarding selesai
      try {
        final existing = await db.rawQuery('SELECT COUNT(*) as cnt FROM santri');
        final count = (existing.first['cnt'] as num?)?.toInt() ?? 0;
        if (count > 0) {
          await db.execute('UPDATE pengaturan_aplikasi SET onboarding_done = 1 WHERE id = 1;');
        }
      } catch (_) {}
    }

    if (oldVersion < 3) {
      await _addColumnIfNotExists(db, 'santri', "kategori_santri TEXT NOT NULL DEFAULT 'SANTRIYIN'");
      await _addColumnIfNotExists(db, 'santri', "status_santri TEXT NOT NULL DEFAULT 'AKTIF'");
      await _addColumnIfNotExists(db, 'pengaturan_aplikasi', "tahun_ajaran TEXT NOT NULL DEFAULT '2026/2027 M / 1448 H'");
      await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'default_infak_masak INTEGER NOT NULL DEFAULT 130000');
      await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'default_infak_listrik INTEGER NOT NULL DEFAULT 20000');
      await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'default_infak_beras_liter REAL NOT NULL DEFAULT 15.0');
      await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'default_infak_beras_uang INTEGER NOT NULL DEFAULT 150000');
      await _createV3InfakTablesAndIndexes(db);
    }

    if (oldVersion < 4) {
      await _createV33AuditTableAndIndex(db);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Tabel santri
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

    // 2. Tabel setoran_bulanan
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

    // 3. Tabel transaksi_harian
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

    // 4. Tabel tunggakan_log
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

    // 5. Tabel mutasi_dompet
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

    // 6. Tabel cash_opname_logs
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

    // 7. Tabel pengaturan_aplikasi (Singleton id = 1)
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

    await _createV3InfakTablesAndIndexes(db);
    await _createV33AuditTableAndIndex(db);

    // Composite & supporting indexes untuk performa query < 100ms
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

    // Inisialisasi data pengaturan bawaan
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

  // ==================== SANTRI OPERATIONS ====================

  Future<List<Santri>> getAllSantri({bool onlyActive = true}) async {
    final db = await database;
    final where = onlyActive ? 'status_aktif = 1' : null;
    final maps = await db.query(
      'santri',
      where: where,
      orderBy: 'kamar ASC, nama_lengkap ASC',
    );
    return maps.map((m) => Santri.fromMap(m)).toList();
  }

  Future<Santri?> getSantriById(String id) async {
    final db = await database;
    final maps = await db.query('santri', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Santri.fromMap(maps.first);
    }
    return null;
  }

  String _normalizeDompet(String raw) {
    final upper = raw.toUpperCase().trim();
    if (upper == 'REKENING' || upper == 'BANK' || upper == 'TRANSFER') {
      return 'REKENING';
    }
    return 'TUNAI';
  }

  Future<int> insertSantri(Santri santri, {String sumberDompet = 'TUNAI'}) async {
    final db = await database;
    final dompet = _normalizeDompet(sumberDompet);
    await db.transaction((txn) async {
      await txn.insert('santri', santri.toMap());
      if (santri.saldoTotal > 0) {
        final now = DateTime.now();
        await txn.insert('mutasi_dompet', {
          'id': const Uuid().v4(),
          'jenis_dompet': dompet,
          'tipe': 'MASUK',
          'nominal': santri.saldoTotal,
          'referensi_id': santri.id,
          'catatan': 'Saldo Awal ${santri.namaLengkap}',
          'tanggal_lokal': DateFormatter.toLocalDateString(now),
          'created_at': now.toIso8601String(),
        });
      }
    });
    return 1;
  }

  Future<int> updateSantri(Santri santri) async {
    final db = await database;
    return await db.update(
      'santri',
      santri.toMap(),
      where: 'id = ?',
      whereArgs: [santri.id],
    );
  }

  Future<void> updateSantriFoto(String santriId, String? fotoPath) async {
    final db = await database;
    await db.update(
      'santri',
      {'foto_path': fotoPath},
      where: 'id = ?',
      whereArgs: [santriId],
    );
  }

  Future<void> quickUpdateSantri(
    String santriId, {
    required String namaLengkap,
    required String namaPanggilan,
    required String kamar,
    String? noWaWali,
    required int jatahHarian,
  }) async {
    final db = await database;
    await db.update(
      'santri',
      {
        'nama_lengkap': namaLengkap,
        'nama_panggilan': namaPanggilan,
        'kamar': kamar,
        'no_wa_wali': noWaWali,
        'jatah_harian': jatahHarian,
      },
      where: 'id = ?',
      whereArgs: [santriId],
    );
  }

  Future<void> toggleSantriStatus(String id, bool active) async {
    final db = await database;
    await db.update(
      'santri',
      {'status_aktif': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSantri(
    String santriId, {
    String sumberDompet = 'TUNAI',
  }) async {
    final db = await database;
    final dompet = _normalizeDompet(sumberDompet);
    int refundedSaldo = 0;
    await db.transaction((txn) async {
      final santriMaps = await txn.query(
        'santri',
        where: 'id = ?',
        whereArgs: [santriId],
      );
      if (santriMaps.isNotEmpty) {
        final santri = Santri.fromMap(santriMaps.first);
        if (santri.saldoTotal > 0) {
          refundedSaldo = santri.saldoTotal;
          final now = DateTime.now();
          await txn.insert('mutasi_dompet', {
            'id': const Uuid().v4(),
            'jenis_dompet': dompet,
            'tipe': 'KELUAR',
            'nominal': refundedSaldo,
            'referensi_id': santriId,
            'catatan':
                'Pengembalian/Penghapusan Saldo Santri ${santri.namaLengkap}',
            'tanggal_lokal': DateFormatter.toLocalDateString(now),
            'created_at': now.toIso8601String(),
          });
        }
      }
      await txn.delete('infak_santri', where: 'santri_id = ?', whereArgs: [santriId]);
      await txn.delete('tunggakan_log', where: 'santri_id = ?', whereArgs: [santriId]);
      await txn.delete('transaksi_harian', where: 'santri_id = ?', whereArgs: [santriId]);
      await txn.delete('setoran_bulanan', where: 'santri_id = ?', whereArgs: [santriId]);
      await txn.delete('santri', where: 'id = ?', whereArgs: [santriId]);
    });
    return refundedSaldo;
  }

  Future<List<String>> getAllKamars() async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT DISTINCT kamar FROM santri ORDER BY kamar ASC',
    );
    return maps.map((m) => m['kamar'] as String).toList();
  }

  // ==================== TUNGGAKAN OPERATIONS ====================

  Future<void> kelolaTunggakan({
    required String santriId,
    required int nominal,
    required String catatan,
    required bool isBayar,
    String sumberDompet = 'TUNAI',
  }) async {
    final db = await database;
    final dompet = _normalizeDompet(sumberDompet);
    await db.transaction((txn) async {
      final santriMaps = await txn.query('santri', where: 'id = ?', whereArgs: [santriId]);
      if (santriMaps.isEmpty) return;

      final santri = Santri.fromMap(santriMaps.first);
      int newTunggakan = santri.tunggakan;
      String newCatatan = santri.catatanTunggakan;

      if (isBayar) {
        newTunggakan = (santri.tunggakan - nominal);
        if (newTunggakan < 0) newTunggakan = 0;
        if (newTunggakan == 0) {
          newCatatan = '';
        } else if (catatan.trim().isNotEmpty) {
          newCatatan = catatan.trim();
        }
      } else {
        newTunggakan = santri.tunggakan + nominal;
        if (catatan.trim().isNotEmpty) {
          newCatatan = catatan.trim();
        } else if (newCatatan.isEmpty) {
          newCatatan = 'Tunggakan Kasbon / Pondok';
        }
      }

      await txn.update(
        'santri',
        {
          'tunggakan': newTunggakan,
          'catatan_tunggakan': newCatatan,
        },
        where: 'id = ?',
        whereArgs: [santriId],
      );

      final now = DateTime.now();
      await txn.insert('tunggakan_log', {
        'id': const Uuid().v4(),
        'santri_id': santriId,
        'tipe': isBayar ? 'BAYAR' : 'TAMBAH',
        'nominal': nominal,
        'saldo_tunggakan_setelah': newTunggakan,
        'catatan': catatan.trim().isNotEmpty ? catatan.trim() : newCatatan,
        'created_at': now.toIso8601String(),
      });

      if (isBayar && nominal > 0) {
        await txn.insert('mutasi_dompet', {
          'id': const Uuid().v4(),
          'jenis_dompet': dompet,
          'tipe': 'MASUK',
          'nominal': nominal,
          'referensi_id': santriId,
          'catatan': 'Pelunasan Tunggakan ${santri.namaLengkap}',
          'tanggal_lokal': DateFormatter.toLocalDateString(now),
          'created_at': now.toIso8601String(),
        });
      }
    });
  }

  Future<int> getTotalTunggakanPondok() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(tunggakan) as total FROM santri WHERE status_aktif = 1',
    );
    final total = result.first['total'];
    return (total as num?)?.toInt() ?? 0;
  }

  Future<int> getCountSantriTunggakan() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM santri WHERE tunggakan > 0 AND status_aktif = 1',
    );
    final count = result.first['count'];
    return (count as num?)?.toInt() ?? 0;
  }

  // ==================== SETORAN OPERATIONS (FASE 3) ====================

  Future<SetoranBulanan> catatSetoranBaru({
    required String santriId,
    required int nominalSetoran,
    required int durasiHari,
    required int jatahHarianHitung,
    required TipeSetoran tipeSetoran,
    required DateTime tanggalSetor,
    String? catatan,
    PerlakuanSisaSaldoLalu perlakuanSisa = PerlakuanSisaSaldoLalu.gabungBulanBaru,
    OpsiSetoranSusulan? opsiSusulan,
    bool potongTunggakan = true,
    String metodeBayar = 'TUNAI',
  }) async {
    final db = await database;
    final setoranId = const Uuid().v4();
    final transaksiId = const Uuid().v4();

    SetoranBulanan setoran = SetoranBulanan(
      id: setoranId,
      santriId: santriId,
      nominalSetoran: nominalSetoran,
      durasiHari: durasiHari,
      jatahHarianHitung: jatahHarianHitung,
      tipeSetoran: tipeSetoran,
      tanggalSetor: tanggalSetor,
      catatan: catatan,
      perlakuanSisa: perlakuanSisa,
    );

    await db.transaction((txn) async {
      final pengaturanMaps = await txn.query('pengaturan_aplikasi', where: 'id = 1');
      final kelipatanPembulatan = pengaturanMaps.isNotEmpty
          ? ((pengaturanMaps.first['pembulatan_jatah'] as num?)?.toInt() ?? 500)
          : 500;

      final santriMaps = await txn.query('santri', where: 'id = ?', whereArgs: [santriId]);
      if (santriMaps.isEmpty) throw Exception('Santri tidak ditemukan');
      final currentSantri = Santri.fromMap(santriMaps.first);

      int sisaSetoranMasukSaldo = nominalSetoran;
      int tunggakanBaru = currentSantri.tunggakan;
      String catatanTunggakanBaru = currentSantri.catatanTunggakan;
      int saldoBaru = currentSantri.saldoTotal;
      int jatahBaru = currentSantri.jatahHarian;
      int nominalPotongTunggakan = 0;
      String logPotongTunggakan = '';

      // Saklar opsional potong tunggakan dari setoran
      if (potongTunggakan && tunggakanBaru > 0) {
        if (sisaSetoranMasukSaldo >= tunggakanBaru) {
          nominalPotongTunggakan = tunggakanBaru;
          sisaSetoranMasukSaldo -= tunggakanBaru;
          tunggakanBaru = 0;
          catatanTunggakanBaru = '';
          logPotongTunggakan = ' (Potong Lunas Tunggakan ${CurrencyFormatter.format(nominalPotongTunggakan)})';
        } else {
          nominalPotongTunggakan = sisaSetoranMasukSaldo;
          tunggakanBaru -= sisaSetoranMasukSaldo;
          logPotongTunggakan = ' (Potong Cicil Tunggakan ${CurrencyFormatter.format(nominalPotongTunggakan)})';
          sisaSetoranMasukSaldo = 0;
        }

        await txn.insert('tunggakan_log', {
          'id': const Uuid().v4(),
          'santri_id': santriId,
          'tipe': 'POTONG_SETORAN',
          'nominal': nominalPotongTunggakan,
          'saldo_tunggakan_setelah': tunggakanBaru,
          'catatan': catatan ?? 'Potong otomatis dari setoran',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (tipeSetoran == TipeSetoran.awalBulan) {
        if (perlakuanSisa == PerlakuanSisaSaldoLalu.simpanTabungan) {
          saldoBaru = sisaSetoranMasukSaldo;
        } else {
          saldoBaru += sisaSetoranMasukSaldo;
        }
        if (durasiHari > 0 && sisaSetoranMasukSaldo > 0) {
          jatahBaru = CurrencyFormatter.hitungJatahHarianBulat(
            sisaSetoranMasukSaldo,
            durasiHari,
            kelipatan: kelipatanPembulatan,
          );
        } else if (sisaSetoranMasukSaldo == 0) {
          jatahBaru = currentSantri.jatahHarian;
        } else {
          jatahBaru = jatahHarianHitung;
        }
      } else {
        saldoBaru += sisaSetoranMasukSaldo;
        if (opsiSusulan == OpsiSetoranSusulan.tambahJatahHarian) {
          final tambahanJatah = durasiHari > 0
              ? CurrencyFormatter.hitungJatahHarianBulat(
                  sisaSetoranMasukSaldo,
                  durasiHari,
                  kelipatan: kelipatanPembulatan,
                )
              : 0;
          jatahBaru += tambahanJatah;
        } else if (opsiSusulan == null && durasiHari > 0 && sisaSetoranMasukSaldo > 0) {
          jatahBaru = CurrencyFormatter.hitungJatahHarianBulat(
            sisaSetoranMasukSaldo,
            durasiHari,
            kelipatan: kelipatanPembulatan,
          );
        }
      }

      final dompet = _normalizeDompet(metodeBayar);
      final setoranMap = setoran.toMap();
      setoranMap['jatah_harian_hitung'] = jatahBaru;
      setoranMap['metode_bayar'] = dompet;
      setoranMap['potong_tunggakan'] = (potongTunggakan && nominalPotongTunggakan > 0) ? 1 : 0;
      setoranMap['nominal_potong_tunggakan'] = nominalPotongTunggakan;
      await txn.insert('setoran_bulanan', setoranMap);

      await txn.update(
        'santri',
        {
          'saldo_total': saldoBaru,
          'jatah_harian': jatahBaru,
          'tunggakan': tunggakanBaru,
          'catatan_tunggakan': catatanTunggakanBaru,
        },
        where: 'id = ?',
        whereArgs: [santriId],
      );

      final now = DateTime.now();
      final tglStr = DateFormatter.toLocalDateString(tanggalSetor);
      final transaksiMutasi = TransaksiHarian(
        id: transaksiId,
        santriId: santriId,
        nominal: nominalSetoran,
        waktuAmbil: now,
        tanggalLokal: tglStr,
        kategoriWaktu: TimeCategory.setoran,
        catatan: (catatan != null && catatan.isNotEmpty)
            ? '$catatan$logPotongTunggakan'
            : (tipeSetoran == TipeSetoran.awalBulan ? 'Setoran Awal Bulan$logPotongTunggakan' : 'Top-Up Susulan$logPotongTunggakan'),
        saldoSetelahTransaksi: saldoBaru,
        tipe: TipeTransaksi.setoran,
        sumberDompet: dompet,
      );
      await txn.insert('transaksi_harian', transaksiMutasi.toMap());

      await txn.insert('mutasi_dompet', {
        'id': const Uuid().v4(),
        'jenis_dompet': dompet,
        'tipe': 'MASUK',
        'nominal': nominalSetoran,
        'referensi_id': transaksiId,
        'catatan': 'Setoran ${currentSantri.namaLengkap}',
        'tanggal_lokal': tglStr,
        'created_at': now.toIso8601String(),
      });
    });

    return setoran;
  }

  Future<List<SetoranBulanan>> getSetoranBySantri(String santriId) async {
    final db = await database;
    final maps = await db.query(
      'setoran_bulanan',
      where: 'santri_id = ?',
      whereArgs: [santriId],
      orderBy: 'tanggal_setor DESC',
    );
    return maps.map((m) => SetoranBulanan.fromMap(m)).toList();
  }

  // ==================== TRANSAKSI & AMBIL UANG ====================

  Future<TransaksiHarian> catatPengambilan({
    required String santriId,
    required int nominal,
    String? catatan,
    bool isOverlimit = false,
    OverlimitHandling? overlimitHandling,
    TimeCategory? waktuCategory,
    DateTime? customTimestamp,
  }) async {
    final db = await database;
    final id = const Uuid().v4();
    final waktu = customTimestamp ?? DateTime.now();
    final tanggalLokal = DateFormatter.toLocalDateString(waktu);
    final kategoriWaktu = waktuCategory ?? TimeCategoryHelper.fromDateTime(waktu);

    late TransaksiHarian transaksi;

    await db.transaction((txn) async {
      final santriMaps = await txn.query('santri', where: 'id = ?', whereArgs: [santriId]);
      if (santriMaps.isEmpty) throw Exception('Santri tidak ditemukan');
      final santri = Santri.fromMap(santriMaps.first);

      int saldoBaru = santri.saldoTotal;
      int tunggakanBaru = santri.tunggakan;
      String catatanTunggakanBaru = santri.catatanTunggakan;
      int tambahanTunggakan = 0;

      if (santri.saldoTotal >= nominal) {
        // Cukup saldo: potong saldo bulanan
        saldoBaru = santri.saldoTotal - nominal;
      } else if (santri.saldoTotal > 0) {
        // Sebagian saldo ada: habiskan saldo sampai 0, kekurangan jadi tunggakan
        final int kekurangan = nominal - santri.saldoTotal;
        saldoBaru = 0;
        tunggakanBaru += kekurangan;
        tambahanTunggakan = kekurangan;
        catatanTunggakanBaru = catatanTunggakanBaru.isEmpty
            ? 'Talangan Kas Pondok'
            : '$catatanTunggakanBaru, Talangan Kas';
      } else {
        // Saldo bulanan sudah 0: seluruhnya jadi tunggakan talangan dari kas pondok
        saldoBaru = 0;
        tunggakanBaru += nominal;
        tambahanTunggakan = nominal;
        catatanTunggakanBaru = catatanTunggakanBaru.isEmpty
            ? 'Talangan Kas Pondok'
            : catatanTunggakanBaru;
      }

      transaksi = TransaksiHarian(
        id: id,
        santriId: santriId,
        nominal: nominal,
        waktuAmbil: waktu,
        tanggalLokal: tanggalLokal,
        kategoriWaktu: kategoriWaktu,
        isOverlimit: isOverlimit || santri.saldoTotal < nominal,
        catatan: catatan,
        isVoided: false,
        overlimitHandling: overlimitHandling,
        saldoSetelahTransaksi: saldoBaru,
        tipe: TipeTransaksi.pengambilan,
        sumberDompet: 'TUNAI',
      );

      await txn.insert('transaksi_harian', transaksi.toMap());

      if (tambahanTunggakan > 0) {
        await txn.insert('tunggakan_log', {
          'id': const Uuid().v4(),
          'santri_id': santriId,
          'tipe': 'TALANGAN_SALDO',
          'nominal': tambahanTunggakan,
          'saldo_tunggakan_setelah': tunggakanBaru,
          'catatan': catatan ?? 'Talangan Kas Pondok',
          'created_at': waktu.toIso8601String(),
        });
      }

      await txn.insert('mutasi_dompet', {
        'id': const Uuid().v4(),
        'jenis_dompet': 'TUNAI',
        'tipe': 'KELUAR',
        'nominal': nominal,
        'referensi_id': id,
        'catatan': 'Pengambilan ${santri.namaLengkap}${catatan != null && catatan.isNotEmpty ? " ($catatan)" : ""}',
        'tanggal_lokal': tanggalLokal,
        'created_at': waktu.toIso8601String(),
      });

      Map<String, dynamic> updateData = {
        'saldo_total': saldoBaru,
        'tunggakan': tunggakanBaru,
        'catatan_tunggakan': catatanTunggakanBaru,
      };

      if (isOverlimit && overlimitHandling == OverlimitHandling.hitungUlangRataRata) {
        if (saldoBaru > 0) {
          int sisaHariPeriode = 0;
          final latestSetoranRows = await txn.query(
            'setoran_bulanan',
            columns: ['tanggal_setor', 'durasi_hari'],
            where: 'santri_id = ?',
            whereArgs: [santriId],
            orderBy: 'tanggal_setor DESC, rowid DESC',
            limit: 1,
          );
          if (latestSetoranRows.isNotEmpty) {
            final tglSetorStr =
                latestSetoranRows.first['tanggal_setor']?.toString() ?? '';
            final durasi =
                (latestSetoranRows.first['durasi_hari'] as num?)?.toInt() ?? 30;
            final tglSetor = DateTime.tryParse(tglSetorStr);
            if (tglSetor != null && durasi > 0) {
              final tglAmbil = DateTime(waktu.year, waktu.month, waktu.day);
              final startDay =
                  DateTime(tglSetor.year, tglSetor.month, tglSetor.day);
              final elapsedDays = tglAmbil.difference(startDay).inDays + 1;
              sisaHariPeriode = (durasi - elapsedDays).clamp(1, durasi);
            }
          }
          if (sisaHariPeriode <= 0) {
            sisaHariPeriode = santri.jatahHarian > 0
                ? (saldoBaru / santri.jatahHarian).ceil().clamp(1, 30)
                : 20;
          }

          final pengaturanMaps = await txn.query('pengaturan_aplikasi', where: 'id = 1');
          final kelipatan = pengaturanMaps.isNotEmpty
              ? ((pengaturanMaps.first['pembulatan_jatah'] as num?)?.toInt() ?? 500)
              : 500;
          final jatahBaru = CurrencyFormatter.hitungJatahHarianBulat(
            saldoBaru,
            sisaHariPeriode,
            kelipatan: kelipatan,
          );
          updateData['jatah_harian'] = jatahBaru;
        }
      }

      await txn.update(
        'santri',
        updateData,
        where: 'id = ?',
        whereArgs: [santriId],
      );
    });

    return transaksi;
  }

  Future<void> voidTransaksi(String transaksiId) async {
    final db = await database;
    await db.transaction((txn) async {
      final txMaps = await txn.query('transaksi_harian', where: 'id = ?', whereArgs: [transaksiId]);
      if (txMaps.isEmpty) return;
      final tx = TransaksiHarian.fromMap(txMaps.first);
      if (tx.isVoided) return;

      await txn.update(
        'transaksi_harian',
        {'is_void': 1},
        where: 'id = ?',
        whereArgs: [transaksiId],
      );

      final santriMaps = await txn.query('santri', where: 'id = ?', whereArgs: [tx.santriId]);
      final now = DateTime.now();
      final dompetAsal = _normalizeDompet(tx.sumberDompet);
      if (santriMaps.isNotEmpty) {
        final currentSantri = Santri.fromMap(santriMaps.first);
        if (tx.tipe == TipeTransaksi.pengambilan) {
          int sisaRefund = tx.nominal;
          int tunggakanBaru = currentSantri.tunggakan;
          String catatanTunggakanBaru = currentSantri.catatanTunggakan;
          int saldoBaru = currentSantri.saldoTotal;
          int nominalRollbackTunggakan = 0;

          // Batalkan tunggakan terlebih dahulu jika ada tunggakan
          if (tunggakanBaru > 0) {
            if (sisaRefund >= tunggakanBaru) {
              nominalRollbackTunggakan = tunggakanBaru;
              sisaRefund -= tunggakanBaru;
              tunggakanBaru = 0;
              catatanTunggakanBaru = '';
            } else {
              nominalRollbackTunggakan = sisaRefund;
              tunggakanBaru -= sisaRefund;
              sisaRefund = 0;
            }
          }
          saldoBaru += sisaRefund;

          await txn.update(
            'santri',
            {
              'saldo_total': saldoBaru,
              'tunggakan': tunggakanBaru,
              'catatan_tunggakan': catatanTunggakanBaru,
            },
            where: 'id = ?',
            whereArgs: [tx.santriId],
          );

          await txn.insert('mutasi_dompet', {
            'id': const Uuid().v4(),
            'jenis_dompet': dompetAsal,
            'tipe': 'MASUK',
            'nominal': tx.nominal,
            'referensi_id': tx.id,
            'catatan': 'Void Pengambilan ${currentSantri.namaLengkap}',
            'tanggal_lokal': DateFormatter.toLocalDateString(now),
            'created_at': now.toIso8601String(),
          });

          if (nominalRollbackTunggakan > 0) {
            await txn.insert('tunggakan_log', {
              'id': const Uuid().v4(),
              'santri_id': tx.santriId,
              'tipe': 'ROLLBACK_VOID',
              'nominal': nominalRollbackTunggakan,
              'saldo_tunggakan_setelah': tunggakanBaru,
              'catatan': 'Pembatalan transaksi ${tx.id}',
              'created_at': now.toIso8601String(),
            });
          }
        } else {
          // Void setoran: rekonsiliasi penuh dengan setoran_bulanan, potongan tunggakan & mutasi_dompet
          int nominalPotongTunggakan = 0;
          final matchingSetoran = await txn.query(
            'setoran_bulanan',
            where: 'santri_id = ? AND tanggal_setor = ? AND nominal_setoran = ?',
            whereArgs: [tx.santriId, tx.tanggalLokal, tx.nominal],
            orderBy: 'rowid DESC',
            limit: 1,
          );
          if (matchingSetoran.isNotEmpty) {
            final setoranRow = matchingSetoran.first;
            nominalPotongTunggakan =
                (setoranRow['nominal_potong_tunggakan'] as num?)?.toInt() ?? 0;
            final setoranId = setoranRow['id']?.toString();
            if (setoranId != null && setoranId.isNotEmpty) {
              await txn.delete(
                'setoran_bulanan',
                where: 'id = ?',
                whereArgs: [setoranId],
              );
            }
          }

          final int porsiSaldoJajan =
              (tx.nominal - nominalPotongTunggakan).clamp(0, tx.nominal);
          int tunggakanBaru = currentSantri.tunggakan + nominalPotongTunggakan;
          String catatanTunggakanBaru = currentSantri.catatanTunggakan;
          if (nominalPotongTunggakan > 0 && catatanTunggakanBaru.isEmpty) {
            catatanTunggakanBaru = 'Pemulihan Tunggakan (Void Setoran)';
          }

          int saldoBaru = currentSantri.saldoTotal;
          int selisihTerpakai = 0;
          if (currentSantri.saldoTotal >= porsiSaldoJajan) {
            saldoBaru = currentSantri.saldoTotal - porsiSaldoJajan;
          } else {
            // Sebagian/seluruh saldo setoran sudah terpakai jajan -> konversi ke Tunggakan (TALANGAN_SALDO)
            selisihTerpakai = porsiSaldoJajan - currentSantri.saldoTotal;
            saldoBaru = 0;
            tunggakanBaru += selisihTerpakai;
            catatanTunggakanBaru = catatanTunggakanBaru.isEmpty
                ? 'Talangan Kas Pondok (Void Setoran)'
                : '$catatanTunggakanBaru, Talangan Void Setoran';
          }

          await txn.update(
            'santri',
            {
              'saldo_total': saldoBaru,
              'tunggakan': tunggakanBaru,
              'catatan_tunggakan': catatanTunggakanBaru,
            },
            where: 'id = ?',
            whereArgs: [tx.santriId],
          );

          if (nominalPotongTunggakan > 0) {
            await txn.insert('tunggakan_log', {
              'id': const Uuid().v4(),
              'santri_id': tx.santriId,
              'tipe': 'ROLLBACK_POTONG_SETORAN',
              'nominal': nominalPotongTunggakan,
              'saldo_tunggakan_setelah':
                  currentSantri.tunggakan + nominalPotongTunggakan,
              'catatan': 'Pemulihan potongan tunggakan dari Void Setoran ${tx.id}',
              'created_at': now.toIso8601String(),
            });
          }

          if (selisihTerpakai > 0) {
            await txn.insert('tunggakan_log', {
              'id': const Uuid().v4(),
              'santri_id': tx.santriId,
              'tipe': 'TALANGAN_SALDO',
              'nominal': selisihTerpakai,
              'saldo_tunggakan_setelah': tunggakanBaru,
              'catatan':
                  'Selisih saldo terpakai dari pembatalan setoran ${tx.id}',
              'created_at': now.toIso8601String(),
            });
          }

          final tglNow = DateFormatter.toLocalDateString(now);
          await txn.insert('mutasi_dompet', {
            'id': const Uuid().v4(),
            'jenis_dompet': dompetAsal,
            'tipe': 'KELUAR',
            'nominal': tx.nominal,
            'referensi_id': tx.id,
            'catatan': 'Void Setoran ${currentSantri.namaLengkap}',
            'tanggal_lokal': tglNow,
            'created_at': now.toIso8601String(),
          });

          // Jika ada potongan tunggakan atau selisih saldo yang sudah terpakai jajan (sudah tercatat KELUAR sebelumnya),
          // catat jurnal penyeimbang piutang talangan agar saldo dompet tetap 100% sama dengan totalBrankasFisik.
          final int koreksiPiutangDompet =
              nominalPotongTunggakan + selisihTerpakai;
          if (koreksiPiutangDompet > 0) {
            await txn.insert('mutasi_dompet', {
              'id': const Uuid().v4(),
              'jenis_dompet': dompetAsal,
              'tipe': 'MASUK',
              'nominal': koreksiPiutangDompet,
              'referensi_id': tx.id,
              'catatan':
                  'Rekonsiliasi Piutang/Tunggakan atas Void Setoran ${currentSantri.namaLengkap}',
              'tanggal_lokal': tglNow,
              'created_at': now.toIso8601String(),
            });
          }
        }
      }
    });
  }

  Future<void> editTransaksi(String id, int newNominal, String? note) async {
    if (newNominal <= 0) {
      throw ArgumentError('Nominal transaksi harus lebih dari Rp 0.');
    }
    final db = await database;
    await db.transaction((txn) async {
      final maps = await txn.query('transaksi_harian', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return;

      final tx = TransaksiHarian.fromMap(maps.first);
      if (tx.isVoided) return;

      final int diff = newNominal - tx.nominal;
      final santriMaps = await txn.query('santri', where: 'id = ?', whereArgs: [tx.santriId]);
      if (santriMaps.isEmpty) return;

      final currentSantri = Santri.fromMap(santriMaps.first);
      final dompet = _normalizeDompet(tx.sumberDompet);
      final now = DateTime.now();
      final tglNow = DateFormatter.toLocalDateString(now);

      int saldoBaru = currentSantri.saldoTotal;
      int tunggakanBaru = currentSantri.tunggakan;
      String catatanTunggakanBaru = currentSantri.catatanTunggakan;
      int deltaDompet = 0; // positif = MASUK ke dompet, negatif = KELUAR dari dompet

      if (tx.tipe == TipeTransaksi.pengambilan) {
        if (diff > 0) {
          // Pengambilan bertambah sebesar diff
          if (currentSantri.saldoTotal >= diff) {
            saldoBaru = currentSantri.saldoTotal - diff;
            deltaDompet = -diff;
          } else {
            final int terpotongDariSaldo = currentSantri.saldoTotal;
            final int tambahanTunggakan = diff - terpotongDariSaldo;
            saldoBaru = 0;
            tunggakanBaru += tambahanTunggakan;
            catatanTunggakanBaru = catatanTunggakanBaru.isEmpty
                ? 'Talangan Kas Pondok'
                : catatanTunggakanBaru;
            deltaDompet = -terpotongDariSaldo;

            await txn.insert('tunggakan_log', {
              'id': const Uuid().v4(),
              'santri_id': tx.santriId,
              'tipe': 'TALANGAN_SALDO',
              'nominal': tambahanTunggakan,
              'saldo_tunggakan_setelah': tunggakanBaru,
              'catatan': note ?? 'Koreksi Edit Pengambilan ${tx.id}',
              'created_at': now.toIso8601String(),
            });
          }
        } else if (diff < 0) {
          // Pengambilan berkurang -> kembalikan ke tunggakan dulu jika ada, sisanya ke saldo
          int sisaRefund = -diff;
          int nominalRollbackTunggakan = 0;
          if (tunggakanBaru > 0) {
            if (sisaRefund >= tunggakanBaru) {
              nominalRollbackTunggakan = tunggakanBaru;
              sisaRefund -= tunggakanBaru;
              tunggakanBaru = 0;
              catatanTunggakanBaru = '';
            } else {
              nominalRollbackTunggakan = sisaRefund;
              tunggakanBaru -= sisaRefund;
              sisaRefund = 0;
            }
          }
          saldoBaru += sisaRefund;
          deltaDompet = sisaRefund;

          if (nominalRollbackTunggakan > 0) {
            await txn.insert('tunggakan_log', {
              'id': const Uuid().v4(),
              'santri_id': tx.santriId,
              'tipe': 'KOREKSI_EDIT',
              'nominal': nominalRollbackTunggakan,
              'saldo_tunggakan_setelah': tunggakanBaru,
              'catatan': 'Pengurangan tunggakan dari edit transaksi ${tx.id}',
              'created_at': now.toIso8601String(),
            });
          }
        }
      } else {
        // TipeTransaksi.setoran
        if (diff > 0) {
          saldoBaru = currentSantri.saldoTotal + diff;
          deltaDompet = diff;
        } else if (diff < 0) {
          final int pengurangan = -diff;
          if (currentSantri.saldoTotal >= pengurangan) {
            saldoBaru = currentSantri.saldoTotal - pengurangan;
            deltaDompet = -pengurangan;
          } else {
            final int terpotongDariSaldo = currentSantri.saldoTotal;
            final int tambahanTunggakan = pengurangan - terpotongDariSaldo;
            saldoBaru = 0;
            tunggakanBaru += tambahanTunggakan;
            catatanTunggakanBaru = catatanTunggakanBaru.isEmpty
                ? 'Talangan Kas Pondok (Koreksi Setoran)'
                : catatanTunggakanBaru;
            deltaDompet = -terpotongDariSaldo;

            await txn.insert('tunggakan_log', {
              'id': const Uuid().v4(),
              'santri_id': tx.santriId,
              'tipe': 'TALANGAN_SALDO',
              'nominal': tambahanTunggakan,
              'saldo_tunggakan_setelah': tunggakanBaru,
              'catatan': note ?? 'Selisih koreksi edit setoran ${tx.id}',
              'created_at': now.toIso8601String(),
            });
          }
        }
      }

      await txn.update(
        'transaksi_harian',
        {
          'nominal': newNominal,
          'catatan': note,
          'saldo_setelah_transaksi': saldoBaru,
          'is_overlimit':
              (tx.isOverlimit || tunggakanBaru > currentSantri.tunggakan)
                  ? 1
                  : 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await txn.update(
        'santri',
        {
          'saldo_total': saldoBaru,
          'tunggakan': tunggakanBaru,
          'catatan_tunggakan': catatanTunggakanBaru,
        },
        where: 'id = ?',
        whereArgs: [tx.santriId],
      );

      if (deltaDompet != 0) {
        await txn.insert('mutasi_dompet', {
          'id': const Uuid().v4(),
          'jenis_dompet': dompet,
          'tipe': deltaDompet > 0 ? 'MASUK' : 'KELUAR',
          'nominal': deltaDompet.abs(),
          'referensi_id': tx.id,
          'catatan':
              'Koreksi Edit Transaksi ${currentSantri.namaLengkap}${note != null && note.isNotEmpty ? ' ($note)' : ''}',
          'tanggal_lokal': tglNow,
          'created_at': now.toIso8601String(),
        });
      }
    });
  }

  Future<List<TransaksiHarian>> getBukuMutasiSantri(
    String santriId, {
    String? tanggalMulai,
    String? tanggalSelesai,
  }) async {
    final db = await database;
    String where = 'santri_id = ?';
    List<dynamic> args = [santriId];

    if (tanggalMulai != null && tanggalSelesai != null) {
      where += ' AND tanggal_lokal BETWEEN ? AND ?';
      args.addAll([tanggalMulai, tanggalSelesai]);
    } else if (tanggalMulai != null) {
      where += ' AND tanggal_lokal >= ?';
      args.add(tanggalMulai);
    }

    final maps = await db.query(
      'transaksi_harian',
      where: where,
      whereArgs: args,
      orderBy: 'waktu_ambil DESC',
    );
    return maps.map((m) => TransaksiHarian.fromMap(m)).toList();
  }

  Future<int> getTotalPengambilanHariIni(String santriId, String tanggalLokal) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(nominal) as total 
      FROM transaksi_harian 
      WHERE santri_id = ? 
        AND tanggal_lokal = ? 
        AND is_void = 0 
        AND tipe = 'PENGAMBILAN'
    ''', [santriId, tanggalLokal]);

    final total = result.first['total'];
    return (total as num?)?.toInt() ?? 0;
  }

  Future<List<TransaksiHarian>> getTransaksiHariIni(String santriId, String tanggalLokal) async {
    final db = await database;
    final maps = await db.query(
      'transaksi_harian',
      where: 'santri_id = ? AND tanggal_lokal = ? AND is_void = 0 AND tipe = "PENGAMBILAN"',
      whereArgs: [santriId, tanggalLokal],
      orderBy: 'waktu_ambil ASC',
    );
    return maps.map((m) => TransaksiHarian.fromMap(m)).toList();
  }

  /// Mengambil seluruh transaksi pengambilan hari ini untuk semua santri dalam 1 query (Eliminasi N+1).
  Future<Map<String, List<TransaksiHarian>>> getAllTransaksiPengambilanHariIniMap(
    String tanggalLokal,
  ) async {
    final db = await database;
    final maps = await db.query(
      'transaksi_harian',
      where: "tanggal_lokal = ? AND is_void = 0 AND tipe = 'PENGAMBILAN'",
      whereArgs: [tanggalLokal],
      orderBy: 'waktu_ambil ASC',
    );
    final grouped = <String, List<TransaksiHarian>>{};
    for (final m in maps) {
      final tx = TransaksiHarian.fromMap(m);
      grouped.putIfAbsent(tx.santriId, () => <TransaksiHarian>[]).add(tx);
    }
    return grouped;
  }

  /// Menghitung kuota efektif harian (`jatahHariIni`) seluruh santri aktif secara batch (0 N+1 query),
  /// menghubungkan `OverlimitHandling.potongBesok` dan `ModeSisaHarian.akumulasi`.
  Future<Map<String, int>> computeEffectiveDailyQuotaMap({
    required String todayLokal,
    required List<Santri> activeSantri,
    required ModeSisaHarian modeSisaHarian,
  }) async {
    final result = <String, int>{
      for (final s in activeSantri) s.id: s.jatahHarian,
    };
    if (activeSantri.isEmpty) return result;

    final todayDate = DateFormatter.parseLocalDate(todayLokal);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));
    final yesterdayLokal = DateFormatter.toLocalDateString(yesterdayDate);

    final db = await database;

    if (modeSisaHarian == ModeSisaHarian.ketat) {
      // Pada mode Ketat, hanya cek apakah kemarin ada transaksi overlimit berstatus POTONG_BESOK
      final yesterdayRows = await db.rawQuery('''
        SELECT
          santri_id,
          COALESCE(SUM(nominal), 0) AS total_kemarin,
          MAX(CASE WHEN overlimit_handling = 'POTONG_BESOK' THEN 1 ELSE 0 END) AS has_potong_besok
        FROM transaksi_harian
        WHERE tanggal_lokal = ?
          AND is_void = 0
          AND tipe = 'PENGAMBILAN'
        GROUP BY santri_id
      ''', [yesterdayLokal]);

      final yesterdayBySantri = <String, ({int total, bool hasPotongBesok})>{};
      for (final r in yesterdayRows) {
        final sid = r['santri_id']?.toString() ?? '';
        if (sid.isEmpty) continue;
        yesterdayBySantri[sid] = (
          total: (r['total_kemarin'] as num?)?.toInt() ?? 0,
          hasPotongBesok: ((r['has_potong_besok'] as num?)?.toInt() ?? 0) == 1,
        );
      }

      for (final s in activeSantri) {
        final yInfo = yesterdayBySantri[s.id];
        if (yInfo != null && yInfo.hasPotongBesok && yInfo.total > s.jatahHarian) {
          final excess = yInfo.total - s.jatahHarian;
          result[s.id] = (s.jatahHarian - excess).clamp(0, s.jatahHarian);
        }
      }
      return result;
    }

    // ModeSisaHarian.akumulasi:
    // Hitung akumulasi sisa jatah dari tanggal mulai periode (setoran terakhir atau transaksi pertama < hari ini)
    final setoranRows = await db.rawQuery('''
      SELECT santri_id, MAX(tanggal_setor) AS last_setor
      FROM setoran_bulanan
      WHERE tanggal_setor < ?
      GROUP BY santri_id
    ''', [todayLokal]);

    final lastSetorBySantri = <String, String>{};
    for (final r in setoranRows) {
      final sid = r['santri_id']?.toString() ?? '';
      final tgl = r['last_setor']?.toString() ?? '';
      if (sid.isNotEmpty && tgl.isNotEmpty) {
        lastSetorBySantri[sid] = tgl;
      }
    }

    final priorTxRows = await db.rawQuery('''
      SELECT
        santri_id,
        tanggal_lokal,
        COALESCE(SUM(nominal), 0) AS total_hari
      FROM transaksi_harian
      WHERE tanggal_lokal < ?
        AND is_void = 0
        AND tipe = 'PENGAMBILAN'
      GROUP BY santri_id, tanggal_lokal
    ''', [todayLokal]);

    final txBySantri = <String, List<({String tanggal, int total})>>{};
    for (final r in priorTxRows) {
      final sid = r['santri_id']?.toString() ?? '';
      final tgl = r['tanggal_lokal']?.toString() ?? '';
      final tot = (r['total_hari'] as num?)?.toInt() ?? 0;
      if (sid.isNotEmpty && tgl.isNotEmpty) {
        txBySantri
            .putIfAbsent(sid, () => <({String tanggal, int total})>[])
            .add((tanggal: tgl, total: tot));
      }
    }

    for (final s in activeSantri) {
      String? anchorStr = lastSetorBySantri[s.id];
      final txList = txBySantri[s.id] ?? const <({String tanggal, int total})>[];
      if (anchorStr == null && txList.isNotEmpty) {
        anchorStr = txList
            .map((e) => e.tanggal)
            .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
      }
      if (anchorStr == null) {
        result[s.id] = s.jatahHarian;
        continue;
      }

      final anchorDate = DateFormatter.parseLocalDate(anchorStr);
      final elapsedDays = todayDate.difference(anchorDate).inDays.clamp(0, 30);
      if (elapsedDays <= 0) {
        result[s.id] = s.jatahHarian;
        continue;
      }

      int totalAmbilSejakAnchor = 0;
      for (final item in txList) {
        if (item.tanggal.compareTo(anchorStr) >= 0) {
          totalAmbilSejakAnchor += item.total;
        }
      }

      final int totalKuotaLalu = elapsedDays * s.jatahHarian;
      final int sisaAkumulasiLalu = totalKuotaLalu - totalAmbilSejakAnchor;
      final int jatahEfektif = (s.jatahHarian + sisaAkumulasiLalu).clamp(
        0,
        s.saldoTotal > s.jatahHarian ? s.saldoTotal : s.jatahHarian * (elapsedDays + 1),
      );
      result[s.id] = jatahEfektif;
    }

    return result;
  }

  Future<List<TransaksiHarian>> getAllTransaksi({
    String? santriId,
    String? kategoriWaktu,
    String? tanggalMulai,
    String? tanggalSelesai,
    int? limit,
  }) async {
    final db = await database;
    String where = 'is_void = 0';
    List<dynamic> args = [];

    if (santriId != null && santriId.isNotEmpty && santriId != 'ALL') {
      where += ' AND santri_id = ?';
      args.add(santriId);
    }

    if (kategoriWaktu != null && kategoriWaktu.isNotEmpty && kategoriWaktu != 'ALL') {
      where += ' AND kategori_waktu = ?';
      args.add(kategoriWaktu);
    }

    if (tanggalMulai != null && tanggalMulai.isNotEmpty) {
      where += ' AND tanggal_lokal >= ?';
      args.add(tanggalMulai);
    }

    if (tanggalSelesai != null && tanggalSelesai.isNotEmpty) {
      where += ' AND tanggal_lokal <= ?';
      args.add(tanggalSelesai);
    }

    final maps = await db.query(
      'transaksi_harian',
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'waktu_ambil DESC',
      limit: limit,
    );

    return maps.map((m) => TransaksiHarian.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentTransactedSantriIds({int limit = 6}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT santri_id, MAX(waktu_ambil) as latest_time
      FROM transaksi_harian
      WHERE is_void = 0
      GROUP BY santri_id
      ORDER BY latest_time DESC
      LIMIT ?
    ''', [limit]);
  }

  // ==================== REKAP & AUDIT ====================

  Future<int> getTotalSaldoBrankasFisik() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(saldo_total) as total FROM santri WHERE status_aktif = 1',
    );
    final total = result.first['total'];
    return (total as num?)?.toInt() ?? 0;
  }

  Future<int> getTotalPengeluaranHariIni(String tanggalLokal) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(nominal) as total 
      FROM transaksi_harian 
      WHERE tanggal_lokal = ? 
        AND is_void = 0 
        AND tipe = 'PENGAMBILAN'
    ''', [tanggalLokal]);

    final total = result.first['total'];
    return (total as num?)?.toInt() ?? 0;
  }

  Future<int> getTotalPagiSiangHariIni(String tanggalLokal) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(nominal) as total 
      FROM transaksi_harian 
      WHERE tanggal_lokal = ? 
        AND is_void = 0 
        AND tipe = 'PENGAMBILAN'
        AND kategori_waktu IN ('PAGI', 'SIANG')
    ''', [tanggalLokal]);

    final total = result.first['total'];
    return (total as num?)?.toInt() ?? 0;
  }

  Future<int> getTotalSoreMalamHariIni(String tanggalLokal) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(nominal) as total 
      FROM transaksi_harian 
      WHERE tanggal_lokal = ? 
        AND is_void = 0 
        AND tipe = 'PENGAMBILAN'
        AND kategori_waktu IN ('SORE', 'MALAM')
    ''', [tanggalLokal]);

    final total = result.first['total'];
    return (total as num?)?.toInt() ?? 0;
  }

  Future<int> getJumlahTransaksiHariIni(String tanggalLokal) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT santri_id) as count 
      FROM transaksi_harian 
      WHERE tanggal_lokal = ? 
        AND is_void = 0 
        AND tipe = 'PENGAMBILAN'
    ''', [tanggalLokal]);

    final count = result.first['count'];
    return (count as num?)?.toInt() ?? 0;
  }

  Future<Map<String, int>> getRekapKategoriHariIni(String tanggalLokal) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT kategori_waktu, SUM(nominal) as total
      FROM transaksi_harian
      WHERE tanggal_lokal = ? AND is_void = 0 AND tipe = 'PENGAMBILAN'
      GROUP BY kategori_waktu
    ''', [tanggalLokal]);

    Map<String, int> rekap = {
      'PAGI': 0,
      'SIANG': 0,
      'SORE': 0,
      'MALAM': 0,
    };

    for (var m in maps) {
      final kat = m['kategori_waktu'] as String;
      final tot = (m['total'] as num).toInt();
      rekap[kat] = tot;
    }
    return rekap;
  }

  Future<List<Map<String, dynamic>>> getDetailTransaksiTanggal(String tanggalLokal) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.*, s.nama_lengkap, s.nama_panggilan, s.kamar
      FROM transaksi_harian t
      JOIN santri s ON t.santri_id = s.id
      WHERE t.tanggal_lokal = ? AND t.is_void = 0
      ORDER BY t.waktu_ambil DESC
    ''', [tanggalLokal]);
  }

  Future<Map<String, int>> getRekapBulanan(int tahun, int bulan) async {
    final db = await database;
    final bulanStr = bulan.toString().padLeft(2, '0');
    final prefix = '$tahun-$bulanStr%';

    final resPengeluaran = await db.rawQuery('''
      SELECT SUM(nominal) as total
      FROM transaksi_harian
      WHERE tanggal_lokal LIKE ? AND is_void = 0 AND tipe = 'PENGAMBILAN'
    ''', [prefix]);

    final resPemasukan = await db.rawQuery('''
      SELECT SUM(nominal_setoran) as total
      FROM setoran_bulanan
      WHERE tanggal_setor LIKE ?
    ''', [prefix]);

    final keluar = (resPengeluaran.first['total'] as num?)?.toInt() ?? 0;
    final masuk = (resPemasukan.first['total'] as num?)?.toInt() ?? 0;

    return {
      'pemasukan': masuk,
      'pengeluaran': keluar,
      'net': masuk - keluar,
    };
  }

  // ==================== PENGATURAN ====================

  Future<PengaturanAplikasi> getPengaturan() async {
    final db = await database;
    final maps = await db.query('pengaturan_aplikasi', where: 'id = 1');
    if (maps.isNotEmpty) {
      return PengaturanAplikasi.fromMap(maps.first);
    }
    return PengaturanAplikasi();
  }

  Future<void> updatePengaturan(PengaturanAplikasi pengaturan) async {
    final db = await database;
    await db.update(
      'pengaturan_aplikasi',
      pengaturan.toMap(),
      where: 'id = 1',
    );
  }

  // ==================== BACKUP & SEED DATA ====================

  Future<Map<String, dynamic>> dumpBackupJson() async {
    final db = await database;
    final santriList = await db.query('santri');
    final setoranList = await db.query('setoran_bulanan');
    final transaksiList = await db.query('transaksi_harian');
    final tunggakanLogList = await db.query('tunggakan_log');
    final mutasiDompetList = await db.query('mutasi_dompet');
    final cashOpnameList = await db.query('cash_opname_logs');
    final infakSantriList = await db.query('infak_santri');
    final serahTerimaInfakList = await db.query('serah_terima_infak');
    List<Map<String, Object?>> auditLogList = const [];
    try {
      auditLogList = await db.query('audit_log', orderBy: 'created_at ASC, rowid ASC');
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
      'audit_log': auditLogList,
      'pengaturan_aplikasi': pengaturanList,
    };
  }

  Future<Set<String>> _getTableColumns(Transaction txn, String tableName) async {
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
      throw FormatException(validation.errorMessage ?? 'Struktur backup JSON tidak valid.');
    }

    // Verifikasi integritas rantai SHA-256 audit_log sebelum membuka transaksi restore
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

    final db = await database;
    await db.transaction((txn) async {
      // Simpan status lisensi & trial asli perangkat agar tidak bisa dimanipulasi via file JSON luar
      final origPengRows =
          await txn.query('pengaturan_aplikasi', where: 'id = 1');
      final origPeng = origPengRows.isNotEmpty ? origPengRows.first : null;
      final int origIsPro = (origPeng?['is_pro'] as num?)?.toInt() ?? 0;
      final Object? origProPlan = origPeng?['pro_plan'];
      final Object? origTrialStarted = origPeng?['trial_started_at'];
      final Object? origTrialExpires = origPeng?['trial_expires_at'];
      final int origHasUsedTrial =
          (origPeng?['has_used_trial'] as num?)?.toInt() ?? 0;

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
            (map['qr_code'] == null || map['qr_code'].toString().trim().isEmpty)) {
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
          // Pertahankan otoritas lisensi & trial asli perangkat (anti-privilege escalation via JSON)
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
    await _backfillQrCodes(db);
  }

  Future<void> resetToInitialDemoData() async {
    final db = await database;
    final currentPengaturan = await getPengaturan();
    await db.transaction((txn) async {
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
    final db = await database;
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
      await db.insert('santri', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final today = DateFormatter.toLocalDateString(DateTime.now());
    final now = DateTime.now();

    final txAhmadPagi = TransaksiHarian(
      id: 'tx_demo_1',
      santriId: 's1',
      nominal: 2000,
      waktuAmbil: DateTime(now.year, now.month, now.day, 7, 15),
      tanggalLokal: today,
      kategoriWaktu: TimeCategory.pagi,
      catatan: 'Jajan Pagi / Sarapan',
      saldoSetelahTransaksi: 248000,
    );
    final txAhmadSiang = TransaksiHarian(
      id: 'tx_demo_2',
      santriId: 's1',
      nominal: 5000,
      waktuAmbil: DateTime(now.year, now.month, now.day, 12, 40),
      tanggalLokal: today,
      kategoriWaktu: TimeCategory.siang,
      catatan: 'Jajan Siang',
      saldoSetelahTransaksi: 243000,
    );

    final txRizkyPagi = TransaksiHarian(
      id: 'tx_demo_3',
      santriId: 's3',
      nominal: 5000,
      waktuAmbil: DateTime(now.year, now.month, now.day, 7, 30),
      tanggalLokal: today,
      kategoriWaktu: TimeCategory.pagi,
      catatan: 'Jajan Harian',
      saldoSetelahTransaksi: 195000,
    );
    final txRizkySiang = TransaksiHarian(
      id: 'tx_demo_4',
      santriId: 's3',
      nominal: 5000,
      waktuAmbil: DateTime(now.year, now.month, now.day, 13, 10),
      tanggalLokal: today,
      kategoriWaktu: TimeCategory.siang,
      catatan: 'Beli Sabun/Cuci',
      saldoSetelahTransaksi: 190000,
    );

    final txBilalPagi = TransaksiHarian(
      id: 'tx_demo_5',
      santriId: 's4',
      nominal: 3000,
      waktuAmbil: DateTime(now.year, now.month, now.day, 8, 0),
      tanggalLokal: today,
      kategoriWaktu: TimeCategory.pagi,
      catatan: 'Jajan Harian',
      saldoSetelahTransaksi: 387000,
    );

    final txNaufalPagi = TransaksiHarian(
      id: 'tx_demo_6',
      santriId: 's5',
      nominal: 4000,
      waktuAmbil: DateTime(now.year, now.month, now.day, 9, 20),
      tanggalLokal: today,
      kategoriWaktu: TimeCategory.pagi,
      catatan: 'Jajan Harian',
      saldoSetelahTransaksi: 266000,
    );

    for (var tx in [txAhmadPagi, txAhmadSiang, txRizkyPagi, txRizkySiang, txBilalPagi, txNaufalPagi]) {
      await db.insert('transaksi_harian', tx.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Seed Multi-Dompet awal (total Rp 1.666.000 = Rp 666.000 Kas Laci Tunai + Rp 1.000.000 Rekening Bank)
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

  // ==================== MULTI-DOMPET & CASH OPNAME (PRO) ====================

  Future<Map<String, int>> getSaldoDompet() async {
    final db = await database;
    final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM mutasi_dompet');
    final cnt = (countRes.first['cnt'] as num?)?.toInt() ?? 0;

    if (cnt == 0) {
      final totalBrankas = await getTotalSaldoBrankasFisik();
      if (totalBrankas > 0) {
        final now = DateTime.now();
        await db.insert('mutasi_dompet', {
          'id': const Uuid().v4(),
          'jenis_dompet': 'TUNAI',
          'tipe': 'MASUK',
          'nominal': totalBrankas,
          'referensi_id': 'SALDO_AWAL',
          'catatan': 'Inisialisasi Kas Laci Tunai',
          'tanggal_lokal': DateFormatter.toLocalDateString(now),
          'created_at': now.toIso8601String(),
        });
      }
    }

    final agg = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE
          WHEN UPPER(TRIM(tipe)) = 'TARIK_TUNAI' THEN nominal
          WHEN UPPER(TRIM(tipe)) = 'MASUK' AND UPPER(TRIM(jenis_dompet)) NOT IN ('REKENING', 'BANK', 'TRANSFER') THEN nominal
          WHEN UPPER(TRIM(tipe)) = 'KELUAR' AND UPPER(TRIM(jenis_dompet)) NOT IN ('REKENING', 'BANK', 'TRANSFER') THEN -nominal
          ELSE 0
        END), 0) AS tunai,
        COALESCE(SUM(CASE
          WHEN UPPER(TRIM(tipe)) = 'TARIK_TUNAI' THEN -nominal
          WHEN UPPER(TRIM(tipe)) = 'MASUK' AND UPPER(TRIM(jenis_dompet)) IN ('REKENING', 'BANK', 'TRANSFER') THEN nominal
          WHEN UPPER(TRIM(tipe)) = 'KELUAR' AND UPPER(TRIM(jenis_dompet)) IN ('REKENING', 'BANK', 'TRANSFER') THEN -nominal
          ELSE 0
        END), 0) AS rekening
      FROM mutasi_dompet
    ''');

    final row = agg.isNotEmpty ? agg.first : const <String, Object?>{};
    return {
      'tunai': (row['tunai'] as num?)?.toInt() ?? 0,
      'rekening': (row['rekening'] as num?)?.toInt() ?? 0,
    };
  }

  Future<void> tarikTunaiKeLaci({required int nominal, String? catatan}) async {
    if (nominal <= 0) {
      throw Exception('Nominal tarik tunai harus lebih dari Rp 0');
    }
    final saldo = await getSaldoDompet();
    final saldoBank = saldo['rekening'] ?? 0;
    if (nominal > saldoBank) {
      throw Exception('Saldo Rekening Bank tidak mencukupi (${CurrencyFormatter.format(saldoBank)})');
    }

    final db = await database;
    final now = DateTime.now();
    await db.insert('mutasi_dompet', {
      'id': const Uuid().v4(),
      'jenis_dompet': 'TUNAI',
      'tipe': 'TARIK_TUNAI',
      'nominal': nominal,
      'referensi_id': 'ATM_LACI',
      'catatan': (catatan != null && catatan.trim().isNotEmpty)
          ? catatan.trim()
          : 'Tarik Tunai Bank ke Kas Laci',
      'tanggal_lokal': DateFormatter.toLocalDateString(now),
      'created_at': now.toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getRecentTarikTunaiLogs({int limit = 5}) async {
    final db = await database;
    return await db.query(
      'mutasi_dompet',
      where: "tipe = 'TARIK_TUNAI'",
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<void> insertCashOpnameLog(CashOpnameLog log) async {
    final db = await database;
    await db.insert('cash_opname_logs', log.toMap());
  }

  Future<List<CashOpnameLog>> getCashOpnameLogs({int limit = 15}) async {
    final db = await database;
    final maps = await db.query(
      'cash_opname_logs',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((m) => CashOpnameLog.fromMap(m)).toList();
  }

  Future<Santri?> getSantriByQrCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    final db = await database;
    final maps = await db.query(
      'santri',
      where: '(UPPER(qr_code) = ? OR UPPER(id) = ?) AND status_aktif = 1',
      whereArgs: [code, code],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Santri.fromMap(maps.first);
  }

  Future<List<Map<String, dynamic>>> getTransaksiByDateRange({
    String? tanggalMulai,
    String? tanggalSelesai,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (tanggalMulai != null && tanggalMulai.isNotEmpty) {
      conditions.add('t.tanggal_lokal >= ?');
      args.add(tanggalMulai);
    }
    if (tanggalSelesai != null && tanggalSelesai.isNotEmpty) {
      conditions.add('t.tanggal_lokal <= ?');
      args.add(tanggalSelesai);
    }
    final whereClause =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    return await db.rawQuery('''
      SELECT t.*, s.nama_lengkap, s.kamar
      FROM transaksi_harian t
      LEFT JOIN santri s ON t.santri_id = s.id
      $whereClause
      ORDER BY t.waktu_ambil DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getAllMutasiDompet({
    String? tanggalMulai,
    String? tanggalSelesai,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (tanggalMulai != null && tanggalMulai.isNotEmpty) {
      conditions.add('tanggal_lokal >= ?');
      args.add(tanggalMulai);
    }
    if (tanggalSelesai != null && tanggalSelesai.isNotEmpty) {
      conditions.add('tanggal_lokal <= ?');
      args.add(tanggalSelesai);
    }
    final whereClause =
        conditions.isEmpty ? null : conditions.join(' AND ');
    return await db.query(
      'mutasi_dompet',
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
  }

  // ==================== MODUL INFAK, SAMBANGAN & SERAH TERIMA (v3.0) ====================

  Future<void> upsertInfakSantri(InfakSantriModel infak) async {
    final db = await database;
    await db.transaction((txn) async {
      await _upsertInfakInTxn(txn, infak);
    });
  }

  Future<void> _upsertInfakInTxn(Transaction txn, InfakSantriModel infak) async {
    final existing = await txn.query(
      'infak_santri',
      columns: ['id'],
      where: 'santri_id = ? AND periode_bulan = ?',
      whereArgs: [infak.santriId, infak.periodeBulan],
      limit: 1,
    );
    final map = infak.toMap();
    if (existing.isNotEmpty) {
      final oldId = existing.first['id']?.toString();
      if (oldId != null && oldId.isNotEmpty) {
        map['id'] = oldId;
      }
      await txn.update(
        'infak_santri',
        map,
        where: 'id = ?',
        whereArgs: [map['id']],
      );
    } else {
      await txn.insert(
        'infak_santri',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<InfakSantriModel>> getInfakByPeriode(String periodeBulan) async {
    final db = await database;
    final rows = await db.query(
      'infak_santri',
      where: 'periode_bulan = ?',
      whereArgs: [periodeBulan],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => InfakSantriModel.fromMap(r)).toList();
  }

  Future<InfakSantriModel?> getInfakBySantriPeriode(
    String santriId,
    String periodeBulan,
  ) async {
    final db = await database;
    final rows = await db.query(
      'infak_santri',
      where: 'santri_id = ? AND periode_bulan = ?',
      whereArgs: [santriId, periodeBulan],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return InfakSantriModel.fromMap(rows.first);
  }

  Future<({
    SetoranBulanan? setoran,
    InfakSantriModel infak,
    int sisaJajan,
    int jatahBaru,
    int nominalPotongTunggakan,
  })> catatSambanganSmartSplit({
    required String santriId,
    required int totalUangDiterima,
    required DateTime tanggalMasuk,
    required String tglHabisYmd,
    required int nominalMasak,
    required bool isMasakBebas,
    required int nominalListrik,
    required bool isListrikBebas,
    required String jenisBeras,
    required double berasLiter,
    required int berasUang,
    required int durasiHari,
    bool potongTunggakan = true,
    String sumberDompet = 'TUNAI',
    String? catatan,
  }) async {
    final db = await database;
    final dompet = _normalizeDompet(sumberDompet);
    final tglMasukYmd = DateFormatter.toLocalDateString(tanggalMasuk);
    final periodeBulan =
        '${tanggalMasuk.year.toString().padLeft(4, '0')}-${tanggalMasuk.month.toString().padLeft(2, '0')}';

    final int actualMasak = isMasakBebas ? 0 : nominalMasak;
    final int actualListrik = isListrikBebas ? 0 : nominalListrik;
    final int actualBerasUang =
        jenisBeras == InfakSantriModel.berasUangVal ? berasUang : 0;
    final double actualBerasLiter =
        jenisBeras == InfakSantriModel.berasFisik ? berasLiter : 0.0;
    final int totalInfakUang = actualMasak + actualListrik + actualBerasUang;

    if (totalInfakUang > totalUangDiterima) {
      throw Exception(
        'Total potongan infak (${CurrencyFormatter.format(totalInfakUang)}) melebihi uang diterima (${CurrencyFormatter.format(totalUangDiterima)}).',
      );
    }

    late SetoranBulanan? createdSetoran;
    late InfakSantriModel savedInfak;
    int sisaJajan = 0;
    int jatahBaru = 0;
    int nominalPotongTunggakan = 0;

    await db.transaction((txn) async {
      final pengMaps = await txn.query('pengaturan_aplikasi', where: 'id = 1');
      final peng = pengMaps.isNotEmpty
          ? PengaturanAplikasi.fromMap(pengMaps.first)
          : PengaturanAplikasi();

      final santriMaps = await txn.query('santri', where: 'id = ?', whereArgs: [santriId]);
      if (santriMaps.isEmpty) {
        throw Exception('Santri tidak ditemukan');
      }
      final currentSantri = Santri.fromMap(santriMaps.first);

      int sisaSetelahInfak = totalUangDiterima - totalInfakUang;
      int tunggakanBaru = currentSantri.tunggakan;
      String catatanTunggakanBaru = currentSantri.catatanTunggakan;

      if (potongTunggakan && tunggakanBaru > 0 && sisaSetelahInfak > 0) {
        if (sisaSetelahInfak >= tunggakanBaru) {
          nominalPotongTunggakan = tunggakanBaru;
          sisaSetelahInfak -= tunggakanBaru;
          tunggakanBaru = 0;
          catatanTunggakanBaru = '';
        } else {
          nominalPotongTunggakan = sisaSetelahInfak;
          tunggakanBaru -= sisaSetelahInfak;
          sisaSetelahInfak = 0;
        }

        await txn.insert('tunggakan_log', {
          'id': const Uuid().v4(),
          'santri_id': santriId,
          'tipe': 'POTONG_SETORAN',
          'nominal': nominalPotongTunggakan,
          'saldo_tunggakan_setelah': tunggakanBaru,
          'catatan': catatan ?? 'Potong otomatis dari Sambangan',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      sisaJajan = sisaSetelahInfak;
      final int saldoBaru = currentSantri.saldoTotal + sisaJajan;
      jatahBaru = (sisaJajan > 0 && durasiHari > 0)
          ? CurrencyFormatter.hitungJatahHarianBulat(
              sisaJajan,
              durasiHari,
              kelipatan: peng.pembulatanJatah,
            )
          : currentSantri.jatahHarian;

      final int jajanDanTunggakan = sisaJajan + nominalPotongTunggakan;
      if (jajanDanTunggakan > 0) {
        final setoranId = const Uuid().v4();
        final transaksiId = const Uuid().v4();
        final noteText = (catatan != null && catatan.trim().isNotEmpty)
            ? '${catatan.trim()} (Smart Split Sambangan)'
            : 'Sambangan Wali (Jajan ${CurrencyFormatter.format(sisaJajan)})';

        createdSetoran = SetoranBulanan(
          id: setoranId,
          santriId: santriId,
          nominalSetoran: jajanDanTunggakan,
          durasiHari: durasiHari > 0 ? durasiHari : 30,
          jatahHarianHitung: jatahBaru,
          tipeSetoran: TipeSetoran.sambanganSplit,
          tanggalSetor: tanggalMasuk,
          catatan: noteText,
        );
        final setoranMap = createdSetoran!.toMap();
        setoranMap['metode_bayar'] = dompet;
        setoranMap['potong_tunggakan'] = nominalPotongTunggakan > 0 ? 1 : 0;
        setoranMap['nominal_potong_tunggakan'] = nominalPotongTunggakan;
        await txn.insert('setoran_bulanan', setoranMap);

        final now = DateTime.now();
        final txMutasi = TransaksiHarian(
          id: transaksiId,
          santriId: santriId,
          nominal: jajanDanTunggakan,
          waktuAmbil: now,
          tanggalLokal: tglMasukYmd,
          kategoriWaktu: TimeCategory.setoran,
          catatan: noteText,
          saldoSetelahTransaksi: saldoBaru,
          tipe: TipeTransaksi.setoran,
          sumberDompet: dompet,
        );
        await txn.insert('transaksi_harian', txMutasi.toMap());

        // Catat HANYA porsi jajan + tunggakan ke mutasi_dompet (Kantong 1)
        // agar terpisah tegas dari Kas Infak Pondok (Kantong 2).
        await txn.insert('mutasi_dompet', {
          'id': const Uuid().v4(),
          'jenis_dompet': dompet,
          'tipe': 'MASUK',
          'nominal': jajanDanTunggakan,
          'referensi_id': transaksiId,
          'catatan': 'Sambangan Jajan ${currentSantri.namaLengkap}',
          'tanggal_lokal': tglMasukYmd,
          'created_at': now.toIso8601String(),
        });
      } else {
        createdSetoran = null;
      }

      await txn.update(
        'santri',
        {
          'saldo_total': saldoBaru,
          'jatah_harian': jatahBaru,
          'tunggakan': tunggakanBaru,
          'catatan_tunggakan': catatanTunggakanBaru,
        },
        where: 'id = ?',
        whereArgs: [santriId],
      );

      final statusLunas = InfakSantriModel.hitungStatusLunas(
        nominalMasak: actualMasak,
        isMasakBebas: isMasakBebas,
        nominalListrik: actualListrik,
        isListrikBebas: isListrikBebas,
        jenisBeras: jenisBeras,
        berasLiter: actualBerasLiter,
        berasUang: actualBerasUang,
        targetMasak: peng.defaultInfakMasak,
        targetListrik: peng.defaultInfakListrik,
        targetBerasLiter: peng.defaultInfakBerasLiter,
        targetBerasUang: peng.defaultInfakBerasUang,
      );

      savedInfak = InfakSantriModel(
        id: const Uuid().v4(),
        santriId: santriId,
        periodeBulan: periodeBulan,
        tahunAjaran: peng.tahunAjaran,
        nominalMasak: actualMasak,
        isMasakBebas: isMasakBebas,
        nominalListrik: actualListrik,
        isListrikBebas: isListrikBebas,
        jenisBeras: jenisBeras,
        berasLiter: actualBerasLiter,
        berasUang: actualBerasUang,
        tglMasuk: tglMasukYmd,
        tglHabis: tglHabisYmd,
        statusLunas: statusLunas,
        sumberDompet: dompet,
        setoranId: createdSetoran?.id,
        catatan: catatan?.trim().isNotEmpty == true ? catatan!.trim() : 'Sambangan Wali',
      );
      await _upsertInfakInTxn(txn, savedInfak);
    });

    return (
      setoran: createdSetoran,
      infak: savedInfak,
      sisaJajan: sisaJajan,
      jatahBaru: jatahBaru,
      nominalPotongTunggakan: nominalPotongTunggakan,
    );
  }

  Future<void> insertSerahTerimaInfak(SerahTerimaInfakModel item) async {
    final db = await database;
    await db.insert(
      'serah_terima_infak',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSerahTerimaInfak(String id) async {
    final db = await database;
    await db.delete('serah_terima_infak', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SerahTerimaInfakModel>> getSerahTerimaInfak({
    String? periodeBulan,
  }) async {
    final db = await database;
    final rows = await db.query(
      'serah_terima_infak',
      where: periodeBulan != null && periodeBulan.isNotEmpty
          ? 'periode_bulan = ?'
          : null,
      whereArgs: periodeBulan != null && periodeBulan.isNotEmpty
          ? [periodeBulan]
          : null,
      orderBy: 'tanggal_serah DESC, created_at DESC',
    );
    return rows.map((r) => SerahTerimaInfakModel.fromMap(r)).toList();
  }

  Future<Map<String, dynamic>> getSaldoKantongInfak() async {
    final db = await database;
    final infakAgg = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE
          WHEN UPPER(TRIM(sumber_dompet)) NOT IN ('REKENING', 'BANK', 'TRANSFER') THEN
            (CASE WHEN is_masak_bebas = 1 THEN 0 ELSE nominal_masak END) +
            (CASE WHEN is_listrik_bebas = 1 THEN 0 ELSE nominal_listrik END) +
            (CASE WHEN jenis_beras = '${InfakSantriModel.berasUangVal}' THEN beras_uang ELSE 0 END)
          ELSE 0
        END), 0) AS masuk_tunai,
        COALESCE(SUM(CASE
          WHEN UPPER(TRIM(sumber_dompet)) IN ('REKENING', 'BANK', 'TRANSFER') THEN
            (CASE WHEN is_masak_bebas = 1 THEN 0 ELSE nominal_masak END) +
            (CASE WHEN is_listrik_bebas = 1 THEN 0 ELSE nominal_listrik END) +
            (CASE WHEN jenis_beras = '${InfakSantriModel.berasUangVal}' THEN beras_uang ELSE 0 END)
          ELSE 0
        END), 0) AS masuk_rekening,
        COALESCE(SUM(CASE
          WHEN jenis_beras = '${InfakSantriModel.berasFisik}' THEN beras_liter
          ELSE 0.0
        END), 0.0) AS beras_masuk
      FROM infak_santri
    ''');

    final serahAgg = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE
          WHEN UPPER(TRIM(sumber_dompet)) = 'TUNAI' THEN nominal_uang
          ELSE 0
        END), 0) AS serah_tunai,
        COALESCE(SUM(CASE
          WHEN UPPER(TRIM(sumber_dompet)) = 'REKENING' THEN nominal_uang
          ELSE 0
        END), 0) AS serah_rekening,
        COALESCE(SUM(jumlah_beras_liter), 0.0) AS beras_serah
      FROM serah_terima_infak
    ''');

    final infRow = infakAgg.isNotEmpty ? infakAgg.first : const <String, Object?>{};
    final serRow = serahAgg.isNotEmpty ? serahAgg.first : const <String, Object?>{};

    final int masukTunai = (infRow['masuk_tunai'] as num?)?.toInt() ?? 0;
    final int masukRekening = (infRow['masuk_rekening'] as num?)?.toInt() ?? 0;
    final double berasMasuk = (infRow['beras_masuk'] as num?)?.toDouble() ?? 0.0;

    final int serahTunai = (serRow['serah_tunai'] as num?)?.toInt() ?? 0;
    final int serahRekening = (serRow['serah_rekening'] as num?)?.toInt() ?? 0;
    final double berasSerah = (serRow['beras_serah'] as num?)?.toDouble() ?? 0.0;

    final sisaTunai = masukTunai - serahTunai;
    final sisaRekening = masukRekening - serahRekening;
    final sisaBeras = berasMasuk - berasSerah;

    return {
      'tunai': sisaTunai,
      'rekening': sisaRekening,
      'total_uang': sisaTunai + sisaRekening,
      'beras_masuk': berasMasuk,
      'beras_serah': berasSerah,
      'beras_stok': sisaBeras < 0 ? 0.0 : sisaBeras,
    };
  }

  // ==================== AUDIT LOG KEAMANAN (IMMUTABLE INSERT-ONLY) ====================

  /// Menambahkan catatan audit baru dengan pengikatan SHA-256 hash berantai (`prev_hash -> entry_hash`).
  /// Bersifat INSERT-only; tidak ada metode hapus atau edit catatan audit.
  Future<AuditLogEntry> insertAuditLog({
    required String actor,
    required String action,
    String? targetId,
    required String summary,
    DateTime? timestamp,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final latestRows = await txn.query(
        'audit_log',
        columns: ['entry_hash'],
        orderBy: 'created_at DESC, rowid DESC',
        limit: 1,
      );
      final prevHash = latestRows.isNotEmpty
          ? (latestRows.first['entry_hash']?.toString() ?? AuditLogEntry.genesisHash)
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
    final db = await database;
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
    final db = await database;
    final rows = await db.query(
      'audit_log',
      orderBy: 'created_at ASC, rowid ASC',
    );
    final entries = rows.map(AuditLogEntry.fromMap).toList();
    return AuditLogEntry.verifyChain(entries);
  }

  // ==================== OPERASI MASSAL & ANALITIK v4.0 ====================

  Future<int> bulkInsertSantri(
    List<Santri> santriList, {
    String sumberDompet = 'TUNAI',
  }) async {
    if (santriList.isEmpty) return 0;
    final db = await database;
    final dompet = _normalizeDompet(sumberDompet);
    final now = DateTime.now();
    final todayStr = DateFormatter.toLocalDateString(now);

    await db.transaction((txn) async {
      for (final santri in santriList) {
        await txn.insert('santri', santri.toMap());
        if (santri.saldoTotal > 0) {
          await txn.insert('mutasi_dompet', {
            'id': const Uuid().v4(),
            'jenis_dompet': dompet,
            'tipe': 'MASUK',
            'nominal': santri.saldoTotal,
            'referensi_id': santri.id,
            'catatan': 'Import Excel Saldo Awal ${santri.namaLengkap}',
            'tanggal_lokal': todayStr,
            'created_at': now.toIso8601String(),
          });
        }
      }
    });
    return santriList.length;
  }

  Future<int> bulkMoveKamar(List<String> santriIds, String newKamar) async {
    final cleanKamar = newKamar.trim();
    if (santriIds.isEmpty || cleanKamar.isEmpty) return 0;
    final db = await database;
    var updatedCount = 0;
    await db.transaction((txn) async {
      for (final id in santriIds) {
        final cnt = await txn.update(
          'santri',
          {'kamar': cleanKamar},
          where: 'id = ?',
          whereArgs: [id],
        );
        updatedCount += cnt;
      }
    });
    return updatedCount;
  }

  Future<int> bulkArchiveSantriStatus(
    List<String> santriIds, {
    required String newStatusSantri,
  }) async {
    if (santriIds.isEmpty) return 0;
    final normalizedStatus = Santri.normalizeStatusSantri(newStatusSantri);
    final db = await database;
    var updatedCount = 0;
    await db.transaction((txn) async {
      for (final id in santriIds) {
        final cnt = await txn.update(
          'santri',
          {
            'status_santri': normalizedStatus,
            'status_aktif': 0,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        updatedCount += cnt;
      }
    });
    return updatedCount;
  }

  Future<List<Map<String, dynamic>>> getAllSetoranByDateRange({
    String? tanggalMulai,
    String? tanggalSelesai,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (tanggalMulai != null && tanggalMulai.isNotEmpty) {
      conditions.add('tanggal_setor >= ?');
      args.add(tanggalMulai);
    }
    if (tanggalSelesai != null && tanggalSelesai.isNotEmpty) {
      conditions.add('tanggal_setor <= ?');
      args.add(tanggalSelesai);
    }
    final whereClause = conditions.isEmpty ? null : conditions.join(' AND ');
    return db.query(
      'setoran_bulanan',
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'tanggal_setor DESC',
    );
  }

  Future<int> getVoidCountSince(DateTime since) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM transaksi_harian WHERE is_void = 1 AND waktu_ambil >= ?',
      [since.toIso8601String()],
    );
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }
}
