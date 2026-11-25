import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/cash_opname_log.dart';
import '../models/infak_santri.dart';
import '../models/pengaturan.dart';
import '../models/santri.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

class CashflowBucket {
  final String label;
  final int setoranMasuk;
  final int jajanKeluar;
  final int infakMasuk;

  const CashflowBucket({
    required this.label,
    required this.setoranMasuk,
    required this.jajanKeluar,
    required this.infakMasuk,
  });

  int get maxVal {
    var m = setoranMasuk;
    if (jajanKeluar > m) m = jajanKeluar;
    if (infakMasuk > m) m = infakMasuk;
    return m;
  }
}

class InfakCategoryCompliance {
  final String kategori;
  final String label;
  final int totalSantri;
  final int lunasCount;
  final int cicilCount;
  final int belumCount;

  const InfakCategoryCompliance({
    required this.kategori,
    required this.label,
    required this.totalSantri,
    required this.lunasCount,
    required this.cicilCount,
    required this.belumCount,
  });

  double get percent =>
      totalSantri <= 0 ? 0.0 : (lunasCount / totalSantri) * 100.0;
}

class ExecutiveAnalyticsSummary {
  final List<CashflowBucket> dailyTrend7d;
  final List<CashflowBucket> monthlyTrend6m;
  final List<InfakCategoryCompliance> complianceByCategory;
  final int totalBrankas;
  final int kasTunai;
  final int kasRekening;
  final int totalTunggakan;
  final int voidCount7d;
  final CashOpnameLog? latestOpname;
  final int criticalSantriCount;
  final int activeSantriCount;
  final List<String> anomalyAlerts;

  const ExecutiveAnalyticsSummary({
    required this.dailyTrend7d,
    required this.monthlyTrend6m,
    required this.complianceByCategory,
    required this.totalBrankas,
    required this.kasTunai,
    required this.kasRekening,
    required this.totalTunggakan,
    required this.voidCount7d,
    required this.latestOpname,
    required this.criticalSantriCount,
    required this.activeSantriCount,
    required this.anomalyAlerts,
  });

  double get overallCompliancePercent {
    final total =
        complianceByCategory.fold<int>(0, (sum, c) => sum + c.totalSantri);
    final lunas =
        complianceByCategory.fold<int>(0, (sum, c) => sum + c.lunasCount);
    if (total <= 0) return 0.0;
    return (lunas / total) * 100.0;
  }
}

/// Mesin Analitik Eksekutif Yayasan & Ringkasan PDF 1 Halaman (v4.0).
class ExecutiveAnalyticsService {
  static final ExecutiveAnalyticsService instance =
      ExecutiveAnalyticsService._init();
  ExecutiveAnalyticsService._init();

  static int _infakMoneyTotal(InfakSantriModel inf) {
    final masak = inf.isMasakBebas ? 0 : inf.nominalMasak;
    final listrik = inf.isListrikBebas ? 0 : inf.nominalListrik;
    final beras =
        inf.jenisBeras == InfakSantriModel.berasUangVal ? inf.berasUang : 0;
    return masak + listrik + beras;
  }

