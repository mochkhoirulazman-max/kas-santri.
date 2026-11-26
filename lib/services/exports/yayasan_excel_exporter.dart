import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../database/database_helper.dart';
import '../../models/cash_opname_log.dart';
import '../../models/infak_santri.dart';
import '../../models/pengaturan.dart';
import '../../models/santri.dart';
import '../../models/serah_terima_infak.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../yayasan_export_service.dart';

class YayasanExcelExporter {
  const YayasanExcelExporter();

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
  static final NumFormat _rupiahNumFormat = CustomNumericNumFormat(
    formatCode: '"Rp "#,##0',
  );
  static final NumFormat _literNumFormat = CustomNumericNumFormat(
    formatCode: '0.0" L"',
  );

  static const List<String> bulanNames = [
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

  static String formatPeriodeId(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = (int.tryParse(parts[1]) ?? 1).clamp(1, 12);
    return '${bulanNames[m]} $y';
  }

  static String formatTanggalId(DateTime dt) {
    return '${dt.day} ${bulanNames[dt.month.clamp(1, 12)]} ${dt.year}';
  }

  static String formatLiter(double liter) {
    return liter == liter.roundToDouble()
        ? liter.toInt().toString()
        : liter.toStringAsFixed(1);
  }

  static String buildKetCicil(
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
      kurang.add('Brs -${formatLiter(sisaB)} L');
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

  static ({
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
  }) summarizeGroupInfak({
    required String kategori,
    required List<Santri> santriList,
    required Map<String, InfakSantriModel> infakBySantriId,
  }) {
    final filtered = santriList
        .where((s) => s.statusAktif && s.kategoriSantri == kategori)
        .toList()
      ..sort(
        (a, b) => a.namaLengkap
            .toLowerCase()
            .compareTo(b.namaLengkap.toLowerCase()),
      );

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
      } else if (inf == null ||
          inf.statusLunas == InfakSantriModel.statusBelumVal) {
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

  static CellStyle _kopTitleStyle() => CellStyle(
        bold: true,
        fontSize: 13,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

  static CellStyle _kopSubStyle() => CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('#0F172A'),
        backgroundColorHex: ExcelColor.fromHexString('#CCFBF1'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

  static CellStyle _kopMetaStyle() => CellStyle(
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#334155'),
        backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

  static CellStyle _tableHeaderStyle({String bgHex = '#0F172A'}) => CellStyle(
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

  static CellStyle _dataStyle({
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

  static CellStyle _totalStyle({
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

  static ({String bgHex, String fontHex}) _statusPalette(String status) {
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

  static void _writeMergedBanner(
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

  static void _writeStyledRow(
    Sheet sheet, {
    required int row,
    required List<CellValue> values,
    required List<CellStyle> styles,
  }) {
    for (int c = 0; c < values.length; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row),
      );
      cell.value = values[c];
      if (c < styles.length) {
        cell.cellStyle = styles[c];
      }
    }
  }

  static void _applyColumnWidths(Sheet sheet, List<double> widths) {
    for (int c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }
  }

  static void _writeSignatureBlock(
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
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .cellStyle = st;
      }

      if (rightStart <= lastCol) {
        final rs = CellIndex.indexByColumnRow(
          columnIndex: rightStart,
          rowIndex: r,
        );
        final re = CellIndex.indexByColumnRow(
          columnIndex: lastCol,
          rowIndex: r,
        );
        sheet.cell(rs).value = TextCellValue(rightText);
        if (lastCol > rightStart) sheet.merge(rs, re);
        for (int c = rightStart; c <= lastCol; c++) {
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
              .cellStyle = st;
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
    return compute<Map<String, dynamic>, List<int>>(
      _buildExcelYayasanBytesIsolate,
      <String, dynamic>{
        'pengaturan': pengaturan,
        'santriList': santriList,
        'mutasiRows': mutasiRows,
        'dompetRows': dompetRows,
        'totalBrankasFisik': totalBrankasFisik,
        'kasLaciTunai': kasLaciTunai,
        'rekeningBank': rekeningBank,
        'totalTunggakanPondok': totalTunggakanPondok,
        'opnameLogs': opnameLogs,
        'periodeLabel': periodeLabel,
      },
    );
  }

  static List<int> _buildExcelYayasanBytesIsolate(
    Map<String, dynamic> request,
  ) {
    final pengaturan = request['pengaturan'] as PengaturanAplikasi;
    final santriList = request['santriList'] as List<Santri>;
    final mutasiRows = request['mutasiRows'] as List<Map<String, dynamic>>;
    final dompetRows = request['dompetRows'] as List<Map<String, dynamic>>;
    final totalBrankasFisik = request['totalBrankasFisik'] as int;
    final kasLaciTunai = request['kasLaciTunai'] as int;
    final rekeningBank = request['rekeningBank'] as int;
    final totalTunggakanPondok = request['totalTunggakanPondok'] as int;
    final opnameLogs = request['opnameLogs'] as List<CashOpnameLog>;
    final periodeLabel = request['periodeLabel'] as String;
    final excel = Excel.createExcel();
    final printDate = formatTanggalId(DateTime.now().toLocal());

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
      text:
          'Periode: $periodeLabel  |  TA: ${pengaturan.tahunAjaran}  |  Bendahara: ${pengaturan.namaPengurus}  |  Dicetak: $printDate',
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
        TextCellValue('Kamar / Kelas'),
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
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: rowBg,
            bold: true,
            numFormat: _rupiahNumFormat,
          ),
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: rowBg,
            numFormat: _rupiahNumFormat,
          ),
          _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg),
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: tunggBg,
            fontHex: tunggFont,
            bold: s.tunggakan > 0,
            numFormat: _rupiahNumFormat,
          ),
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

    final sheet2 = excel['Buku Mutasi'];
    _applyColumnWidths(
      sheet2,
      [6, 13, 9, 24, 14, 15, 12, 11, 18, 18, 16, 28],
    );

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
      text:
          'Periode: $periodeLabel  |  TA: ${pengaturan.tahunAjaran}  |  Bendahara: ${pengaturan.namaPengurus}',
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
        TextCellValue('Kamar / Kelas'),
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
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: rowBg,
            bold: true,
            numFormat: _rupiahNumFormat,
          ),
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: rowBg,
            numFormat: _rupiahNumFormat,
          ),
          _dataStyle(
            align: HorizontalAlign.Center,
            bgHex: pal.bgHex,
            fontHex: pal.fontHex,
            bold: true,
          ),
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
      text:
          'Periode: $periodeLabel  |  TA: ${pengaturan.tahunAjaran}  |  Bendahara: ${pengaturan.namaPengurus}',
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
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: bg,
            bold: true,
            numFormat: _rupiahNumFormat,
          ),
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
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: bg,
            bold: true,
            numFormat: _rupiahNumFormat,
          ),
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
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: bg,
            numFormat: _rupiahNumFormat,
          ),
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: bg,
            bold: true,
            numFormat: _rupiahNumFormat,
          ),
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: pal.bgHex,
            fontHex: pal.fontHex,
            bold: true,
            numFormat: _rupiahNumFormat,
          ),
          _dataStyle(
            align: HorizontalAlign.Center,
            bgHex: pal.bgHex,
            fontHex: pal.fontHex,
            bold: true,
          ),
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
    final range = YayasanExportService.resolveRange(
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
      p.join(
        dir.path,
        'laporan_yayasan_${safePondok}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      ),
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

  Future<List<int>> buildExcelBukuInfakBytes({
    required PengaturanAplikasi pengaturan,
    required String periodeBulan,
    required List<Santri> santriList,
    required List<InfakSantriModel> infakList,
    required List<SerahTerimaInfakModel> serahTerimaList,
    required Map<String, dynamic> saldoKantongInfak,
  }) async {
    return compute<Map<String, dynamic>, List<int>>(
      _buildExcelBukuInfakBytesIsolate,
      <String, dynamic>{
        'pengaturan': pengaturan,
        'periodeBulan': periodeBulan,
        'santriList': santriList,
        'infakList': infakList,
        'serahTerimaList': serahTerimaList,
        'saldoKantongInfak': saldoKantongInfak,
      },
    );
  }

  static List<int> _buildExcelBukuInfakBytesIsolate(
    Map<String, dynamic> request,
  ) {
    final pengaturan = request['pengaturan'] as PengaturanAplikasi;
    final periodeBulan = request['periodeBulan'] as String;
    final santriList = request['santriList'] as List<Santri>;
    final infakList = request['infakList'] as List<InfakSantriModel>;
    final serahTerimaList =
        request['serahTerimaList'] as List<SerahTerimaInfakModel>;
    final saldoKantongInfak =
        request['saldoKantongInfak'] as Map<String, dynamic>;
    final infakBySantriId = <String, InfakSantriModel>{
      for (final item in infakList) item.santriId: item,
    };
    final periodeLabel = formatPeriodeId(periodeBulan);
    final taLabel = DateFormatter.formatAcademicYearForPeriode(
      periodeBulan,
      configuredTa: pengaturan.tahunAjaran,
    );
    final printDate = formatTanggalId(DateTime.now().toLocal());
    final excel = Excel.createExcel();

    final groups = [
      (
        kategori: Santri.kategoriSantriyin,
        sheetName: 'Santriyin',
        title: 'DATA INFAK SANTRIYIN',
      ),
      (
        kategori: Santri.kategoriSantriyat,
        sheetName: 'Santriyat',
        title: 'DATA INFAK SANTRIYAT',
      ),
      (
        kategori: Santri.kategoriSantriBaru,
        sheetName: 'Santri Baru',
        title: 'DATA INFAK SANTRI BARU',
      ),
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
      final sum = summarizeGroupInfak(
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
      text:
          'Bulan: $periodeLabel  |  Tahun Ajaran: $taLabel  |  Bendahara: ${pengaturan.namaPengurus}  |  Dicetak: $printDate',
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
          _dataStyle(
            align: HorizontalAlign.Center,
            bgHex: '#DCFCE7',
            fontHex: '#166534',
            bold: true,
          ),
          _dataStyle(
            align: HorizontalAlign.Center,
            bgHex: '#FEF3C7',
            fontHex: '#92400E',
            bold: true,
          ),
          _dataStyle(
            align: HorizontalAlign.Center,
            bgHex: '#FFE4E6',
            fontHex: '#9F1239',
            bold: true,
          ),
          _dataStyle(
            align: HorizontalAlign.Center,
            bgHex: '#E2E8F0',
            fontHex: '#334155',
          ),
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: bg,
            numFormat: _rupiahNumFormat,
          ),
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: bg,
            numFormat: _rupiahNumFormat,
          ),
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: bg,
            numFormat: _rupiahNumFormat,
          ),
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: bg,
            bold: true,
            numFormat: _rupiahNumFormat,
          ),
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: bg,
            bold: true,
            numFormat: _literNumFormat,
          ),
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
        _totalStyle(
          align: HorizontalAlign.Right,
          numFormat: _rupiahNumFormat,
          bgHex: '#CCFBF1',
        ),
        _totalStyle(
          align: HorizontalAlign.Right,
          numFormat: _literNumFormat,
          bgHex: '#FEF3C7',
        ),
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
      (
        'Sudah Disetor ke Dapur/Yayasan Periode Ini (Uang)',
        IntCellValue(disetorUangPeriode),
        _rupiahNumFormat,
      ),
      (
        'Sudah Disetor Beras Fisik Periode Ini (Liter)',
        DoubleCellValue(disetorBerasPeriode),
        _literNumFormat,
      ),
      (
        'Sisa Kas Infak Tunai Belum Disetor',
        IntCellValue((saldoKantongInfak['tunai'] as num?)?.toInt() ?? 0),
        _rupiahNumFormat,
      ),
      (
        'Sisa Kas Infak Rekening Belum Disetor',
        IntCellValue((saldoKantongInfak['rekening'] as num?)?.toInt() ?? 0),
        _rupiahNumFormat,
      ),
      (
        'Total Sisa Kas Infak Belum Disetor',
        IntCellValue((saldoKantongInfak['total_uang'] as num?)?.toInt() ?? 0),
        _rupiahNumFormat,
      ),
      (
        'Sisa Stok Beras Fisik di Gudang',
        DoubleCellValue(
          (saldoKantongInfak['beras_stok'] as num?)?.toDouble() ?? 0.0,
        ),
        _literNumFormat,
      ),
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
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: bg,
            bold: true,
            numFormat: pr.$3,
          ),
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
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: bg,
            bold: true,
            numFormat: _rupiahNumFormat,
          ),
          _dataStyle(
            align: HorizontalAlign.Right,
            bgHex: bg,
            bold: true,
            numFormat: _literNumFormat,
          ),
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

