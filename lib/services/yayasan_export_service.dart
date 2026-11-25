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
import '../models/infak_santri.dart';
import '../models/pengaturan.dart';
import '../models/santri.dart';
import '../models/serah_terima_infak.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

enum ExportPeriod {
  hariIni,
  tujuhHari,
  bulanIni,
  semua,
}

enum InfakPrintScope {
  santriyin,
  santriyat,
  santriBaru,
  semuaTerpisah,
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
      final createdRaw = (row['waktu_ambil'] ?? '').toString();
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

  static const List<String> _bulanNames = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static String _formatPeriodeId(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = (int.tryParse(parts[1]) ?? 1).clamp(1, 12);
    return '${_bulanNames[m]} $y';
  }

  static String _formatTanggalId(DateTime dt) {
    return '${dt.day} ${_bulanNames[dt.month.clamp(1, 12)]} ${dt.year}';
  }

  static String _formatLiter(double liter) {
    return liter == liter.roundToDouble()
        ? liter.toInt().toString()
        : liter.toStringAsFixed(1);
  }

  static String _buildKetCicil(
    InfakSantriModel inf,
    PengaturanAplikasi peng,
  ) {
    final kurang = <String>[];
    if (!inf.isMasakBebas && inf.nominalMasak < peng.defaultInfakMasak) {
      final sisaM = peng.defaultInfakMasak - inf.nominalMasak;
      kurang.add('Msk -${CurrencyFormatter.format(sisaM)}');
    }
    if (!inf.isListrikBebas && inf.nominalListrik < peng.defaultInfakListrik) {
      final sisaL = peng.defaultInfakListrik - inf.nominalListrik;
      kurang.add('Lst -${CurrencyFormatter.format(sisaL)}');
    }
    if (inf.jenisBeras == InfakSantriModel.berasBelum) {
      kurang.add('Beras Belum');
    } else if (inf.jenisBeras == InfakSantriModel.berasFisik &&
        inf.berasLiter < peng.defaultInfakBerasLiter) {
      final sisaB = peng.defaultInfakBerasLiter - inf.berasLiter;
      kurang.add('Brs -${_formatLiter(sisaB)} L');
    } else if (inf.jenisBeras == InfakSantriModel.berasUang &&
        inf.berasUang < peng.defaultInfakBerasUang) {
      final sisaBu = peng.defaultInfakBerasUang - inf.berasUang;
      kurang.add('Brs -${CurrencyFormatter.format(sisaBu)}');
    }

    final catatan = inf.catatan?.trim() ?? '';
    if (kurang.isNotEmpty) {
      return 'CICIL (${kurang.join(', ')})';
    }
    if (catatan.isNotEmpty) {
      return 'CICIL - $catatan';
    }
    return 'CICIL';
  }

  ({
    List<Santri> sorted,
    int totalMasak,
    int totalListrik,
    int totalBerasUang,
    double totalBerasLiter,
    int grandTotalUang,
    int countLunas,
    int countCicil,
    int countBelum,
    int countPulangPindah,
  }) _summarizeGroupInfak({
    required String kategori,
    required List<Santri> santriList,
    required Map<String, InfakSantriModel> infakBySantriId,
  }) {
    final filtered = santriList
        .where((s) => s.statusAktif && s.kategoriSantri == kategori)
        .toList()
      ..sort((a, b) => a.namaLengkap.toLowerCase().compareTo(b.namaLengkap.toLowerCase()));

    int totalMasak = 0;
    int totalListrik = 0;
    int totalBerasUang = 0;
    double totalBerasLiter = 0.0;
    int countLunas = 0;
    int countCicil = 0;
    int countBelum = 0;
    int countPulangPindah = 0;

    for (final s in filtered) {
      final inf = infakBySantriId[s.id];
      if (inf != null) {
        if (!inf.isMasakBebas) totalMasak += inf.nominalMasak;
        if (!inf.isListrikBebas) totalListrik += inf.nominalListrik;
        if (inf.jenisBeras == InfakSantriModel.berasUang) {
          totalBerasUang += inf.berasUang;
        } else if (inf.jenisBeras == InfakSantriModel.berasFisik) {
          totalBerasLiter += inf.berasLiter;
        }
      }

      if (s.isPulang || s.isPindah) {
        countPulangPindah++;
      } else if (inf == null || inf.statusLunas == InfakSantriModel.statusBelumVal) {
        countBelum++;
      } else if (inf.statusLunas == InfakSantriModel.statusCicilVal) {
        countCicil++;
      } else {
        countLunas++;
      }
    }

    return (
      sorted: filtered,
      totalMasak: totalMasak,
      totalListrik: totalListrik,
      totalBerasUang: totalBerasUang,
      totalBerasLiter: totalBerasLiter,
      grandTotalUang: totalMasak + totalListrik + totalBerasUang,
      countLunas: countLunas,
      countCicil: countCicil,
      countBelum: countBelum,
      countPulangPindah: countPulangPindah,
    );
  }

