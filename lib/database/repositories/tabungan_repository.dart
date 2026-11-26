import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/santri.dart';
import '../../models/transaksi_tabungan.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import 'santri_repository.dart';

/// Repository modular untuk mengelola Brankas Tabungan Terpisah (Kantong Kas ke-4)
/// yang terisolasi penuh dari saldo uang jajan harian dan mendukung transfer dua arah
/// serta rekonsiliasi saldo tunai/rekening melalui agregasi SQL.
class TabunganRepository {
  final Future<Database> Function() _getDb;

  const TabunganRepository(this._getDb);

  Future<Map<String, int>> getSaldoBrankasTabungan() async {
    final db = await _getDb();
    try {
      final agg = await db.rawQuery('''
        SELECT
          COALESCE(SUM(CASE
            WHEN UPPER(TRIM(sumber_dompet)) NOT IN ('REKENING', 'BANK', 'TRANSFER') THEN
              CASE
                WHEN tipe IN ('${TransaksiTabungan.tipeSetor}', '${TransaksiTabungan.tipeTransferDariJajan}') THEN nominal
                WHEN tipe IN ('${TransaksiTabungan.tipeTarik}', '${TransaksiTabungan.tipeTransferKeJajan}') THEN -nominal
                ELSE 0
              END
            ELSE 0
          END), 0) AS tunai,
          COALESCE(SUM(CASE
            WHEN UPPER(TRIM(sumber_dompet)) IN ('REKENING', 'BANK', 'TRANSFER') THEN
              CASE
                WHEN tipe IN ('${TransaksiTabungan.tipeSetor}', '${TransaksiTabungan.tipeTransferDariJajan}') THEN nominal
                WHEN tipe IN ('${TransaksiTabungan.tipeTarik}', '${TransaksiTabungan.tipeTransferKeJajan}') THEN -nominal
                ELSE 0
              END
            ELSE 0
          END), 0) AS rekening
        FROM transaksi_tabungan
        WHERE is_void = 0
      ''');

      final row = agg.isNotEmpty ? agg.first : const <String, Object?>{};
      final tunai = (row['tunai'] as num?)?.toInt() ?? 0;
      final rekening = (row['rekening'] as num?)?.toInt() ?? 0;
      return {
        'tunai': tunai,
        'rekening': rekening,
        'total': tunai + rekening,
      };
    } catch (_) {
      return {'tunai': 0, 'rekening': 0, 'total': 0};
    }
  }

  Future<TransaksiTabungan> setorTabungan({
    required String santriId,
    required int nominal,
    String sumberDompet = 'TUNAI',
    String? catatan,
    DateTime? customTimestamp,
  }) async {
    if (nominal <= 0) {
      throw ArgumentError('Nominal setoran tabungan harus lebih dari Rp 0.');
    }
    final db = await _getDb();
    final dompet = SantriRepository.normalizeDompet(sumberDompet);
    final now = customTimestamp ?? DateTime.now();
    final tglLokal = DateFormatter.toLocalDateString(now);

    late TransaksiTabungan created;
    await db.transaction((txn) async {
      final santriMaps = await txn.query(
        'santri',
        where: 'id = ?',
        whereArgs: [santriId],
      );
      if (santriMaps.isEmpty) {
        throw Exception('Santri tidak ditemukan');
      }
      final santri = Santri.fromMap(santriMaps.first);
      final newTabungan = santri.saldoTabungan + nominal;

      await txn.update(
        'santri',
        {'saldo_tabungan': newTabungan},
        where: 'id = ?',
        whereArgs: [santriId],
      );

      created = TransaksiTabungan(
        id: const Uuid().v4(),
        santriId: santriId,
        tipe: TransaksiTabungan.tipeSetor,
        nominal: nominal,
        sumberDompet: dompet,
        saldoTabunganSetelah: newTabungan,
        tanggalLokal: tglLokal,
        catatan: catatan?.trim().isNotEmpty == true
            ? catatan!.trim()
            : 'Setor Tabungan Terpisah',
        isVoided: false,
        createdAt: now,
        namaSantri: santri.namaLengkap,
        kamarSantri: santri.kamar,
      );
      await txn.insert('transaksi_tabungan', created.toMap());
    });
    return created;
  }

