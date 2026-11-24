import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../models/cash_opname_log.dart';
import '../models/pengaturan.dart';
import '../models/santri.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

enum ExportPeriod {
  hariIni,
  tujuhHari,
  bulanIni,
  semua,
}

class YayasanExportService {
  static final YayasanExportService instance = YayasanExportService._init();
  YayasanExportService._init();

  static String periodLabel(ExportPeriod period) {
    switch (period) {
      case ExportPeriod.hariIni:
        return 'Hari Ini';
      case ExportPeriod.tujuhHari:
        return '7 Hari Terakhir';
      case ExportPeriod.bulanIni:
        return 'Bulan Ini';
      case ExportPeriod.semua:
        return 'Semua Riwayat';
    }
  }

  static ({String? mulai, String? selesai, String label}) resolveRange(ExportPeriod period) {
    final now = DateTime.now();
    final today = DateFormatter.toLocalDateString(now);
    switch (period) {
      case ExportPeriod.hariIni:
        return (mulai: today, selesai: today, label: 'Hari Ini ($today)');
      case ExportPeriod.tujuhHari:
        final start = DateFormatter.toLocalDateString(now.subtract(const Duration(days: 6)));
        return (mulai: start, selesai: today, label: '7 Hari ($start s.d. $today)');
      case ExportPeriod.bulanIni:
        final start = DateFormatter.toLocalDateString(DateTime(now.year, now.month, 1));
        return (mulai: start, selesai: today, label: 'Bulan Ini ($start s.d. $today)');
      case ExportPeriod.semua:
        return (mulai: null, selesai: null, label: 'Semua Periode');
    }
  }

