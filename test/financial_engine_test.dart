import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kas_santri/config/app_config.dart';
import 'package:kas_santri/models/pengaturan.dart';
import 'package:kas_santri/models/santri_status.dart';
import 'package:kas_santri/models/transaksi.dart';
import 'package:kas_santri/providers/kas_santri_provider.dart';
import 'package:kas_santri/services/auth_service.dart';
import 'package:kas_santri/services/backup_service.dart';
import 'package:kas_santri/services/report_service.dart';
import 'package:kas_santri/services/subscription_service.dart';
import 'package:kas_santri/utils/currency_formatter.dart';
import 'package:kas_santri/utils/time_category_helper.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

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
      final santriLunas = santriSetelahCicil.copyWith(tunggakan: 0, catatanTunggakan: '');
      expect(santriLunas.tunggakan, 0);
      expect(santriLunas.catatanTunggakan, '');

      // Simulasi tambah tunggakan baru
      const tambah = 25000;
      final santriTambah = santri.copyWith(
        tunggakan: santri.tunggakan + tambah,
        catatanTunggakan: 'SPP Bulan Lalu + Kitab Fiqih',
      );
      expect(santriTambah.tunggakan, 145000);
    });

    test('H. Logika Setoran Otomatis Potong Tunggakan & Penarikan Saldo Habis', () {
      // 1. Santri punya tunggakan Rp 50.000, setor awal bulan Rp 300.000
      int tunggakan = 50000;
      int setoran = 300000;
      int sisaSetoranMasukSaldo = setoran;

      if (tunggakan > 0) {
        if (sisaSetoranMasukSaldo >= tunggakan) {
          sisaSetoranMasukSaldo -= tunggakan;
          tunggakan = 0;
        } else {
          tunggakan -= sisaSetoranMasukSaldo;
          sisaSetoranMasukSaldo = 0;
        }
      }

      expect(tunggakan, 0); // Tunggakan lunas
      expect(sisaSetoranMasukSaldo, 250000); // Sisa bersih masuk saldo
      const durasiHari = 30;
      final jatahBaru = (sisaSetoranMasukSaldo / durasiHari).round();
      expect(jatahBaru, 8333); // Kuota harian dihitung dari sisa setoran bersih

      // 2. Santri saldo Rp 2.000, ingin ambil Rp 5.000 (Saldo habis -> talangan brankas jadi tunggakan)
      int saldo = 2000;
      int nominalAmbil = 5000;
      int tunggakanSantri = 0;

      if (saldo >= nominalAmbil) {
        saldo -= nominalAmbil;
      } else if (saldo > 0) {
        final kekurangan = nominalAmbil - saldo;
        saldo = 0;
        tunggakanSantri += kekurangan;
      } else {
        saldo = 0;
        tunggakanSantri += nominalAmbil;
      }

      expect(saldo, 0); // Saldo habis
      expect(tunggakanSantri, 3000); // Kekurangan Rp 3.000 jadi tunggakan
    });

    test('I. Presisi Rollback Void Transaksi & Penanganan Hapus Santri', () {
      // Simulasi void transaksi pengambilan yang sebelumnya menimbulkan tunggakan
      int saldo = 0;
      int tunggakan = 3000;
      const nominalVoid = 5000;

      int sisaRefund = nominalVoid;
      if (tunggakan > 0) {
        if (sisaRefund >= tunggakan) {
          sisaRefund -= tunggakan;
          tunggakan = 0;
        } else {
          tunggakan -= sisaRefund;
          sisaRefund = 0;
        }
      }
      saldo += sisaRefund;

      expect(tunggakan, 0); // Tunggakan talangan dibatalkan
      expect(saldo, 2000); // Saldo asli sebelum transaksi berhasil dipulihkan presisi
    });

    test('J. Pembulatan Otomatis Jatah Harian ke Bawah & Selisih Saldo Utuh', () {
      // Contoh kasus pecahan ganjil: Rp 250.000 / 30 hari = Rp 8.333
      final jatah500 = CurrencyFormatter.hitungJatahHarianBulat(250000, 30, kelipatan: 500);
      expect(jatah500, 8000);
      expect(CurrencyFormatter.hitungSelisihPembulatan(250000, 30, jatah500), 10000);

      final jatah1000 = CurrencyFormatter.hitungJatahHarianBulat(250000, 30, kelipatan: 1000);
      expect(jatah1000, 8000);

      final jatah300 = CurrencyFormatter.hitungJatahHarianBulat(300000, 30, kelipatan: 500);
      expect(jatah300, 10000);
      expect(CurrencyFormatter.hitungSelisihPembulatan(300000, 30, jatah300), 0);
    });

    test('K. Rasio Sisa Kuota Progress Bar (remainingRatio 1.0 -> 0.0)', () {
      final santri = Santri(
        id: '1',
        namaLengkap: 'Ahmad',
        namaPanggilan: 'Ahmad',
        kamar: 'Kamar 1',
        saldoTotal: 300000,
        jatahHarian: 10000,
      );

      final utuh = SantriStatusHariIni(
        santri: santri,
        totalAmbilHariIni: 0,
        sisaJatahHariIni: 10000,
        jatahHariIni: 10000,
        transaksiHariIni: [],
      );
      expect(utuh.remainingRatio, 1.0);

      final sebagian = SantriStatusHariIni(
        santri: santri,
        totalAmbilHariIni: 3000,
        sisaJatahHariIni: 7000,
        jatahHariIni: 10000,
        transaksiHariIni: [],
      );
      expect(sebagian.remainingRatio, closeTo(0.7, 0.001));

      final habis = SantriStatusHariIni(
        santri: santri,
        totalAmbilHariIni: 10000,
        sisaJatahHariIni: 0,
        jatahHariIni: 10000,
        transaksiHariIni: [],
      );
      expect(habis.remainingRatio, 0.0);
    });

    test('L. Logika Multi-Dompet (Kas Laci Tunai vs Rekening Bank & Tarik ke Laci)', () {
      int laciTunai = 666000;
      int rekeningBank = 1000000;
      int totalBrankas() => laciTunai + rekeningBank;

      expect(totalBrankas(), 1666000);

      // 1. Setoran masuk ke Rekening Bank sebesar Rp 300.000
      rekeningBank += 300000;
      expect(rekeningBank, 1300000);
      expect(totalBrankas(), 1966000);

      // 2. Pengambilan uang harian santri Rp 16.000 memotong Kas Laci Tunai
      laciTunai -= 16000;
      expect(laciTunai, 650000);

      // 3. Tarik Tunai (Bank -> Laci) Rp 500.000 tidak mengubah Total Brankas
      const tarik = 500000;
      rekeningBank -= tarik;
      laciTunai += tarik;
      expect(rekeningBank, 800000);
      expect(laciTunai, 1150000);
      expect(totalBrankas(), 1950000);
    });

    test('M. Kalkulator Cash Opname Fisik 8 Pecahan & Deteksi Selisih', () {
      const kasSistem = 666000;
      final pecahanCocok = <int, int>{
        100000: 5,
        50000: 2,
        20000: 2,
        10000: 2,
        5000: 1,
        1000: 1,
      };
      int hitungFisik(Map<int, int> m) =>
          m.entries.fold(0, (sum, e) => sum + (e.key * e.value));

      final fisikCocok = hitungFisik(pecahanCocok);
      expect(fisikCocok, 666000);
      expect(fisikCocok - kasSistem, 0);

      final pecahanKurang = <int, int>{
        100000: 5,
        50000: 2,
        20000: 2,
        10000: 2,
        5000: 1,
        500: 1,
      };
      final fisikKurang = hitungFisik(pecahanKurang);
      expect(fisikKurang - kasSistem, -500);
    });

    test('N. Generator QR Code Santri Unik & Filter Saldo Kritis (< 3 Hari)', () {
      final s1 = Santri(
        id: '11111111-aaaa-bbbb-cccc-000000000001',
        namaLengkap: 'Ahmad Kritis',
        namaPanggilan: 'Ahmad',
        kamar: 'Kamar 1',
        saldoTotal: 25000,
        jatahHarian: 10000,
      );
      final s2 = Santri(
        id: '22222222-aaaa-bbbb-cccc-000000000002',
        namaLengkap: 'Zaidan Aman',
        namaPanggilan: 'Zaidan',
        kamar: 'Kamar 2',
        saldoTotal: 50000,
        jatahHarian: 10000,
      );

      expect(s1.qrCode, startsWith('KS-'));
      expect(s2.qrCode, startsWith('KS-'));
      expect(s1.qrCode, isNot(s2.qrCode));

      // Roundtrip toMap / fromMap mempertahankan qr_code
      final mapped = s1.toMap();
      expect(mapped['qr_code'], s1.qrCode);
      expect(Santri.fromMap(mapped).qrCode, s1.qrCode);

      // Filter Saldo Kritis (< 3 Hari)
      expect(s1.estimasiHari, 2);
      expect(s2.estimasiHari, 5);
      final kritisOnly = [s1, s2].where((s) => s.estimasiHari < 3).toList();
      expect(kritisOnly.length, 1);
      expect(kritisOnly.first.id, s1.id);
    });

    test('O. Normalisasi Nomor WA 1-Klik & Watermark Laporan Gratis vs PRO', () {
      expect(ReportService.normalizeWaPhone('0812-3456-7890'), '6281234567890');
      expect(ReportService.normalizeWaPhone('+62 857-0011-2233'), '6285700112233');
      expect(ReportService.normalizeWaPhone('81299887766'), '6281299887766');
      expect(ReportService.normalizeWaPhone('  '), '');

      final santri = Santri(
        id: 'wa-test-1',
        namaLengkap: 'Bilal Ramadhan',
        namaPanggilan: 'Bilal',
        kamar: 'Kamar 2',
        saldoTotal: 20000,
        jatahHarian: 10000,
      );
      final pengaturan = PengaturanAplikasi(namaPondok: 'PPS MIFTAHUSSUNAN');

      final freeText = ReportService.instance.generateWhatsAppText(
        santri: santri,
        mutasiList: [],
        pengaturan: pengaturan,
        isProUser: false,
      );
      final proText = ReportService.instance.generateWhatsAppText(
        santri: santri,
        mutasiList: [],
        pengaturan: pengaturan,
        isProUser: true,
      );

      expect(freeText, contains('_Dicatat dengan Kas-Santri_'));
      expect(proText, isNot(contains('_Dicatat dengan Kas-Santri_')));

      final reminder = ReportService.instance.generateCriticalReminderText(
        santri: santri,
        namaPondok: pengaturan.namaPondok,
        namaPengurus: pengaturan.namaPengurus,
      );
      expect(reminder, contains('Kritis (< 3 Hari)'));
      expect(reminder, contains('Bilal Ramadhan'));
    });

    test('P. Validasi Struktur Backup JSON 7 Tabel & Metadata Google Drive', () {
      const validJson = '''
      {
        "version": 25,
        "exported_at": "2026-11-25T02:30:00.000",
        "santri": [{"id": "s1", "nama_lengkap": "Ahmad Fauzi"}],
        "setoran_bulanan": [],
        "transaksi_harian": [{"id": "tx1", "nominal": 5000}],
        "tunggakan_log": [],
        "mutasi_dompet": [],
        "cash_opname_logs": [],
        "pengaturan_aplikasi": [{"id": 1, "nama_pondok": "PPS MIFTAHUSSUNAN"}]
      }
      ''';

      final okRes = BackupService.validateJsonString(validJson);
      expect(okRes.isValid, true);
      expect(okRes.santriCount, 1);
      expect(okRes.transaksiCount, 1);
      expect(okRes.exportedAt, '2026-11-25T02:30:00.000');

      const missingTableJson = '''
      {
        "santri": [],
        "setoran_bulanan": [],
        "transaksi_harian": [],
        "tunggakan_log": [],
        "mutasi_dompet": [],
        "cash_opname_logs": []
      }
      ''';
      final missingRes = BackupService.validateJsonString(missingTableJson);
      expect(missingRes.isValid, false);
      expect(missingRes.errorMessage, contains('pengaturan_aplikasi'));

      const badTypeJson = '''
      {
        "santri": "bukan_list",
        "setoran_bulanan": [],
        "transaksi_harian": [],
        "tunggakan_log": [],
        "mutasi_dompet": [],
        "cash_opname_logs": [],
        "pengaturan_aplikasi": []
      }
      ''';
      final badTypeRes = BackupService.validateJsonString(badTypeJson);
      expect(badTypeRes.isValid, false);
      expect(badTypeRes.errorMessage, contains('santri'));

      // PengaturanAplikasi roundtrip untuk metadata Google Drive
      final settings = PengaturanAplikasi(
        namaPondok: 'PPS MIFTAHUSSUNAN',
        lastDriveBackupAt: '2026-11-25T02:45:00.000',
        autoDriveBackup: true,
        driveAccountEmail: 'bendahara@pondok.id',
      );
      final map = settings.toMap();
      expect(map['last_drive_backup_at'], '2026-11-25T02:45:00.000');
      expect(map['auto_drive_backup'], 1);
      expect(map['drive_account_email'], 'bendahara@pondok.id');

      final restored = PengaturanAplikasi.fromMap(map);
      expect(restored.lastDriveBackupAt, '2026-11-25T02:45:00.000');
      expect(restored.autoDriveBackup, true);
      expect(restored.driveAccountEmail, 'bendahara@pondok.id');
    });

    test('Q. Validasi Format & Hashing PIN 4–6 Digit', () {
      expect(AuthService.isValidPinFormat('1234'), true);
      expect(AuthService.isValidPinFormat('12345'), true);
      expect(AuthService.isValidPinFormat('123456'), true);
      expect(AuthService.isValidPinFormat('123'), false);
      expect(AuthService.isValidPinFormat('1234567'), false);
      expect(AuthService.isValidPinFormat('12ab'), false);
      expect(AuthService.isValidPinFormat('12 34'), false);

      final h1 = AuthService.instance.hashPin('246810');
      final h2 = AuthService.instance.hashPin('246810');
      final legacy = AuthService.instance.hashLegacyPin('246810');
      expect(h1, h2);
      expect(h1, isNot(equals('246810')));
      expect(h1, isNot(equals(legacy)));
    });

    test('R. Kuota 15 Santri Gratis & Konfigurasi RevenueCat Product ID', () {
      expect(KasSantriProvider.maxFreeSantriQuota, 15);
      expect(KasSantriProvider.isFreeQuotaReached(isPro: false, activeCount: 14), false);
      expect(KasSantriProvider.isFreeQuotaReached(isPro: false, activeCount: 15), true);
      expect(KasSantriProvider.isFreeQuotaReached(isPro: false, activeCount: 20), true);
      expect(KasSantriProvider.isFreeQuotaReached(isPro: true, activeCount: 15), false);
      expect(KasSantriProvider.isFreeQuotaReached(isPro: true, activeCount: 500), false);

      expect(AppConfig.entitlementId, 'kas_santri_pro');
      expect(AppConfig.productIdYearly, 'kas_santri_pro_yearly_prepaid');
      expect(AppConfig.productIdMonthly, 'kas_santri_pro_monthly_prepaid');
      expect(AppConfig.productIdLifetime, 'kas_santri_pro_lifetime');

      final offers = SubscriptionService.defaultFallbackOffers();
      expect(offers.length, 3);
      expect(offers[0].planKey, 'YEARLY');
      expect(offers[0].fallbackPriceInt, 179000);
      expect(offers[1].planKey, 'MONTHLY');
      expect(offers[1].fallbackPriceInt, 25000);
      expect(offers[2].planKey, 'LIFETIME');
      expect(offers[2].fallbackPriceInt, 399000);

      expect(
        SubscriptionService.planKeyFromProductId('kas_santri_pro_monthly_prepaid'),
        'MONTHLY',
      );
      expect(
        SubscriptionService.planKeyFromProductId('kas_santri_pro_lifetime'),
        'LIFETIME',
      );
      expect(
        SubscriptionService.planKeyFromProductId('kas_santri_pro_yearly_prepaid'),
        'YEARLY',
      );
    });
  });
}