    for (final g in groups) {
      final sheet = excel[g.sheetName];
      _applyColumnWidths(
        sheet,
        [6, 26, 15, 13, 17, 17, 17, 13, 13, 13, 26],
      );

      final summary = summarizeGroupInfak(
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
        text:
            'Bulan: $periodeLabel  |  Tahun Ajaran: $taLabel  |  Bendahara: ${pengaturan.namaPengurus}',
        style: _kopMetaStyle(),
      );
      rg++;

      _writeStyledRow(
        sheet,
        row: rg++,
        values: [
          TextCellValue('No'),
          TextCellValue('Nama Santri'),
          TextCellValue('Kamar / Kelas'),
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
        } else if (inf == null ||
            inf.statusLunas == InfakSantriModel.statusBelumVal) {
          statusInfak = 'BELUM';
          ketText = 'BELUM BAYAR';
        } else if (inf.statusLunas == InfakSantriModel.statusCicilVal) {
          statusInfak = 'CICIL';
          ketText = buildKetCicil(inf, pengaturan);
        } else {
          statusInfak = 'LUNAS';
          ketText = 'LUNAS';
        }

        final statusPal = _statusPalette(statusInfak);
        final rowBg = (s.isPulang ||
                s.isPindah ||
                statusInfak == 'CICIL' ||
                statusInfak == 'LUNAS')
            ? statusPal.bgHex
            : (i.isEven ? '#FFFFFF' : '#F8FAFC');

        final CellValue masakCell = inf == null
            ? TextCellValue('-')
            : (inf.isMasakBebas
                ? TextCellValue('✓ Bebas')
                : IntCellValue(inf.nominalMasak));
        final CellStyle masakStyle = inf == null
            ? _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg)
            : (inf.isMasakBebas
                ? _dataStyle(
                    align: HorizontalAlign.Center,
                    bgHex: '#DCFCE7',
                    fontHex: '#166534',
                    bold: true,
                  )
                : _dataStyle(
                    align: HorizontalAlign.Right,
                    bgHex: rowBg,
                    numFormat: _rupiahNumFormat,
                  ));

        final CellValue listrikCell = inf == null
            ? TextCellValue('-')
            : (inf.isListrikBebas
                ? TextCellValue('✓ Bebas')
                : IntCellValue(inf.nominalListrik));
        final CellStyle listrikStyle = inf == null
            ? _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg)
            : (inf.isListrikBebas
                ? _dataStyle(
                    align: HorizontalAlign.Center,
                    bgHex: '#DCFCE7',
                    fontHex: '#166534',
                    bold: true,
                  )
                : _dataStyle(
                    align: HorizontalAlign.Right,
                    bgHex: rowBg,
                    numFormat: _rupiahNumFormat,
                  ));

