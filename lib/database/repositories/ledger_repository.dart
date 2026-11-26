import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/cash_opname_log.dart';
import '../../models/pengaturan.dart';
import '../../models/santri.dart';
import '../../models/setoran.dart';
import '../../models/transaksi.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/time_category_helper.dart';
import 'santri_repository.dart';

class LedgerRepository {
  final Future<Database> Function() _getDb;

  const LedgerRepository(this._getDb);

  Future<void> kelolaTunggakan({
    required String santriId,
    required int nominal,
    required String catatan,
    required bool isBayar,
    String sumberDompet = 'TUNAI',
  }) async {
    final db = await _getDb();
    final dompet = SantriRepository.normalizeDompet(sumberDompet);
    await db.transaction((txn) async {
      final santriMaps = await txn.query(
        'santri',
        where: 'id = ?',
        whereArgs: [santriId],
      );
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
    final db = await _getDb();
    final result = await db.rawQuery(
      'SELECT SUM(tunggakan) as total FROM santri WHERE status_aktif = 1',
    );
    final total = result.first['total'];
    return (total as num?)?.toInt() ?? 0;
  }

  Future<int> getCountSantriTunggakan() async {
    final db = await _getDb();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM santri WHERE tunggakan > 0 AND status_aktif = 1',
    );
    final count = result.first['count'];
    return (count as num?)?.toInt() ?? 0;
  }

  Future<SetoranBulanan> catatSetoranBaru({
    required String santriId,
    required int nominalSetoran,
    required int durasiHari,
    required int jatahHarianHitung,
    required TipeSetoran tipeSetoran,
    required DateTime tanggalSetor,
    String? catatan,
    PerlakuanSisaSaldoLalu perlakuanSisa =
        PerlakuanSisaSaldoLalu.gabungBulanBaru,
    OpsiSetoranSusulan? opsiSusulan,
    bool potongTunggakan = true,
    String metodeBayar = 'TUNAI',
  }) async {
    final db = await _getDb();
    final setoranId = const Uuid().v4();
    final transaksiId = const Uuid().v4();

    final setoran = SetoranBulanan(
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
      final pengaturanMaps = await txn.query(
        'pengaturan_aplikasi',
        where: 'id = 1',
      );
      final kelipatanPembulatan = pengaturanMaps.isNotEmpty
          ? ((pengaturanMaps.first['pembulatan_jatah'] as num?)?.toInt() ?? 500)
          : 500;

      final santriMaps = await txn.query(
        'santri',
        where: 'id = ?',
        whereArgs: [santriId],
      );
      if (santriMaps.isEmpty) throw Exception('Santri tidak ditemukan');
      final currentSantri = Santri.fromMap(santriMaps.first);

      int sisaSetoranMasukSaldo = nominalSetoran;
      int tunggakanBaru = currentSantri.tunggakan;
      String catatanTunggakanBaru = currentSantri.catatanTunggakan;
      int saldoBaru = currentSantri.saldoTotal;
      int jatahBaru = currentSantri.jatahHarian;
      int nominalPotongTunggakan = 0;
      String logPotongTunggakan = '';

      if (potongTunggakan && tunggakanBaru > 0) {
        if (sisaSetoranMasukSaldo >= tunggakanBaru) {
          nominalPotongTunggakan = tunggakanBaru;
          sisaSetoranMasukSaldo -= tunggakanBaru;
          tunggakanBaru = 0;
          catatanTunggakanBaru = '';
          logPotongTunggakan =
              ' (Potong Lunas Tunggakan ${CurrencyFormatter.format(nominalPotongTunggakan)})';
        } else {
          nominalPotongTunggakan = sisaSetoranMasukSaldo;
          tunggakanBaru -= sisaSetoranMasukSaldo;
          logPotongTunggakan =
              ' (Potong Cicil Tunggakan ${CurrencyFormatter.format(nominalPotongTunggakan)})';
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
        } else if (opsiSusulan == null &&
            durasiHari > 0 &&
            sisaSetoranMasukSaldo > 0) {
          jatahBaru = CurrencyFormatter.hitungJatahHarianBulat(
            sisaSetoranMasukSaldo,
            durasiHari,
            kelipatan: kelipatanPembulatan,
          );
        }
      }

      final dompet = SantriRepository.normalizeDompet(metodeBayar);
      final setoranMap = setoran.toMap();
      setoranMap['jatah_harian_hitung'] = jatahBaru;
      setoranMap['metode_bayar'] = dompet;
      setoranMap['potong_tunggakan'] =
          (potongTunggakan && nominalPotongTunggakan > 0) ? 1 : 0;
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
            : (tipeSetoran == TipeSetoran.awalBulan
                ? 'Setoran Awal Bulan$logPotongTunggakan'
                : 'Top-Up Susulan$logPotongTunggakan'),
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
    final db = await _getDb();
    final maps = await db.query(
      'setoran_bulanan',
      where: 'santri_id = ?',
      whereArgs: [santriId],
      orderBy: 'tanggal_setor DESC',
    );
    return maps.map((m) => SetoranBulanan.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllSetoranByDateRange({
    String? tanggalMulai,
    String? tanggalSelesai,
  }) async {
    final db = await _getDb();
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

  Future<TransaksiHarian> catatPengambilan({
    required String santriId,
    required int nominal,
    String? catatan,
    bool isOverlimit = false,
    OverlimitHandling? overlimitHandling,
    TimeCategory? waktuCategory,
    DateTime? customTimestamp,
  }) async {
    final db = await _getDb();
    final id = const Uuid().v4();
    final waktu = customTimestamp ?? DateTime.now();
    final tanggalLokal = DateFormatter.toLocalDateString(waktu);
    final kategoriWaktu =
        waktuCategory ?? TimeCategoryHelper.fromDateTime(waktu);

    late TransaksiHarian transaksi;

    await db.transaction((txn) async {
      final santriMaps = await txn.query(
        'santri',
        where: 'id = ?',
        whereArgs: [santriId],
      );
      if (santriMaps.isEmpty) throw Exception('Santri tidak ditemukan');
      final santri = Santri.fromMap(santriMaps.first);

      int saldoBaru = santri.saldoTotal;
      int tunggakanBaru = santri.tunggakan;
      String catatanTunggakanBaru = santri.catatanTunggakan;
      int tambahanTunggakan = 0;

      if (santri.saldoTotal >= nominal) {
        saldoBaru = santri.saldoTotal - nominal;
      } else if (santri.saldoTotal > 0) {
        final int kekurangan = nominal - santri.saldoTotal;
        saldoBaru = 0;
        tunggakanBaru += kekurangan;
        tambahanTunggakan = kekurangan;
        catatanTunggakanBaru = catatanTunggakanBaru.isEmpty
            ? 'Talangan Kas Pondok'
            : '$catatanTunggakanBaru, Talangan Kas';
      } else {
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
        'catatan':
            'Pengambilan ${santri.namaLengkap}${catatan != null && catatan.isNotEmpty ? " ($catatan)" : ""}',
        'tanggal_lokal': tanggalLokal,
        'created_at': waktu.toIso8601String(),
      });

      final Map<String, dynamic> updateData = {
        'saldo_total': saldoBaru,
        'tunggakan': tunggakanBaru,
        'catatan_tunggakan': catatanTunggakanBaru,
      };

      if (isOverlimit &&
          overlimitHandling == OverlimitHandling.hitungUlangRataRata) {
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
              final startDay = DateTime(
                tglSetor.year,
                tglSetor.month,
                tglSetor.day,
              );
              final elapsedDays = tglAmbil.difference(startDay).inDays + 1;
              sisaHariPeriode = (durasi - elapsedDays).clamp(1, durasi);
            }
          }
          if (sisaHariPeriode <= 0) {
            sisaHariPeriode = santri.jatahHarian > 0
                ? (saldoBaru / santri.jatahHarian).ceil().clamp(1, 30)
                : 20;
          }

          final pengaturanMaps = await txn.query(
            'pengaturan_aplikasi',
            where: 'id = 1',
          );
          final kelipatan = pengaturanMaps.isNotEmpty
              ? ((pengaturanMaps.first['pembulatan_jatah'] as num?)?.toInt() ??
                  500)
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
    final db = await _getDb();
    await db.transaction((txn) async {
      final txMaps = await txn.query(
        'transaksi_harian',
        where: 'id = ?',
        whereArgs: [transaksiId],
      );
      if (txMaps.isEmpty) return;
      final tx = TransaksiHarian.fromMap(txMaps.first);
      if (tx.isVoided) return;

      await txn.update(
        'transaksi_harian',
        {'is_void': 1},
        where: 'id = ?',
        whereArgs: [transaksiId],
      );

      final santriMaps = await txn.query(
        'santri',
        where: 'id = ?',
        whereArgs: [tx.santriId],
      );
      final now = DateTime.now();
      final dompetAsal = SantriRepository.normalizeDompet(tx.sumberDompet);
      if (santriMaps.isNotEmpty) {
        final currentSantri = Santri.fromMap(santriMaps.first);
        if (tx.tipe == TipeTransaksi.pengambilan) {
          int sisaRefund = tx.nominal;
          int tunggakanBaru = currentSantri.tunggakan;
          String catatanTunggakanBaru = currentSantri.catatanTunggakan;
          int saldoBaru = currentSantri.saldoTotal;
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
          int nominalPotongTunggakan = 0;
          final matchingSetoran = await txn.query(
            'setoran_bulanan',
            where:
                'santri_id = ? AND tanggal_setor = ? AND nominal_setoran = ?',
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
              'catatan':
                  'Pemulihan potongan tunggakan dari Void Setoran ${tx.id}',
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
    final db = await _getDb();
    await db.transaction((txn) async {
      final maps = await txn.query(
        'transaksi_harian',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return;

      final tx = TransaksiHarian.fromMap(maps.first);
      if (tx.isVoided) return;

      final int diff = newNominal - tx.nominal;
      final santriMaps = await txn.query(
        'santri',
        where: 'id = ?',
        whereArgs: [tx.santriId],
      );
      if (santriMaps.isEmpty) return;

      final currentSantri = Santri.fromMap(santriMaps.first);
      final dompet = SantriRepository.normalizeDompet(tx.sumberDompet);
      final now = DateTime.now();
      final tglNow = DateFormatter.toLocalDateString(now);

      int saldoBaru = currentSantri.saldoTotal;
      int tunggakanBaru = currentSantri.tunggakan;
      String catatanTunggakanBaru = currentSantri.catatanTunggakan;
      int deltaDompet = 0;

      if (tx.tipe == TipeTransaksi.pengambilan) {
        if (diff > 0) {
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
    final db = await _getDb();
    String where = 'santri_id = ?';
    final List<dynamic> args = [santriId];

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

  Future<int> getTotalPengambilanHariIni(
    String santriId,
    String tanggalLokal,
  ) async {
    final db = await _getDb();
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

  Future<List<TransaksiHarian>> getTransaksiHariIni(
    String santriId,
    String tanggalLokal,
  ) async {
    final db = await _getDb();
    final maps = await db.query(
      'transaksi_harian',
      where:
          'santri_id = ? AND tanggal_lokal = ? AND is_void = 0 AND tipe = "PENGAMBILAN"',
      whereArgs: [santriId, tanggalLokal],
      orderBy: 'waktu_ambil ASC',
    );
    return maps.map((m) => TransaksiHarian.fromMap(m)).toList();
  }

  Future<Map<String, List<TransaksiHarian>>>
      getAllTransaksiPengambilanHariIniMap(String tanggalLokal) async {
    final db = await _getDb();
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

    final db = await _getDb();

    if (modeSisaHarian == ModeSisaHarian.ketat) {
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
        if (yInfo != null &&
            yInfo.hasPotongBesok &&
            yInfo.total > s.jatahHarian) {
          final excess = yInfo.total - s.jatahHarian;
          result[s.id] = (s.jatahHarian - excess).clamp(0, s.jatahHarian);
        }
      }
      return result;
    }

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
      final txList =
          txBySantri[s.id] ?? const <({String tanggal, int total})>[];
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
        s.saldoTotal > s.jatahHarian
            ? s.saldoTotal
            : s.jatahHarian * (elapsedDays + 1),
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
    final db = await _getDb();
    String where = 'is_void = 0';
    final List<dynamic> args = [];

    if (santriId != null && santriId.isNotEmpty && santriId != 'ALL') {
      where += ' AND santri_id = ?';
      args.add(santriId);
    }

    if (kategoriWaktu != null &&
        kategoriWaktu.isNotEmpty &&
        kategoriWaktu != 'ALL') {
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

  Future<List<Map<String, dynamic>>> getRecentTransactedSantriIds({
    int limit = 6,
  }) async {
    final db = await _getDb();
    return await db.rawQuery('''
      SELECT santri_id, MAX(waktu_ambil) as latest_time
      FROM transaksi_harian
      WHERE is_void = 0
      GROUP BY santri_id
      ORDER BY latest_time DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<int> getTotalSaldoBrankasFisik() async {
    final db = await _getDb();
    final result = await db.rawQuery(
      'SELECT SUM(saldo_total) as total FROM santri WHERE status_aktif = 1',
    );
    final total = result.first['total'];
    return (total as num?)?.toInt() ?? 0;
  }

  Future<int> getTotalPengeluaranHariIni(String tanggalLokal) async {
    final db = await _getDb();
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
    final db = await _getDb();
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
    final db = await _getDb();
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
    final db = await _getDb();
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
    final db = await _getDb();
    final maps = await db.rawQuery('''
      SELECT kategori_waktu, SUM(nominal) as total
      FROM transaksi_harian
      WHERE tanggal_lokal = ? AND is_void = 0 AND tipe = 'PENGAMBILAN'
      GROUP BY kategori_waktu
    ''', [tanggalLokal]);

    final Map<String, int> rekap = {
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

  Future<List<Map<String, dynamic>>> getDetailTransaksiTanggal(
    String tanggalLokal,
  ) async {
    final db = await _getDb();
    return await db.rawQuery('''
      SELECT t.*, s.nama_lengkap, s.nama_panggilan, s.kamar
      FROM transaksi_harian t
      JOIN santri s ON t.santri_id = s.id
      WHERE t.tanggal_lokal = ? AND t.is_void = 0
      ORDER BY t.waktu_ambil DESC
    ''', [tanggalLokal]);
  }

  Future<Map<String, int>> getRekapBulanan(int tahun, int bulan) async {
    final db = await _getDb();
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

  Future<Map<String, int>> getSaldoDompet() async {
    final db = await _getDb();
    final countRes = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM mutasi_dompet',
    );
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
      throw Exception(
        'Saldo Rekening Bank tidak mencukupi (${CurrencyFormatter.format(saldoBank)})',
      );
    }

    final db = await _getDb();
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

  Future<List<Map<String, dynamic>>> getRecentTarikTunaiLogs({
    int limit = 5,
  }) async {
    final db = await _getDb();
    return await db.query(
      'mutasi_dompet',
      where: "tipe = 'TARIK_TUNAI'",
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<void> insertCashOpnameLog(CashOpnameLog log) async {
    final db = await _getDb();
    await db.insert('cash_opname_logs', log.toMap());
  }

  Future<List<CashOpnameLog>> getCashOpnameLogs({int limit = 15}) async {
    final db = await _getDb();
    final maps = await db.query(
      'cash_opname_logs',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((m) => CashOpnameLog.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getTransaksiByDateRange({
    String? tanggalMulai,
    String? tanggalSelesai,
  }) async {
    final db = await _getDb();
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
    final db = await _getDb();
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
    final whereClause = conditions.isEmpty ? null : conditions.join(' AND ');
    return await db.query(
      'mutasi_dompet',
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
  }

  Future<int> getVoidCountSince(DateTime since) async {
    final db = await _getDb();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM transaksi_harian WHERE is_void = 1 AND waktu_ambil >= ?',
      [since.toIso8601String()],
    );
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }
}