  Future<Uint8List?> _loadLogoBytes(PengaturanAplikasi pengaturan) async {
    try {
      final path = pengaturan.logoPath;
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
      final data = await rootBundle.load('logo.jpg');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Ekspor Excel (.xlsx) Multi-Sheet:
  /// Sheet 1: Rekap Saldo & Tunggakan Santri
  /// Sheet 2: Buku Mutasi Detail
  /// Sheet 3: Ringkasan Multi-Dompet & Riwayat Cash Opname
  Future<File> exportExcelMultiSheet({
    required PengaturanAplikasi pengaturan,
    required List<Santri> santriList,
    required int totalBrankasFisik,
    required int kasLaciTunai,
    required int rekeningBank,
    required int totalTunggakanPondok,
    required List<CashOpnameLog> opnameLogs,
    required ExportPeriod period,
    bool shareAfterCreate = true,
  }) async {
    final range = resolveRange(period);
    final mutasiRows = await DatabaseHelper.instance.getTransaksiByDateRange(
      tanggalMulai: range.mulai,
      tanggalSelesai: range.selesai,
    );
    final dompetRows = await DatabaseHelper.instance.getAllMutasiDompet(
      tanggalMulai: range.mulai,
      tanggalSelesai: range.selesai,
    );

    final excel = Excel.createExcel();

    // Sheet 1: Rekap Santri
    final sheet1 = excel['Rekap Santri'];
    sheet1.appendRow([TextCellValue(pengaturan.namaPondok.toUpperCase())]);
    sheet1.appendRow([TextCellValue('LAPORAN REKAP SALDO & TUNGGAKAN SANTRI')]);
    sheet1.appendRow([TextCellValue('Periode: ${range.label} | Dicetak: ${DateFormatter.formatDisplayDate(DateTime.now())}')]);
    sheet1.appendRow([TextCellValue('')]);
    sheet1.appendRow([
      TextCellValue('No'),
      TextCellValue('Nama Lengkap'),
      TextCellValue('Panggilan'),
      TextCellValue('Kamar'),
      TextCellValue('No WA Wali'),
      TextCellValue('Kode QR'),
      TextCellValue('Saldo Titipan (Rp)'),
      TextCellValue('Jatah Harian (Rp)'),
      TextCellValue('Estimasi (Hari)'),
      TextCellValue('Tunggakan (Rp)'),
      TextCellValue('Catatan Tunggakan'),
    ]);

    int sumSaldo = 0;
    int sumTunggakan = 0;
    for (int i = 0; i < santriList.length; i++) {
      final s = santriList[i];
      sumSaldo += s.saldoTotal;
      sumTunggakan += s.tunggakan;
      sheet1.appendRow([
        IntCellValue(i + 1),
        TextCellValue(s.namaLengkap),
        TextCellValue(s.namaPanggilan),
        TextCellValue(s.kamar),
        TextCellValue(s.noWaWali ?? '-'),
        TextCellValue(s.qrCode),
        IntCellValue(s.saldoTotal),
        IntCellValue(s.jatahHarian),
        IntCellValue(s.estimasiHari),
        IntCellValue(s.tunggakan),
        TextCellValue(s.catatanTunggakan.isEmpty ? '-' : s.catatanTunggakan),
      ]);
    }
    sheet1.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue('${santriList.length} Santri'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      IntCellValue(sumSaldo),
      TextCellValue(''),
      TextCellValue(''),
      IntCellValue(sumTunggakan),
      TextCellValue(''),
    ]);

    // Sheet 2: Buku Mutasi
    final sheet2 = excel['Buku Mutasi'];
    sheet2.appendRow([TextCellValue(pengaturan.namaPondok.toUpperCase())]);
    sheet2.appendRow([TextCellValue('BUKU MUTASI TRANSAKSI SANTRI DETAIL')]);
    sheet2.appendRow([TextCellValue('Periode: ${range.label}')]);
    sheet2.appendRow([TextCellValue('')]);
    sheet2.appendRow([
      TextCellValue('No'),
      TextCellValue('Tanggal'),
      TextCellValue('Waktu'),
      TextCellValue('Nama Santri'),
      TextCellValue('Kamar'),
      TextCellValue('Tipe'),
      TextCellValue('Sesi Waktu'),
      TextCellValue('Dompet'),
      TextCellValue('Nominal (Rp)'),
      TextCellValue('Saldo Setelah (Rp)'),
      TextCellValue('Status'),
      TextCellValue('Catatan'),
    ]);

    for (int i = 0; i < mutasiRows.length; i++) {
      final row = mutasiRows[i];
      final isVoid = (row['is_void'] as num?)?.toInt() == 1 ||
          (row['is_voided'] as num?)?.toInt() == 1;
      final createdRaw = (row['waktu_ambil'] ?? row['created_at'] ?? '').toString();
      final dt = DateTime.tryParse(createdRaw);
      final jam = dt != null
          ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : '-';
      sheet2.appendRow([
        IntCellValue(i + 1),
        TextCellValue((row['tanggal_lokal'] ?? '-').toString()),
        TextCellValue(jam),
        TextCellValue((row['nama_lengkap'] ?? '-').toString()),
        TextCellValue((row['kamar'] ?? '-').toString()),
        TextCellValue((row['tipe'] ?? 'PENGAMBILAN').toString()),
        TextCellValue((row['kategori_waktu'] ?? '-').toString()),
        TextCellValue((row['sumber_dompet'] ?? 'TUNAI').toString()),
        IntCellValue((row['nominal'] as num?)?.toInt() ?? 0),
        IntCellValue((row['saldo_setelah_transaksi'] as num?)?.toInt() ?? 0),
        TextCellValue(isVoid ? 'VOID (DIBATALKAN)' : 'SAH'),
        TextCellValue((row['catatan'] ?? '-').toString()),
      ]);
    }

    // Sheet 3: Dompet & Opname
    final sheet3 = excel['Dompet & Opname'];
    sheet3.appendRow([TextCellValue(pengaturan.namaPondok.toUpperCase())]);
    sheet3.appendRow([TextCellValue('RINGKASAN MULTI-DOMPET & RIWAYAT CASH OPNAME')]);
    sheet3.appendRow([TextCellValue('Periode: ${range.label}')]);
    sheet3.appendRow([TextCellValue('')]);
    sheet3.appendRow([TextCellValue('RINGKASAN BRANKAS SAAT INI'), TextCellValue('Nominal (Rp)')]);
    sheet3.appendRow([TextCellValue('Total Uang Titipan (Brankas)'), IntCellValue(totalBrankasFisik)]);
    sheet3.appendRow([TextCellValue('Kas Laci Tunai'), IntCellValue(kasLaciTunai)]);
    sheet3.appendRow([TextCellValue('Rekening Bank'), IntCellValue(rekeningBank)]);
    sheet3.appendRow([TextCellValue('Total Tunggakan Pondok'), IntCellValue(totalTunggakanPondok)]);
    sheet3.appendRow([TextCellValue('')]);

    sheet3.appendRow([TextCellValue('RIWAYAT MUTASI DOMPET')]);
    sheet3.appendRow([
      TextCellValue('No'),
      TextCellValue('Tanggal'),
      TextCellValue('Dompet'),
      TextCellValue('Tipe'),
      TextCellValue('Nominal (Rp)'),
      TextCellValue('Catatan'),
    ]);
    for (int i = 0; i < dompetRows.length; i++) {
      final d = dompetRows[i];
      sheet3.appendRow([
        IntCellValue(i + 1),
        TextCellValue((d['tanggal_lokal'] ?? '-').toString()),
        TextCellValue((d['jenis_dompet'] ?? 'TUNAI').toString()),
        TextCellValue((d['tipe'] ?? '-').toString()),
        IntCellValue((d['nominal'] as num?)?.toInt() ?? 0),
        TextCellValue((d['catatan'] ?? '-').toString()),
      ]);
    }

    sheet3.appendRow([TextCellValue('')]);
    sheet3.appendRow([TextCellValue('RIWAYAT CASH OPNAME FISIK')]);
    sheet3.appendRow([
      TextCellValue('No'),
      TextCellValue('Tanggal'),
      TextCellValue('Kas Sistem (Rp)'),
      TextCellValue('Uang Fisik (Rp)'),
      TextCellValue('Selisih (Rp)'),
      TextCellValue('Status'),
      TextCellValue('Catatan'),
    ]);
    for (int i = 0; i < opnameLogs.length; i++) {
      final op = opnameLogs[i];
      sheet3.appendRow([
        IntCellValue(i + 1),
        TextCellValue(op.tanggalLokal),
        IntCellValue(op.totalSistem),
        IntCellValue(op.totalFisik),
        IntCellValue(op.selisih),
        TextCellValue(op.isCocok ? 'COCOK' : 'SELISIH'),
        TextCellValue(op.catatan ?? '-'),
      ]);
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final encoded = excel.save();
    if (encoded == null) {
      throw Exception('Gagal membuat file Excel (.xlsx).');
    }

    final dir = await getTemporaryDirectory();
    final safePondok = pengaturan.namaPondok
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .toLowerCase();
    final file = File(
      p.join(dir.path, 'laporan_yayasan_${safePondok}_${DateTime.now().millisecondsSinceEpoch}.xlsx'),
    );
    await file.writeAsBytes(encoded, flush: true);

    if (shareAfterCreate) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Laporan Resmi Yayasan ${pengaturan.namaPondok} — ${range.label}',
      );
    }
    return file;
  }