  Future<TransaksiTabungan> tarikTabungan({
    required String santriId,
    required int nominal,
    String sumberDompet = 'TUNAI',
    String? catatan,
    DateTime? customTimestamp,
  }) async {
    if (nominal <= 0) {
      throw ArgumentError('Nominal penarikan tabungan harus lebih dari Rp 0.');
    }
    final db = await _getDb();
    final dompet = SantriRepository.normalizeDompet(sumberDompet);
    final now = customTimestamp ?? DateTime.now();
    final tglLokal = DateFormatter.toLocalDateString(now);

    late TransaksiTabungan created;
    await db.transaction((txn) async {
      final santriMaps = await txn.query(
        'santri',
        where: 'id = ?',
        whereArgs: [santriId],
      );
      if (santriMaps.isEmpty) {
        throw Exception('Santri tidak ditemukan');
      }
      final santri = Santri.fromMap(santriMaps.first);
      if (nominal > santri.saldoTabungan) {
        throw Exception(
          'Saldo tabungan ${santri.namaLengkap} (${CurrencyFormatter.format(santri.saldoTabungan)}) tidak mencukupi untuk penarikan ${CurrencyFormatter.format(nominal)}.',
        );
      }
      final newTabungan = santri.saldoTabungan - nominal;

      await txn.update(
        'santri',
        {'saldo_tabungan': newTabungan},
        where: 'id = ?',
        whereArgs: [santriId],
      );

      created = TransaksiTabungan(
        id: const Uuid().v4(),
        santriId: santriId,
        tipe: TransaksiTabungan.tipeTarik,
        nominal: nominal,
        sumberDompet: dompet,
        saldoTabunganSetelah: newTabungan,
        tanggalLokal: tglLokal,
        catatan: catatan?.trim().isNotEmpty == true
            ? catatan!.trim()
            : 'Tarik Tabungan Santri',
        isVoided: false,
        createdAt: now,
        namaSantri: santri.namaLengkap,
        kamarSantri: santri.kamar,
      );
      await txn.insert('transaksi_tabungan', created.toMap());
    });
    return created;
  }

  Future<TransaksiTabungan> transferJajanKeTabungan({
    required String santriId,
    required int nominal,
    String sumberDompet = 'TUNAI',
    String? catatan,
    DateTime? customTimestamp,
  }) async {
    if (nominal <= 0) {
      throw ArgumentError('Nominal pemindahan harus lebih dari Rp 0.');
    }
    final db = await _getDb();
    final dompet = SantriRepository.normalizeDompet(sumberDompet);
    final now = customTimestamp ?? DateTime.now();
    final tglLokal = DateFormatter.toLocalDateString(now);

    late TransaksiTabungan created;
    await db.transaction((txn) async {
      final santriMaps = await txn.query(
        'santri',
        where: 'id = ?',
        whereArgs: [santriId],
      );
      if (santriMaps.isEmpty) {
        throw Exception('Santri tidak ditemukan');
      }
      final santri = Santri.fromMap(santriMaps.first);
      if (nominal > santri.saldoTotal) {
        throw Exception(
          'Saldo uang jajan ${santri.namaLengkap} (${CurrencyFormatter.format(santri.saldoTotal)}) tidak mencukupi.',
        );
      }

      final newSaldoJajan = santri.saldoTotal - nominal;
      final newSaldoTabungan = santri.saldoTabungan + nominal;
      final txTabunganId = const Uuid().v4();
      final noteText = catatan?.trim().isNotEmpty == true
          ? catatan!.trim()
          : 'Pindah Saldo Jajan ke Tabungan';

      await txn.update(
        'santri',
        {
          'saldo_total': newSaldoJajan,
          'saldo_tabungan': newSaldoTabungan,
        },
        where: 'id = ?',
        whereArgs: [santriId],
      );

      await txn.insert('mutasi_dompet', {
        'id': const Uuid().v4(),
        'jenis_dompet': dompet,
        'tipe': 'KELUAR',
        'nominal': nominal,
        'referensi_id': txTabunganId,
        'catatan': 'Pindah ke Brankas Tabungan (${santri.namaLengkap})',
        'tanggal_lokal': tglLokal,
        'created_at': now.toIso8601String(),
      });

      created = TransaksiTabungan(
        id: txTabunganId,
        santriId: santriId,
        tipe: TransaksiTabungan.tipeTransferDariJajan,
        nominal: nominal,
        sumberDompet: dompet,
        saldoTabunganSetelah: newSaldoTabungan,
        tanggalLokal: tglLokal,
        catatan: noteText,
        isVoided: false,
        createdAt: now,
        namaSantri: santri.namaLengkap,
        kamarSantri: santri.kamar,
      );
      await txn.insert('transaksi_tabungan', created.toMap());
    });
    return created;
  }