        final CellValue berasUangCell =
            (inf != null && inf.jenisBeras == InfakSantriModel.berasUangVal)
                ? IntCellValue(inf.berasUang)
                : (inf != null && inf.jenisBeras == InfakSantriModel.berasBebas
                    ? TextCellValue('✓ Bebas')
                    : TextCellValue('-'));
        final CellStyle berasUangStyle =
            (inf != null && inf.jenisBeras == InfakSantriModel.berasUangVal)
                ? _dataStyle(
                    align: HorizontalAlign.Right,
                    bgHex: rowBg,
                    numFormat: _rupiahNumFormat,
                  )
                : (inf != null && inf.jenisBeras == InfakSantriModel.berasBebas
                    ? _dataStyle(
                        align: HorizontalAlign.Center,
                        bgHex: '#DCFCE7',
                        fontHex: '#166534',
                        bold: true,
                      )
                    : _dataStyle(align: HorizontalAlign.Center, bgHex: rowBg));

        final CellValue berasFisikCell =
            (inf != null && inf.jenisBeras == InfakSantriModel.berasFisik)
                ? DoubleCellValue(inf.berasLiter)
                : TextCellValue('-');
        final CellStyle berasFisikStyle =
            (inf != null && inf.jenisBeras == InfakSantriModel.berasFisik)
                ? _dataStyle(
                    align: HorizontalAlign.Right,
                    bgHex: rowBg,
                    numFormat: _literNumFormat,
                  )
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
            _dataStyle(
              align: HorizontalAlign.Left,
              bgHex: statusPal.bgHex,
              fontHex: statusPal.fontHex,
              bold: true,
            ),
          ],
        );
      }

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
          TextCellValue(
            'Lunas: ${summary.countLunas} | Cicil: ${summary.countCicil} | Belum: ${summary.countBelum} | PP: ${summary.countPulangPindah}',
          ),
        ],
        styles: [
          _totalStyle(align: HorizontalAlign.Center),
          _totalStyle(align: HorizontalAlign.Left),
          _totalStyle(align: HorizontalAlign.Left),
          _totalStyle(align: HorizontalAlign.Left),
          _totalStyle(
            align: HorizontalAlign.Right,
            numFormat: _rupiahNumFormat,
          ),
          _totalStyle(
            align: HorizontalAlign.Right,
            numFormat: _rupiahNumFormat,
          ),
          _totalStyle(
            align: HorizontalAlign.Right,
            numFormat: _rupiahNumFormat,
          ),
          _totalStyle(
            align: HorizontalAlign.Right,
            numFormat: _literNumFormat,
            bgHex: '#FEF3C7',
          ),
          _totalStyle(align: HorizontalAlign.Right, bgHex: '#CCFBF1'),
          _totalStyle(
            align: HorizontalAlign.Right,
            numFormat: _rupiahNumFormat,
            bgHex: '#CCFBF1',
          ),
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

  Future<File> exportExcelBukuInfak({
    required PengaturanAplikasi pengaturan,
    required String periodeBulan,
    required List<Santri> santriList,
    bool shareAfterCreate = true,
  }) async {
    final infakList = await DatabaseHelper.instance.getInfakByPeriode(
      periodeBulan,
    );
    final serahTerimaList = await DatabaseHelper.instance.getSerahTerimaInfak(
      periodeBulan: periodeBulan,
    );
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
      p.join(
        dir.path,
        'buku_infak_4sheet_${safePondok}_${periodeBulan}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      ),
    );
    await file.writeAsBytes(encoded, flush: true);

    if (shareAfterCreate) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Buku Infak 4-Sheet ${pengaturan.namaPondok} (${formatPeriodeId(periodeBulan)})',
      );
    }
    return file;
  }
}
