import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../database/database_helper.dart';
import '../../models/infak_santri.dart';
import '../../models/pengaturan.dart';
import '../../models/santri.dart';
import '../../models/serah_terima_infak.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../yayasan_export_service.dart';
import 'yayasan_excel_exporter.dart';

class YayasanPdfExporter {
  const YayasanPdfExporter();

  Future<Uint8List?> _loadLogoBytes(PengaturanAplikasi pengaturan) async {
    try {
      final path = pengaturan.logoPath;
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  pw.Widget _buildPdfLogoOrEmblem(Uint8List? logoBytes, {double size = 44}) {
    if (logoBytes != null) {
      return pw.Container(
        width: size,
        height: size,
        margin: const pw.EdgeInsets.only(right: 12),
        child: pw.ClipOval(
          child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.cover),
        ),
      );
    }
    return pw.Container(
      width: size,
      height: size,
      margin: const pw.EdgeInsets.only(right: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal800,
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: PdfColors.amber400, width: 1.5),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        'KS',
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: size * 0.34,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _pdfMetric(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.teal900,
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfHeaderCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
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
    final range = YayasanExportService.resolveRange(
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
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                _buildPdfLogoOrEmblem(logoBytes, size: 48),
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
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.8, color: PdfColors.teal800),
            pw.SizedBox(height: 10),
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
                  _pdfMetric(
                    'Total Titipan',
                    CurrencyFormatter.format(totalBrankasFisik),
                  ),
                  _pdfMetric(
                    'Kas Laci Tunai',
                    CurrencyFormatter.format(kasLaciTunai),
                  ),
                  _pdfMetric(
                    'Rekening Bank',
                    CurrencyFormatter.format(rekeningBank),
                  ),
                  _pdfMetric(
                    'Total Tunggakan',
                    CurrencyFormatter.format(totalTunggakanPondok),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'A. Rekapitulasi Saldo & Tunggakan Santri (${santriList.length} Santri)',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: PdfColors.teal900,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: [
                'No',
                'Nama Santri',
                'Kamar / Kelas',
                'Saldo',
                'Jatah/Hr',
                'Est.',
                'Tunggakan',
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 8.5,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 4,
              ),
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
            pw.Text(
              'B. Buku Mutasi Transaksi Periode (${mutasiRows.length} catatan)',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: PdfColors.teal900,
              ),
            ),
            pw.SizedBox(height: 6),
            if (mutasiRows.isEmpty)
              pw.Text(
                'Tidak ada transaksi pada periode yang dipilih.',
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  color: PdfColors.grey600,
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                context: context,
                headers: [
                  'Tanggal',
                  'Santri',
                  'Tipe / Sesi',
                  'Dompet',
                  'Nominal',
                  'Status',
                  'Catatan',
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 8,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 3.5,
                ),
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
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Mengetahui,',
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                    pw.Text(
                      'Pengasuh Pondok,',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 46),
                    pw.Text(
                      '( ........................................ )',
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Dicetak: ${DateFormatter.formatDisplayDate(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Bendahara Kas,',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 46),
                    pw.Text(
                      '( ${pengaturan.namaPengurus} )',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
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
      name:
          'Laporan_Yayasan_${safePondok}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

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
        logoBytesOverride ??
            (loadAssetLogo ? await _loadLogoBytes(pengaturan) : null);
    final infakBySantriId = <String, InfakSantriModel>{
      for (final item in infakList) item.santriId: item,
    };

    final List<({String kategori, String title})> sections;
    switch (scope) {
      case InfakPrintScope.santriyin:
        sections = [
          (
            kategori: Santri.kategoriSantriyin,
            title: 'DATA INFAK SANTRIYIN',
          ),
        ];
        break;
      case InfakPrintScope.santriyat:
        sections = [
          (
            kategori: Santri.kategoriSantriyat,
            title: 'DATA INFAK SANTRIYAT',
          ),
        ];
        break;
      case InfakPrintScope.santriBaru:
        sections = [
          (
            kategori: Santri.kategoriSantriBaru,
            title: 'DATA INFAK SANTRI BARU',
          ),
        ];
        break;
      case InfakPrintScope.semuaTerpisah:
        sections = [
          (
            kategori: Santri.kategoriSantriyin,
            title: 'DATA INFAK SANTRIYIN',
          ),
          (
            kategori: Santri.kategoriSantriyat,
            title: 'DATA INFAK SANTRIYAT',
          ),
          (
            kategori: Santri.kategoriSantriBaru,
            title: 'DATA INFAK SANTRI BARU',
          ),
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
    final sisaKasInfakTotal =
        (saldoKantongInfak['total_uang'] as num?)?.toInt() ?? 0;
    final sisaKasInfakTunai =
        (saldoKantongInfak['tunai'] as num?)?.toInt() ?? 0;
    final sisaKasInfakBank =
        (saldoKantongInfak['rekening'] as num?)?.toInt() ?? 0;
    final stokBerasGudang =
        (saldoKantongInfak['beras_stok'] as num?)?.toDouble() ?? 0.0;
    final periodeLabel = YayasanExcelExporter.formatPeriodeId(periodeBulan);
    final printDateLabel = YayasanExcelExporter.formatTanggalId(DateTime.now());

    final pdf = pw.Document();

    for (final section in sections) {
      final summary = YayasanExcelExporter.summarizeGroupInfak(
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
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  _buildPdfLogoOrEmblem(logoBytes, size: 44),
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
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.8, color: PdfColors.teal800),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.6,
                ),
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
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey100,
                      ),
                      children: [
                        _pdfDataCell('-', align: pw.TextAlign.center),
                        _pdfDataCell(
                          'Belum ada data santri pada kelompok ini.',
                        ),
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
                      } else if (inf != null &&
                          inf.statusLunas == InfakSantriModel.statusLunasVal) {
                        rowBg = PdfColor.fromInt(0xFFECFDF5);
                        ketText = 'LUNAS';
                        ketColor = PdfColors.green800;
                      } else if (inf != null &&
                          inf.statusLunas == InfakSantriModel.statusCicilVal) {
                        rowBg = PdfColor.fromInt(0xFFFEF3C7);
                        ketText = YayasanExcelExporter.buildKetCicil(
                          inf,
                          pengaturan,
                        );
                        ketColor = PdfColors.amber900;
                      } else {
                        rowBg = i.isEven
                            ? PdfColors.white
                            : PdfColor.fromInt(0xFFF8FAFC);
                        ketText = 'BELUM BAYAR';
                        ketColor = PdfColors.red800;
                      }

                      final masakCell = inf == null
                          ? '-'
                          : (inf.isMasakBebas
                              ? 'BEBAS'
                              : CurrencyFormatter.format(inf.nominalMasak));
                      final listrikCell = inf == null
                          ? '-'
                          : (inf.isListrikBebas
                              ? 'BEBAS'
                              : CurrencyFormatter.format(inf.nominalListrik));
                      final String berasCell;
                      if (inf == null ||
                          inf.jenisBeras == InfakSantriModel.berasBelum) {
                        berasCell = '-';
                      } else if (inf.jenisBeras ==
                          InfakSantriModel.berasBebas) {
                        berasCell = 'BEBAS';
                      } else if (inf.jenisBeras ==
                          InfakSantriModel.berasFisik) {
                        berasCell =
                            '${YayasanExcelExporter.formatLiter(inf.berasLiter)} L';
                      } else {
                        berasCell = CurrencyFormatter.format(inf.berasUang);
                      }

                      final tglMasukCell =
                          inf != null && inf.tglMasuk.isNotEmpty
                              ? inf.tglMasuk
                              : '-';
                      final tglHabisCell =
                          inf != null && inf.tglHabis.isNotEmpty
                              ? inf.tglHabis
                              : '-';
                      final kamarSuffix =
                          s.kamar.trim().isNotEmpty ? ' (${s.kamar})' : '';

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: rowBg),
                        children: [
                          _pdfDataCell('${i + 1}', align: pw.TextAlign.center),
                          _pdfDataCell('${s.namaLengkap}$kamarSuffix'),
                          _pdfDataCell(
                            masakCell,
                            align: pw.TextAlign.right,
                            color: masakCell == 'BEBAS'
                                ? PdfColors.green800
                                : PdfColors.black,
                            bold: masakCell == 'BEBAS',
                          ),
                          _pdfDataCell(
                            listrikCell,
                            align: pw.TextAlign.right,
                            color: listrikCell == 'BEBAS'
                                ? PdfColors.green800
                                : PdfColors.black,
                            bold: listrikCell == 'BEBAS',
                          ),
                          _pdfDataCell(
                            berasCell,
                            align: pw.TextAlign.right,
                            color: berasCell == 'BEBAS'
                                ? PdfColors.green800
                                : PdfColors.black,
                            bold: berasCell == 'BEBAS',
                          ),
                          _pdfDataCell(
                            tglMasukCell,
                            align: pw.TextAlign.center,
                          ),
                          _pdfDataCell(
                            tglHabisCell,
                            align: pw.TextAlign.center,
                          ),
                          _pdfDataCell(ketText, color: ketColor, bold: true),
                        ],
                      );
                    }),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 11,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.teal50,
                        border: pw.Border.all(
                          color: PdfColors.teal300,
                          width: 0.8,
                        ),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'REKAP TOTAL KELOMPOK (${summary.sorted.length} SANTRI)',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal900,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          _pdfKeyValueRow(
                            'Total Uang Masak',
                            CurrencyFormatter.format(summary.totalMasak),
                          ),
                          _pdfKeyValueRow(
                            'Total Uang Listrik',
                            CurrencyFormatter.format(summary.totalListrik),
                          ),
                          _pdfKeyValueRow(
                            'Total Uang Beras',
                            CurrencyFormatter.format(summary.totalBerasUang),
                          ),
                          _pdfKeyValueRow(
                            'Total Beras Fisik',
                            '${YayasanExcelExporter.formatLiter(summary.totalBerasLiter)} Liter',
                          ),
                          pw.Divider(color: PdfColors.teal300, height: 6),
                          _pdfKeyValueRow(
                            'GRAND TOTAL UANG INFAK',
                            CurrencyFormatter.format(summary.grandTotalUang),
                            bold: true,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Status: Lunas ${summary.countLunas} | Cicil ${summary.countCicil} | Belum ${summary.countBelum} | Pulang/Pindah ${summary.countPulangPindah}',
                            style: const pw.TextStyle(
                              fontSize: 7.5,
                              color: PdfColors.grey800,
                            ),
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
                        border: pw.Border.all(
                          color: PdfColors.amber300,
                          width: 0.8,
                        ),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SERAH TERIMA DAPUR / YAYASAN ($periodeLabel)',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.amber900,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          _pdfKeyValueRow(
                            'Sudah Disetor (Uang)',
                            CurrencyFormatter.format(disetorUangPeriode),
                          ),
                          _pdfKeyValueRow(
                            'Sudah Disetor (Beras)',
                            '${YayasanExcelExporter.formatLiter(disetorBerasPeriode)} Liter',
                          ),
                          _pdfKeyValueRow(
                            'Sisa Kas Infak di Bendahara',
                            CurrencyFormatter.format(sisaKasInfakTotal),
                            bold: true,
                          ),
                          _pdfKeyValueRow(
                            'Rincian Sisa (Tunai / Bank)',
                            '${CurrencyFormatter.format(sisaKasInfakTunai)} / ${CurrencyFormatter.format(sisaKasInfakBank)}',
                          ),
                          _pdfKeyValueRow(
                            'Sisa Beras di Gudang',
                            '${YayasanExcelExporter.formatLiter(stokBerasGudang)} Liter',
                          ),
                          if (serahTerimaList.isNotEmpty) ...[
                            pw.Divider(color: PdfColors.amber300, height: 6),
                            ...serahTerimaList.take(3).map((st) {
                              final nilaiStr = st.nominalUang > 0
                                  ? CurrencyFormatter.format(st.nominalUang)
                                  : '${YayasanExcelExporter.formatLiter(st.jumlahBerasLiter)} L';
                              return pw.Text(
                                '- ${st.tanggalSerah} -> ${st.penerima}: $nilaiStr',
                                style: const pw.TextStyle(
                                  fontSize: 7.2,
                                  color: PdfColors.grey800,
                                ),
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
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Mengetahui,',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        'Pengasuh Pondok,',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 40),
                      pw.Text(
                        '( ........................................ )',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Dicetak: $printDateLabel',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                      pw.Text(
                        'Bendahara Infak,',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 40),
                      pw.Text(
                        '( ${pengaturan.namaPengurus} )',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
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

  Future<void> exportPdfBukuInfak({
    required PengaturanAplikasi pengaturan,
    required String periodeBulan,
    required List<Santri> santriList,
    required InfakPrintScope scope,
  }) async {
    final infakList = await DatabaseHelper.instance.getInfakByPeriode(
      periodeBulan,
    );
    final serahTerimaList = await DatabaseHelper.instance.getSerahTerimaInfak(
      periodeBulan: periodeBulan,
    );
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
      name:
          'Buku_Infak_${safePondok}_${periodeBulan}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
