import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/santri.dart';
import '../models/setoran.dart';
import '../models/transaksi.dart';
import '../models/pengaturan.dart';
import '../models/cash_opname_log.dart';
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

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: (db) async {
        await _ensureColumnsAndIndexes(db);
      },
    );
  }

  Future<void> _addColumnIfNotExists(Database db, String table, String columnDef) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDef;');
    } catch (_) {}
  }

  Future<void> _ensureColumnsAndIndexes(Database db) async {
    await _addColumnIfNotExists(db, 'santri', 'foto_path TEXT');
    await _addColumnIfNotExists(db, 'santri', 'qr_code TEXT');
    await _addColumnIfNotExists(db, 'setoran_bulanan', "metode_bayar TEXT NOT NULL DEFAULT 'TUNAI'");
    await _addColumnIfNotExists(db, 'setoran_bulanan', 'potong_tunggakan INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfNotExists(db, 'setoran_bulanan', 'nominal_potong_tunggakan INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfNotExists(db, 'transaksi_harian', 'is_void INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfNotExists(db, 'transaksi_harian', "sumber_dompet TEXT NOT NULL DEFAULT 'TUNAI'");
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'pembulatan_jatah INTEGER NOT NULL DEFAULT 500');
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'is_pro INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'pro_plan TEXT');
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'onboarding_done INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'last_drive_backup_at TEXT');
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'auto_drive_backup INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfNotExists(db, 'pengaturan_aplikasi', 'drive_account_email TEXT');
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_santri_tgl ON transaksi_harian (santri_id, tanggal_lokal, is_void);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_santri_qr ON santri (qr_code);');
    } catch (_) {}
    await _backfillQrCodes(db);
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
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Tabel santri
    await db.execute('''
      CREATE TABLE santri (
        id TEXT PRIMARY KEY,
        nama_lengkap TEXT NOT NULL,
        nama_panggilan TEXT,
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
        drive_account_email TEXT
      )
    ''');

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
      'CREATE INDEX idx_mutasi_dompet_tanggal ON mutasi_dompet (tanggal_lokal);',
    );

    // Inisialisasi data pengaturan bawaan
    await db.insert('pengaturan_aplikasi', {
      'id': 1,
      'nama_pondok': 'PPS MIFTAHUSSUNAN',
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

  Future<void> deleteSantri(String santriId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tunggakan_log', where: 'santri_id = ?', whereArgs: [santriId]);
      await txn.delete('transaksi_harian', where: 'santri_id = ?', whereArgs: [santriId]);
      await txn.delete('setoran_bulanan', where: 'santri_id = ?', whereArgs: [santriId]);
      await txn.delete('santri', where: 'id = ?', whereArgs: [santriId]);
    });
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
        const sisaHariPeriode = 20;
        if (saldoBaru > 0) {
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
          // Void setoran: kurangi saldo yang sempat disetor dan tarik balik dari dompet asal
          final int restoredSaldo = (currentSantri.saldoTotal - tx.nominal).clamp(0, double.infinity).toInt();
          await txn.update(
            'santri',
            {'saldo_total': restoredSaldo},
            where: 'id = ?',
            whereArgs: [tx.santriId],
          );

          await txn.insert('mutasi_dompet', {
            'id': const Uuid().v4(),
            'jenis_dompet': dompetAsal,
            'tipe': 'KELUAR',
            'nominal': tx.nominal,
            'referensi_id': tx.id,
            'catatan': 'Void Setoran ${currentSantri.namaLengkap}',
            'tanggal_lokal': DateFormatter.toLocalDateString(now),
            'created_at': now.toIso8601String(),
          });
        }
      }
    });
  }

  Future<void> editTransaksi(String id, int newNominal, String? note) async {
    final db = await database;
    await db.transaction((txn) async {
      final maps = await txn.query('transaksi_harian', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return;

      final tx = TransaksiHarian.fromMap(maps.first);
      final int diff = newNominal - tx.nominal;

      await txn.update(
        'transaksi_harian',
        {
          'nominal': newNominal,
          'catatan': note,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      final santriMaps = await txn.query('santri', where: 'id = ?', whereArgs: [tx.santriId]);
      if (santriMaps.isNotEmpty) {
        final currentSaldo = santriMaps.first['saldo_total'] as int;
        final updatedSaldo = tx.tipe == TipeTransaksi.pengambilan
            ? currentSaldo - diff
            : currentSaldo + diff;

        await txn.update(
          'santri',
          {'saldo_total': updatedSaldo},
          where: 'id = ?',
          whereArgs: [tx.santriId],
        );
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

  Future<List<TransaksiHarian>> getAllTransaksi({
    String? santriId,
    String? kategoriWaktu,
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
    final pengaturanList = await db.query('pengaturan_aplikasi');

    return {
      'version': 25,
      'exported_at': DateTime.now().toIso8601String(),
      'santri': santriList,
      'setoran_bulanan': setoranList,
      'transaksi_harian': transaksiList,
      'tunggakan_log': tunggakanLogList,
      'mutasi_dompet': mutasiDompetList,
      'cash_opname_logs': cashOpnameList,
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

    final db = await database;
    await db.transaction((txn) async {
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

      final pengCols = await _getTableColumns(txn, 'pengaturan_aplikasi');
      final pengList = data['pengaturan_aplikasi'] as List;
      if (pengList.isEmpty) {
        await txn.insert('pengaturan_aplikasi', {
          ...PengaturanAplikasi(onboardingDone: true).toMap(),
        });
      } else {
        for (var row in pengList) {
          final map = Map<String, dynamic>.from(row as Map);
          map['onboarding_done'] = map['onboarding_done'] ?? 1;
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
      'nama_pondok': 'PPS MIFTAHUSSUNAN',
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

    final rows = await db.query('mutasi_dompet');
    int tunai = 0;
    int rekening = 0;

    for (final row in rows) {
      final jenis = _normalizeDompet(row['jenis_dompet'] as String? ?? 'TUNAI');
      final tipe = (row['tipe'] as String? ?? 'MASUK').toUpperCase();
      final nominal = (row['nominal'] as num?)?.toInt() ?? 0;

      if (tipe == 'TARIK_TUNAI') {
        rekening -= nominal;
        tunai += nominal;
      } else if (tipe == 'MASUK') {
        if (jenis == 'REKENING') {
          rekening += nominal;
        } else {
          tunai += nominal;
        }
      } else if (tipe == 'KELUAR') {
        if (jenis == 'REKENING') {
          rekening -= nominal;
        } else {
          tunai -= nominal;
        }
      }
    }

    return {
      'tunai': tunai,
      'rekening': rekening,
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
      ORDER BY t.created_at DESC
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
}
