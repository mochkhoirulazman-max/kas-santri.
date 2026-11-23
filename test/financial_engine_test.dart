import 'package:flutter_test/flutter_test.dart';
import 'package:kas_santri/models/santri.dart';
import 'package:kas_santri/models/santri_status.dart';
import 'package:kas_santri/models/transaksi.dart';
import 'package:kas_santri/utils/currency_formatter.dart';
import 'package:kas_santri/utils/time_category_helper.dart';

void main() {
  group('Core Financial Engine & PRD Logic Tests', () {
    test('A. Perhitungan Jatah Harian Dasar: Jharian = Sawal / Dhari', () {
      const setoranAwal = 300000;
      const durasiHari = 30;
      final jatahHarian = (setoranAwal / durasiHari).round();
      expect(jatahHarian, 10000);
    });

    test('B. Perhitungan Pengambilan Harian Bertahap (Multi-Withdrawal)', () {
      const jatahHarian = 10000;
      const p1Pagi = 2000;
      const p2Siang = 5000;
      const p3Malam = 3000;

      final totalHariIni = p1Pagi + p2Siang + p3Malam;
      final sisaJatah = jatahHarian - totalHariIni;

      expect(totalHariIni, 10000);
      expect(sisaJatah, 0); // Limit Habis
    });

    test('C. Perhitungan Sisa Saldo Total dan Estimasi Hari', () {
      final santri = Santri(
        id: '1',
        namaLengkap: 'Ahmad Fauzi',
        namaPanggilan: 'Ahmad',
        kamar: 'Kamar 1',
        saldoTotal: 250000,
        jatahHarian: 10000,
        tunggakan: 50000,
        catatanTunggakan: 'Spp Nov',
      );

      expect(santri.estimasiHari, 25);
      expect(santri.tunggakan, 50000);
      expect(santri.catatanTunggakan, 'Spp Nov');
    });

    test('D. Klasifikasi Badge Status Santri (Utuh, Sebagian, Limit Habis, Overlimit)', () {
      final santri = Santri(
        id: '1',
        namaLengkap: 'Zaid',
        namaPanggilan: 'Zaid',
        kamar: 'Kamar 2',
        saldoTotal: 300000,
        jatahHarian: 10000,
      );

      // Status Utuh (Belum ambil)
      final statusUtuh = SantriStatusHariIni(
        santri: santri,
        totalAmbilHariIni: 0,
        sisaJatahHariIni: 10000,
        jatahHariIni: 10000,
        transaksiHariIni: [],
      );
      expect(statusUtuh.badgeStatus, BadgeStatusHariIni.utuh);

      // Status Sebagian
      final txPagi = TransaksiHarian(
        id: 'tx1',
        santriId: '1',
        nominal: 2000,
        waktuAmbil: DateTime(2026, 11, 23, 8, 0),
        tanggalLokal: '2026-11-23',
        kategoriWaktu: TimeCategory.pagi,
      );
      final statusSebagian = SantriStatusHariIni(
        santri: santri,
        totalAmbilHariIni: 2000,
        sisaJatahHariIni: 8000,
        jatahHariIni: 10000,
        transaksiHariIni: [txPagi],
      );
      expect(statusSebagian.badgeStatus, BadgeStatusHariIni.sebagian);

      // Status Limit Habis
      final statusHabis = SantriStatusHariIni(
        santri: santri,
        totalAmbilHariIni: 10000,
        sisaJatahHariIni: 0,
        jatahHariIni: 10000,
        transaksiHariIni: [txPagi],
      );
      expect(statusHabis.badgeStatus, BadgeStatusHariIni.limitHabis);

      // Status Overlimit Kritis
      final statusOverlimit = SantriStatusHariIni(
        santri: santri,
        totalAmbilHariIni: 15000,
        sisaJatahHariIni: -5000,
        jatahHariIni: 10000,
        transaksiHariIni: [txPagi],
        hasOverlimitToday: true,
      );
      expect(statusOverlimit.badgeStatus, BadgeStatusHariIni.overlimitKritis);
      expect(statusOverlimit.badgeLabel, 'Overlimit');
    });

    test('E. Kategori Waktu (PAGI, SIANG, SORE, MALAM)', () {
      expect(TimeCategoryHelper.fromDateTime(DateTime(2026, 1, 1, 7, 30)), TimeCategory.pagi);
      expect(TimeCategoryHelper.fromDateTime(DateTime(2026, 1, 1, 12, 45)), TimeCategory.siang);
      expect(TimeCategoryHelper.fromDateTime(DateTime(2026, 1, 1, 16, 15)), TimeCategory.sore);
      expect(TimeCategoryHelper.fromDateTime(DateTime(2026, 1, 1, 20, 00)), TimeCategory.malam);
    });

    test('F. Currency Formatter and Parser', () {
      expect(CurrencyFormatter.parse('10.000'), 10000);
      expect(CurrencyFormatter.parse('Rp 350.000'), 350000);
      expect(CurrencyFormatter.formatWithoutSymbol(10000), '10.000');
    });

    test('G. Fitur Tunggakan Santri (Bayar / Cicil dan Tambah Tunggakan)', () {
      final santri = Santri(
        id: '1',
        namaLengkap: 'M. Rizky Pratama',
        namaPanggilan: 'Rizky',
        kamar: 'Kamar 2',
        saldoTotal: 20000,
        jatahHarian: 10000,
        tunggakan: 120000,
        catatanTunggakan: 'SPP Bulan Lalu',
      );

      expect(santri.tunggakan, 120000);

      // Simulasi cicil 50.000
      const cicil = 50000;
      final sisaTunggakan = (santri.tunggakan - cicil).clamp(0, double.infinity).toInt();
      final santriSetelahCicil = santri.copyWith(tunggakan: sisaTunggakan);
      expect(santriSetelahCicil.tunggakan, 70000);

      // Simulasi pelunasan penuh
      final santriLunas = santriSetelahCicil.copyWith(tunggakan: 0, catatanTunggakan: null);
      expect(santriLunas.tunggakan, 0);
      expect(santriLunas.catatanTunggakan, isNull);

      // Simulasi tambah tunggakan baru
      const tambah = 25000;
      final santriTambah = santri.copyWith(
        tunggakan: santri.tunggakan + tambah,
        catatanTunggakan: 'SPP Bulan Lalu + Kitab Fiqih',
      );
      expect(santriTambah.tunggakan, 145000);
    });
  });
}
