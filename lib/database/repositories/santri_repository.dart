import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/pengaturan.dart';
import '../../models/santri.dart';
import '../../utils/date_formatter.dart';

class SantriRepository {
  final Future<Database> Function() _getDb;

  const SantriRepository(this._getDb);

  static String normalizeDompet(String raw) {
    final upper = raw.toUpperCase().trim();
    if (upper == 'REKENING' || upper == 'BANK' || upper == 'TRANSFER') {
      return 'REKENING';
    }
    return 'TUNAI';
  }

  Future<List<Santri>> getAllSantri({bool onlyActive = true}) async {
    final db = await _getDb();
    final where = onlyActive ? 'status_aktif = 1' : null;
    final maps = await db.query(
      'santri',
      where: where,
      orderBy: 'kamar ASC, nama_lengkap ASC',
    );
    return maps.map((m) => Santri.fromMap(m)).toList();
  }

  Future<Santri?> getSantriById(String id) async {
    final db = await _getDb();
    final maps = await db.query('santri', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Santri.fromMap(maps.first);
    }
    return null;
  }

  Future<Santri?> getSantriByQrCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    final db = await _getDb();
    final maps = await db.query(
      'santri',
      where: '(UPPER(qr_code) = ? OR UPPER(id) = ?) AND status_aktif = 1',
      whereArgs: [code, code],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Santri.fromMap(maps.first);
  }

  Future<int> insertSantri(
    Santri santri, {
    String sumberDompet = 'TUNAI',
  }) async {
    final db = await _getDb();
    final dompet = normalizeDompet(sumberDompet);
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
    final db = await _getDb();
    return await db.update(
      'santri',
      santri.toMap(),
      where: 'id = ?',
      whereArgs: [santri.id],
    );
  }

  Future<void> updateSantriFoto(String santriId, String? fotoPath) async {
    final db = await _getDb();
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
    final db = await _getDb();
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
    final db = await _getDb();
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
    final db = await _getDb();
    final dompet = normalizeDompet(sumberDompet);
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
      await txn.delete(
        'infak_santri',
        where: 'santri_id = ?',
        whereArgs: [santriId],
      );
      await txn.delete(
        'tunggakan_log',
        where: 'santri_id = ?',
        whereArgs: [santriId],
      );
      await txn.delete(
        'transaksi_harian',
        where: 'santri_id = ?',
        whereArgs: [santriId],
      );
      await txn.delete(
        'setoran_bulanan',
        where: 'santri_id = ?',
        whereArgs: [santriId],
      );
      await txn.delete('santri', where: 'id = ?', whereArgs: [santriId]);
    });
    return refundedSaldo;
  }

  Future<List<String>> getAllKamars() async {
    final db = await _getDb();
    final maps = await db.rawQuery(
      'SELECT DISTINCT kamar FROM santri ORDER BY kamar ASC',
    );
    return maps.map((m) => m['kamar'] as String).toList();
  }

  Future<int> bulkInsertSantri(
    List<Santri> santriList, {
    String sumberDompet = 'TUNAI',
  }) async {
    if (santriList.isEmpty) return 0;
    final db = await _getDb();
    final dompet = normalizeDompet(sumberDompet);
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
    final db = await _getDb();
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
    final db = await _getDb();
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

  Future<PengaturanAplikasi> getPengaturan() async {
    final db = await _getDb();
    final maps = await db.query('pengaturan_aplikasi', where: 'id = 1');
    if (maps.isNotEmpty) {
      return PengaturanAplikasi.fromMap(maps.first);
    }
    return PengaturanAplikasi();
  }

  Future<void> updatePengaturan(PengaturanAplikasi pengaturan) async {
    final db = await _getDb();
    await db.update(
      'pengaturan_aplikasi',
      pengaturan.toMap(),
      where: 'id = 1',
    );
  }
}
