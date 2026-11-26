import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/infak_santri.dart';
import '../../models/pengaturan.dart';
import '../../models/santri.dart';
import '../../models/serah_terima_infak.dart';
import '../../models/setoran.dart';
import '../../models/transaksi.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/time_category_helper.dart';
import 'santri_repository.dart';

class InfakRepository {
  final Future<Database> Function() _getDb;

  const InfakRepository(this._getDb);

  Future<void> upsertInfakSantri(InfakSantriModel infak) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await upsertInfakInTxn(txn, infak);
    });
  }

  Future<void> upsertInfakInTxn(
    Transaction txn,
    InfakSantriModel infak,
  ) async {
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
    final db = await _getDb();
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
    final db = await _getDb();
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
    final db = await _getDb();
    final dompet = SantriRepository.normalizeDompet(sumberDompet);
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

      final santriMaps = await txn.query(
        'santri',
        where: 'id = ?',
        whereArgs: [santriId],
      );
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
        catatan: catatan?.trim().isNotEmpty == true
            ? catatan!.trim()
            : 'Sambangan Wali',
      );
      await upsertInfakInTxn(txn, savedInfak);
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
    final db = await _getDb();
    await db.insert(
      'serah_terima_infak',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSerahTerimaInfak(String id) async {
    final db = await _getDb();
    await db.delete('serah_terima_infak', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SerahTerimaInfakModel>> getSerahTerimaInfak({
    String? periodeBulan,
  }) async {
    final db = await _getDb();
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
    final db = await _getDb();
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

    final infRow =
        infakAgg.isNotEmpty ? infakAgg.first : const <String, Object?>{};
    final serRow =
        serahAgg.isNotEmpty ? serahAgg.first : const <String, Object?>{};

    final int masukTunai = (infRow['masuk_tunai'] as num?)?.toInt() ?? 0;
    final int masukRekening = (infRow['masuk_rekening'] as num?)?.toInt() ?? 0;
    final double berasMasuk =
        (infRow['beras_masuk'] as num?)?.toDouble() ?? 0.0;

    final int serahTunai = (serRow['serah_tunai'] as num?)?.toInt() ?? 0;
    final int serahRekening = (serRow['serah_rekening'] as num?)?.toInt() ?? 0;
    final double berasSerah =
        (serRow['beras_serah'] as num?)?.toDouble() ?? 0.0;

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
}
