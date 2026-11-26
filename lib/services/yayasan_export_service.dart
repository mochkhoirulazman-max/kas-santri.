import 'dart:io';
import 'dart:typed_data';
import '../models/cash_opname_log.dart';
import '../models/infak_santri.dart';
import '../models/pengaturan.dart';
import '../models/santri.dart';
import '../models/serah_terima_infak.dart';
import '../utils/date_formatter.dart';
import 'exports/yayasan_excel_exporter.dart';
import 'exports/yayasan_pdf_exporter.dart';

enum ExportPeriod {
  hariIni,
  kemarin,
  tujuhHari,
  bulanIni,
  rentangKhusus,
  semua,
}

enum InfakPrintScope {
  santriyin,
  santriyat,
  santriBaru,
  semuaTerpisah,
}

/// Facade ekspor laporan resmi Yayasan & Buku Infak Kas-Santri v4.2 yang
/// mendelegasikan pembuatan Excel (`.xlsx` via background isolate `compute()`)
/// ke `YayasanExcelExporter` dan dokumen PDF A4 ke `YayasanPdfExporter`.
class YayasanExportService {
  static final YayasanExportService instance = YayasanExportService._init();
  YayasanExportService._init();

  final YayasanExcelExporter excelExporter = const YayasanExcelExporter();
  final YayasanPdfExporter pdfExporter = const YayasanPdfExporter();

  static String periodLabel(
    ExportPeriod period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    switch (period) {
      case ExportPeriod.hariIni:
        return 'Hari Ini';
      case ExportPeriod.kemarin:
        return 'Kemarin';
      case ExportPeriod.tujuhHari:
        return '7 Hari Terakhir';
      case ExportPeriod.bulanIni:
        return 'Bulan Ini';
      case ExportPeriod.rentangKhusus:
        if (customStart != null && customEnd != null) {
          return '${DateFormatter.toLocalDateString(customStart)} s.d. ${DateFormatter.toLocalDateString(customEnd)}';
        }
        return '📅 Rentang Khusus';
      case ExportPeriod.semua:
        return 'Semua Riwayat';
    }
  }

  static ({String? mulai, String? selesai, String label}) resolveRange(
    ExportPeriod period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final now = DateTime.now().toLocal();
    final today = DateFormatter.toLocalDateString(now);
    switch (period) {
      case ExportPeriod.hariIni:
        return (mulai: today, selesai: today, label: 'Hari Ini ($today)');
      case ExportPeriod.kemarin:
        final yest = DateFormatter.toLocalDateString(
          now.subtract(const Duration(days: 1)),
        );
        return (mulai: yest, selesai: yest, label: 'Kemarin ($yest)');
      case ExportPeriod.tujuhHari:
        final start = DateFormatter.toLocalDateString(
          now.subtract(const Duration(days: 6)),
        );
        return (
          mulai: start,
          selesai: today,
          label: '7 Hari ($start s.d. $today)',
        );
      case ExportPeriod.bulanIni:
        final start = DateFormatter.toLocalDateString(
          DateTime(now.year, now.month, 1),
        );
        return (
          mulai: start,
          selesai: today,
          label: 'Bulan Ini ($start s.d. $today)',
        );
      case ExportPeriod.rentangKhusus:
        final sDate = customStart ?? now;
        final eDate = customEnd ?? sDate;
        final startStr = DateFormatter.toLocalDateString(sDate);
        final endStr = DateFormatter.toLocalDateString(eDate);
        return (
          mulai: startStr,
          selesai: endStr,
          label: 'Rentang ($startStr s.d. $endStr)',
        );
      case ExportPeriod.semua:
        return (mulai: null, selesai: null, label: 'Semua Periode');
    }
  }

  Future<List<int>> buildExcelYayasanBytes({
    required PengaturanAplikasi pengaturan,
    required List<Santri> santriList,
    required List<Map<String, dynamic>> mutasiRows,
    required List<Map<String, dynamic>> dompetRows,
    required int totalBrankasFisik,
    required int kasLaciTunai,
    required int rekeningBank,
    required int totalTunggakanPondok,
    required List<CashOpnameLog> opnameLogs,
    required String periodeLabel,
  }) =>
      excelExporter.buildExcelYayasanBytes(
        pengaturan: pengaturan,
        santriList: santriList,
        mutasiRows: mutasiRows,
        dompetRows: dompetRows,
        totalBrankasFisik: totalBrankasFisik,
        kasLaciTunai: kasLaciTunai,
        rekeningBank: rekeningBank,
        totalTunggakanPondok: totalTunggakanPondok,
        opnameLogs: opnameLogs,
        periodeLabel: periodeLabel,
      );