  static ExecutiveAnalyticsSummary computeSummary({
    required List<Santri> activeSantri,
    required List<Map<String, dynamic>> transaksiRows,
    required List<Map<String, dynamic>> setoranRows,
    required List<InfakSantriModel> infakPeriodeList,
    required List<CashOpnameLog> opnameLogs,
    required int totalBrankas,
    required int kasTunai,
    required int kasRekening,
    required int totalTunggakan,
    DateTime? now,
  }) {
    final refNow = (now ?? DateTime.now()).toLocal();
    final todayDate = DateTime(refNow.year, refNow.month, refNow.day);

    // 1. Tren 7 Hari Terakhir
    final daily7d = <CashflowBucket>[];
    for (var i = 6; i >= 0; i--) {
      final d = todayDate.subtract(Duration(days: i));
      final ymd = DateFormatter.toLocalDateString(d);
      final label = '${d.day}/${d.month}';

      var setoran = 0;
      for (final s in setoranRows) {
        final tgl = (s['tanggal_setor'] ?? '').toString();
        if (tgl.startsWith(ymd)) {
          setoran += (s['nominal_setoran'] as num?)?.toInt() ?? 0;
        }
      }

      var jajan = 0;
      for (final tx in transaksiRows) {
        final isVoid = (tx['is_void'] as num?)?.toInt() == 1;
        final tipe = (tx['tipe'] ?? 'PENGAMBILAN').toString().toUpperCase();
        final tgl = (tx['tanggal_lokal'] ?? '').toString();
        if (!isVoid && tipe == 'PENGAMBILAN' && tgl == ymd) {
          jajan += (tx['nominal'] as num?)?.toInt() ?? 0;
        }
      }

      var infak = 0;
      for (final inf in infakPeriodeList) {
        if (inf.tglMasuk == ymd) {
          infak += _infakMoneyTotal(inf);
        }
      }

      daily7d.add(
        CashflowBucket(
          label: label,
          setoranMasuk: setoran,
          jajanKeluar: jajan,
          infakMasuk: infak,
        ),
      );
    }

    // 2. Tren 6 Bulan Terakhir
    final monthly6m = <CashflowBucket>[];
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    for (var i = 5; i >= 0; i--) {
      final mDate = DateTime(refNow.year, refNow.month - i, 1);
      final ym =
          '${mDate.year.toString().padLeft(4, '0')}-${mDate.month.toString().padLeft(2, '0')}';
      final label = monthNames[mDate.month - 1];

      var setoran = 0;
      for (final s in setoranRows) {
        final tgl = (s['tanggal_setor'] ?? '').toString();
        if (tgl.startsWith(ym)) {
          setoran += (s['nominal_setoran'] as num?)?.toInt() ?? 0;
        }
      }

      var jajan = 0;
      for (final tx in transaksiRows) {
        final isVoid = (tx['is_void'] as num?)?.toInt() == 1;
        final tipe = (tx['tipe'] ?? 'PENGAMBILAN').toString().toUpperCase();
        final tgl = (tx['tanggal_lokal'] ?? '').toString();
        if (!isVoid && tipe == 'PENGAMBILAN' && tgl.startsWith(ym)) {
          jajan += (tx['nominal'] as num?)?.toInt() ?? 0;
        }
      }

      var infak = 0;
      for (final inf in infakPeriodeList) {
        if (inf.periodeBulan == ym || inf.tglMasuk.startsWith(ym)) {
          infak += _infakMoneyTotal(inf);
        }
      }

      monthly6m.add(
        CashflowBucket(
          label: label,
          setoranMasuk: setoran,
          jajanKeluar: jajan,
          infakMasuk: infak,
        ),
      );
    }

    // 3. Kepatuhan Infak per Kategori
    final infakBySantriId = <String, InfakSantriModel>{
      for (final inf in infakPeriodeList) inf.santriId: inf,
    };
    const categories = [
      (Santri.kategoriSantriyin, 'Santriyin'),
      (Santri.kategoriSantriyat, 'Santriyat'),
      (Santri.kategoriSantriBaru, 'Santri Baru'),
    ];
    final compliance = <InfakCategoryCompliance>[];
    for (final cat in categories) {
      final members = activeSantri
          .where((s) => s.isAktifDiPondok && s.kategoriSantri == cat.$1)
          .toList();
      var lunas = 0;
      var cicil = 0;
      var belum = 0;
      for (final s in members) {
        final inf = infakBySantriId[s.id];
        if (inf == null || inf.statusLunas == InfakSantriModel.statusBelum) {
          belum++;
        } else if (inf.statusLunas == InfakSantriModel.statusLunasVal) {
          lunas++;
        } else {
          cicil++;
        }
      }
      compliance.add(
        InfakCategoryCompliance(
          kategori: cat.$1,
          label: cat.$2,
          totalSantri: members.length,
          lunasCount: lunas,
          cicilCount: cicil,
          belumCount: belum,
        ),
      );
    }

    // 4. Kesehatan Kas & Radar Anomali
    final sevenDaysAgo = todayDate.subtract(const Duration(days: 6));
    var voidCount7d = 0;
    for (final tx in transaksiRows) {
      final isVoid = (tx['is_void'] as num?)?.toInt() == 1;
      if (!isVoid) continue;
      final tgl = DateTime.tryParse((tx['waktu_ambil'] ?? '').toString()) ??
          DateTime.tryParse((tx['tanggal_lokal'] ?? '').toString());
      if (tgl != null && !tgl.isBefore(sevenDaysAgo)) {
        voidCount7d++;
      }
    }

    final latestOpname = opnameLogs.isNotEmpty ? opnameLogs.first : null;
    final criticalCount =
        activeSantri.where((s) => s.isAktifDiPondok && s.estimasiHari < 3).length;

    final alerts = <String>[];
    if (latestOpname == null) {
      alerts.add('Belum ada riwayat Cash Opname fisik.');
    } else if (!latestOpname.isCocok) {
      alerts.add(
        'Selisih Cash Opname terakhir (${latestOpname.tanggalLokal}): ${CurrencyFormatter.format(latestOpname.selisih)}.',
      );
    }
    if (voidCount7d >= 3) {
      alerts.add('Terdapat $voidCount7d pembatalan (Void) transaksi dalam 7 hari terakhir.');
    }
    if (criticalCount > 0) {
      alerts.add('$criticalCount santri bersaldo kritis (< 3 hari).');
    }
    if (totalTunggakan > 0) {
      alerts.add('Total piutang/tunggakan santri aktif: ${CurrencyFormatter.format(totalTunggakan)}.');
    }

    return ExecutiveAnalyticsSummary(
      dailyTrend7d: daily7d,
      monthlyTrend6m: monthly6m,
      complianceByCategory: compliance,
      totalBrankas: totalBrankas,
      kasTunai: kasTunai,
      kasRekening: kasRekening,
      totalTunggakan: totalTunggakan,
      voidCount7d: voidCount7d,
      latestOpname: latestOpname,
      criticalSantriCount: criticalCount,
      activeSantriCount: activeSantri.where((s) => s.isAktifDiPondok).length,
      anomalyAlerts: alerts,
    );
  }