  Future<TransaksiTabungan> transferTabunganKeJajan({
    required String santriId,
    required int nominal,
    String sumberDompet = 'TUNAI',
    String? catatan,
    DateTime? customTimestamp,
  }) async {
    if (nominal <= 0) {
      throw ArgumentError('Nominal pemindahan harus lebih dari Rp 0.');
    }
    final db = await _getDb();
    final dompet = SantriRepository.normalizeDompet(sumberDompet);
    final now = customTimestamp ?? DateTime.now();
    final tglLokal = DateFormatter.toLocalDateString(now);

    late TransaksiTabungan created;
    await db.transaction((txn) async {
      final santriMaps = await txn.query(
        'santri',
        where: 'id = ?',
        whereArgs: [santriId],
      );
      if (santriMaps.isEmpty) {
        throw Exception('Santri tidak ditemukan');
      }
      final santri = Santri.fromMap(santriMaps.first);
      if (nominal > santri.saldoTabungan) {
        throw Exception(
          'Saldo tabungan ${santri.namaLengkap} (${CurrencyFormatter.format(santri.saldoTabungan)}) tidak mencukupi.',
        );
      }

      final newSaldoJajan = santri.saldoTotal + nominal;
      final newSaldoTabungan = santri.saldoTabungan - nominal;
      final txTabunganId = const Uuid().v4();
      final noteText = catatan?.trim().isNotEmpty == true
          ? catatan!.trim()
          : 'Pindah Tabungan ke Saldo Jajan';

      await txn.update(
        'santri',
        {
          'saldo_total': newSaldoJajan,
          'saldo_tabungan': newSaldoTabungan,
        },
        where: 'id = ?',
        whereArgs: [santriId],
      );

      await txn.insert('mutasi_dompet', {
        'id': const Uuid().v4(),
        'jenis_dompet': dompet,
        'tipe': 'MASUK',
        'nominal': nominal,
        'referensi_id': txTabunganId,
        'catatan': 'Masuk dari Brankas Tabungan (${santri.namaLengkap})',
        'tanggal_lokal': tglLokal,
        'created_at': now.toIso8601String(),
      });

      created = TransaksiTabungan(
        id: txTabunganId,
        santriId: santriId,
        tipe: TransaksiTabungan.tipeTransferKeJajan,
        nominal: nominal,
        sumberDompet: dompet,
        saldoTabunganSetelah: newSaldoTabungan,
        tanggalLokal: tglLokal,
        catatan: noteText,
        isVoided: false,
        createdAt: now,
        namaSantri: santri.namaLengkap,
        kamarSantri: santri.kamar,
      );
      await txn.insert('transaksi_tabungan', created.toMap());
    });
    return created;
  }

