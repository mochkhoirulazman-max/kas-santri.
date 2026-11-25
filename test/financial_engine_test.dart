import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kas_santri/config/app_config.dart';
import 'package:kas_santri/database/database_helper.dart';
import 'package:kas_santri/models/audit_log.dart';
import 'package:kas_santri/models/bendahara_account.dart';
import 'package:kas_santri/models/cash_opname_log.dart';
import 'package:kas_santri/models/infak_santri.dart';
import 'package:kas_santri/models/pengaturan.dart';
import 'package:kas_santri/models/santri_status.dart';
import 'package:kas_santri/models/serah_terima_infak.dart';
import 'package:kas_santri/models/transaksi.dart';
import 'package:kas_santri/providers/kas_santri_provider.dart';
import 'package:kas_santri/services/account_auth_service.dart';
import 'package:kas_santri/services/auth_service.dart';
import 'package:kas_santri/services/backup_service.dart';
import 'package:kas_santri/services/bulk_santri_excel_service.dart';
import 'package:kas_santri/services/customer_sync_service.dart';
import 'package:kas_santri/services/executive_analytics_service.dart';
import 'package:kas_santri/services/license_service.dart';
import 'package:kas_santri/services/qr_card_pdf_service.dart';
import 'package:kas_santri/services/report_service.dart';
import 'package:kas_santri/services/security_guard_service.dart';
import 'package:kas_santri/services/smart_wa_reminder_service.dart';
import 'package:kas_santri/services/subscription_service.dart';
import 'package:kas_santri/services/yayasan_export_service.dart';
import 'package:kas_santri/utils/currency_formatter.dart';
import 'package:kas_santri/utils/date_formatter.dart';
import 'package:kas_santri/utils/time_category_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(h1, startsWith('v33:'));
      expect(h1, isNot(equals(h2)));
      expect(h1, isNot(equals('246810')));
      expect(h1, isNot(equals(legacy)));
      expect(AuthService.instance.verifyPinAgainstStored('246810', h1), true);
      expect(AuthService.instance.verifyPinAgainstStored('246810', h2), true);
      expect(AuthService.instance.verifyPinAgainstStored('246810', legacy), true);
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

    test('S. Verifikasi Lisensi Asimetris Ed25519 (MONTHLY, YEARLY, LIFETIME, Anti-Forged)', () async {
      const deviceA = 'KS-A7B94X2M';
      const deviceB = 'KS-ZZZZ9999';
      final now = DateTime.utc(2026, 11, 25, 10, 0);

      String encodeB32(List<int> bytes) {
        const alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
        final out = StringBuffer();
        var buffer = 0;
        var bitsLeft = 0;
        for (final b in bytes) {
          buffer = (buffer << 8) | (b & 0xff);
          bitsLeft += 8;
          while (bitsLeft >= 5) {
            out.write(alpha[(buffer >> (bitsLeft - 5)) & 0x1f]);
            bitsLeft -= 5;
          }
        }
        if (bitsLeft > 0) {
          out.write(alpha[(buffer << (5 - bitsLeft)) & 0x1f]);
        }
        return out.toString();
      }

      final ed = Ed25519();
      final testKeyPair = await ed.newKeyPair();
      final testPubKey = await testKeyPair.extractPublicKey();
      final testPubB64 = base64Encode(testPubKey.bytes);

      Future<String> signTestCode({
        required String deviceId,
        required String tier,
        required int expiryEpochSec,
        SimpleKeyPair? keyPairOverride,
      }) async {
        final payload = utf8.encode('$deviceId|$tier|$expiryEpochSec');
        final sig = await ed.sign(payload, keyPair: keyPairOverride ?? testKeyPair);
        return 'KSPRO-${encodeB32(payload)}-${encodeB32(sig.bytes)}';
      }

      // 1. Verifikasi paket YEARLY
      final futureEpoch = DateTime.utc(2027, 11, 25).millisecondsSinceEpoch ~/ 1000;
      final y1Code = await signTestCode(
        deviceId: deviceA,
        tier: 'YEARLY',
        expiryEpochSec: futureEpoch,
      );
      final y1Res = await LicenseService.verifyCodeAsync(
        code: y1Code,
        deviceId: deviceA,
        now: now.toLocal(),
        publicKeyBase64Override: testPubB64,
      );
      expect(y1Res.isValid, true);
      expect(y1Res.planKey, 'YEARLY');

      // 2. Verifikasi paket LIFETIME (expiry = 0)
      final ltCode = await signTestCode(
        deviceId: deviceA,
        tier: 'LIFETIME',
        expiryEpochSec: 0,
      );
      final ltRes = await LicenseService.verifyCodeAsync(
        code: ltCode,
        deviceId: deviceA,
        now: DateTime(2050, 1, 1),
        publicKeyBase64Override: testPubB64,
      );
      expect(ltRes.isValid, true);
      expect(ltRes.planKey, 'LIFETIME');

      // 3. Ditolak jika device berbeda
      final wrongDevice = await LicenseService.verifyCodeAsync(
        code: y1Code,
        deviceId: deviceB,
        now: now.toLocal(),
        publicKeyBase64Override: testPubB64,
      );
      expect(wrongDevice.isValid, false);

      // 4. Ditolak jika sudah kadaluarsa
      final expiredEpoch = DateTime.utc(2026, 11, 1).millisecondsSinceEpoch ~/ 1000;
      final expiredM1 = await signTestCode(
        deviceId: deviceA,
        tier: 'MONTHLY',
        expiryEpochSec: expiredEpoch,
      );
      final expiredRes = await LicenseService.verifyCodeAsync(
        code: expiredM1,
        deviceId: deviceA,
        now: now.toLocal(),
        publicKeyBase64Override: testPubB64,
      );
      expect(expiredRes.isValid, false);
      expect(expiredRes.isExpired, true);

      // 5. Ditolak jika ditandatangani key lain (anti-keygen / anti-forge)
      final rogueKp = await ed.newKeyPair();
      final forgedCode = await signTestCode(
        deviceId: deviceA,
        tier: 'LIFETIME',
        expiryEpochSec: 0,
        keyPairOverride: rogueKp,
      );
      final forgedRes = await LicenseService.verifyCodeAsync(
        code: forgedCode,
        deviceId: deviceA,
        now: now.toLocal(),
        publicKeyBase64Override: testPubB64,
      );
      expect(forgedRes.isValid, false);
    });

    test('T. Logika Uji Coba Gratis 14 Hari & Konstanta Dual-Mode DANA', () {
      expect(AppConfig.adminDanaNumber, '082130678956');
      expect(AppConfig.adminWhatsappNumber, '6282130678956');
      expect(
        SubscriptionService.qrisAssetForPlan('MONTHLY'),
        'assets/qris_dana_25k.jpg',
      );
      expect(
        SubscriptionService.qrisAssetForPlan('YEARLY'),
        'assets/qris_dana_179k.jpg',
      );
      expect(
        SubscriptionService.qrisAssetForPlan('LIFETIME'),
        'assets/qris_dana_399k.jpg',
      );

      // 1. Belum pernah trial
      final fresh = SubscriptionService.evaluateTrial(hasUsedTrial: false);
      expect(fresh.isActive, false);
      expect(fresh.isExpired, false);
      expect(fresh.remainingDays, 0);

      // 2. Baru mengaktifkan trial hari ke-1
      final start = DateTime(2026, 11, 25, 8, 0);
      final expires = start.add(const Duration(days: 14));
      final day1 = SubscriptionService.evaluateTrial(
        hasUsedTrial: true,
        startedAt: start,
        expiresAt: expires,
        now: start.add(const Duration(hours: 2)),
      );
      expect(day1.isActive, true);
      expect(day1.remainingDays, 14);

      // 3. Hari ke-14 (sisa kurang dari 24 jam tetap terhitung sisa 1 hari)
      final day14 = SubscriptionService.evaluateTrial(
        hasUsedTrial: true,
        startedAt: start,
        expiresAt: expires,
        now: expires.subtract(const Duration(hours: 6)),
      );
      expect(day14.isActive, true);
      expect(day14.remainingDays, 1);

      // 4. Setelah 14 hari lewat -> otomatis expired
      final day15 = SubscriptionService.evaluateTrial(
        hasUsedTrial: true,
        startedAt: start,
        expiresAt: expires,
        now: expires.add(const Duration(minutes: 1)),
      );
      expect(day15.isActive, false);
      expect(day15.isExpired, true);
      expect(day15.remainingDays, 0);
    });

    test('U. Audit Query SQLite Ekspor Excel & PDF (waktu_ambil, mutasi_dompet, opname)', () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.instance.setDatabaseForTesting(db);
      addTearDown(() async {
        DatabaseHelper.instance.setDatabaseForTesting(null);
        await db.close();
      });

      final santri = Santri(
        id: 'sql-test-1',
        namaLengkap: 'Abdullah Muqri',
        namaPanggilan: 'Muqri',
        kamar: 'Kamar 3',
        saldoTotal: 300000,
        jatahHarian: 10000,
      );
      await DatabaseHelper.instance.insertSantri(santri, sumberDompet: 'TUNAI');

      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await DatabaseHelper.instance.catatPengambilan(
        santriId: santri.id,
        nominal: 5000,
        catatan: 'Jajan Siang',
        waktuCategory: TimeCategory.siang,
        customTimestamp: now,
      );

      await DatabaseHelper.instance.insertCashOpnameLog(
        CashOpnameLog(
          id: 'opname-sql-1',
          tanggalLokal: today,
          totalSistem: 295000,
          totalFisik: 295000,
          selisih: 0,
          rincianPecahan: {100000: 2, 50000: 1, 20000: 2, 5000: 1},
          catatan: 'Cocok',
          createdAt: now,
        ),
      );

      final mutasiAll = await DatabaseHelper.instance.getTransaksiByDateRange();
      expect(mutasiAll.length, 1);
      expect(mutasiAll.first['nama_lengkap'], 'Abdullah Muqri');
      expect(mutasiAll.first['kamar'], 'Kamar 3');
      expect(mutasiAll.first['waktu_ambil'], isNotNull);

      final mutasiRange = await DatabaseHelper.instance.getTransaksiByDateRange(
        tanggalMulai: today,
        tanggalSelesai: today,
      );
      expect(mutasiRange.length, 1);

      final dompetRows = await DatabaseHelper.instance.getAllMutasiDompet(
        tanggalMulai: today,
        tanggalSelesai: today,
      );
      expect(dompetRows.length, 2);

      final opnames = await DatabaseHelper.instance.getCashOpnameLogs();
      expect(opnames.length, 1);

      final detailTanggal = await DatabaseHelper.instance.getDetailTransaksiTanggal(today);
      expect(detailTanggal.length, 1);

      final rekapBulan = await DatabaseHelper.instance.getRekapBulanan(now.year, now.month);
      expect(rekapBulan['pengeluaran'], 5000);
    });

    test('V. Fondasi v3.0: Migrasi SQLite v2->v3, Model Infak/SerahTerima & Backup 9 Tabel', () async {
      // 1. Model Santri & PengaturanAplikasi v3.0 roundtrip
      final santriBaru = Santri(
        id: 'v3-s1',
        namaLengkap: 'Fatimah Az-Zahra',
        namaPanggilan: 'Fatimah',
        kategoriSantri: Santri.kategoriSantriyat,
        statusSantri: Santri.statusPulangVal,
        kamar: 'Asrama Putri 1',
      );
      expect(santriBaru.kategoriLabel, 'Santriyat');
      expect(santriBaru.isPulang, true);
      expect(santriBaru.isAktifDiPondok, false);
      final santriRestored = Santri.fromMap(santriBaru.toMap());
      expect(santriRestored.kategoriSantri, Santri.kategoriSantriyat);
      expect(santriRestored.statusSantri, Santri.statusPulangVal);

      final peng = PengaturanAplikasi(
        tahunAjaran: '2026/2027 M / 1448 H',
        defaultInfakMasak: 140000,
        defaultInfakListrik: 25000,
        defaultInfakBerasLiter: 12.5,
        defaultInfakBerasUang: 160000,
      );
      final pengRestored = PengaturanAplikasi.fromMap(peng.toMap());
      expect(pengRestored.tahunAjaran, '2026/2027 M / 1448 H');
      expect(pengRestored.defaultInfakMasak, 140000);
      expect(pengRestored.defaultInfakListrik, 25000);
      expect(pengRestored.defaultInfakBerasLiter, 12.5);
      expect(pengRestored.defaultInfakBerasUang, 160000);

      // 2. InfakSantriModel rolling date & status lunas
      expect(InfakSantriModel.hitungTglHabis('2026-11-18'), '2026-12-18');
      expect(InfakSantriModel.hitungTglHabis('2026-12-20'), '2027-01-20');
      expect(InfakSantriModel.hitungTglHabis('2026-01-31'), '2026-02-28');

      final infakLunas = InfakSantriModel(
        id: 'inf-1',
        santriId: 'v3-s1',
        periodeBulan: '2026-11',
        nominalMasak: 130000,
        nominalListrik: 20000,
        jenisBeras: InfakSantriModel.berasUangVal,
        berasUang: 150000,
        tglMasuk: '2026-11-18',
      );
      expect(infakLunas.tglHabis, '2026-12-18');
      expect(infakLunas.statusLunas, InfakSantriModel.statusLunasVal);
      expect(infakLunas.totalUangMasuk, 300000);

      final serah = SerahTerimaInfakModel(
        id: 'st-1',
        tanggalSerah: '2026-11-25',
        periodeBulan: '2026-11',
        posInfak: 'BERAS_FISIK',
        sumberDompet: 'GUDANG_BERAS',
        jumlahBerasLiter: 15.0,
        penerima: 'Ustadzah Dapur',
      );
      expect(SerahTerimaInfakModel.fromMap(serah.toMap()).penerima, 'Ustadzah Dapur');

      // 3. Simulasi upgrade SQLite aman v2 -> v3 tanpa kehilangan data lama
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE santri (
          id TEXT PRIMARY KEY, nama_lengkap TEXT NOT NULL, nama_panggilan TEXT,
          kamar TEXT NOT NULL, no_wa_wali TEXT, saldo_total INTEGER NOT NULL DEFAULT 0,
          jatah_harian INTEGER NOT NULL DEFAULT 10000, setoran_awal INTEGER NOT NULL DEFAULT 300000,
          tunggakan INTEGER NOT NULL DEFAULT 0, catatan_tunggakan TEXT DEFAULT '',
          foto_path TEXT, qr_code TEXT, status_aktif INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE setoran_bulanan (
          id TEXT PRIMARY KEY, santri_id TEXT NOT NULL, nominal_setoran INTEGER NOT NULL,
          durasi_hari INTEGER NOT NULL, jatah_harian_hitung INTEGER NOT NULL,
          tipe_setoran TEXT NOT NULL, tanggal_setor TEXT NOT NULL, catatan TEXT,
          perlakuan_sisa TEXT, metode_bayar TEXT NOT NULL DEFAULT 'TUNAI',
          potong_tunggakan INTEGER NOT NULL DEFAULT 0, nominal_potong_tunggakan INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE transaksi_harian (
          id TEXT PRIMARY KEY, santri_id TEXT NOT NULL, nominal INTEGER NOT NULL,
          waktu_ambil TEXT NOT NULL, tanggal_lokal TEXT NOT NULL, kategori_waktu TEXT NOT NULL,
          is_overlimit INTEGER NOT NULL DEFAULT 0, catatan TEXT, is_void INTEGER NOT NULL DEFAULT 0,
          overlimit_handling TEXT, saldo_setelah_transaksi INTEGER NOT NULL DEFAULT 0,
          tipe TEXT NOT NULL DEFAULT 'PENGAMBILAN', sumber_dompet TEXT NOT NULL DEFAULT 'TUNAI'
        )
      ''');
      await db.execute('CREATE TABLE tunggakan_log (id TEXT PRIMARY KEY, santri_id TEXT NOT NULL, tipe TEXT NOT NULL, nominal INTEGER NOT NULL, saldo_tunggakan_setelah INTEGER NOT NULL DEFAULT 0, catatan TEXT, created_at TEXT NOT NULL)');
      await db.execute('CREATE TABLE mutasi_dompet (id TEXT PRIMARY KEY, jenis_dompet TEXT NOT NULL DEFAULT "TUNAI", tipe TEXT NOT NULL, nominal INTEGER NOT NULL, referensi_id TEXT, catatan TEXT, tanggal_lokal TEXT NOT NULL, created_at TEXT NOT NULL)');
      await db.execute('CREATE TABLE cash_opname_logs (id TEXT PRIMARY KEY, tanggal_lokal TEXT NOT NULL, total_sistem INTEGER NOT NULL DEFAULT 0, total_fisik INTEGER NOT NULL DEFAULT 0, selisih INTEGER NOT NULL DEFAULT 0, rincian_pecahan_json TEXT, catatan TEXT, created_at TEXT NOT NULL)');
      await db.execute('CREATE TABLE pengaturan_aplikasi (id INTEGER PRIMARY KEY, nama_pondok TEXT NOT NULL, nama_pengurus TEXT NOT NULL, kontak_pengurus TEXT, default_jatah_harian INTEGER NOT NULL DEFAULT 10000, default_durasi_hari INTEGER NOT NULL DEFAULT 30, mode_sisa_harian TEXT NOT NULL DEFAULT "KETAT", pin_keamanan TEXT, is_biometric_enabled INTEGER NOT NULL DEFAULT 0, auto_lock_minutes INTEGER NOT NULL DEFAULT 1, logo_path TEXT, is_two_col_grid INTEGER NOT NULL DEFAULT 1, hide_balance INTEGER NOT NULL DEFAULT 0, pembulatan_jatah INTEGER NOT NULL DEFAULT 500, is_pro INTEGER NOT NULL DEFAULT 0, pro_plan TEXT, onboarding_done INTEGER NOT NULL DEFAULT 1, last_drive_backup_at TEXT, auto_drive_backup INTEGER NOT NULL DEFAULT 0, drive_account_email TEXT)');

      await db.insert('santri', {
        'id': 'legacy-1',
        'nama_lengkap': 'Santri Lama v2',
        'nama_panggilan': 'Lama',
        'kamar': 'Kamar 1',
        'saldo_total': 125000,
        'jatah_harian': 10000,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('pengaturan_aplikasi', {
        'id': 1,
        'nama_pondok': 'PPS MIFTAHUSSUNAN',
        'nama_pengurus': 'Pengurus Lama',
      });

      await DatabaseHelper.instance.upgradeSchemaForTesting(db, 2, 4);
      DatabaseHelper.instance.setDatabaseForTesting(db);
      addTearDown(() async {
        DatabaseHelper.instance.setDatabaseForTesting(null);
        await db.close();
      });

      final upgradedSantri = await DatabaseHelper.instance.getSantriById('legacy-1');
      expect(upgradedSantri, isNotNull);
      expect(upgradedSantri!.saldoTotal, 125000);
      expect(upgradedSantri.kategoriSantri, Santri.kategoriSantriyin);
      expect(upgradedSantri.statusSantri, Santri.statusAktifVal);

      final upgradedPeng = await DatabaseHelper.instance.getPengaturan();
      expect(upgradedPeng.defaultInfakMasak, 130000);
      expect(upgradedPeng.defaultInfakListrik, 20000);
      expect(upgradedPeng.defaultInfakBerasLiter, 15.0);
      expect(upgradedPeng.defaultInfakBerasUang, 150000);

      await db.insert('infak_santri', infakLunas.toMap());
      await db.insert('serah_terima_infak', serah.toMap());

      final dump = await DatabaseHelper.instance.dumpBackupJson();
      expect(dump['version'], 33);
      expect((dump['infak_santri'] as List).length, 1);
      expect((dump['serah_terima_infak'] as List).length, 1);
      expect(dump['audit_log'], isA<List>());

      final val = BackupService.validateBackupMap(dump);
      expect(val.isValid, true);
      expect(val.infakCount, 1);
      expect(val.serahTerimaInfakCount, 1);

      await DatabaseHelper.instance.restoreFromJson(dump);
      expect((await db.query('infak_santri')).length, 1);
      expect((await db.query('serah_terima_infak')).length, 1);
    });

    test('W. Tahap B: Smart Split Sambangan Atomik, 3 Kantong Kas, Serah Terima & Target Opname', () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.instance.setDatabaseForTesting(db);
      addTearDown(() async {
        DatabaseHelper.instance.setDatabaseForTesting(null);
        await db.close();
      });

      final santri = Santri(
        id: 'sambangan-1',
        namaLengkap: 'Zayd Al-Khair',
        namaPanggilan: 'Zayd',
        kategoriSantri: Santri.kategoriSantriyin,
        kamar: 'Kamar 2',
        saldoTotal: 0,
        jatahHarian: 10000,
      );
      await DatabaseHelper.instance.insertSantri(santri, sumberDompet: 'TUNAI');

      // 1. Sambangan Rp 500.000 (Tunai): Masak 130rb, Listrik 20rb, Beras Uang 150rb -> Sisa Jajan 200rb
      final res1 = await DatabaseHelper.instance.catatSambanganSmartSplit(
        santriId: santri.id,
        totalUangDiterima: 500000,
        tanggalMasuk: DateTime(2026, 11, 25),
        tglHabisYmd: '2026-12-25',
        nominalMasak: 130000,
        isMasakBebas: false,
        nominalListrik: 20000,
        isListrikBebas: false,
        jenisBeras: InfakSantriModel.berasUangVal,
        berasLiter: 0.0,
        berasUang: 150000,
        durasiHari: 30,
        sumberDompet: 'TUNAI',
        catatan: 'Sambangan Wali',
      );
      expect(res1.sisaJajan, 200000);
      expect(res1.jatahBaru, 6500); // floor(200000 / (30 * 500)) * 500 = 6500
      expect(res1.infak.statusLunas, InfakSantriModel.statusLunasVal);

      final updatedSantri = await DatabaseHelper.instance.getSantriById(santri.id);
      expect(updatedSantri!.saldoTotal, 200000);

      // Verifikasi pemisahan Kantong 1 (Jajan Laci = 200rb) & Kantong 2 (Infak Tunai = 300rb) -> Total 500rb
      final dompet = await DatabaseHelper.instance.getSaldoDompet();
      final kantongInfak = await DatabaseHelper.instance.getSaldoKantongInfak();
      expect(dompet['tunai'], 200000);
      expect(kantongInfak['tunai'], 300000);
      expect((dompet['tunai'] ?? 0) + ((kantongInfak['tunai'] as num?)?.toInt() ?? 0), 500000);

      // 2. Sambangan ke-2 bawa Beras Fisik 15 L (via Rekening, Masak 130rb + Listrik 20rb = 150rb infak)
      final s2 = Santri(
        id: 'sambangan-2',
        namaLengkap: 'Hafidz Fisik',
        namaPanggilan: 'Hafidz',
        kamar: 'Kamar 4',
        saldoTotal: 0,
      );
      await DatabaseHelper.instance.insertSantri(s2, sumberDompet: 'TUNAI');
      await DatabaseHelper.instance.catatSambanganSmartSplit(
        santriId: s2.id,
        totalUangDiterima: 450000,
        tanggalMasuk: DateTime(2026, 11, 25),
        tglHabisYmd: '2026-12-25',
        nominalMasak: 130000,
        isMasakBebas: false,
        nominalListrik: 20000,
        isListrikBebas: false,
        jenisBeras: InfakSantriModel.berasFisik,
        berasLiter: 15.0,
        berasUang: 0,
        durasiHari: 30,
        sumberDompet: 'REKENING',
      );
      final k2 = await DatabaseHelper.instance.getSaldoKantongInfak();
      expect(k2['rekening'], 150000);
      expect(k2['beras_stok'], 15.0);

      // 3. Serah Terima Rp 200.000 Tunai & 10 Liter Beras ke Dapur -> sisa Infak Tunai = 100rb, sisa Beras = 5 L
      await DatabaseHelper.instance.insertSerahTerimaInfak(
        SerahTerimaInfakModel(
          id: 'st-tunai-1',
          tanggalSerah: '2026-11-25',
          periodeBulan: '2026-11',
          posInfak: 'GABUNGAN',
          sumberDompet: 'TUNAI',
          nominalUang: 200000,
          penerima: 'Ustadzah Dapur',
        ),
      );
      await DatabaseHelper.instance.insertSerahTerimaInfak(
        SerahTerimaInfakModel(
          id: 'st-beras-1',
          tanggalSerah: '2026-11-25',
          periodeBulan: '2026-11',
          posInfak: 'BERAS_FISIK',
          sumberDompet: 'GUDANG_BERAS',
          jumlahBerasLiter: 10.0,
          penerima: 'Ustadzah Dapur',
        ),
      );
      final k3 = await DatabaseHelper.instance.getSaldoKantongInfak();
      expect(k3['tunai'], 100000);
      expect(k3['beras_stok'], 5.0);

      // Format Struk Sambangan & Berita Acara Serah Terima
      final peng = await DatabaseHelper.instance.getPengaturan();
      final strukWa = ReportService.instance.generateSambanganReceiptText(
        santri: updatedSantri,
        infak: res1.infak,
        pengaturan: peng,
        totalDiterima: 500000,
        sisaJajan: res1.sisaJajan,
        jatahBaru: res1.jatahBaru,
        isProUser: false,
      );
      expect(strukWa, contains('Setoran Sambangan'));
      expect(strukWa, contains('Zayd Al-Khair'));
      expect(strukWa, contains('_Dicatat dengan Kas-Santri_'));

      final baText = ReportService.instance.generateSerahTerimaBeritaAcaraText(
        item: SerahTerimaInfakModel(
          id: 'st-ba',
          tanggalSerah: '2026-11-25',
          periodeBulan: '2026-11',
          nominalUang: 200000,
          penerima: 'Ustadzah Dapur',
        ),
        pengaturan: peng,
      );
      expect(baText, contains('BERITA ACARA SERAH TERIMA INFAK PONDOK'));
      expect(baText, contains('Ustadzah Dapur'));
    });

    test('X. Tahap C: Smart Split 500rb (Uang vs Fisik), Saldo Infak, WA Reminder, PDF & Excel 4-Sheet', () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.instance.setDatabaseForTesting(db);
      addTearDown(() async {
        DatabaseHelper.instance.setDatabaseForTesting(null);
        await db.close();
      });

      final sYin = Santri(
        id: 'c-yin',
        namaLengkap: 'Ahmad Santriyin',
        namaPanggilan: 'Ahmad',
        kategoriSantri: Santri.kategoriSantriyin,
        kamar: 'Al-Bukhori 1',
        noWaWali: '628111111111',
      );
      final sYat = Santri(
        id: 'c-yat',
        namaLengkap: 'Aisyah Santriyat',
        namaPanggilan: 'Aisyah',
        kategoriSantri: Santri.kategoriSantriyat,
        kamar: 'Fatimah 2',
        noWaWali: '628222222222',
      );
      final sBaru = Santri(
        id: 'c-baru',
        namaLengkap: 'Umar Santri Baru',
        namaPanggilan: 'Umar',
        kategoriSantri: Santri.kategoriSantriBaru,
        kamar: 'Abu Bakar 1',
        noWaWali: '628333333333',
      );
      final sPulang = Santri(
        id: 'c-pulang',
        namaLengkap: 'Bilal Pulang',
        namaPanggilan: 'Bilal',
        kategoriSantri: Santri.kategoriSantriyin,
        statusSantri: Santri.statusPulangVal,
        kamar: 'Al-Bukhori 2',
      );

      for (final s in [sYin, sYat, sBaru, sPulang]) {
        await DatabaseHelper.instance.insertSantri(s, sumberDompet: 'TUNAI');
      }

      // 1. Smart Split Rp 500.000 dengan Beras Uang Rp 150.000 -> Sisa Jajan Rp 200.000
      final splitUang = await DatabaseHelper.instance.catatSambanganSmartSplit(
        santriId: sYin.id,
        totalUangDiterima: 500000,
        tanggalMasuk: DateTime(2026, 11, 25),
        tglHabisYmd: '2026-12-25',
        nominalMasak: 130000,
        isMasakBebas: false,
        nominalListrik: 20000,
        isListrikBebas: false,
        jenisBeras: InfakSantriModel.berasUangVal,
        berasLiter: 0.0,
        berasUang: 150000,
        durasiHari: 30,
        sumberDompet: 'TUNAI',
      );
      expect(splitUang.sisaJajan, 200000);
      expect(splitUang.infak.statusLunas, InfakSantriModel.statusLunasVal);

      // 2. Smart Split Rp 500.000 dengan Beras Fisik 15 L -> Sisa Jajan Rp 350.000
      final splitFisik = await DatabaseHelper.instance.catatSambanganSmartSplit(
        santriId: sYat.id,
        totalUangDiterima: 500000,
        tanggalMasuk: DateTime(2026, 11, 25),
        tglHabisYmd: '2026-12-25',
        nominalMasak: 130000,
        isMasakBebas: false,
        nominalListrik: 20000,
        isListrikBebas: false,
        jenisBeras: InfakSantriModel.berasFisik,
        berasLiter: 15.0,
        berasUang: 0,
        durasiHari: 30,
        sumberDompet: 'TUNAI',
      );
      expect(splitFisik.sisaJajan, 350000);
      expect(splitFisik.infak.statusLunas, InfakSantriModel.statusLunasVal);

      // 3. Cicilan Infak untuk Santri Baru
      await DatabaseHelper.instance.upsertInfakSantri(
        InfakSantriModel(
          id: 'inf-c-baru',
          santriId: sBaru.id,
          periodeBulan: '2026-11',
          nominalMasak: 130000,
          nominalListrik: 20000,
          jenisBeras: InfakSantriModel.berasBelum,
          tglMasuk: '2026-11-25',
          tglHabis: '2026-12-25',
          statusLunas: InfakSantriModel.statusCicilVal,
          sumberDompet: 'TUNAI',
          catatan: 'Kurang Beras 15L',
        ),
      );

      // 4. Serah Terima ke Dapur/Yayasan (Rp 200.000 Tunai & 5 L Beras)
      await DatabaseHelper.instance.insertSerahTerimaInfak(
        SerahTerimaInfakModel(
          id: 'st-c-1',
          tanggalSerah: '2026-11-25',
          periodeBulan: '2026-11',
          posInfak: 'GABUNGAN',
          sumberDompet: 'TUNAI',
          nominalUang: 200000,
          penerima: 'Ustadzah Dapur',
        ),
      );
      await DatabaseHelper.instance.insertSerahTerimaInfak(
        SerahTerimaInfakModel(
          id: 'st-c-2',
          tanggalSerah: '2026-11-25',
          periodeBulan: '2026-11',
          posInfak: 'BERAS_FISIK',
          sumberDompet: 'GUDANG_BERAS',
          jumlahBerasLiter: 5.0,
          penerima: 'Ustadzah Dapur',
        ),
      );

      // Total Infak Tunai masuk = 300rb + 150rb + 150rb = 600rb; disetor 200rb -> sisa 400rb
      // Beras masuk = 15 L; disetor 5 L -> sisa 10 L
      final saldoKantong = await DatabaseHelper.instance.getSaldoKantongInfak();
      expect(saldoKantong['tunai'], 400000);
      expect(saldoKantong['beras_stok'], 10.0);

      // 5. Audit seluruh query SQLite ekspor (waktu_ambil + Buku Infak) -> 0 SQLite error
      final mutasiRows = await DatabaseHelper.instance.getTransaksiByDateRange();
      expect(mutasiRows.length, 2);
      expect(mutasiRows.first['waktu_ambil'], isNotNull);

      final peng = await DatabaseHelper.instance.getPengaturan();
      final allSantri = await DatabaseHelper.instance.getAllSantri(onlyActive: false);
      final infakPeriode = await DatabaseHelper.instance.getInfakByPeriode('2026-11');
      final serahList = await DatabaseHelper.instance.getSerahTerimaInfak(periodeBulan: '2026-11');

      // 6. Generator PDF Resmi Buku Infak (Semua Kelompok Terpisah per Halaman)
      final pdfBytes = await YayasanExportService.instance.buildBukuInfakPdfBytes(
        pengaturan: peng,
        periodeBulan: '2026-11',
        santriList: allSantri,
        infakList: infakPeriode,
        serahTerimaList: serahList,
        saldoKantongInfak: saldoKantong,
        scope: InfakPrintScope.semuaTerpisah,
        loadAssetLogo: false,
      );
      expect(pdfBytes.length, greaterThan(500));
      expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');

      // 7. Generator Excel 4-Sheet Buku Infak
      final xlsxBytes = await YayasanExportService.instance.buildExcelBukuInfakBytes(
        pengaturan: peng,
        periodeBulan: '2026-11',
        santriList: allSantri,
        infakList: infakPeriode,
        serahTerimaList: serahList,
        saldoKantongInfak: saldoKantong,
      );
      final decoded = Excel.decodeBytes(xlsxBytes);
      expect(decoded.sheets.keys, contains('Rekap Total & Serah Terima'));
      expect(decoded.sheets.keys, contains('Santriyin'));
      expect(decoded.sheets.keys, contains('Santriyat'));
      expect(decoded.sheets.keys, contains('Santri Baru'));
      expect(decoded.sheets.keys.contains('Sheet1'), false);

      // 8. Pesan Pengingat Jatuh Tempo Infak via WA
      final reminderMsg = ReportService.instance.generateInfakReminderText(
        santri: sBaru,
        pengaturan: peng,
        periodeBulan: '2026-11',
        infak: infakPeriode.where((i) => i.santriId == sBaru.id).firstOrNull,
      );
      expect(reminderMsg, contains('Umar Santri Baru'));
      expect(reminderMsg, contains('PPS MIFTAHUSSUNAN'));
      expect(reminderMsg, contains('2026-12-25'));
    });

    test('Y. v3.2: Autentikasi Bendahara, Akurasi Tanggal Lokal & Filter Rentang Mutasi', () async {
      SharedPreferences.setMockInitialValues({});
      await AccountAuthService.instance.clearAllForTesting();

      // 1. Register & Login Lokal
      final acc = await AccountAuthService.instance.registerLocalAccount(
        namaLengkap: 'Ustadz Ahmad Fauzan',
        jabatan: 'Bendahara Putra',
        username: 'fauzan_putra',
        password: 'password123',
        rememberSession: true,
      );
      expect(acc.authMode, BendaharaAccount.modeLocal);
      expect(acc.namaLengkap, 'Ustadz Ahmad Fauzan');
      expect((await AccountAuthService.instance.getActiveAccount())?.id, acc.id);

      // Wrong password rejected
      await expectLater(
        () => AccountAuthService.instance.loginLocal(
          username: 'fauzan_putra',
          password: 'salahpassword',
        ),
        throwsException,
      );

      // Change password & verify login with new password
      await AccountAuthService.instance.changePassword(
        oldPassword: 'password123',
        newPassword: 'passwordBaru99',
      );
      final relogin = await AccountAuthService.instance.loginLocal(
        username: 'fauzan_putra',
        password: 'passwordBaru99',
      );
      expect(relogin.id, acc.id);

      // Update profile & Logout
      final updatedProf = await AccountAuthService.instance.updateActiveProfile(
        jabatan: 'Bendahara Umum',
      );
      expect(updatedProf.jabatan, 'Bendahara Umum');

      await AccountAuthService.instance.logout();
      expect(await AccountAuthService.instance.getActiveAccount(), isNull);
      expect(await AccountAuthService.instance.isExplicitlyLoggedOut(), true);

      // Offline quick mode always works
      final offlineAcc = await AccountAuthService.instance.enterOfflineQuickMode(
        namaLengkap: 'Petugas Malam',
        jabatan: 'Musyrif Kas',
      );
      expect(offlineAcc.authMode, BendaharaAccount.modeOfflineQuick);

      // 2. Akurasi Tanggal Lokal, Tahun Ajaran per Periode & Rolling Date Infak
      final localParsed = DateFormatter.parseLocalDate('2026-11-26');
      expect(DateFormatter.toLocalDateString(localParsed), '2026-11-26');
      expect(
        DateFormatter.formatAcademicYearForPeriode(
          '2026-11',
          configuredTa: '2026/2027 M / 1448 H',
        ),
        '2026/2027 M / 1448 H',
      );
      expect(
        DateFormatter.formatAcademicYearForPeriode(
          '2027-02',
          configuredTa: '2026/2027 M / 1448 H',
        ),
        '2026/2027 M / 1448 H',
      );
      expect(
        DateFormatter.formatAcademicYearForPeriode(
          '2027-07',
          configuredTa: '2026/2027 M / 1448 H',
        ),
        contains('2027/2028'),
      );
      expect(InfakSantriModel.hitungTglHabis('2026-11-26'), '2026-12-26');
      expect(InfakSantriModel.hitungTglHabis('2024-01-31'), '2024-02-29');

      // 3. Filter Rentang Tanggal SQLite pada getAllTransaksi + ExportPeriod
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.instance.setDatabaseForTesting(db);
      addTearDown(() async {
        DatabaseHelper.instance.setDatabaseForTesting(null);
        await db.close();
      });

      final s = Santri(
        id: 'date-filter-s1',
        namaLengkap: 'Santri Uji Tanggal',
        namaPanggilan: 'Uji',
        kamar: 'Kamar 1',
        saldoTotal: 200000,
      );
      await DatabaseHelper.instance.insertSantri(s, sumberDompet: 'TUNAI');
      await DatabaseHelper.instance.catatPengambilan(
        santriId: s.id,
        nominal: 5000,
        waktuCategory: TimeCategory.pagi,
        customTimestamp: DateTime(2026, 11, 20, 8, 0),
      );
      await DatabaseHelper.instance.catatPengambilan(
        santriId: s.id,
        nominal: 7000,
        waktuCategory: TimeCategory.siang,
        customTimestamp: DateTime(2026, 11, 25, 13, 0),
      );

      final range20 = await DatabaseHelper.instance.getAllTransaksi(
        tanggalMulai: '2026-11-20',
        tanggalSelesai: '2026-11-20',
      );
      expect(range20.length, 1);
      expect(range20.first.nominal, 5000);

      final rangeCustom = YayasanExportService.resolveRange(
        ExportPeriod.rentangKhusus,
        customStart: DateTime(2026, 11, 20),
        customEnd: DateTime(2026, 11, 25),
      );
      expect(rangeCustom.mulai, '2026-11-20');
      expect(rangeCustom.selesai, '2026-11-25');

      final rangeAll = await DatabaseHelper.instance.getAllTransaksi(
        tanggalMulai: rangeCustom.mulai,
        tanggalSelesai: rangeCustom.selesai,
      );
      expect(rangeAll.length, 2);
    });

    test('Z. v3.2 Tahap 2: Validasi Format Excel Rapi (Yayasan 3-Sheet & Buku Infak 4-Sheet)', () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.instance.setDatabaseForTesting(db);
      addTearDown(() async {
        DatabaseHelper.instance.setDatabaseForTesting(null);
        await db.close();
      });

      final s1 = Santri(
        id: 'xls-s1',
        namaLengkap: 'Hasan Al-Basri',
        namaPanggilan: 'Hasan',
        kategoriSantri: Santri.kategoriSantriyin,
        kamar: 'Kamar 1',
        saldoTotal: 250000,
        jatahHarian: 10000,
        tunggakan: 25000,
      );
      final s2 = Santri(
        id: 'xls-s2',
        namaLengkap: 'Fatimah Azzahra',
        namaPanggilan: 'Fatimah',
        kategoriSantri: Santri.kategoriSantriyat,
        kamar: 'Putri 2',
        saldoTotal: 150000,
        jatahHarian: 10000,
      );
      await DatabaseHelper.instance.insertSantri(s1, sumberDompet: 'TUNAI');
      await DatabaseHelper.instance.insertSantri(s2, sumberDompet: 'REKENING');

      await DatabaseHelper.instance.catatPengambilan(
        santriId: s1.id,
        nominal: 5000,
        waktuCategory: TimeCategory.pagi,
        customTimestamp: DateTime(2026, 11, 26, 8, 15),
      );
      await DatabaseHelper.instance.upsertInfakSantri(
        InfakSantriModel(
          id: 'inf-xls-1',
          santriId: s1.id,
          periodeBulan: '2026-11',
          nominalMasak: 130000,
          nominalListrik: 20000,
          jenisBeras: InfakSantriModel.berasUangVal,
          berasUang: 150000,
          tglMasuk: '2026-11-26',
        ),
      );

      final peng = await DatabaseHelper.instance.getPengaturan();
      final santriList = await DatabaseHelper.instance.getAllSantri(onlyActive: false);
      final mutasiRows = await DatabaseHelper.instance.getTransaksiByDateRange();
      final dompetRows = await DatabaseHelper.instance.getAllMutasiDompet();
      final opnames = await DatabaseHelper.instance.getCashOpnameLogs();

      // 1. Validasi Excel Yayasan 3-Sheet rapi & ber-kop
      final yayasanBytes = await YayasanExportService.instance.buildExcelYayasanBytes(
        pengaturan: peng,
        santriList: santriList,
        mutasiRows: mutasiRows,
        dompetRows: dompetRows,
        totalBrankasFisik: 395000,
        kasLaciTunai: 245000,
        rekeningBank: 150000,
        totalTunggakanPondok: 25000,
        opnameLogs: opnames,
        periodeLabel: 'Semua Periode',
      );
      final decodedYayasan = Excel.decodeBytes(yayasanBytes);
      expect(decodedYayasan.sheets.keys, contains('Rekap Santri'));
      expect(decodedYayasan.sheets.keys, contains('Buku Mutasi'));
      expect(decodedYayasan.sheets.keys, contains('Dompet & Opname'));
      expect(decodedYayasan.sheets.keys.contains('Sheet1'), false);

      // 2. Validasi Excel Buku Infak 4-Sheet rapi & ber-kop
      final infakList = await DatabaseHelper.instance.getInfakByPeriode('2026-11');
      final serahList = await DatabaseHelper.instance.getSerahTerimaInfak(periodeBulan: '2026-11');
      final saldoKantong = await DatabaseHelper.instance.getSaldoKantongInfak();
      final infakBytes = await YayasanExportService.instance.buildExcelBukuInfakBytes(
        pengaturan: peng,
        periodeBulan: '2026-11',
        santriList: santriList,
        infakList: infakList,
        serahTerimaList: serahList,
        saldoKantongInfak: saldoKantong,
      );
      final decodedInfak = Excel.decodeBytes(infakBytes);
      expect(decodedInfak.sheets.keys, contains('Rekap Total & Serah Terima'));
      expect(decodedInfak.sheets.keys, contains('Santriyin'));
      expect(decodedInfak.sheets.keys, contains('Santriyat'));
      expect(decodedInfak.sheets.keys, contains('Santri Baru'));
      expect(decodedInfak.sheets.keys.contains('Sheet1'), false);
    });

    test('AA. Hardening v3.3: Anti-Clock Tampering, AES-256-GCM .ksbak, Random Salted Auth & Audit Chain', () async {
      // 1. Anti-Clock Tampering
      final baseTime = DateTime(2026, 11, 26, 12, 0);
      final normalClock = SecurityGuardService.evaluateClockTamper(
        currentNow: baseTime,
        lastKnownEpochMs: baseTime.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
      );
      expect(normalClock.isTampered, false);

      final rewoundClock = SecurityGuardService.evaluateClockTamper(
        currentNow: baseTime.subtract(const Duration(hours: 2)),
        lastKnownEpochMs: baseTime.millisecondsSinceEpoch,
      );
      expect(rewoundClock.isTampered, true);
      expect(rewoundClock.reason, 'CLOCK_REWIND');

      final networkDrift = SecurityGuardService.evaluateClockTamper(
        currentNow: baseTime.subtract(const Duration(days: 3)),
        lastKnownEpochMs: null,
        networkNow: baseTime,
      );
      expect(networkDrift.isTampered, true);
      expect(networkDrift.reason, 'NETWORK_DRIFT');

      // Monotonic check via mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      final mono1 = await SecurityGuardService.instance.checkAndAdvanceClock(
        nowOverride: baseTime,
      );
      expect(mono1.isTampered, false);
      final mono2 = await SecurityGuardService.instance.checkAndAdvanceClock(
        nowOverride: baseTime.subtract(const Duration(minutes: 30)),
      );
      expect(mono2.isTampered, true);

      // 2. Random 16-byte salted PIN & Account Password
      final pHash1 = AuthService.instance.hashPin('2580');
      final pHash2 = AuthService.instance.hashPin('2580');
      expect(pHash1, startsWith('v33:'));
      expect(pHash1 != pHash2, true);
      expect(AuthService.instance.verifyPinAgainstStored('2580', pHash1), true);
      expect(AuthService.instance.verifyPinAgainstStored('1111', pHash1), false);

      final accHash1 = AccountAuthService.hashPassword('bendahara', 'Rahasia123');
      final accHash2 = AccountAuthService.hashPassword('bendahara', 'Rahasia123');
      expect(accHash1, startsWith('v33:'));
      expect(accHash1 != accHash2, true);
      expect(
        AccountAuthService.verifyPasswordHash(
          usernameOrEmail: 'bendahara',
          password: 'Rahasia123',
          storedHash: accHash1,
        ),
        true,
      );

      // 3. AES-256-GCM .ksbak Backup & Restore Validation
      final sampleBackup = <String, dynamic>{
        'version': 33,
        'exported_at': baseTime.toIso8601String(),
        'santri': <dynamic>[],
        'setoran_bulanan': <dynamic>[],
        'transaksi_harian': <dynamic>[],
        'tunggakan_log': <dynamic>[],
        'mutasi_dompet': <dynamic>[],
        'cash_opname_logs': <dynamic>[],
        'pengaturan_aplikasi': <dynamic>[],
        'audit_log': <dynamic>[],
      };
      final encryptedKsbak = await BackupService.encryptBackupToKsbak(
        backupData: sampleBackup,
        password: 'PondokAman2026!',
      );
      expect(BackupService.isEncryptedKsbakBytes(encryptedKsbak), true);

      final wrongPwdRes = await BackupService.decryptAndValidateKsbak(
        bytes: encryptedKsbak,
        password: 'SalahPassword',
      );
      expect(wrongPwdRes.isValid, false);

      final okRes = await BackupService.decryptAndValidateKsbak(
        bytes: encryptedKsbak,
        password: 'PondokAman2026!',
      );
      expect(okRes.isValid, true);
      expect(okRes.parsedData?['version'], 33);

      // 4. Immutable Hash-Chained Audit Log (SQLite v4 FFI)
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 4),
      );
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.instance.setDatabaseForTesting(db);

      await DatabaseHelper.instance.insertAuditLog(
        actor: 'Ustadz Ahmad',
        action: 'VOID_TRANSAKSI',
        targetId: 'tx-001',
        summary: 'Void salah nominal',
      );
      await DatabaseHelper.instance.insertAuditLog(
        actor: 'Ustadz Ahmad',
        action: 'EDIT_SANTRI',
        targetId: 's-001',
        summary: 'Ubah kamar ke A2',
      );
      await DatabaseHelper.instance.insertAuditLog(
        actor: 'Ustadz Ahmad',
        action: 'PRIVASI_LAYAR',
        summary: 'Aktifkan FLAG_SECURE',
      );

      final intact = await DatabaseHelper.instance.verifyAuditLogIntegrity();
      expect(intact.isValid, true);
      expect(intact.totalEntries, 3);
      final logs = await DatabaseHelper.instance.getAuditLogs();
      expect(logs.last.prevHash, AuditLogEntry.genesisHash);

      // Simulasi kecurangan pengubahan langsung isi tabel audit_log
      await db.execute(
        "UPDATE audit_log SET summary = 'Diubah diam-diam' WHERE action = 'VOID_TRANSAKSI'",
      );
      final tampered = await DatabaseHelper.instance.verifyAuditLogIntegrity();
      expect(tampered.isValid, false);

      await db.close();
      DatabaseHelper.instance.setDatabaseForTesting(null);
    });

    test('AB. CustomerSyncService v3.4: Privasi Payload, Semver, Remote Revoke & Mode Offline', () async {
      // 1. Verifikasi payload hanya berisi metadata lisensi non-sensitif (0 data santri/saldo)
      final payload = CustomerSyncService.buildTelemetryPayload(
        deviceId: 'ks-abcd1234',
        namaPondok: 'PPS Miftahussunan',
        namaBendahara: 'Ustadz Ahmad',
        noWaPengurus: '081234567890',
        tier: 'yearly',
        expiryDate: DateTime.utc(2027, 11, 26),
        appVersion: '3.4.0',
        paymentChannel: 'dana',
      );
      expect(payload.keys.toSet(), {
        'p_device_id',
        'p_nama_pondok',
        'p_nama_bendahara',
        'p_no_wa',
        'p_tier',
        'p_expiry_date',
        'p_app_version',
        'p_payment_channel',
      });
      expect(payload['p_device_id'], 'KS-ABCD1234');
      expect(payload['p_tier'], 'YEARLY');
      expect(payload['p_payment_channel'], 'DANA');

      // 2. Verifikasi perbandingan versi Semver
      expect(CustomerSyncService.compareSemver('3.5.0', '3.4.0'), 1);
      expect(CustomerSyncService.compareSemver('3.4.0', '3.4.0'), 0);
      expect(CustomerSyncService.compareSemver('3.3.9', '3.4.0'), -1);

      // 3. Mode offline / belum dikonfigurasi selalu gagal sunyi tanpa melempar error
      final unconfigured = await CustomerSyncService.instance.syncDeviceInBackground(
        deviceId: 'KS-ABCD1234',
        namaPondok: 'PPS Miftahussunan',
        namaBendahara: 'Ustadz Ahmad',
        noWaPengurus: '081234567890',
        tier: 'FREE',
        supabaseUrlOverride: '',
        supabaseAnonKeyOverride: '',
      );
      expect(unconfigured.synced, false);
      expect(unconfigured.isRevoked, false);

      // 4. Verifikasi MockClient menangani Remote Revoke + AppRemoteConfig
      SharedPreferences.setMockInitialValues({});
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://demo.supabase.co/rest/v1/rpc/sync_device_telemetry');
        return http.Response(
          jsonEncode({
            'device_id': 'KS-ABCD1234',
            'is_revoked': true,
            'status': 'DIBLOKIR',
            'remote_config': {
              'latest_version': '3.5.0',
              'min_version': '3.0.0',
              'announcement_title': 'Update Keamanan v3.5',
              'announcement_body': 'Segera perbarui aplikasi Kas-Santri.',
              'promo_banner_active': true,
              'update_url': 'https://mochkhoirulazman-max.github.io/kas-santri./',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final syncRes = await CustomerSyncService.instance.syncDeviceInBackground(
        deviceId: 'KS-ABCD1234',
        namaPondok: 'PPS Miftahussunan',
        namaBendahara: 'Ustadz Ahmad',
        noWaPengurus: '081234567890',
        tier: 'YEARLY',
        client: mockClient,
        supabaseUrlOverride: 'https://demo.supabase.co',
        supabaseAnonKeyOverride: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9_valid_anon_key_length',
      );
      expect(syncRes.synced, true);
      expect(syncRes.isRevoked, true);
      expect(syncRes.remoteConfig?.isUpdateAvailable('3.4.0'), true);
      expect(await CustomerSyncService.instance.getCachedRevokedStatus(), true);
      final cachedCfg = await CustomerSyncService.instance.getCachedRemoteConfig();
      expect(cachedCfg?.latestVersion, '3.5.0');
    });

    test('AC. Ekosistem v4.0: Import Excel Massal, Kartu QR A4, Mutasi/Tutup Buku, Eksekutif PDF & Smart WA Queue', () async {
      // 1. Template & Parse Excel Massal + Deteksi Duplikat + Kuota Gratis
      final tplBytes = BulkSantriExcelService.instance.buildTemplateExcelBytes();
      expect(tplBytes.isNotEmpty, true);

      final parseOk = BulkSantriExcelService.instance.parseAndValidateExcelBytes(
        bytes: tplBytes,
        existingSantri: const [],
        isProUser: true,
      );
      expect(parseOk.validRows.length, 2);
      expect(parseOk.duplicateNames.isEmpty, true);
      expect(parseOk.exceedsFreeQuota, false);

      final parseDupAndQuota = BulkSantriExcelService.instance.parseAndValidateExcelBytes(
        bytes: tplBytes,
        existingSantri: List.generate(
          14,
          (i) => Santri(
            id: 'ex-$i',
            namaLengkap: i == 0 ? 'Ahmad Zaki Mubarroq' : 'Santri $i',
            namaPanggilan: 'S$i',
            kamar: 'K1',
          ),
        ),
        isProUser: false,
      );
      expect(parseDupAndQuota.duplicateNames.length, 1);
      expect(parseDupAndQuota.validRows.length, 1);
      expect(parseDupAndQuota.exceedsFreeQuota, false);

      // 2. Cetak Massal Kartu Santri QR PDF (8 kartu / halaman A4)
      final samplePeng = PengaturanAplikasi(namaPondok: 'PPS MIFTAHUSSUNAN');
      final qrSantri = List.generate(
        9,
        (i) => Santri(
          id: 'qr-$i',
          namaLengkap: 'Santri QR $i',
          namaPanggilan: 'QR$i',
          kamar: 'Kamar ${i % 2 + 1}',
        ),
      );
      final qrPdfBytes = await QrCardPdfService.instance.buildBulkQrCardsPdfBytes(
        pengaturan: samplePeng,
        santriList: qrSantri,
      );
      expect(qrPdfBytes.isNotEmpty, true);
      expect(String.fromCharCodes(qrPdfBytes.sublist(0, 4)), '%PDF');

      // 3. Batch Pindah Kamar & Tutup Buku Alumni (SQLite FFI)
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 4),
      );
      await DatabaseHelper.instance.createSchemaForTesting(db);
      DatabaseHelper.instance.setDatabaseForTesting(db);

      await DatabaseHelper.instance.bulkInsertSantri(parseOk.santriList);
      final inserted = await DatabaseHelper.instance.getAllSantri(onlyActive: false);
      expect(inserted.length, 2);

      final moved = await DatabaseHelper.instance.bulkMoveKamar(
        [inserted.first.id],
        'Kelas 2 MTs',
      );
      expect(moved, 1);

      final archived = await DatabaseHelper.instance.bulkArchiveSantriStatus(
        [inserted.last.id],
        newStatusSantri: Santri.statusAlumniVal,
      );
      expect(archived, 1);

      final activeOnly = await DatabaseHelper.instance.getAllSantri(onlyActive: true);
      expect(activeOnly.length, 1);
      final alumniRow = await DatabaseHelper.instance.getSantriById(inserted.last.id);
      expect(alumniRow?.isAlumni, true);
      expect(alumniRow?.statusAktif, false);

      // 4. Executive Analytics & 1-Page PDF
      final analytics = ExecutiveAnalyticsService.computeSummary(
        activeSantri: activeOnly,
        transaksiRows: const [],
        setoranRows: const [],
        infakPeriodeList: const [],
        opnameLogs: const [],
        totalBrankas: 300000,
        kasTunai: 300000,
        kasRekening: 0,
        totalTunggakan: 0,
      );
      expect(analytics.dailyTrend7d.length, 7);
      expect(analytics.monthlyTrend6m.length, 6);
      final execPdf = await ExecutiveAnalyticsService.instance.buildExecutiveOnePagePdfBytes(
        pengaturan: samplePeng,
        summary: analytics,
      );
      expect(String.fromCharCodes(execPdf.sublist(0, 4)), '%PDF');

      // 5. Smart WA Reminder Queue
      final krisisSantri = Santri(
        id: 'wa-1',
        namaLengkap: 'Santri Kritis',
        namaPanggilan: 'Kritis',
        kamar: 'K1',
        noWaWali: '081234567890',
        saldoTotal: 15000,
        jatahHarian: 10000,
        tunggakan: 50000,
      );
      final queues = SmartWaReminderService.buildPriorityQueues(
        activeSantri: [krisisSantri],
        infakPeriodeList: const [],
      );
      expect(queues[ReminderCategory.saldoKritis]?.length, 1);
      expect(queues[ReminderCategory.infakJatuhTempo]?.length, 1);
      expect(queues[ReminderCategory.tunggakan]?.length, 1);
      final waMsg = SmartWaReminderService.composePoliteMessage(
        item: queues[ReminderCategory.saldoKritis]!.first,
        namaPondok: 'PPS MIFTAHUSSUNAN',
      );
      expect(waMsg, contains('Santri Kritis'));

      await db.close();
      DatabaseHelper.instance.setDatabaseForTesting(null);
    });
  });
}