  Future<Uint8List?> _loadLogoBytes(PengaturanAplikasi pengaturan) async {
    try {
      final path = pengaturan.logoPath;
      if (path != null && path.isNotEmpty) {
        final f = File(path);
        if (await f.exists()) return await f.readAsBytes();
      }
      final data = await rootBundle.load('logo.jpg');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Menghasilkan Ringkasan Eksekutif Yayasan 1 Halaman PDF siap rapat pengasuh.
  Future<Uint8List> buildExecutiveOnePagePdfBytes({
    required PengaturanAplikasi pengaturan,
    required ExecutiveAnalyticsSummary summary,
  }) async {
    final doc = pw.Document();
    final logoBytes = await _loadLogoBytes(pengaturan);
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
    final printedAt = DateFormatter.formatFullDateTime(DateTime.now());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Kop Eksekutif
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFF064E3B),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  children: [
                    if (logoImage != null) ...[
                      pw.Container(
                        width: 40,
                        height: 40,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(width: 10),
                    ],
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'RINGKASAN EKSEKUTIF PENGASUH & YAYASAN',
                            style: pw.TextStyle(
                              color: const PdfColor.fromInt(0xFFFDE68A),
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            pengaturan.namaPondok.toUpperCase(),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Tahun Ajaran: ${pengaturan.tahunAjaran} • Dicetak: $printedAt',
                            style: const pw.TextStyle(
                              color: PdfColor.fromInt(0xFFD1FAE5),
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // 4 KPI Cards
              pw.Row(
                children: [
                  _pdfKpiBox(
                    'Total Brankas Kas',
                    CurrencyFormatter.format(summary.totalBrankas),
                    'Tunai ${CurrencyFormatter.format(summary.kasTunai)} • Bank ${CurrencyFormatter.format(summary.kasRekening)}',
                  ),
                  pw.SizedBox(width: 8),
                  _pdfKpiBox(
                    'Kepatuhan Infak',
                    '${summary.overallCompliancePercent.toStringAsFixed(1)}%',
                    '${summary.activeSantriCount} santri aktif di pondok',
                  ),
                  pw.SizedBox(width: 8),
                  _pdfKpiBox(
                    'Total Tunggakan',
                    CurrencyFormatter.format(summary.totalTunggakan),
                    '${summary.criticalSantriCount} santri saldo kritis (<3 hari)',
                  ),
                  pw.SizedBox(width: 8),
                  _pdfKpiBox(
                    'Radar Keamanan',
                    '${summary.voidCount7d} Void (7h)',
                    summary.latestOpname == null
                        ? 'Opname: Belum ada'
                        : (summary.latestOpname!.isCocok
                            ? 'Opname: Cocok ✓'
                            : 'Opname: Selisih ${CurrencyFormatter.format(summary.latestOpname!.selisih)}'),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // Tabel Arus Kas 6 Bulan
              pw.Text(
                '1. Tren Arus Kas 6 Bulan Terakhir',
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal900,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerRight,
                headerAlignments: {0: pw.Alignment.centerLeft},
                cellAlignments: {0: pw.Alignment.centerLeft},
                headers: const [
                  'Bulan',
                  'Setoran Jajan Masuk',
                  'Pengeluaran Jajan',
                  'Infak Terkumpul',
                ],
                data: summary.monthlyTrend6m
                    .map(
                      (b) => [
                        b.label,
                        CurrencyFormatter.format(b.setoranMasuk),
                        CurrencyFormatter.format(b.jajanKeluar),
                        CurrencyFormatter.format(b.infakMasuk),
                      ],
                    )
                    .toList(),
              ),
              pw.SizedBox(height: 14),

              // Tabel Kepatuhan Infak per Kategori
              pw.Text(
                '2. Kepatuhan Infak Bulanan per Kelompok Santri',
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal900,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColor.fromInt(0xFF065F46)),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                headers: const [
                  'Kelompok',
                  'Total Aktif',
                  'Lunas',
                  'Cicil',
                  'Belum Bayar',
                  'Persentase Lunas',
                ],
                data: summary.complianceByCategory
                    .map(
                      (c) => [
                        c.label,
                        '${c.totalSantri}',
                        '${c.lunasCount}',
                        '${c.cicilCount}',
                        '${c.belumCount}',
                        '${c.percent.toStringAsFixed(1)}%',
                      ],
                    )
                    .toList(),
              ),
              pw.SizedBox(height: 14),

              // Catatan Radar Anomali
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF8FAFC),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '3. Catatan Kesehatan Kas & Radar Anomali',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (summary.anomalyAlerts.isEmpty)
                      pw.Text(
                        '• Kondisi kas sehat: opname cocok, tidak ada lonjakan void, dan saldo aman.',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: PdfColors.green900,
                        ),
                      )
                    else
                      ...summary.anomalyAlerts.map(
                        (a) => pw.Text(
                          '• $a',
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Blok Tanda Tangan
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        'Mengetahui,\nPengasuh / Pimpinan Pondok',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                      pw.SizedBox(height: 38),
                      pw.Text(
                        '( ________________________ )',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'Disusun oleh,\nBendahara Pondok',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                      pw.SizedBox(height: 38),
                      pw.Text(
                        '( ${pengaturan.namaPengurus} )',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfKpiBox(String title, String value, String sub) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF1F5F9),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal900,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              sub,
              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
  }
}
