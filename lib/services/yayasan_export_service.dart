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

class YayasanExportService {
  static final YayasanExportService instance = YayasanExportService._init();
  YayasanExportService._init();

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
        return (mulai: start, selesai: today, label: '7 Hari ($start s.d. $today)');
      case ExportPeriod.bulanIni:
        final start = DateFormatter.toLocalDateString(DateTime(now.year, now.month, 1));
        return (mulai: start, selesai: today, label: 'Bulan Ini ($start s.d. $today)');
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

  static final Border _thinCellBorder = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.fromHexString('#CBD5E1'),
  );
  static final Border _headerCellBorder = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.fromHexString('#0F766E'),
  );
  static final Border _totalTopBorder = Border(
    borderStyle: BorderStyle.Medium,
    borderColorHex: ExcelColor.fromHexString('#0F766E'),
  );
  static final NumFormat _rupiahNumFormat =
      CustomNumericNumFormat(formatCode: '"Rp "#,##0');
  static final NumFormat _literNumFormat =
      CustomNumericNumFormat(formatCode: '0.0" L"');

  CellStyle _kopTitleStyle() => CellStyle(
        bold: true,
        fontSize: 13,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _kopSubStyle() => CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('#0F172A'),
        backgroundColorHex: ExcelColor.fromHexString('#CCFBF1'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _kopMetaStyle() => CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#334155'),
        backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _tableHeaderStyle({String bgHex = '#0F172A'}) => CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString(bgHex),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
        leftBorder: _headerCellBorder,
        rightBorder: _headerCellBorder,
        topBorder: _headerCellBorder,
        bottomBorder: _headerCellBorder,
      );

  CellStyle _dataStyle({
    HorizontalAlign align = HorizontalAlign.Left,
    String? bgHex,
    String fontHex = '#0F172A',
    bool bold = false,
    NumFormat? numFormat,
  }) {
    return CellStyle(
      bold: bold,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString(fontHex),
      backgroundColorHex:
          bgHex != null ? ExcelColor.fromHexString(bgHex) : ExcelColor.none,
      horizontalAlign: align,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      numberFormat: numFormat ?? NumFormat.standard_0,
      leftBorder: _thinCellBorder,
      rightBorder: _thinCellBorder,
      topBorder: _thinCellBorder,
      bottomBorder: _thinCellBorder,
    );
  }

  CellStyle _totalStyle({
    HorizontalAlign align = HorizontalAlign.Right,
    NumFormat? numFormat,
    String bgHex = '#E2E8F0',
  }) {
    return CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      backgroundColorHex: ExcelColor.fromHexString(bgHex),
      horizontalAlign: align,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      numberFormat: numFormat ?? NumFormat.standard_0,
      leftBorder: _thinCellBorder,
      rightBorder: _thinCellBorder,
      topBorder: _totalTopBorder,
      bottomBorder: _totalTopBorder,
    );
  }

  ({String bgHex, String fontHex}) _statusPalette(String status) {
    switch (status.toUpperCase()) {
      case 'LUNAS':
      case 'SAH':
      case 'COCOK':
      case 'BEBAS':
        return (bgHex: '#DCFCE7', fontHex: '#166534');
      case 'CICIL':
      case 'SELISIH':
        return (bgHex: '#FEF3C7', fontHex: '#92400E');
      case 'BELUM':
      case 'VOID':
      case 'VOID (DIBATALKAN)':
        return (bgHex: '#FFE4E6', fontHex: '#9F1239');
      case 'PULANG':
      case 'PINDAH':
        return (bgHex: '#E2E8F0', fontHex: '#334155');
      default:
        return (bgHex: '#F8FAFC', fontHex: '#0F172A');
    }
  }

  void _writeMergedBanner(
    Sheet sheet, {
    required int row,
    required int lastCol,
    required String text,
    required CellStyle style,
  }) {
    final start = CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row);
    final end = CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: row);
    sheet.cell(start).value = TextCellValue(text);
    sheet.merge(start, end);
    for (int c = 0; c <= lastCol; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
          .cellStyle = style;
    }
  }

  void _writeStyledRow(
    Sheet sheet, {
    required int row,
    required List<CellValue> values,
    required List<CellStyle> styles,
  }) {
    for (int c = 0; c < values.length; c++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      cell.value = values[c];
      if (c < styles.length) {
        cell.cellStyle = styles[c];
      }
    }
  }

  void _applyColumnWidths(Sheet sheet, List<double> widths) {
    for (int c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }
  }

  void _writeSignatureBlock(
    Sheet sheet, {
    required int startRow,
    required int lastCol,
    required PengaturanAplikasi pengaturan,
    required String printDate,
    required String bendaharaRole,
  }) {
    final signStyle = CellStyle(
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final signBold = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final leftEnd = (lastCol ~/ 2).clamp(1, lastCol);
    final rightStart = (leftEnd + 1).clamp(1, lastCol);

    void mergePair(int r, String leftText, String rightText, CellStyle st) {
      final ls = CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r);
      final le = CellIndex.indexByColumnRow(columnIndex: leftEnd, rowIndex: r);
      sheet.cell(ls).value = TextCellValue(leftText);
      if (leftEnd > 0) sheet.merge(ls, le);
      for (int c = 0; c <= leftEnd; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = st;
      }

      if (rightStart <= lastCol) {
        final rs = CellIndex.indexByColumnRow(columnIndex: rightStart, rowIndex: r);
        final re = CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: r);
        sheet.cell(rs).value = TextCellValue(rightText);
        if (lastCol > rightStart) sheet.merge(rs, re);
        for (int c = rightStart; c <= lastCol; c++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = st;
        }
      }
    }

    mergePair(startRow, 'Mengetahui,', 'Dicetak: $printDate', signStyle);
    mergePair(startRow + 1, 'Pengasuh Pondok,', bendaharaRole, signBold);
    mergePair(
      startRow + 4,
      '( ........................................ )',
      '( ${pengaturan.namaPengurus} )',
      signBold,
    );
  }

  /// Menghasilkan bytes Excel (.xlsx) Multi-Sheet Yayasan yang rapi & siap cetak:
  /// Sheet 1: Rekap Santri
  /// Sheet 2: Buku Mutasi
  /// Sheet 3: Dompet & Opname
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
  }) async {
    final excel = Excel.createExcel();
    final printDate = _formatTanggalId(DateTime.now().toLocal());

    // ==================== SHEET 1: REKAP SANTRI ====================
    final sheet1 = excel['Rekap Santri'];
    _applyColumnWidths(sheet1, [6, 26, 14, 16, 16, 15, 18, 16, 13, 18, 24]);

    int r1 = 0;
    _writeMergedBanner(
      sheet1,
      row: r1++,
      lastCol: 10,
      text: pengaturan.namaPondok.toUpperCase(),
      style: _kopTitleStyle(),
    );
    _writeMergedBanner(
      sheet1,
      row: r1++,
      lastCol: 10,
      text: 'LAPORAN REKAPITULASI SALDO TITIPAN & TUNGGAKAN SANTRI',
      style: _kopSubStyle(),
    );
    _writeMergedBanner(
      sheet1,
      row: r1++,
      lastCol: 10,
      text: 'Periode: $periodeLabel  |  TA: ${pengaturan.tahunAjaran}  |  Bendahara: ${pengaturan.namaPengurus}  |  Dicetak: $printDate',
      style: _kopMetaStyle(),
    );
    r1++;

    _writeStyledRow(
      sheet1,
      row: r1++,
      values: [
        TextCellValue('No'),
        TextCellValue('Nama Lengkap'),
        TextCellValue('Panggilan'),
        TextCellValue('Kamar'),
        TextCellValue('No WA Wali'),
        TextCellValue('Kode QR'),
        TextCellValue('Saldo Titipan'),
        TextCellValue('Jatah Harian'),
        TextCellValue('Estimasi (Hr)'),
        TextCellValue('Tunggakan'),
        TextCellValue('Catatan Tunggakan'),
      ],
      styles: List.filled(11, _tableHeaderStyle(bgHex: '#0F172A')),
    );

    int sumSaldo = 0;
    int sumTunggakan = 0;
    for (int i = 0; i < santriList.length; i++) {
      final s = santriList[i];
      sumSaldo += s.saldoTotal;
      sumTunggakan += s.tunggakan;
      final rowBg = i.isEven ? '#FFFFFF' : '#F8FAFC';
      final tunggBg = s.tunggakan > 0 ? '#FFE4E6' : rowBg;
      final tunggFont = s.tunggakan > 0 ? '#9F1239' : '#0F172A';

      _writeStyledRow(
        sheet1,
        row: r1++,
        values: [
          IntCellValue(i + 1),
          TextCellValue(s.namaLengkap),
          TextCellValue(s.namaPanggilan),
          TextCellValue(s.kamar.isEmpty ? '-' : s.kamar),
          TextCellValue(s.noWaWali ?? '-'),
          TextCellValue(s.qrCode),
          IntCellValue(s.saldoTotal),
          IntCellValue(s.jatahHarian),
          IntCellValue(s.estimasiHari),
          IntCellValue(s.tunggakan),
          TextCellValue(s.catatanTunggakan.isEmpty ? '-' : s.catatanTunggakan),
        ],
        styles: [
          _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
          _dataStyle(bgHex: rowBg, bold: true),
          _dataStyle(bgHex: rowBg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
          _dataStyle(align: HorizontalAlign.Right, bgHex: rowBg, bold: true, numFormat: _rupiahNumFormat),
          _dataStyle(align: HorizontalAlign.Right, bgHex: rowBg, numFormat: _rupiahNumFormat),
          _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
          _dataStyle(align: HorizontalAlign.Right, bgHex: tunggBg, fontHex: tunggFont, bold: s.tunggakan > 0, numFormat: _rupiahNumFormat),
          _dataStyle(bgHex: rowBg),
        ],
      );
    }

    _writeStyledRow(
      sheet1,
      row: r1++,
      values: [
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
      ],
      styles: [
        _totalStyle(align: HorizontalAlign.Center),
        _totalStyle(align: HorizontalAlign.Left),
        _totalStyle(align: HorizontalAlign.Left),
        _totalStyle(align: HorizontalAlign.Left),
        _totalStyle(align: HorizontalAlign.Left),
        _totalStyle(align: HorizontalAlign.Left),
        _totalStyle(align: HorizontalAlign.Right, numFormat: _rupiahNumFormat),
        _totalStyle(align: HorizontalAlign.Right),
        _totalStyle(align: HorizontalAlign.Center),
        _totalStyle(align: HorizontalAlign.Right, numFormat: _rupiahNumFormat),
        _totalStyle(align: HorizontalAlign.Left),
      ],
    );
    _writeSignatureBlock(
      sheet1,
      startRow: r1 + 2,
      lastCol: 10,
      pengaturan: pengaturan,
      printDate: printDate,
      bendaharaRole: 'Bendahara Kas,',
    );

    // ==================== SHEET 2: BUKU MUTASI ====================
    final sheet2 = excel['Buku Mutasi'];
    _applyColumnWidths(sheet2, [6, 13, 9, 24, 14, 15, 12, 11, 18, 18, 16, 28]);

    int r2 = 0;
    _writeMergedBanner(
      sheet2,
      row: r2++,
      lastCol: 11,
      text: pengaturan.namaPondok.toUpperCase(),
      style: _kopTitleStyle(),
    );
    _writeMergedBanner(
      sheet2,
      row: r2++,
      lastCol: 11,
      text: 'BUKU MUTASI TRANSAKSI SANTRI DETAIL',
      style: _kopSubStyle(),
    );
    _writeMergedBanner(
      sheet2,
      row: r2++,
      lastCol: 11,
      text: 'Periode: $periodeLabel  |  TA: ${pengaturan.tahunAjaran}  |  Bendahara: ${pengaturan.namaPengurus}',
      style: _kopMetaStyle(),
    );
    r2++;

    _writeStyledRow(
      sheet2,
      row: r2++,
      values: [
        TextCellValue('No'),
        TextCellValue('Tanggal'),
        TextCellValue('Jam'),
        TextCellValue('Nama Santri'),
        TextCellValue('Kamar'),
        TextCellValue('Tipe'),
        TextCellValue('Sesi'),
        TextCellValue('Dompet'),
        TextCellValue('Nominal'),
        TextCellValue('Saldo Setelah'),
        TextCellValue('Status'),
        TextCellValue('Catatan'),
      ],
      styles: List.filled(12, _tableHeaderStyle(bgHex: '#0F172A')),
    );

    int totalSetoranSah = 0;
    int totalAmbilSah = 0;
    for (int i = 0; i < mutasiRows.length; i++) {
      final row = mutasiRows[i];
      final isVoid = (row['is_void'] as num?)?.toInt() == 1 ||
          (row['is_voided'] as num?)?.toInt() == 1;
      final createdRaw = (row['waktu_ambil'] ?? '').toString();
      final dt = DateTime.tryParse(createdRaw)?.toLocal();
      final jam = dt != null
          ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : '-';
      final tipe = (row['tipe'] ?? 'PENGAMBILAN').toString();
      final nom = (row['nominal'] as num?)?.toInt() ?? 0;
      if (!isVoid) {
        if (tipe == 'SETORAN') {
          totalSetoranSah += nom;
        } else {
          totalAmbilSah += nom;
        }
      }
      final statusStr = isVoid ? 'VOID (DIBATALKAN)' : 'SAH';
      final pal = _statusPalette(statusStr);
      final rowBg = i.isEven ? '#FFFFFF' : '#F8FAFC';

      _writeStyledRow(
        sheet2,
        row: r2++,
        values: [
          IntCellValue(i + 1),
          TextCellValue((row['tanggal_lokal'] ?? '-').toString()),
          TextCellValue(jam),
          TextCellValue((row['nama_lengkap'] ?? '-').toString()),
          TextCellValue((row['kamar'] ?? '-').toString()),
          TextCellValue(tipe),
          TextCellValue((row['kategori_waktu'] ?? '-').toString()),
          TextCellValue((row['sumber_dompet'] ?? 'TUNAI').toString()),
          IntCellValue(nom),
          IntCellValue((row['saldo_setelah_transaksi'] as num?)?.toInt() ?? 0),
          TextCellValue(statusStr),
          TextCellValue((row['catatan'] ?? '-').toString()),
        ],
        styles: [
          _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
          _dataStyle(bgHex: rowBg, bold: true),
          _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
          _dataStyle(align: HorizontalAlign.Right, bgHex: rowBg, bold: true, numFormat: _rupiahNumFormat),
          _dataStyle(align: HorizontalAlign.Right, bgHex: rowBg, numFormat: _rupiahNumFormat),
          _dataStyle(align: HorizontalAlign.Center, bgHex: pal.bgHex, fontHex: pal.fontHex, bold: true),
          _dataStyle(bgHex: rowBg),
        ],
      );
    }

    _writeStyledRow(
      sheet2,
      row: r2++,
      values: [
        TextCellValue('TOTAL'),
        TextCellValue('${mutasiRows.length} Mutasi'),
        TextCellValue(''),
        TextCellValue('Masuk Sah:'),
        IntCellValue(totalSetoranSah),
        TextCellValue('Keluar Sah:'),
        IntCellValue(totalAmbilSah),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
      ],
      styles: [
        _totalStyle(align: HorizontalAlign.Center),
        _totalStyle(align: HorizontalAlign.Left),
        _totalStyle(align: HorizontalAlign.Left),
        _totalStyle(align: HorizontalAlign.Right),
        _totalStyle(align: HorizontalAlign.Right, numFormat: _rupiahNumFormat),
        _totalStyle(align: HorizontalAlign.Right),
        _totalStyle(align: HorizontalAlign.Right, numFormat: _rupiahNumFormat),
        _totalStyle(align: HorizontalAlign.Left),
        _totalStyle(align: HorizontalAlign.Right),
        _totalStyle(align: HorizontalAlign.Right),
        _totalStyle(align: HorizontalAlign.Center),
        _totalStyle(align: HorizontalAlign.Left),
      ],
    );
    _writeSignatureBlock(
      sheet2,
      startRow: r2 + 2,
      lastCol: 11,
      pengaturan: pengaturan,
      printDate: printDate,
      bendaharaRole: 'Bendahara Kas,',
    );

    // ==================== SHEET 3: DOMPET & OPNAME ====================
    final sheet3 = excel['Dompet & Opname'];
    _applyColumnWidths(sheet3, [6, 14, 24, 18, 18, 18, 28]);

    int r3 = 0;
    _writeMergedBanner(
      sheet3,
      row: r3++,
      lastCol: 6,
      text: pengaturan.namaPondok.toUpperCase(),
      style: _kopTitleStyle(),
    );
    _writeMergedBanner(
      sheet3,
      row: r3++,
      lastCol: 6,
      text: 'RINGKASAN MULTI-DOMPET & RIWAYAT CASH OPNAME FISIK',
      style: _kopSubStyle(),
    );
    _writeMergedBanner(
      sheet3,
      row: r3++,
      lastCol: 6,
      text: 'Periode: $periodeLabel  |  TA: ${pengaturan.tahunAjaran}  |  Bendahara: ${pengaturan.namaPengurus}',
      style: _kopMetaStyle(),
    );
    r3++;

    _writeStyledRow(
      sheet3,
      row: r3++,
      values: [
        TextCellValue('RINGKASAN BRANKAS SAAT INI'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('Nominal'),
      ],
      styles: List.filled(4, _tableHeaderStyle(bgHex: '#0F766E')),
    );
    final brankasSummary = [
      ('Total Uang Titipan Santri (Brankas)', totalBrankasFisik),
      ('Kas Laci Tunai (Uang Jajan)', kasLaciTunai),
      ('Saldo Rekening Bank', rekeningBank),
      ('Total Tunggakan Pondok', totalTunggakanPondok),
    ];
    for (int i = 0; i < brankasSummary.length; i++) {
      final bg = i.isEven ? '#FFFFFF' : '#F8FAFC';
      _writeStyledRow(
        sheet3,
        row: r3++,
        values: [
          TextCellValue(brankasSummary[i].$1),
          TextCellValue(''),
          TextCellValue(''),
          IntCellValue(brankasSummary[i].$2),
        ],
        styles: [
          _dataStyle(bgHex: bg, bold: true),
          _dataStyle(bgHex: bg),
          _dataStyle(bgHex: bg),
          _dataStyle(align: HorizontalAlign.Right, bgHex: bg, bold: true, numFormat: _rupiahNumFormat),
        ],
      );
    }
    r3++;

    _writeMergedBanner(
      sheet3,
      row: r3++,
      lastCol: 6,
      text: 'RIWAYAT MUTASI DOMPET (${dompetRows.length} Catatan)',
      style: _kopSubStyle(),
    );
    _writeStyledRow(
      sheet3,
      row: r3++,
      values: [
        TextCellValue('No'),
        TextCellValue('Tanggal'),
        TextCellValue('Dompet'),
        TextCellValue('Tipe'),
        TextCellValue('Nominal'),
        TextCellValue('Referensi'),
        TextCellValue('Catatan'),
      ],
      styles: List.filled(7, _tableHeaderStyle(bgHex: '#0F172A')),
    );
    for (int i = 0; i < dompetRows.length; i++) {
      final d = dompetRows[i];
      final bg = i.isEven ? '#FFFFFF' : '#F8FAFC';
      _writeStyledRow(
        sheet3,
        row: r3++,
        values: [
          IntCellValue(i + 1),
          TextCellValue((d['tanggal_lokal'] ?? '-').toString()),
          TextCellValue((d['jenis_dompet'] ?? 'TUNAI').toString()),
          TextCellValue((d['tipe'] ?? '-').toString()),
          IntCellValue((d['nominal'] as num?)?.toInt() ?? 0),
          TextCellValue((d['referensi_id'] ?? '-').toString()),
          TextCellValue((d['catatan'] ?? '-').toString()),
        ],
        styles: [
          _dataStyle(align: HorizontalAlign.Center, bgHex: bg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: bg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: bg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: bg, bold: true),
          _dataStyle(align: HorizontalAlign.Right, bgHex: bg, bold: true, numFormat: _rupiahNumFormat),
          _dataStyle(align: HorizontalAlign.Center, bgHex: bg),
          _dataStyle(bgHex: bg),
        ],
      );
    }
    r3++;

    _writeMergedBanner(
      sheet3,
      row: r3++,
      lastCol: 6,
      text: 'RIWAYAT CASH OPNAME FISIK (${opnameLogs.length} Catatan)',
      style: _kopSubStyle(),
    );
    _writeStyledRow(
      sheet3,
      row: r3++,
      values: [
        TextCellValue('No'),
        TextCellValue('Tanggal'),
        TextCellValue('Kas Sistem'),
        TextCellValue('Uang Fisik'),
        TextCellValue('Selisih'),
        TextCellValue('Status'),
        TextCellValue('Catatan'),
      ],
      styles: List.filled(7, _tableHeaderStyle(bgHex: '#0F172A')),
    );
    for (int i = 0; i < opnameLogs.length; i++) {
      final op = opnameLogs[i];
      final statusStr = op.isCocok ? 'COCOK' : 'SELISIH';
      final pal = _statusPalette(statusStr);
      final bg = i.isEven ? '#FFFFFF' : '#F8FAFC';
      _writeStyledRow(
        sheet3,
        row: r3++,
        values: [
          IntCellValue(i + 1),
          TextCellValue(op.tanggalLokal),
          IntCellValue(op.totalSistem),
          IntCellValue(op.totalFisik),
          IntCellValue(op.selisih),
          TextCellValue(statusStr),
          TextCellValue(op.catatan ?? '-'),
        ],
        styles: [
          _dataStyle(align: HorizontalAlign.Center, bgHex: bg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: bg),
          _dataStyle(align: HorizontalAlign.Right, bgHex: bg, numFormat: _rupiahNumFormat),
          _dataStyle(align: HorizontalAlign.Right, bgHex: bg, bold: true, numFormat: _rupiahNumFormat),
          _dataStyle(align: HorizontalAlign.Right, bgHex: pal.bgHex, fontHex: pal.fontHex, bold: true, numFormat: _rupiahNumFormat),
          _dataStyle(align: HorizontalAlign.Center, bgHex: pal.bgHex, fontHex: pal.fontHex, bold: true),
          _dataStyle(bgHex: bg),
        ],
      );
    }

    _writeSignatureBlock(
      sheet3,
      startRow: r3 + 2,
      lastCol: 6,
      pengaturan: pengaturan,
      printDate: printDate,
      bendaharaRole: 'Bendahara Kas,',
    );

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final encoded = excel.save();
    if (encoded == null) {
      throw Exception('Gagal membuat file Excel (.xlsx).');
    }
    return encoded;
  }

  /// Ekspor Excel (.xlsx) Multi-Sheet Yayasan:
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
    DateTime? customStart,
    DateTime? customEnd,
    bool shareAfterCreate = true,
  }) async {
    final range = resolveRange(
      period,
      customStart: customStart,
      customEnd: customEnd,
    );
    final mutasiRows = await DatabaseHelper.instance.getTransaksiByDateRange(
      tanggalMulai: range.mulai,
      tanggalSelesai: range.selesai,
    );
    final dompetRows = await DatabaseHelper.instance.getAllMutasiDompet(
      tanggalMulai: range.mulai,
      tanggalSelesai: range.selesai,
    );

    final encoded = await buildExcelYayasanBytes(
      pengaturan: pengaturan,
      santriList: santriList,
      mutasiRows: mutasiRows,
      dompetRows: dompetRows,
      totalBrankasFisik: totalBrankasFisik,
      kasLaciTunai: kasLaciTunai,
      rekeningBank: rekeningBank,
      totalTunggakanPondok: totalTunggakanPondok,
      opnameLogs: opnameLogs,
      periodeLabel: range.label,
    );

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
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final range = resolveRange(
      period,
      customStart: customStart,
      customEnd: customEnd,
    );
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
    } else if (inf.jenisBeras == InfakSantriModel.berasUangVal &&
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
        if (inf.jenisBeras == InfakSantriModel.berasUangVal) {
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

  /// Menghasilkan bytes Excel (.xlsx) 4-Sheet Buku Infak rapi & siap cetak:
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
    final taLabel = DateFormatter.formatAcademicYearForPeriode(
      periodeBulan,
      configuredTa: pengaturan.tahunAjaran,
    );
    final printDate = _formatTanggalId(DateTime.now().toLocal());
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

    // ==================== SHEET 1: REKAP TOTAL & SERAH TERIMA ====================
    final rekapSheet = excel['Rekap Total & Serah Terima'];
    _applyColumnWidths(rekapSheet, [18, 12, 9, 9, 9, 13, 18, 18, 19, 20, 17]);

    int rr = 0;
    _writeMergedBanner(
      rekapSheet,
      row: rr++,
      lastCol: 10,
      text: pengaturan.namaPondok.toUpperCase(),
      style: _kopTitleStyle(),
    );
    _writeMergedBanner(
      rekapSheet,
      row: rr++,
      lastCol: 10,
      text: 'REKAP TOTAL BUKU INFAK & SERAH TERIMA DAPUR / YAYASAN',
      style: _kopSubStyle(),
    );
    _writeMergedBanner(
      rekapSheet,
      row: rr++,
      lastCol: 10,
      text: 'Bulan: $periodeLabel  |  Tahun Ajaran: $taLabel  |  Bendahara: ${pengaturan.namaPengurus}  |  Dicetak: $printDate',
      style: _kopMetaStyle(),
    );
    rr++;

    _writeStyledRow(
      rekapSheet,
      row: rr++,
      values: [
        TextCellValue('Kelompok'),
        TextCellValue('Jml Santri'),
        TextCellValue('Lunas'),
        TextCellValue('Cicil'),
        TextCellValue('Belum'),
        TextCellValue('Pulang/Pindah'),
        TextCellValue('Total Masak'),
        TextCellValue('Total Listrik'),
        TextCellValue('Total Beras Uang'),
        TextCellValue('Grand Total Uang'),
        TextCellValue('Beras Fisik (L)'),
      ],
      styles: List.filled(11, _tableHeaderStyle(bgHex: '#0F766E')),
    );

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

    for (int i = 0; i < groupSummaries.length; i++) {
      final gs = groupSummaries[i];
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

      final bg = i.isEven ? '#FFFFFF' : '#F8FAFC';
      _writeStyledRow(
        rekapSheet,
        row: rr++,
        values: [
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
        ],
        styles: [
          _dataStyle(bgHex: bg, bold: true),
          _dataStyle(align: HorizontalAlign.Center, bgHex: bg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: '#DCFCE7', fontHex: '#166534', bold: true),
          _dataStyle(align: HorizontalAlign.Center, bgHex: '#FEF3C7', fontHex: '#92400E', bold: true),
          _dataStyle(align: HorizontalAlign.Center, bgHex: '#FFE4E6', fontHex: '#9F1239', bold: true),
          _dataStyle(align: HorizontalAlign.Center, bgHex: '#E2E8F0', fontHex: '#334155'),
          _dataStyle(align: HorizontalAlign.Right, bgHex: bg, numFormat: _rupiahNumFormat),
          _dataStyle(align: HorizontalAlign.Right, bgHex: bg, numFormat: _rupiahNumFormat),
          _dataStyle(align: HorizontalAlign.Right, bgHex: bg, numFormat: _rupiahNumFormat),
          _dataStyle(align: HorizontalAlign.Right, bgHex: bg, bold: true, numFormat: _rupiahNumFormat),
          _dataStyle(align: HorizontalAlign.Right, bgHex: bg, bold: true, numFormat: _literNumFormat),
        ],
      );
    }

    _writeStyledRow(
      rekapSheet,
      row: rr++,
      values: [
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
      ],
      styles: [
        _totalStyle(align: HorizontalAlign.Left),
        _totalStyle(align: HorizontalAlign.Center),
        _totalStyle(align: HorizontalAlign.Center),
        _totalStyle(align: HorizontalAlign.Center),
        _totalStyle(align: HorizontalAlign.Center),
        _totalStyle(align: HorizontalAlign.Center),
        _totalStyle(align: HorizontalAlign.Right, numFormat: _rupiahNumFormat),
        _totalStyle(align: HorizontalAlign.Right, numFormat: _rupiahNumFormat),
        _totalStyle(align: HorizontalAlign.Right, numFormat: _rupiahNumFormat),
        _totalStyle(align: HorizontalAlign.Right, numFormat: _rupiahNumFormat, bgHex: '#CCFBF1'),
        _totalStyle(align: HorizontalAlign.Right, numFormat: _literNumFormat, bgHex: '#FEF3C7'),
      ],
    );
    rr++;

    int disetorUangPeriode = 0;
    double disetorBerasPeriode = 0.0;
    for (final st in serahTerimaList) {
      if (st.periodeBulan == periodeBulan) {
        disetorUangPeriode += st.nominalUang;
        disetorBerasPeriode += st.jumlahBerasLiter;
      }
    }

    _writeMergedBanner(
      rekapSheet,
      row: rr++,
      lastCol: 5,
      text: 'POSISI KAS INFAK & GUDANG BERAS (KANTONG 2 & 3)',
      style: _tableHeaderStyle(bgHex: '#0F172A'),
    );
    final posisiRows = <(String label, CellValue val, NumFormat? fmt)>[
      ('Sudah Disetor ke Dapur/Yayasan Periode Ini (Uang)', IntCellValue(disetorUangPeriode), _rupiahNumFormat),
      ('Sudah Disetor Beras Fisik Periode Ini (Liter)', DoubleCellValue(disetorBerasPeriode), _literNumFormat),
      ('Sisa Kas Infak Tunai Belum Disetor', IntCellValue((saldoKantongInfak['tunai'] as num?)?.toInt() ?? 0), _rupiahNumFormat),
      ('Sisa Kas Infak Rekening Belum Disetor', IntCellValue((saldoKantongInfak['rekening'] as num?)?.toInt() ?? 0), _rupiahNumFormat),
      ('Total Sisa Kas Infak Belum Disetor', IntCellValue((saldoKantongInfak['total_uang'] as num?)?.toInt() ?? 0), _rupiahNumFormat),
      ('Sisa Stok Beras Fisik di Gudang', DoubleCellValue((saldoKantongInfak['beras_stok'] as num?)?.toDouble() ?? 0.0), _literNumFormat),
    ];
    for (int i = 0; i < posisiRows.length; i++) {
      final pr = posisiRows[i];
      final bg = i >= 4 ? '#ECFDF5' : (i.isEven ? '#FFFFFF' : '#F8FAFC');
      _writeStyledRow(
        rekapSheet,
        row: rr++,
        values: [
          TextCellValue(pr.$1),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          pr.$2,
          TextCellValue(''),
        ],
        styles: [
          _dataStyle(bgHex: bg, bold: i >= 4),
          _dataStyle(bgHex: bg),
          _dataStyle(bgHex: bg),
          _dataStyle(bgHex: bg),
          _dataStyle(align: HorizontalAlign.Right, bgHex: bg, bold: true, numFormat: pr.$3),
          _dataStyle(bgHex: bg),
        ],
      );
    }
    rr++;

    _writeMergedBanner(
      rekapSheet,
      row: rr++,
      lastCol: 8,
      text: 'RIWAYAT SERAH TERIMA KE DAPUR / YAYASAN',
      style: _kopSubStyle(),
    );
    _writeStyledRow(
      rekapSheet,
      row: rr++,
      values: [
        TextCellValue('No'),
        TextCellValue('Tanggal Serah'),
        TextCellValue('Periode'),
        TextCellValue('Pos Infak'),
        TextCellValue('Sumber Kantong'),
        TextCellValue('Nominal Uang'),
        TextCellValue('Beras Fisik (L)'),
        TextCellValue('Penerima'),
        TextCellValue('Catatan'),
      ],
      styles: List.filled(9, _tableHeaderStyle(bgHex: '#0F172A')),
    );
    for (int i = 0; i < serahTerimaList.length; i++) {
      final st = serahTerimaList[i];
      final bg = i.isEven ? '#FFFFFF' : '#F8FAFC';
      _writeStyledRow(
        rekapSheet,
        row: rr++,
        values: [
          IntCellValue(i + 1),
          TextCellValue(st.tanggalSerah),
          TextCellValue(st.periodeBulan),
          TextCellValue(st.posInfak),
          TextCellValue(st.sumberDompet),
          IntCellValue(st.nominalUang),
          DoubleCellValue(st.jumlahBerasLiter),
          TextCellValue(st.penerima),
          TextCellValue(st.catatan ?? '-'),
        ],
        styles: [
          _dataStyle(align: HorizontalAlign.Center, bgHex: bg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: bg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: bg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: bg),
          _dataStyle(align: HorizontalAlign.Center, bgHex: bg),
          _dataStyle(align: HorizontalAlign.Right, bgHex: bg, bold: true, numFormat: _rupiahNumFormat),
          _dataStyle(align: HorizontalAlign.Right, bgHex: bg, bold: true, numFormat: _literNumFormat),
          _dataStyle(bgHex: bg, bold: true),
          _dataStyle(bgHex: bg),
        ],
      );
    }

    _writeSignatureBlock(
      rekapSheet,
      startRow: rr + 2,
      lastCol: 10,
      pengaturan: pengaturan,
      printDate: printDate,
      bendaharaRole: 'Bendahara Infak,',
    );

    // ==================== SHEET 2, 3, 4: SANTRIYIN, SANTRIYAT, SANTRI BARU ====================
    for (final g in groups) {
      final sheet = excel[g.sheetName];
      _applyColumnWidths(sheet, [6, 26, 15, 13, 17, 17, 17, 13, 13, 13, 26]);

      final summary = _summarizeGroupInfak(
        kategori: g.kategori,
        santriList: santriList,
        infakBySantriId: infakBySantriId,
      );

      int rg = 0;
      _writeMergedBanner(
        sheet,
        row: rg++,
        lastCol: 10,
        text: pengaturan.namaPondok.toUpperCase(),
        style: _kopTitleStyle(),
      );
      _writeMergedBanner(
        sheet,
        row: rg++,
        lastCol: 10,
        text: g.title,
        style: _kopSubStyle(),
      );
      _writeMergedBanner(
        sheet,
        row: rg++,
        lastCol: 10,
        text: 'Bulan: $periodeLabel  |  Tahun Ajaran: $taLabel  |  Bendahara: ${pengaturan.namaPengurus}',
        style: _kopMetaStyle(),
      );
      rg++;

      _writeStyledRow(
        sheet,
        row: rg++,
        values: [
          TextCellValue('No'),
          TextCellValue('Nama Santri'),
          TextCellValue('Kamar'),
          TextCellValue('Status Santri'),
          TextCellValue('Infak Masak'),
          TextCellValue('Infak Listrik'),
          TextCellValue('Beras Uang'),
          TextCellValue('Beras Fisik'),
          TextCellValue('Tgl Masuk'),
          TextCellValue('Tgl Habis'),
          TextCellValue('Status & Keterangan'),
        ],
        styles: List.filled(11, _tableHeaderStyle(bgHex: '#0F766E')),
      );

      for (int i = 0; i < summary.sorted.length; i++) {
        final s = summary.sorted[i];
        final inf = infakBySantriId[s.id];

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
          ketText = 'BELUM BAYAR';
        } else if (inf.statusLunas == InfakSantriModel.statusCicilVal) {
          statusInfak = 'CICIL';
          ketText = _buildKetCicil(inf, pengaturan);
        } else {
          statusInfak = 'LUNAS';
          ketText = 'LUNAS';
        }

        final statusPal = _statusPalette(statusInfak);
        final rowBg = (s.isPulang || s.isPindah || statusInfak == 'CICIL' || statusInfak == 'LUNAS')
            ? statusPal.bgHex
            : (i.isEven ? '#FFFFFF' : '#F8FAFC');

        final CellValue masakCell = inf == null
            ? TextCellValue('-')
            : (inf.isMasakBebas ? TextCellValue('✓ Bebas') : IntCellValue(inf.nominalMasak));
        final CellStyle masakStyle = inf == null
            ? _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg)
            : (inf.isMasakBebas
                ? _dataStyle(align: HorizontalAlign.Center, bgHex: '#DCFCE7', fontHex: '#166534', bold: true)
                : _dataStyle(align: HorizontalAlign.Right, bgHex: rowBg, numFormat: _rupiahNumFormat));

        final CellValue listrikCell = inf == null
            ? TextCellValue('-')
            : (inf.isListrikBebas ? TextCellValue('✓ Bebas') : IntCellValue(inf.nominalListrik));
        final CellStyle listrikStyle = inf == null
            ? _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg)
            : (inf.isListrikBebas
                ? _dataStyle(align: HorizontalAlign.Center, bgHex: '#DCFCE7', fontHex: '#166534', bold: true)
                : _dataStyle(align: HorizontalAlign.Right, bgHex: rowBg, numFormat: _rupiahNumFormat));

        final CellValue berasUangCell = (inf != null && inf.jenisBeras == InfakSantriModel.berasUangVal)
            ? IntCellValue(inf.berasUang)
            : (inf != null && inf.jenisBeras == InfakSantriModel.berasBebas
                ? TextCellValue('✓ Bebas')
                : TextCellValue('-'));
        final CellStyle berasUangStyle = (inf != null && inf.jenisBeras == InfakSantriModel.berasUangVal)
            ? _dataStyle(align: HorizontalAlign.Right, bgHex: rowBg, numFormat: _rupiahNumFormat)
            : (inf != null && inf.jenisBeras == InfakSantriModel.berasBebas
                ? _dataStyle(align: HorizontalAlign.Center, bgHex: '#DCFCE7', fontHex: '#166534', bold: true)
                : _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg));

        final CellValue berasFisikCell = (inf != null && inf.jenisBeras == InfakSantriModel.berasFisik)
            ? DoubleCellValue(inf.berasLiter)
            : TextCellValue('-');
        final CellStyle berasFisikStyle = (inf != null && inf.jenisBeras == InfakSantriModel.berasFisik)
            ? _dataStyle(align: HorizontalAlign.Right, bgHex: rowBg, numFormat: _literNumFormat)
            : _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg);

        _writeStyledRow(
          sheet,
          row: rg++,
          values: [
            IntCellValue(i + 1),
            TextCellValue(s.namaLengkap),
            TextCellValue(s.kamar.isEmpty ? '-' : s.kamar),
            TextCellValue(s.statusSantriLabel),
            masakCell,
            listrikCell,
            berasUangCell,
            berasFisikCell,
            TextCellValue(inf?.tglMasuk ?? '-'),
            TextCellValue(inf?.tglHabis ?? '-'),
            TextCellValue(ketText),
          ],
          styles: [
            _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
            _dataStyle(bgHex: rowBg, bold: true),
            _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
            _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
            masakStyle,
            listrikStyle,
            berasUangStyle,
            berasFisikStyle,
            _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
            _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
            _dataStyle(align: HorizontalAlign.Left, bgHex: statusPal.bgHex, fontHex: statusPal.fontHex, bold: true),
          ],
        );
      }

      // Baris TOTAL Kelompok (Beras Fisik & Beras Uang terpisah)
      _writeStyledRow(
        sheet,
        row: rg++,
        values: [
          TextCellValue('TOTAL'),
          TextCellValue('${summary.sorted.length} Santri'),
          TextCellValue(''),
          TextCellValue(''),
          IntCellValue(summary.totalMasak),
          IntCellValue(summary.totalListrik),
          IntCellValue(summary.totalBerasUang),
          DoubleCellValue(summary.totalBerasLiter),
          TextCellValue('GRAND TOTAL UANG:'),
          IntCellValue(summary.grandTotalUang),
          TextCellValue('Lunas: ${summary.countLunas} | Cicil: ${summary.countCicil} | Belum: ${summary.countBelum} | PP: ${summary.countPulangPindah}'),
        ],
        styles: [
          _totalStyle(align: HorizontalAlign.Center),
          _totalStyle(align: HorizontalAlign.Left),
          _totalStyle(align: HorizontalAlign.Left),
          _totalStyle(align: HorizontalAlign.Left),
          _totalStyle(align: HorizontalAlign.Right, numFormat: _rupiahNumFormat),
          _totalStyle(align: HorizontalAlign.Right, numFormat: _rupiahNumFormat),
          _totalStyle(align: HorizontalAlign.Right, numFormat: _rupiahNumFormat),
          _totalStyle(align: HorizontalAlign.Right, numFormat: _literNumFormat, bgHex: '#FEF3C7'),
          _totalStyle(align: HorizontalAlign.Right, bgHex: '#CCFBF1'),
          _totalStyle(align: HorizontalAlign.Right, numFormat: _rupiahNumFormat, bgHex: '#CCFBF1'),
          _totalStyle(align: HorizontalAlign.Left),
        ],
      );

      _writeSignatureBlock(
        sheet,
        startRow: rg + 2,
        lastCol: 10,
        pengaturan: pengaturan,
        printDate: printDate,
        bendaharaRole: 'Bendahara Infak,',
      );
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