  /// Ekspor PDF Resmi Yayasan lengkap dengan Kop Logo Pondok, ringkasan brankas,
  /// tabel santri & mutasi, serta kolom tanda tangan Bendahara & Pengasuh Pondok.
  Future<void> exportPdfResmiYayasan({
    required PengaturanAplikasi pengaturan,
    required List<Santri> santriList,
    required int totalBrankasFisik,
    required int kasLaciTunai,
    required int rekeningBank,
    required int totalTunggakanPondok,
    required ExportPeriod period,
  }) async {
    final range = resolveRange(period);
    final mutasiRows = await DatabaseHelper.instance.getTransaksiByDateRange(
      tanggalMulai: range.mulai,
      tanggalSelesai: range.selesai,
    );
    final logoBytes = await _loadLogoBytes(pengaturan);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            // Kop Resmi Yayasan + Logo
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoBytes != null)
                  pw.Container(
                    width: 48,
                    height: 48,
                    margin: const pw.EdgeInsets.only(right: 12),
                    child: pw.ClipOval(
                      child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.cover),
                    ),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        pengaturan.namaPondok.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'LAPORAN KEUANGAN RESMI YAYASAN — KAS & TITIPAN SANTRI',
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.Text(
                        'Periode: ${range.label}  •  Dicetak: ${DateFormatter.formatDisplayDate(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.8, color: PdfColors.teal800),
            pw.SizedBox(height: 10),

            // Ringkasan Multi-Dompet & Brankas
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.teal300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfMetric('Total Titipan', CurrencyFormatter.format(totalBrankasFisik)),
                  _pdfMetric('Kas Laci Tunai', CurrencyFormatter.format(kasLaciTunai)),
                  _pdfMetric('Rekening Bank', CurrencyFormatter.format(rekeningBank)),
                  _pdfMetric('Total Tunggakan', CurrencyFormatter.format(totalTunggakanPondok)),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Tabel 1: Rekap Saldo Santri
            pw.Text(
              'A. Rekapitulasi Saldo & Tunggakan Santri (${santriList.length} Santri)',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.teal900),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['No', 'Nama Santri', 'Kamar', 'Saldo', 'Jatah/Hr', 'Est.', 'Tunggakan'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              data: List.generate(santriList.length, (i) {
                final s = santriList[i];
                return [
                  '${i + 1}',
                  s.namaLengkap,
                  s.kamar,
                  CurrencyFormatter.format(s.saldoTotal),
                  CurrencyFormatter.format(s.jatahHarian),
                  '${s.estimasiHari} hr',
                  s.tunggakan > 0 ? CurrencyFormatter.format(s.tunggakan) : '-',
                ];
              }),
            ),
            pw.SizedBox(height: 16),

            // Tabel 2: Mutasi Detail
            pw.Text(
              'B. Buku Mutasi Transaksi Periode (${mutasiRows.length} catatan)',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.teal900),
            ),
            pw.SizedBox(height: 6),
            if (mutasiRows.isEmpty)
              pw.Text(
                'Tidak ada transaksi pada periode yang dipilih.',
                style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey600),
              )
            else
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Tanggal', 'Santri', 'Tipe / Sesi', 'Dompet', 'Nominal', 'Status', 'Catatan'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                data: mutasiRows.take(120).map((row) {
                  final isVoid = (row['is_void'] as num?)?.toInt() == 1 ||
                      (row['is_voided'] as num?)?.toInt() == 1;
                  final nom = (row['nominal'] as num?)?.toInt() ?? 0;
                  return [
                    (row['tanggal_lokal'] ?? '-').toString(),
                    (row['nama_lengkap'] ?? '-').toString(),
                    '${row['tipe'] ?? ''} (${row['kategori_waktu'] ?? ''})',
                    (row['sumber_dompet'] ?? 'TUNAI').toString(),
                    CurrencyFormatter.format(nom),
                    isVoid ? 'VOID' : 'SAH',
                    (row['catatan'] ?? '-').toString(),
                  ];
                }).toList(),
              ),

            pw.SizedBox(height: 28),

            // Kolom Pengesahan Resmi Yayasan
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Mengetahui,', style: const pw.TextStyle(fontSize: 9.5)),
                    pw.Text('Pengasuh Pondok,', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 46),
                    pw.Text('( ........................................ )', style: const pw.TextStyle(fontSize: 9.5)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Dicetak: ${DateFormatter.formatDisplayDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Bendahara Kas,', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 46),
                    pw.Text(
                      '( ${pengaturan.namaPengurus} )',
                      style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    final safePondok = pengaturan.namaPondok
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .toLowerCase();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_Yayasan_${safePondok}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  pw.Widget _pdfMetric(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
        ),
      ],
    );
  }
}
