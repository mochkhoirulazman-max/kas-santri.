import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/santri.dart';
import '../models/setoran.dart';
import '../models/transaksi.dart';
import '../models/pengaturan.dart';
import '../utils/time_category_helper.dart';
import '../utils/date_formatter.dart';

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
      version: 1,
      onCreate: _createDB,
    );
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
        is_voided INTEGER NOT NULL DEFAULT 0,
        overlimit_handling TEXT,
        saldo_setelah_transaksi INTEGER NOT NULL DEFAULT 0,
        tipe TEXT NOT NULL DEFAULT 'PENGAMBILAN',
        FOREIGN KEY (santri_id) REFERENCES santri (id) ON DELETE CASCADE
      )
    ''');

    // 4. Tabel pengaturan_aplikasi (Singleton id = 1)
    await db.execute('''
      CREATE TABLE pengaturan_aplikasi (
        id INTEGER PRIMARY KEY,
        nama_pondok TEXT NOT NULL,
        nama_pengurus TEXT NOT NULL,
        kontak_pengurus TEXT,
        default_jatah_harian INTEGER NOT NULL DEFAULT 10000,
        default_durasi_hari INTEGER NOT NULL DEFAULT 30,
        mode_sisa_harian TEXT NOT NULL DEFAULT 'KETAT',
        pin_keamanan TEXT DEFAULT '1234',
        is_biometric_enabled INTEGER NOT NULL DEFAULT 0,
        auto_lock_minutes INTEGER NOT NULL DEFAULT 1,
        logo_path TEXT,
        is_two_col_grid INTEGER NOT NULL DEFAULT 1,
        hide_balance INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Indeks untuk kecepatan & performa query < 100ms
    await db.execute(
      'CREATE INDEX idx_transaksi_santri_tanggal ON transaksi_harian (santri_id, tanggal_lokal);',
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

    // Inisialisasi data pengaturan bawaan
    await db.insert('pengaturan_aplikasi', {
      'id': 1,
      'nama_pondok': 'PPS MIFTAHUSSUNAN',
      'nama_pengurus': 'Pengurus Kas & Keuangan',
      'kontak_pengurus': '081234567890',
      'default_jatah_harian': 10000,
      'default_durasi_hari': 30,
      'mode_sisa_harian': 'KETAT',
      'pin_keamanan': '1234',
      'is_biometric_enabled': 0,
      'auto_lock_minutes': 1,
      'logo_path': null,
      'is_two_col_grid': 1,
      'hide_balance': 0,
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

  Future<int> insertSantri(Santri santri) async {
    final db = await database;
    return await db.insert('santri', santri.toMap());
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

  Future<void> toggleSantriStatus(String id, bool active) async {
    final db = await database;
    await db.update(
      'santri',
      {'status_aktif': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
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
  }) async {
    final db = await database;
    final santriMaps = await db.query('santri', where: 'id = ?', whereArgs: [santriId]);
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

    await db.update(
      'santri',
      {
        'tunggakan': newTunggakan,
        'catatan_tunggakan': newCatatan,
      },
      where: 'id = ?',
      whereArgs: [santriId],
    );
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
      await txn.insert('setoran_bulanan', setoran.toMap());

      final santriMaps = await txn.query('santri', where: 'id = ?', whereArgs: [santriId]);
      if (santriMaps.isEmpty) throw Exception('Santri tidak ditemukan');
      final currentSantri = Santri.fromMap(santriMaps.first);

      int saldoBaru = currentSantri.saldoTotal + nominalSetoran;
      int jatahBaru = currentSantri.jatahHarian;

      if (tipeSetoran == TipeSetoran.awalBulan) {
        if (perlakuanSisa == PerlakuanSisaSaldoLalu.simpanTabungan) {
          saldoBaru = nominalSetoran;
        }
        jatahBaru = jatahHarianHitung;
      } else {
        if (opsiSusulan == OpsiSetoranSusulan.tambahJatahHarian) {
          final tambahanJatah = durasiHari > 0 ? (nominalSetoran / durasiHari).round() : 0;
          jatahBaru += tambahanJatah;
        }
      }

      await txn.update(
        'santri',
        {
          'saldo_total': saldoBaru,
          'jatah_harian': jatahBaru,
        },
        where: 'id = ?',
        whereArgs: [santriId],
      );

      final now = DateTime.now();
      final transaksiMutasi = TransaksiHarian(
        id: transaksiId,
        santriId: santriId,
        nominal: nominalSetoran,
        waktuAmbil: now,
        tanggalLokal: DateFormatter.toLocalDateString(tanggalSetor),
        kategoriWaktu: TimeCategory.setoran,
        catatan: catatan ?? (tipeSetoran == TipeSetoran.awalBulan ? 'Setoran Awal Bulan' : 'Top-Up Susulan'),
        saldoSetelahTransaksi: saldoBaru,
        tipe: TipeTransaksi.setoran,
      );
      await txn.insert('transaksi_harian', transaksiMutasi.toMap());
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

      final saldoBaru = santri.saldoTotal - nominal;

      transaksi = TransaksiHarian(
        id: id,
        santriId: santriId,
        nominal: nominal,
        waktuAmbil: waktu,
        tanggalLokal: tanggalLokal,
        kategoriWaktu: kategoriWaktu,
        isOverlimit: isOverlimit,
        catatan: catatan,
        isVoided: false,
        overlimitHandling: overlimitHandling,
        saldoSetelahTransaksi: saldoBaru,
        tipe: TipeTransaksi.pengambilan,
      );

      await txn.insert('transaksi_harian', transaksi.toMap());

      Map<String, dynamic> updateData = {'saldo_total': saldoBaru};

      if (isOverlimit && overlimitHandling == OverlimitHandling.hitungUlangRataRata) {
        const sisaHariPeriode = 20;
        if (saldoBaru > 0) {
          final jatahBaru = (saldoBaru / sisaHariPeriode).round();
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
        {'is_voided': 1},
        where: 'id = ?',
        whereArgs: [transaksiId],
      );

      final santriMaps = await txn.query('santri', where: 'id = ?', whereArgs: [tx.santriId]);
      if (santriMaps.isNotEmpty) {
        final currentSaldo = santriMaps.first['saldo_total'] as int;
        final restoredSaldo = tx.tipe == TipeTransaksi.pengambilan
            ? currentSaldo + tx.nominal
            : currentSaldo - tx.nominal;

        await txn.update(
          'santri',
          {'saldo_total': restoredSaldo},
          where: 'id = ?',
          whereArgs: [tx.santriId],
        );
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
        AND is_voided = 0 
        AND tipe = 'PENGAMBILAN'
    ''', [santriId, tanggalLokal]);

    final total = result.first['total'];
    return (total as num?)?.toInt() ?? 0;
  }

  Future<List<TransaksiHarian>> getTransaksiHariIni(String santriId, String tanggalLokal) async {
    final db = await database;
    final maps = await db.query(
      'transaksi_harian',
      where: 'santri_id = ? AND tanggal_lokal = ? AND is_voided = 0 AND tipe = "PENGAMBILAN"',
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
    String where = 'is_voided = 0';
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
      WHERE is_voided = 0
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
        AND is_voided = 0 
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
        AND is_voided = 0 
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
        AND is_voided = 0 
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
        AND is_voided = 0 
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
      WHERE tanggal_lokal = ? AND is_voided = 0 AND tipe = 'PENGAMBILAN'
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
      WHERE t.tanggal_lokal = ? AND t.is_voided = 0
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
      WHERE tanggal_lokal LIKE ? AND is_voided = 0 AND tipe = 'PENGAMBILAN'
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
    final pengaturanList = await db.query('pengaturan_aplikasi');

    return {
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'santri': santriList,
      'setoran_bulanan': setoranList,
      'transaksi_harian': transaksiList,
      'pengaturan_aplikasi': pengaturanList,
    };
  }

  Future<void> restoreFromJson(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transaksi_harian');
      await txn.delete('setoran_bulanan');
      await txn.delete('santri');
      await txn.delete('pengaturan_aplikasi');

      if (data['santri'] != null) {
        for (var row in data['santri'] as List) {
          await txn.insert('santri', Map<String, dynamic>.from(row));
        }
      }
      if (data['setoran_bulanan'] != null) {
        for (var row in data['setoran_bulanan'] as List) {
          await txn.insert('setoran_bulanan', Map<String, dynamic>.from(row));
        }
      }
      if (data['transaksi_harian'] != null) {
        for (var row in data['transaksi_harian'] as List) {
          await txn.insert('transaksi_harian', Map<String, dynamic>.from(row));
        }
      }
      if (data['pengaturan_aplikasi'] != null) {
        for (var row in data['pengaturan_aplikasi'] as List) {
          await txn.insert('pengaturan_aplikasi', Map<String, dynamic>.from(row));
        }
      }
    });
  }

  Future<void> resetToInitialDemoData() async {
    final db = await database;
    await db.transaction((txn) async {
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
      'pin_keamanan': '1234',
      'is_biometric_enabled': 0,
      'auto_lock_minutes': 1,
      'logo_path': null,
      'is_two_col_grid': 1,
      'hide_balance': 0,
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
  }
}