  Future<void> voidTransaksiTabungan(String txId) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'transaksi_tabungan',
        where: 'id = ?',
        whereArgs: [txId],
      );
      if (rows.isEmpty) return;
      final tx = TransaksiTabungan.fromMap(rows.first);
      if (tx.isVoided) return;

      final santriMaps = await txn.query(
        'santri',
        where: 'id = ?',
        whereArgs: [tx.santriId],
      );
      if (santriMaps.isEmpty) {
        await txn.update(
          'transaksi_tabungan',
          {'is_void': 1},
          where: 'id = ?',
          whereArgs: [txId],
        );
        return;
      }

      final santri = Santri.fromMap(santriMaps.first);
      final dompet = SantriRepository.normalizeDompet(tx.sumberDompet);
      final now = DateTime.now();
      final tglNow = DateFormatter.toLocalDateString(now);

      int newSaldoTabungan = santri.saldoTabungan;
      int newSaldoJajan = santri.saldoTotal;

      switch (tx.tipe) {
        case TransaksiTabungan.tipeSetor:
          if (santri.saldoTabungan < tx.nominal) {
            throw Exception(
              'Sebagian saldo tabungan ${santri.namaLengkap} sudah ditarik. Batalkan penarikan terlebih dahulu agar saldo tidak negatif.',
            );
          }
          newSaldoTabungan -= tx.nominal;
          break;
        case TransaksiTabungan.tipeTarik:
          newSaldoTabungan += tx.nominal;
          break;
        case TransaksiTabungan.tipeTransferDariJajan:
          if (santri.saldoTabungan < tx.nominal) {
            throw Exception(
              'Saldo tabungan ${santri.namaLengkap} saat ini lebih kecil dari nominal transfer yang akan dibatalkan.',
            );
          }
          newSaldoTabungan -= tx.nominal;
          newSaldoJajan += tx.nominal;
          await txn.insert('mutasi_dompet', {
            'id': const Uuid().v4(),
            'jenis_dompet': dompet,
            'tipe': 'MASUK',
            'nominal': tx.nominal,
            'referensi_id': tx.id,
            'catatan':
                'Void Transfer Jajan -> Tabungan (${santri.namaLengkap})',
            'tanggal_lokal': tglNow,
            'created_at': now.toIso8601String(),
          });
          break;
        case TransaksiTabungan.tipeTransferKeJajan:
          if (santri.saldoTotal < tx.nominal) {
            throw Exception(
              'Saldo uang jajan ${santri.namaLengkap} saat ini lebih kecil dari nominal transfer yang akan dibatalkan.',
            );
          }
          newSaldoTabungan += tx.nominal;
          newSaldoJajan -= tx.nominal;
          await txn.insert('mutasi_dompet', {
            'id': const Uuid().v4(),
            'jenis_dompet': dompet,
            'tipe': 'KELUAR',
            'nominal': tx.nominal,
            'referensi_id': tx.id,
            'catatan':
                'Void Transfer Tabungan -> Jajan (${santri.namaLengkap})',
            'tanggal_lokal': tglNow,
            'created_at': now.toIso8601String(),
          });
          break;
      }

      await txn.update(
        'santri',
        {
          'saldo_tabungan': newSaldoTabungan,
          'saldo_total': newSaldoJajan,
        },
        where: 'id = ?',
        whereArgs: [tx.santriId],
      );

      await txn.update(
        'transaksi_tabungan',
        {'is_void': 1},
        where: 'id = ?',
        whereArgs: [txId],
      );
    });
  }

  Future<List<TransaksiTabungan>> getTransaksiTabungan({
    String? santriId,
    int limit = 120,
  }) async {
    final db = await _getDb();
    try {
      final where =
          (santriId != null && santriId.isNotEmpty) ? 'WHERE t.santri_id = ?' : '';
      final args = (santriId != null && santriId.isNotEmpty)
          ? <Object?>[santriId, limit]
          : <Object?>[limit];
      final rows = await db.rawQuery('''
        SELECT t.*, s.nama_lengkap AS nama_santri, s.kamar AS kamar_santri
        FROM transaksi_tabungan t
        LEFT JOIN santri s ON t.santri_id = s.id
        $where
        ORDER BY t.created_at DESC, t.rowid DESC
        LIMIT ?
      ''', args);
      return rows.map((r) => TransaksiTabungan.fromMap(r)).toList();
    } catch (_) {
      return const [];
    }
  }
}
