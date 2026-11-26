import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/santri.dart';

class ParsedSantriRow {
  final int rowNumber;
  final Santri santri;

  const ParsedSantriRow({
    required this.rowNumber,
    required this.santri,
  });
}

class BulkExcelParseResult {
  final List<ParsedSantriRow> validRows;
  final List<String> duplicateNames;
  final List<String> invalidRows;
  final int totalRowsRead;
  final bool exceedsFreeQuota;
  final int remainingFreeSlots;

  const BulkExcelParseResult({
    required this.validRows,
    required this.duplicateNames,
    required this.invalidRows,
    required this.totalRowsRead,
    required this.exceedsFreeQuota,
    required this.remainingFreeSlots,
  });

  List<Santri> get santriList => validRows.map((e) => e.santri).toList();
}

/// Layanan Pembuatan Template & Impor Massal Santri dari Excel (.xlsx) v4.0.
class BulkSantriExcelService {
  static final BulkSantriExcelService instance = BulkSantriExcelService._init();
  BulkSantriExcelService._init();

  static const List<String> templateHeaders = [
    'Nama Lengkap',
    'Nama Panggilan',
    'Kategori (SANTRIYIN/SANTRIYAT/SANTRI_BARU)',
    'Kamar / Kelas',
    'No WA Wali',
    'Saldo Awal (Rp)',
    'Jatah Harian (Rp)',
    'Tunggakan Awal (Rp)',
  ];

  /// Menghasilkan file `.xlsx` template rapi siap isi untuk pondok besar.
  Uint8List buildTemplateExcelBytes({
    String namaPondok = 'Nama Pondok',
  }) {
    final excel = Excel.createExcel();
    const sheetName = 'Template Santri';
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.rename(defaultSheet, sheetName);
    }
    final sheet = excel[sheetName];

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    final exampleStyle = CellStyle(
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'),
    );

    for (var c = 0; c < templateHeaders.length; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.value = TextCellValue(templateHeaders[c]);
      cell.cellStyle = headerStyle;
    }

    final samples = <List<CellValue>>[
      [
        TextCellValue('Ahmad Zaki Mubarroq'),
        TextCellValue('Zaki'),
        TextCellValue('SANTRIYIN'),
        TextCellValue('Kamar 1A'),
        TextCellValue('081234567890'),
        IntCellValue(300000),
        IntCellValue(10000),
        IntCellValue(0),
      ],
      [
        TextCellValue('Aisyah Putri Rahmawati'),
        TextCellValue('Aisyah'),
        TextCellValue('SANTRIYAT'),
        TextCellValue('Putri 2B'),
        TextCellValue('085612345678'),
        IntCellValue(250000),
        IntCellValue(10000),
        IntCellValue(25000),
      ],
    ];