  Future<File> exportExcelMultiSheet({
    required PengaturanAplikasi pengaturan,
    required List<Santri> santriList,
    required int totalBrankasFisik,
    required int kasLaciTunai,
    required int rekeningBank,
    required int totalTunggakanPondok,
    required List<CashOpnameLog> opnameLogs,
    required ExportPeriod period,
    DateTime? customStart,
    DateTime? customEnd,
    bool shareAfterCreate = true,
  }) =>
      excelExporter.exportExcelMultiSheet(
        pengaturan: pengaturan,
        santriList: santriList,
        totalBrankasFisik: totalBrankasFisik,
        kasLaciTunai: kasLaciTunai,
        rekeningBank: rekeningBank,
        totalTunggakanPondok: totalTunggakanPondok,
        opnameLogs: opnameLogs,
        period: period,
        customStart: customStart,
        customEnd: customEnd,
        shareAfterCreate: shareAfterCreate,
      );

  Future<void> exportPdfResmiYayasan({
    required PengaturanAplikasi pengaturan,
    required List<Santri> santriList,
    required int totalBrankasFisik,
    required int kasLaciTunai,
    required int rekeningBank,
    required int totalTunggakanPondok,
    required ExportPeriod period,
    DateTime? customStart,
    DateTime? customEnd,
  }) =>
      pdfExporter.exportPdfResmiYayasan(
        pengaturan: pengaturan,
        santriList: santriList,
        totalBrankasFisik: totalBrankasFisik,
        kasLaciTunai: kasLaciTunai,
        rekeningBank: rekeningBank,
        totalTunggakanPondok: totalTunggakanPondok,
        period: period,
        customStart: customStart,
        customEnd: customEnd,
      );

  Future<Uint8List> buildBukuInfakPdfBytes({
    required PengaturanAplikasi pengaturan,
    required String periodeBulan,
    required List<Santri> santriList,
    required List<InfakSantriModel> infakList,
    required List<SerahTerimaInfakModel> serahTerimaList,
    required Map<String, dynamic> saldoKantongInfak,
    required InfakPrintScope scope,
    Uint8List? logoBytesOverride,
    bool loadAssetLogo = true,
  }) =>
      pdfExporter.buildBukuInfakPdfBytes(
        pengaturan: pengaturan,
        periodeBulan: periodeBulan,
        santriList: santriList,
        infakList: infakList,
        serahTerimaList: serahTerimaList,
        saldoKantongInfak: saldoKantongInfak,
        scope: scope,
        logoBytesOverride: logoBytesOverride,
        loadAssetLogo: loadAssetLogo,
      );

  Future<void> exportPdfBukuInfak({
    required PengaturanAplikasi pengaturan,
    required String periodeBulan,
    required List<Santri> santriList,
    required InfakPrintScope scope,
  }) =>
      pdfExporter.exportPdfBukuInfak(
        pengaturan: pengaturan,
        periodeBulan: periodeBulan,
        santriList: santriList,
        scope: scope,
      );

  Future<List<int>> buildExcelBukuInfakBytes({
    required PengaturanAplikasi pengaturan,
    required String periodeBulan,
    required List<Santri> santriList,
    required List<InfakSantriModel> infakList,
    required List<SerahTerimaInfakModel> serahTerimaList,
    required Map<String, dynamic> saldoKantongInfak,
  }) =>
      excelExporter.buildExcelBukuInfakBytes(
        pengaturan: pengaturan,
        periodeBulan: periodeBulan,
        santriList: santriList,
        infakList: infakList,
        serahTerimaList: serahTerimaList,
        saldoKantongInfak: saldoKantongInfak,
      );

  Future<File> exportExcelBukuInfak({
    required PengaturanAplikasi pengaturan,
    required String periodeBulan,
    required List<Santri> santriList,
    bool shareAfterCreate = true,
  }) =>
      excelExporter.exportExcelBukuInfak(
        pengaturan: pengaturan,
        periodeBulan: periodeBulan,
        santriList: santriList,
        shareAfterCreate: shareAfterCreate,
      );
}
