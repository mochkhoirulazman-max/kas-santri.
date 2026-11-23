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
    _database = await _initDB('kas_santri.db');
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
        pin_keamanan TEXT,
        is_biometric_enabled INTEGER NOT NULL DEFAULT 0,
        auto_lock_minutes INTEGER NOT NULL DEFAULT 1
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
      'nama_pondok': 'Pondok Pesantren Darul Falah',
      'nama_pengurus': 'Ustadz Abdullah',
      'kontak_pengurus': '081234567890',
      'default_jatah_harian': 10000,
      'default_durasi_hari': 30,
      'mode_sisa_harian': 'KETAT',
      'pin_keamanan': null,
      'is_biometric_enabled': 0,
      'auto_lock_minutes': 1,
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
      // 1. Simpan record setoran_bulanan
      await txn.insert('setoran_bulanan', setoran.toMap());

      // 2. Ambil data santri saat ini
      final santriMaps = await txn.query('santri', where: 'id = ?', whereArgs: [santriId]);
      if (santriMaps.isEmpty) throw Exception('Santri tidak ditemukan');
      final currentSantri = Santri.fromMap(santriMaps.first);

      int saldoBaru = currentSantri.saldoTotal + nominalSetoran;
      int jatahBaru = currentSantri.jatahHarian;

      if (tipeSetoran == TipeSetoran.awalBulan) {
        // Jika sisa bulan lalu disimpan sebagai tabungan terpisah, saldo awal di-reset ke setoran baru
        if (perlakuanSisa == PerlakuanSisaSaldoLalu.simpanTabungan) {
          saldoBaru = nominalSetoran;
        }
        jatahBaru = jatahHarianHitung;
      } else {
        // Setoran Susulan
        if (opsiSusulan == OpsiSetoranSusulan.tambahJatahHarian) {
          // Tambah jatah harian dari nominal susulan dibagi sisa durasi
          final tambahanJatah = durasiHari > 0 ? (nominalSetoran / durasiHari).round() : 0;
          jatahBaru += tambahanJatah;
        }
        // Jika perpanjang hari, jatah harian tetap, saldo total bertambah
      }

      // 3. Update saldo & jatah santri
      await txn.update(
        'santri',
        {
          'saldo_total': saldoBaru,
          'jatah_harian': jatahBaru,
        },
        where: 'id = ?',
        whereArgs: [santriId],
      );

      // 4. Catat juga ke transaksi_harian sebagai mutasi pemasukan
      final now = DateTime.now();
      final transaksiMutasi = TransaksiHarian(
        id: transaksiId,
        santriId: santriId,
        nominal: nominalSetoran,
        waktuAmbil: now,
        tanggalLokal: DateFormatter.toLocalDateString(tanggalSetor),
        kategoriWaktu: TimeCategoryHelper.fromDateTime(now),
        catatan: catatan ?? (tipeSetoran == TipeSetoran.awalBulan ? 'Setoran Awal Bulan' : 'Setoran Susulan Top-Up'),
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

  // ==================== TRANSAKSI & AMBIL UANG (FASE 1 & 3) ====================

  Future<TransaksiHarian> catatPengambilan({
    required String santriId,
    required int nominal,
    String? catatan,
    bool isOverlimit = false,
    OverlimitHandling? overlimitHandling,
    DateTime? customTimestamp,
  }) async {
    final db = await database;
    final id = const Uuid().v4();
    final waktu = customTimestamp ?? DateTime.now();
    final tanggalLokal = DateFormatter.toLocalDateString(waktu);
    final kategoriWaktu = TimeCategoryHelper.fromDateTime(waktu);

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

      // 1. Simpan transaksi
      await txn.insert('transaksi_harian', transaksi.toMap());

      // 2. Update saldo santri
      Map<String, dynamic> updateData = {'saldo_total': saldoBaru};

      // Jika overlimit dan dipilih hitung ulang rata-rata
      if (isOverlimit && overlimitHandling == OverlimitHandling.hitungUlangRataRata) {
        // Jatah harian baru = Saldo akhir / sisa hari (asumsi default 15 hari sisa periode jika tidak spesifik)
        const sisaHariPeriode = 15;
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

  /// Membatalkan / Void transaksi (Fitur Undo 5 detik & Pembatalan Pengurus)
  Future<void> voidTransaksi(String transaksiId) async {
    final db = await database;
    await db.transaction((txn) async {
      final txMaps = await txn.query('transaksi_harian', where: 'id = ?', whereArgs: [transaksiId]);
      if (txMaps.isEmpty) return;
      final tx = TransaksiHarian.fromMap(txMaps.first);
      if (tx.isVoided) return; // Sudah pernah dibatalkan

      // 1. Tandai transaksi batal
      await txn.update(
        'transaksi_harian',
        {'is_voided': 1},
        where: 'id = ?',
        whereArgs: [transaksiId],
      );

      // 2. Kembalikan saldo santri
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

  /// Menyesuaikan / Edit transaksi jika ada kesalahan input nominal
  Future<void> editTransaksi(String transaksiId, int nominalBaru, String? catatanBaru) async {
    final db = await database;
    await db.transaction((txn) async {
      final txMaps = await txn.query('transaksi_harian', where: 'id = ?', whereArgs: [transaksiId]);
      if (txMaps.isEmpty) return;
      final tx = TransaksiHarian.fromMap(txMaps.first);
      if (tx.isVoided) return;

      final selisih = nominalBaru - tx.nominal;

      await txn.update(
        'transaksi_harian',
        {
          'nominal': nominalBaru,
          'catatan': catatanBaru,
        },
        where: 'id = ?',
        whereArgs: [transaksiId],
      );

      final santriMaps = await txn.query('santri', where: 'id = ?', whereArgs: [tx.santriId]);
      if (santriMaps.isNotEmpty) {
        final currentSaldo = santriMaps.first['saldo_total'] as int;
        final updatedSaldo = tx.tipe == TipeTransaksi.pengambilan
            ? currentSaldo - selisih
            : currentSaldo + selisih;

        await txn.update(
          'santri',
          {'saldo_total': updatedSaldo},
          where: 'id = ?',
          whereArgs: [tx.santriId],
        );
      }
    });
  }

  /// Ambil total pengambilan santri pada tanggal tertentu
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

  /// Ambil transaksi santri pada hari ini
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

  /// Buku mutasi digital lengkap per santri
  Future<List<TransaksiHarian>> getBukuMutasiSantri(
    String santriId, {
    String? tanggalMulai,
    String? tanggalSelesai,
  }) async {
    final db = await database;
    String where = 'santri_id = ?';
    List<dynamic> whereArgs = [santriId];

    if (tanggalMulai != null && tanggalSelesai != null) {
      where += ' AND tanggal_lokal BETWEEN ? AND ?';
      whereArgs.addAll([tanggalMulai, tanggalSelesai]);
    }

    final maps = await db.query(
      'transaksi_harian',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'waktu_ambil DESC',
    );
    return maps.map((m) => TransaksiHarian.fromMap(m)).toList();
  }

  /// Riwayat transaksi santri yang paling baru (untuk tampilan transaksi terakhir)
  Future<List<Map<String, dynamic>>> getRecentTransactedSantriIds({int limit = 5}) async {
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

  // ==================== REKAP & LAPORAN AUDIT (FASE 4) ====================

  /// Total Sisa Saldo Seluruh Santri Aktif (Brankas Fisik)
  Future<int> getTotalSaldoBrankasFisik() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(saldo_total) as total_brankas
      FROM santri
      WHERE status_aktif = 1
    ''');
    final total = result.first['total_brankas'];
    return (total as num?)?.toInt() ?? 0;
  }

  /// Total Uang Tunai yang Keluar Hari Ini dari seluruh santri
  Future<int> getTotalPengeluaranHariIni(String tanggalLokal) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(nominal) as total_keluar
      FROM transaksi_harian
      WHERE tanggal_lokal = ? 
        AND is_voided = 0 
        AND tipe = 'PENGAMBILAN'
    ''', [tanggalLokal]);
    final total = result.first['total_keluar'];
    return (total as num?)?.toInt() ?? 0;
  }

  /// Jumlah transaksi pengambilan hari ini
  Future<int> getJumlahTransaksiHariIni(String tanggalLokal) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as jumlah
      FROM transaksi_harian
      WHERE tanggal_lokal = ? 
        AND is_voided = 0 
        AND tipe = 'PENGAMBILAN'
    ''', [tanggalLokal]);
    final count = result.first['jumlah'];
    return (count as num?)?.toInt() ?? 0;
  }

  /// Rekap pengeluaran harian per kategori (Jajan, Sabun, Obat, dll.)
  Future<Map<String, int>> getRekapKategoriHariIni(String tanggalLokal) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT COALESCE(catatan, 'Lainnya') as kategori, SUM(nominal) as total
      FROM transaksi_harian
      WHERE tanggal_lokal = ? 
        AND is_voided = 0 
        AND tipe = 'PENGAMBILAN'
      GROUP BY kategori
    ''', [tanggalLokal]);

    Map<String, int> rekap = {};
    for (var r in results) {
      final kat = r['kategori'] as String;
      final tot = (r['total'] as num?)?.toInt() ?? 0;
      rekap[kat] = tot;
    }
    return rekap;
  }

  /// Rekap Bulanan (Pemasukan setoran vs Pengeluaran penarikan)
  Future<Map<String, int>> getRekapBulanan(int tahun, int bulan) async {
    final db = await database;
    final bulanStr = bulan.toString().padLeft(2, '0');
    final prefix = '$tahun-$bulanStr';

    final resultKeluar = await db.rawQuery('''
      SELECT SUM(nominal) as total
      FROM transaksi_harian
      WHERE tanggal_lokal LIKE '$prefix%' 
        AND is_voided = 0 
        AND tipe = 'PENGAMBILAN'
    ''');
    final totalKeluar = (resultKeluar.first['total'] as num?)?.toInt() ?? 0;

    final resultMasuk = await db.rawQuery('''
      SELECT SUM(nominal_setoran) as total
      FROM setoran_bulanan
      WHERE tanggal_setor LIKE '$prefix%'
    ''');
    final totalMasuk = (resultMasuk.first['total'] as num?)?.toInt() ?? 0;

    return {
      'pemasukan': totalMasuk,
      'pengeluaran': totalKeluar,
      'net': totalMasuk - totalKeluar,
    };
  }

  /// Ambil seluruh transaksi pada tanggal tertentu (beserta nama & kamar santri)
  Future<List<Map<String, dynamic>>> getDetailTransaksiTanggal(String tanggalLokal) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.*, s.nama_lengkap, s.nama_panggilan, s.kamar
      FROM transaksi_harian t
      JOIN santri s ON t.santri_id = s.id
      WHERE t.tanggal_lokal = ?
      ORDER BY t.waktu_ambil DESC
    ''', [tanggalLokal]);
  }

  // ==================== PENGATURAN (FASE 5) ====================

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
      'version': 1,
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

  Future<void> seedDemoData() async {
    final db = await database;
    final existing = await db.query('santri');
    if (existing.isNotEmpty) return; // Jangan timpah jika sudah ada santri

    final santriDemo = [
      Santri(
        id: '1',
        namaLengkap: 'Ahmad Fauzi',
        namaPanggilan: 'Ahmad',
        kamar: 'Kamar Abu Bakar (01)',
        noWaWali: '628123456701',
        saldoTotal: 285000,
        jatahHarian: 10000,
      ),
      Santri(
        id: '2',
        namaLengkap: 'Muhammad Rizky',
        namaPanggilan: 'Rizky',
        kamar: 'Kamar Abu Bakar (01)',
        noWaWali: '628123456702',
        saldoTotal: 300000,
        jatahHarian: 10000,
      ),
      Santri(
        id: '3',
        namaLengkap: 'Fikri Haikal',
        namaPanggilan: 'Haikal',
        kamar: 'Kamar Umar bin Khattab (02)',
        noWaWali: '628123456703',
        saldoTotal: 150000,
        jatahHarian: 10000,
      ),
      Santri(
        id: '4',
        namaLengkap: 'Zaid bin Tsabit',
        namaPanggilan: 'Zaid',
        kamar: 'Kamar Umar bin Khattab (02)',
        noWaWali: '628123456704',
        saldoTotal: 5000,
        jatahHarian: 10000,
      ),
      Santri(
        id: '5',
        namaLengkap: 'Bilal Al-Habasyi',
        namaPanggilan: 'Bilal',
        kamar: 'Kamar Utsman bin Affan (03)',
        noWaWali: '628123456705',
        saldoTotal: 420000,
        jatahHarian: 12000,
      ),
      Santri(
        id: '6',
        namaLengkap: 'Ali Zainal Abidin',
        namaPanggilan: 'Ali',
        kamar: 'Kamar Ali bin Abi Thalib (04)',
        noWaWali: '628123456706',
        saldoTotal: 290000,
        jatahHarian: 10000,
      ),
    ];

    for (var s in santriDemo) {
      await db.insert('santri', s.toMap());
    }

    final today = DateFormatter.toLocalDateString(DateTime.now());
    final now = DateTime.now();

    // Transaksi pagi untuk Ahmad (Rp 2.000)
    final txAhmad1 = TransaksiHarian(
      id: const Uuid().v4(),
      santriId: '1',
      nominal: 2000,
      waktuAmbil: DateTime(now.year, now.month, now.day, 7, 30),
      tanggalLokal: today,
      kategoriWaktu: TimeCategory.pagi,
      catatan: 'Jajan',
      saldoSetelahTransaksi: 288000,
    );
    await db.insert('transaksi_harian', txAhmad1.toMap());

    // Transaksi siang untuk Ahmad (Rp 5.000)
    final txAhmad2 = TransaksiHarian(
      id: const Uuid().v4(),
      santriId: '1',
      nominal: 5000,
      waktuAmbil: DateTime(now.year, now.month, now.day, 12, 45),
      tanggalLokal: today,
      kategoriWaktu: TimeCategory.siang,
      catatan: 'Beli Sabun/Toiletries',
      saldoSetelahTransaksi: 285000,
    );
    await db.insert('transaksi_harian', txAhmad2.toMap());
  }
}