    for (var r = 0; r < samples.length; r++) {
      for (var c = 0; c < samples[r].length; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1),
        );
        cell.value = samples[r][c];
        cell.cellStyle = exampleStyle;
      }
    }

    sheet.setColumnWidth(0, 26);
    sheet.setColumnWidth(1, 16);
    sheet.setColumnWidth(2, 24);
    sheet.setColumnWidth(3, 18);
    sheet.setColumnWidth(4, 18);
    sheet.setColumnWidth(5, 16);
    sheet.setColumnWidth(6, 16);
    sheet.setColumnWidth(7, 16);

    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError('Gagal membuat file template Excel untuk $namaPondok.');
    }
    return Uint8List.fromList(encoded);
  }

  static String _extractExcelSpanText(TextSpan span) {
    final buf = StringBuffer(span.text ?? '');
    final kids = span.children;
    if (kids != null) {
      for (final child in kids) {
        buf.write(_extractExcelSpanText(child));
      }
    }
    return buf.toString();
  }

  static String _cellToString(Data? cell) {
    final val = cell?.value;
    if (val == null) return '';
    return switch (val) {
      TextCellValue() => _extractExcelSpanText(val.value).trim(),
      IntCellValue() => val.value.toString(),
      DoubleCellValue() => val.value.toString(),
      BoolCellValue() => val.value ? 'true' : 'false',
      FormulaCellValue() => val.formula.trim(),
      _ => val.toString().trim(),
    };
  }

  static int _cellToInt(Data? cell, {int fallback = 0}) {
    final val = cell?.value;
    if (val == null) return fallback;
    if (val is IntCellValue) return val.value;
    if (val is DoubleCellValue) return val.value.round();
    final raw = _cellToString(cell);
    final digits = raw.replaceAll(RegExp(r'[^0-9\-]'), '');
    return int.tryParse(digits) ?? fallback;
  }

  static String _parseKategori(String raw) {
    final u = raw.trim().toUpperCase();
    if (u.contains('YAT') || u.contains('PUTRI')) {
      return Santri.kategoriSantriyat;
    }
    if (u.contains('BARU') || u.contains('NEW')) {
      return Santri.kategoriSantriBaru;
    }
    return Santri.kategoriSantriyin;
  }

  /// Membaca, memvalidasi, dan mendeteksi duplikat dari file `.xlsx` unggahan pengurus.
  BulkExcelParseResult parseAndValidateExcelBytes({
    required Uint8List bytes,
    required List<Santri> existingSantri,
    required bool isProUser,
    int maxFreeQuota = AppConfig.maxFreeSantriQuota,
  }) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return const BulkExcelParseResult(
        validRows: [],
        duplicateNames: [],
        invalidRows: ['File Excel tidak memiliki sheet data.'],
        totalRowsRead: 0,
        exceedsFreeQuota: false,
        remainingFreeSlots: 0,
      );
    }

    final sheet = excel.tables.values.first;
    final rows = sheet.rows;
    final existingNames = existingSantri
        .map((s) => s.namaLengkap.trim().toLowerCase())
        .toSet();
    final seenInSheet = <String>{};

    final validRows = <ParsedSantriRow>[];
    final duplicateNames = <String>[];
    final invalidRows = <String>[];
    var totalRead = 0;

    for (var idx = 0; idx < rows.length; idx++) {
      final row = rows[idx];
      if (row.isEmpty) continue;

      final col0 = _cellToString(row.isNotEmpty ? row[0] : null);
      final col1 = _cellToString(row.length > 1 ? row[1] : null);
      final col2 = _cellToString(row.length > 2 ? row[2] : null);
      final col3 = _cellToString(row.length > 3 ? row[3] : null);
      final col4 = _cellToString(row.length > 4 ? row[4] : null);

      final allBlank = [col0, col1, col2, col3, col4].every((e) => e.isEmpty);
      if (allBlank) continue;

      // Lewati baris header
      if (idx == 0 && col0.toLowerCase().contains('nama')) {
        continue;
      }

      totalRead++;
      final humanRow = idx + 1;
      if (col0.trim().isEmpty) {
        invalidRows.add('Baris $humanRow: Nama Lengkap kosong.');
        continue;
      }

      final normalizedKey = col0.trim().toLowerCase();
      if (existingNames.contains(normalizedKey) || seenInSheet.contains(normalizedKey)) {
        duplicateNames.add('Baris $humanRow: "$col0" sudah ada / duplikat.');
        continue;
      }
      seenInSheet.add(normalizedKey);

      final panggilan = col1.trim().isNotEmpty
          ? col1.trim()
          : col0.trim().split(RegExp(r'\s+')).first;
      final kategori = _parseKategori(col2);
      final kamar = col3.trim().isNotEmpty ? col3.trim() : 'Kamar 1';
      final waClean = col4.replaceAll(RegExp(r'[^0-9+]'), '');
      final saldoAwal = _cellToInt(row.length > 5 ? row[5] : null, fallback: 0);
      final jatahRaw = _cellToInt(row.length > 6 ? row[6] : null, fallback: 10000);
      final tunggakanAwal = _cellToInt(row.length > 7 ? row[7] : null, fallback: 0);

      if (saldoAwal < 0 || jatahRaw < 0 || tunggakanAwal < 0) {
        invalidRows.add('Baris $humanRow ($col0): Nominal tidak boleh negatif.');
        continue;
      }

      final santri = Santri(
        id: const Uuid().v4(),
        namaLengkap: col0.trim(),
        namaPanggilan: panggilan,
        kategoriSantri: kategori,
        statusSantri: Santri.statusAktifVal,
        kamar: kamar,
        noWaWali: waClean.isNotEmpty ? waClean : null,
        saldoTotal: saldoAwal,
        setoranAwal: saldoAwal,
        jatahHarian: jatahRaw > 0 ? jatahRaw : 10000,
        tunggakan: tunggakanAwal,
        catatanTunggakan: tunggakanAwal > 0 ? 'Tunggakan Awal (Excel)' : '',
      );

      validRows.add(ParsedSantriRow(rowNumber: humanRow, santri: santri));
    }

    final activeExistingCount = existingSantri.where((s) => s.statusAktif).length;
    final remainingSlots = isProUser
        ? 999999
        : (maxFreeQuota - activeExistingCount).clamp(0, maxFreeQuota);
    final exceedsQuota = !isProUser && (validRows.length > remainingSlots);

    return BulkExcelParseResult(
      validRows: validRows,
      duplicateNames: duplicateNames,
      invalidRows: invalidRows,
      totalRowsRead: totalRead,
      exceedsFreeQuota: exceedsQuota,
      remainingFreeSlots: remainingSlots,
    );
  }
}