  /// Menghasilkan bytes PDF Resmi Buku Infak A4 siap cetak
  /// (dapat dipanggil langsung dari UI maupun unit test tanpa ketergantungan UI).
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
  }) async {
    final Uint8List? logoBytes =
        logoBytesOverride ?? (loadAssetLogo ? await _loadLogoBytes(pengaturan) : null);
    final infakBySantriId = <String, InfakSantriModel>{
      for (final item in infakList) item.santriId: item,
    };

    final List<({String kategori, String title})> sections;
    switch (scope) {
      case InfakPrintScope.santriyin:
        sections = [(kategori: Santri.kategoriSantriyin, title: 'DATA INFAK SANTRIYIN')];
        break;
      case InfakPrintScope.santriyat:
        sections = [(kategori: Santri.kategoriSantriyat, title: 'DATA INFAK SANTRIYAT')];
        break;
      case InfakPrintScope.santriBaru:
        sections = [(kategori: Santri.kategoriSantriBaru, title: 'DATA INFAK SANTRI BARU')];
        break;
      case InfakPrintScope.semuaTerpisah:
        sections = [
          (kategori: Santri.kategoriSantriyin, title: 'DATA INFAK SANTRIYIN'),
          (kategori: Santri.kategoriSantriyat, title: 'DATA INFAK SANTRIYAT'),
          (kategori: Santri.kategoriSantriBaru, title: 'DATA INFAK SANTRI BARU'),
        ];
        break;
    }

    int disetorUangPeriode = 0;
    double disetorBerasPeriode = 0.0;
    for (final st in serahTerimaList) {
      if (st.periodeBulan == periodeBulan) {
        disetorUangPeriode += st.nominalUang;
        disetorBerasPeriode += st.jumlahBerasLiter;
      }
    }
    final sisaKasInfakTotal = (saldoKantongInfak['total_uang'] as num?)?.toInt() ?? 0;
    final sisaKasInfakTunai = (saldoKantongInfak['tunai'] as num?)?.toInt() ?? 0;
    final sisaKasInfakBank = (saldoKantongInfak['rekening'] as num?)?.toInt() ?? 0;
    final stokBerasGudang = (saldoKantongInfak['beras_stok'] as num?)?.toDouble() ?? 0.0;
    final periodeLabel = _formatPeriodeId(periodeBulan);
    final printDateLabel = _formatTanggalId(DateTime.now());

    final pdf = pw.Document();

    for (final section in sections) {
      final summary = _summarizeGroupInfak(
        kategori: section.kategori,
        santriList: santriList,
        infakBySantriId: infakBySantriId,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(22),
          build: (pw.Context context) {
            return [
              // Kop Resmi Pondok
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoBytes != null)
                    pw.Container(
                      width: 44,
                      height: 44,
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
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal900,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          section.title,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Tahun Ajaran: ${pengaturan.tahunAjaran}   |   Bulan: $periodeLabel',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.8, color: PdfColors.teal800),
              pw.SizedBox(height: 8),

              // Tabel Rapi Berwarna Lembut
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
                columnWidths: {
                  0: const pw.FixedColumnWidth(24),
                  1: const pw.FlexColumnWidth(2.4),
                  2: const pw.FlexColumnWidth(1.3),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1.3),
                  5: const pw.FlexColumnWidth(1.25),
                  6: const pw.FlexColumnWidth(1.25),
                  7: const pw.FlexColumnWidth(2.1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal800),
                    children: [
                      _pdfHeaderCell('NO', align: pw.TextAlign.center),
                      _pdfHeaderCell('NAMA SANTRI'),
                      _pdfHeaderCell('MASAK', align: pw.TextAlign.right),
                      _pdfHeaderCell('LISTRIK', align: pw.TextAlign.right),
                      _pdfHeaderCell('BERAS', align: pw.TextAlign.right),
                      _pdfHeaderCell('TGL MASUK', align: pw.TextAlign.center),
                      _pdfHeaderCell('TGL HABIS', align: pw.TextAlign.center),
                      _pdfHeaderCell('KET'),
                    ],
                  ),
                  if (summary.sorted.isEmpty)
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        _pdfDataCell('-', align: pw.TextAlign.center),
                        _pdfDataCell('Belum ada data santri pada kelompok ini.'),
                        _pdfDataCell('-'),
                        _pdfDataCell('-'),
                        _pdfDataCell('-'),
                        _pdfDataCell('-'),
                        _pdfDataCell('-'),
                        _pdfDataCell('-'),
                      ],
                    )
                  else
                    ...List.generate(summary.sorted.length, (i) {
                      final s = summary.sorted[i];
                      final inf = infakBySantriId[s.id];

                      final PdfColor rowBg;
                      final String ketText;
                      final PdfColor ketColor;
                      if (s.isPulang) {
                        rowBg = PdfColor.fromInt(0xFFD1FAE5);
                        ketText = 'PULANG';
                        ketColor = PdfColors.teal900;
                      } else if (s.isPindah) {
                        rowBg = PdfColor.fromInt(0xFFE2E8F0);
                        ketText = 'PINDAH';
                        ketColor = PdfColors.blueGrey800;
                      } else if (inf != null && inf.statusLunas == InfakSantriModel.statusLunasVal) {
                        rowBg = PdfColor.fromInt(0xFFECFDF5);
                        ketText = 'LUNAS';
                        ketColor = PdfColors.green800;
                      } else if (inf != null && inf.statusLunas == InfakSantriModel.statusCicilVal) {
                        rowBg = PdfColor.fromInt(0xFFFEF3C7);
                        ketText = _buildKetCicil(inf, pengaturan);
                        ketColor = PdfColors.amber900;
                      } else {
                        rowBg = i.isEven ? PdfColors.white : PdfColor.fromInt(0xFFF8FAFC);
                        ketText = 'BELUM BAYAR';
                        ketColor = PdfColors.red800;
                      }

                      final masakCell = inf == null
                          ? '-'
                          : (inf.isMasakBebas ? 'BEBAS' : CurrencyFormatter.format(inf.nominalMasak));
                      final listrikCell = inf == null
                          ? '-'
                          : (inf.isListrikBebas ? 'BEBAS' : CurrencyFormatter.format(inf.nominalListrik));
                      final String berasCell;
                      if (inf == null || inf.jenisBeras == InfakSantriModel.berasBelum) {
                        berasCell = '-';
                      } else if (inf.jenisBeras == InfakSantriModel.berasBebas) {
                        berasCell = 'BEBAS';
                      } else if (inf.jenisBeras == InfakSantriModel.berasFisik) {
                        berasCell = '${_formatLiter(inf.berasLiter)} L';
                      } else {
                        berasCell = CurrencyFormatter.format(inf.berasUang);
                      }

                      final tglMasukCell = inf != null && inf.tglMasuk.isNotEmpty ? inf.tglMasuk : '-';
                      final tglHabisCell = inf != null && inf.tglHabis.isNotEmpty ? inf.tglHabis : '-';
                      final kamarSuffix = s.kamar.trim().isNotEmpty ? ' (${s.kamar})' : '';

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: rowBg),
                        children: [
                          _pdfDataCell('${i + 1}', align: pw.TextAlign.center),
                          _pdfDataCell('${s.namaLengkap}$kamarSuffix'),
                          _pdfDataCell(
                            masakCell,
                            align: pw.TextAlign.right,
                            color: masakCell == 'BEBAS' ? PdfColors.green800 : PdfColors.black,
                            bold: masakCell == 'BEBAS',
                          ),
                          _pdfDataCell(
                            listrikCell,
                            align: pw.TextAlign.right,
                            color: listrikCell == 'BEBAS' ? PdfColors.green800 : PdfColors.black,
                            bold: listrikCell == 'BEBAS',
                          ),
                          _pdfDataCell(
                            berasCell,
                            align: pw.TextAlign.right,
                            color: berasCell == 'BEBAS' ? PdfColors.green800 : PdfColors.black,
                            bold: berasCell == 'BEBAS',
                          ),
                          _pdfDataCell(tglMasukCell, align: pw.TextAlign.center),
                          _pdfDataCell(tglHabisCell, align: pw.TextAlign.center),
                          _pdfDataCell(ketText, color: ketColor, bold: true),
                        ],
                      );
                    }),
                ],
              ),
              pw.SizedBox(height: 12),

              // Blok Rekap Total Otomatis + Ringkasan Serah Terima ke Dapur/Yayasan
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 11,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.teal50,
                        border: pw.Border.all(color: PdfColors.teal300, width: 0.8),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'REKAP TOTAL KELOMPOK (${summary.sorted.length} SANTRI)',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                          ),
                          pw.SizedBox(height: 4),
                          _pdfKeyValueRow('Total Uang Masak', CurrencyFormatter.format(summary.totalMasak)),
                          _pdfKeyValueRow('Total Uang Listrik', CurrencyFormatter.format(summary.totalListrik)),
                          _pdfKeyValueRow('Total Uang Beras', CurrencyFormatter.format(summary.totalBerasUang)),
                          _pdfKeyValueRow('Total Beras Fisik', '${_formatLiter(summary.totalBerasLiter)} Liter'),
                          pw.Divider(color: PdfColors.teal300, height: 6),
                          _pdfKeyValueRow(
                            'GRAND TOTAL UANG INFAK',
                            CurrencyFormatter.format(summary.grandTotalUang),
                            bold: true,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Status: Lunas ${summary.countLunas} | Cicil ${summary.countCicil} | Belum ${summary.countBelum} | Pulang/Pindah ${summary.countPulangPindah}',
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    flex: 10,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.amber50,
                        border: pw.Border.all(color: PdfColors.amber300, width: 0.8),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SERAH TERIMA DAPUR / YAYASAN ($periodeLabel)',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
                          ),
                          pw.SizedBox(height: 4),
                          _pdfKeyValueRow('Sudah Disetor (Uang)', CurrencyFormatter.format(disetorUangPeriode)),
                          _pdfKeyValueRow('Sudah Disetor (Beras)', '${_formatLiter(disetorBerasPeriode)} Liter'),
                          _pdfKeyValueRow('Sisa Kas Infak di Bendahara', CurrencyFormatter.format(sisaKasInfakTotal), bold: true),
                          _pdfKeyValueRow(
                            'Rincian Sisa (Tunai / Bank)',
                            '${CurrencyFormatter.format(sisaKasInfakTunai)} / ${CurrencyFormatter.format(sisaKasInfakBank)}',
                          ),
                          _pdfKeyValueRow('Sisa Beras di Gudang', '${_formatLiter(stokBerasGudang)} Liter'),
                          if (serahTerimaList.isNotEmpty) ...[
                            pw.Divider(color: PdfColors.amber300, height: 6),
                            ...serahTerimaList.take(3).map((st) {
                              final nilaiStr = st.nominalUang > 0
                                  ? CurrencyFormatter.format(st.nominalUang)
                                  : '${_formatLiter(st.jumlahBerasLiter)} L';
                              return pw.Text(
                                '- ${st.tanggalSerah} -> ${st.penerima}: $nilaiStr',
                                style: const pw.TextStyle(fontSize: 7.2, color: PdfColors.grey800),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 22),

              // Blok Tanda Tangan Resmi
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Mengetahui,', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Pengasuh Pondok,', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 40),
                      pw.Text('( ........................................ )', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Dicetak: $printDateLabel', style: const pw.TextStyle(fontSize: 8.5)),
                      pw.Text('Bendahara Infak,', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 40),
                      pw.Text(
                        '( ${pengaturan.namaPengurus} )',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );
    }

    return await pdf.save();
  }

  pw.Widget _pdfHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  pw.Widget _pdfDataCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = PdfColors.black,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _pdfKeyValueRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7.8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.grey900,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  /// Cetak / Pratinjau PDF Resmi Buku Infak (PRO)
  Future<void> exportPdfBukuInfak({
    required PengaturanAplikasi pengaturan,
    required String periodeBulan,
    required List<Santri> santriList,
    required InfakPrintScope scope,
  }) async {
    final infakList = await DatabaseHelper.instance.getInfakByPeriode(periodeBulan);
    final serahTerimaList =
        await DatabaseHelper.instance.getSerahTerimaInfak(periodeBulan: periodeBulan);
    final saldoKantong = await DatabaseHelper.instance.getSaldoKantongInfak();

    final pdfBytes = await buildBukuInfakPdfBytes(
      pengaturan: pengaturan,
      periodeBulan: periodeBulan,
      santriList: santriList,
      infakList: infakList,
      serahTerimaList: serahTerimaList,
      saldoKantongInfak: saldoKantong,
      scope: scope,
    );

    final safePondok = pengaturan.namaPondok
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .toLowerCase();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Buku_Infak_${safePondok}_${periodeBulan}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Menghasilkan bytes Excel (.xlsx) 4-Sheet Buku Infak:
  /// Sheet 1: Rekap Total & Serah Terima
  /// Sheet 2: Santriyin
  /// Sheet 3: Santriyat
  /// Sheet 4: Santri Baru
  Future<List<int>> buildExcelBukuInfakBytes({
    required PengaturanAplikasi pengaturan,
    required String periodeBulan,
    required List<Santri> santriList,
    required List<InfakSantriModel> infakList,
    required List<SerahTerimaInfakModel> serahTerimaList,
    required Map<String, dynamic> saldoKantongInfak,
  }) async {
    final infakBySantriId = <String, InfakSantriModel>{
      for (final item in infakList) item.santriId: item,
    };
    final periodeLabel = _formatPeriodeId(periodeBulan);
    final excel = Excel.createExcel();

    final groups = [
      (kategori: Santri.kategoriSantriyin, sheetName: 'Santriyin', title: 'DATA INFAK SANTRIYIN'),
      (kategori: Santri.kategoriSantriyat, sheetName: 'Santriyat', title: 'DATA INFAK SANTRIYAT'),
      (kategori: Santri.kategoriSantriBaru, sheetName: 'Santri Baru', title: 'DATA INFAK SANTRI BARU'),
    ];

    final groupSummaries = <({
      String label,
      int totalSantri,
      int totalMasak,
      int totalListrik,
      int totalBerasUang,
      double totalBerasLiter,
      int grandTotalUang,
      int countLunas,
      int countCicil,
      int countBelum,
      int countPulangPindah,
    })>[];

    for (final g in groups) {
      final sum = _summarizeGroupInfak(
        kategori: g.kategori,
        santriList: santriList,
        infakBySantriId: infakBySantriId,
      );
      groupSummaries.add((
        label: g.sheetName,
        totalSantri: sum.sorted.length,
        totalMasak: sum.totalMasak,
        totalListrik: sum.totalListrik,
        totalBerasUang: sum.totalBerasUang,
        totalBerasLiter: sum.totalBerasLiter,
        grandTotalUang: sum.grandTotalUang,
        countLunas: sum.countLunas,
        countCicil: sum.countCicil,
        countBelum: sum.countBelum,
        countPulangPindah: sum.countPulangPindah,
      ));
    }

    // Sheet 1: Rekap Total & Serah Terima
    final rekapSheet = excel['Rekap Total & Serah Terima'];
    rekapSheet.appendRow([TextCellValue(pengaturan.namaPondok.toUpperCase())]);
    rekapSheet.appendRow([TextCellValue('REKAP TOTAL BUKU INFAK & SERAH TERIMA DAPUR / YAYASAN')]);
    rekapSheet.appendRow([TextCellValue('Tahun Ajaran: ${pengaturan.tahunAjaran} | Bulan: $periodeLabel | Dicetak: ${_formatTanggalId(DateTime.now())}')]);
    rekapSheet.appendRow([TextCellValue('')]);
    rekapSheet.appendRow([
      TextCellValue('Kelompok'),
      TextCellValue('Jumlah Santri'),
      TextCellValue('Lunas'),
      TextCellValue('Cicil'),
      TextCellValue('Belum'),
      TextCellValue('Pulang/Pindah'),
      TextCellValue('Total Masak (Rp)'),
      TextCellValue('Total Listrik (Rp)'),
      TextCellValue('Total Beras Uang (Rp)'),
      TextCellValue('Grand Total Uang (Rp)'),
      TextCellValue('Total Beras Fisik (Liter)'),
    ]);

    int allSantri = 0;
    int allLunas = 0;
    int allCicil = 0;
    int allBelum = 0;
    int allPp = 0;
    int allMasak = 0;
    int allListrik = 0;
    int allBerasUang = 0;
    int allGrandUang = 0;
    double allBerasLiter = 0.0;

    for (final gs in groupSummaries) {
      allSantri += gs.totalSantri;
      allLunas += gs.countLunas;
      allCicil += gs.countCicil;
      allBelum += gs.countBelum;
      allPp += gs.countPulangPindah;
      allMasak += gs.totalMasak;
      allListrik += gs.totalListrik;
      allBerasUang += gs.totalBerasUang;
      allGrandUang += gs.grandTotalUang;
      allBerasLiter += gs.totalBerasLiter;

      rekapSheet.appendRow([
        TextCellValue(gs.label),
        IntCellValue(gs.totalSantri),
        IntCellValue(gs.countLunas),
        IntCellValue(gs.countCicil),
        IntCellValue(gs.countBelum),
        IntCellValue(gs.countPulangPindah),
        IntCellValue(gs.totalMasak),
        IntCellValue(gs.totalListrik),
        IntCellValue(gs.totalBerasUang),
        IntCellValue(gs.grandTotalUang),
        DoubleCellValue(gs.totalBerasLiter),
      ]);
    }

    rekapSheet.appendRow([
      TextCellValue('TOTAL PONDOK'),
      IntCellValue(allSantri),
      IntCellValue(allLunas),
      IntCellValue(allCicil),
      IntCellValue(allBelum),
      IntCellValue(allPp),
      IntCellValue(allMasak),
      IntCellValue(allListrik),
      IntCellValue(allBerasUang),
      IntCellValue(allGrandUang),
      DoubleCellValue(allBerasLiter),
    ]);

    int disetorUangPeriode = 0;
    double disetorBerasPeriode = 0.0;
    for (final st in serahTerimaList) {
      if (st.periodeBulan == periodeBulan) {
        disetorUangPeriode += st.nominalUang;
        disetorBerasPeriode += st.jumlahBerasLiter;
      }
    }

    rekapSheet.appendRow([TextCellValue('')]);
    rekapSheet.appendRow([TextCellValue('POSISI KAS INFAK & GUDANG BERAS (KANTONG 2 & 3)'), TextCellValue('Nilai')]);
    rekapSheet.appendRow([TextCellValue('Sudah Disetor ke Dapur/Yayasan Periode Ini (Rp)'), IntCellValue(disetorUangPeriode)]);
    rekapSheet.appendRow([TextCellValue('Sudah Disetor Beras Fisik Periode Ini (Liter)'), DoubleCellValue(disetorBerasPeriode)]);
    rekapSheet.appendRow([TextCellValue('Sisa Kas Infak Tunai Belum Disetor (Rp)'), IntCellValue((saldoKantongInfak['tunai'] as num?)?.toInt() ?? 0)]);
    rekapSheet.appendRow([TextCellValue('Sisa Kas Infak Rekening Belum Disetor (Rp)'), IntCellValue((saldoKantongInfak['rekening'] as num?)?.toInt() ?? 0)]);
    rekapSheet.appendRow([TextCellValue('Total Sisa Kas Infak Belum Disetor (Rp)'), IntCellValue((saldoKantongInfak['total_uang'] as num?)?.toInt() ?? 0)]);
    rekapSheet.appendRow([TextCellValue('Sisa Stok Beras Fisik di Gudang (Liter)'), DoubleCellValue((saldoKantongInfak['beras_stok'] as num?)?.toDouble() ?? 0.0)]);

    rekapSheet.appendRow([TextCellValue('')]);
    rekapSheet.appendRow([TextCellValue('RIWAYAT SERAH TERIMA KE DAPUR / YAYASAN')]);
    rekapSheet.appendRow([
      TextCellValue('No'),
      TextCellValue('Tanggal Serah'),
      TextCellValue('Periode'),
      TextCellValue('Pos Infak'),
      TextCellValue('Sumber Kantong'),
      TextCellValue('Nominal Uang (Rp)'),
      TextCellValue('Jumlah Beras (Liter)'),
      TextCellValue('Penerima'),
      TextCellValue('Catatan'),
    ]);
    for (int i = 0; i < serahTerimaList.length; i++) {
      final st = serahTerimaList[i];
      rekapSheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(st.tanggalSerah),
        TextCellValue(st.periodeBulan),
        TextCellValue(st.posInfak),
        TextCellValue(st.sumberDompet),
        IntCellValue(st.nominalUang),
        DoubleCellValue(st.jumlahBerasLiter),
        TextCellValue(st.penerima),
        TextCellValue(st.catatan ?? '-'),
      ]);
    }

    // Sheet 2, 3, 4: Santriyin, Santriyat, Santri Baru
    for (final g in groups) {
      final sheet = excel[g.sheetName];
      final summary = _summarizeGroupInfak(
        kategori: g.kategori,
        santriList: santriList,
        infakBySantriId: infakBySantriId,
      );

      sheet.appendRow([TextCellValue(pengaturan.namaPondok.toUpperCase())]);
      sheet.appendRow([TextCellValue(g.title)]);
      sheet.appendRow([TextCellValue('Tahun Ajaran: ${pengaturan.tahunAjaran} | Bulan: $periodeLabel')]);
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue('No'),
        TextCellValue('Nama Santri'),
        TextCellValue('Kamar'),
        TextCellValue('Status Santri'),
        TextCellValue('Infak Masak'),
        TextCellValue('Infak Listrik'),
        TextCellValue('Infak Beras'),
        TextCellValue('Tgl Masuk'),
        TextCellValue('Tgl Habis'),
        TextCellValue('Status Infak'),
        TextCellValue('Keterangan'),
      ]);

      for (int i = 0; i < summary.sorted.length; i++) {
        final s = summary.sorted[i];
        final inf = infakBySantriId[s.id];

        final masakText = inf == null
            ? '-'
            : (inf.isMasakBebas ? '✓ Bebas' : CurrencyFormatter.format(inf.nominalMasak));
        final listrikText = inf == null
            ? '-'
            : (inf.isListrikBebas ? '✓ Bebas' : CurrencyFormatter.format(inf.nominalListrik));
        final String berasText;
        if (inf == null || inf.jenisBeras == InfakSantriModel.berasBelum) {
          berasText = '-';
        } else if (inf.jenisBeras == InfakSantriModel.berasBebas) {
          berasText = '✓ Bebas';
        } else if (inf.jenisBeras == InfakSantriModel.berasFisik) {
          berasText = '${_formatLiter(inf.berasLiter)} L';
        } else {
          berasText = CurrencyFormatter.format(inf.berasUang);
        }

        final String ketText;
        final String statusInfak;
        if (s.isPulang) {
          statusInfak = 'PULANG';
          ketText = 'PULANG';
        } else if (s.isPindah) {
          statusInfak = 'PINDAH';
          ketText = 'PINDAH';
        } else if (inf == null || inf.statusLunas == InfakSantriModel.statusBelumVal) {
          statusInfak = 'BELUM';
          ketText = 'Belum Bayar';
        } else if (inf.statusLunas == InfakSantriModel.statusCicilVal) {
          statusInfak = 'CICIL';
          ketText = _buildKetCicil(inf, pengaturan);
        } else {
          statusInfak = 'LUNAS';
          ketText = 'Lunas';
        }

        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(s.namaLengkap),
          TextCellValue(s.kamar.isEmpty ? '-' : s.kamar),
          TextCellValue(s.statusSantriLabel),
          TextCellValue(masakText),
          TextCellValue(listrikText),
          TextCellValue(berasText),
          TextCellValue(inf?.tglMasuk ?? '-'),
          TextCellValue(inf?.tglHabis ?? '-'),
          TextCellValue(statusInfak),
          TextCellValue(ketText),
        ]);
      }

      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([
        TextCellValue('TOTAL'),
        TextCellValue('${summary.sorted.length} Santri'),
        TextCellValue(''),
        TextCellValue(''),
        IntCellValue(summary.totalMasak),
        IntCellValue(summary.totalListrik),
        TextCellValue('${_formatLiter(summary.totalBerasLiter)} L + ${CurrencyFormatter.format(summary.totalBerasUang)}'),
        TextCellValue('Grand Total Uang'),
        IntCellValue(summary.grandTotalUang),
        TextCellValue('Lunas: ${summary.countLunas}'),
        TextCellValue('Cicil: ${summary.countCicil}, Belum: ${summary.countBelum}, PP: ${summary.countPulangPindah}'),
      ]);
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final encoded = excel.save();
    if (encoded == null) {
      throw Exception('Gagal membuat file Excel 4-Sheet Buku Infak (.xlsx).');
    }
    return encoded;
  }

  /// Ekspor & bagikan Excel (.xlsx) 4-Sheet Buku Infak (PRO)
  Future<File> exportExcelBukuInfak({
    required PengaturanAplikasi pengaturan,
    required String periodeBulan,
    required List<Santri> santriList,
    bool shareAfterCreate = true,
  }) async {
    final infakList = await DatabaseHelper.instance.getInfakByPeriode(periodeBulan);
    final serahTerimaList =
        await DatabaseHelper.instance.getSerahTerimaInfak(periodeBulan: periodeBulan);
    final saldoKantong = await DatabaseHelper.instance.getSaldoKantongInfak();

    final encoded = await buildExcelBukuInfakBytes(
      pengaturan: pengaturan,
      periodeBulan: periodeBulan,
      santriList: santriList,
      infakList: infakList,
      serahTerimaList: serahTerimaList,
      saldoKantongInfak: saldoKantong,
    );

    final dir = await getTemporaryDirectory();
    final safePondok = pengaturan.namaPondok
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .toLowerCase();
    final file = File(
      p.join(dir.path, 'buku_infak_4sheet_${safePondok}_${periodeBulan}_${DateTime.now().millisecondsSinceEpoch}.xlsx'),
    );
    await file.writeAsBytes(encoded, flush: true);

    if (shareAfterCreate) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Buku Infak 4-Sheet ${pengaturan.namaPondok} (${_formatPeriodeId(periodeBulan)})',
      );
    }
    return file;
  }
}
