import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../database/database_helper.dart';
import '../../providers/kas_santri_provider.dart';
import '../../services/executive_analytics_service.dart';
import '../../utils/app_feedback.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_background_wrapper.dart';
import '../../widgets/guided_spotlight_tour.dart';
import '../paywall_screen.dart';

class ExecutiveDashboardScreen extends StatefulWidget {
  const ExecutiveDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ExecutiveDashboardScreen> createState() =>
      _ExecutiveDashboardScreenState();
}

class _ExecutiveDashboardScreenState extends State<ExecutiveDashboardScreen> {
  final ScreenSpotlightController _spotCtrl = ScreenSpotlightController();
  bool _loading = true;
  bool _showMonthly = true;
  bool _exportingPdf = false;
  ExecutiveAnalyticsSummary? _summary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnalytics());
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    try {
      final provider = Provider.of<KasSantriProvider>(context, listen: false);
      final db = DatabaseHelper.instance;
      final txRows = await db.getTransaksiByDateRange();
      final setoranRows = await db.getAllSetoranByDateRange();

      final summary = ExecutiveAnalyticsService.computeSummary(
        activeSantri: provider.santriStatusList.map((e) => e.santri).toList(),
        transaksiRows: txRows,
        setoranRows: setoranRows,
        infakPeriodeList: provider.infakPeriodeList,
        opnameLogs: provider.opnameLogs,
        totalBrankas: provider.totalBrankasFisik,
        kasTunai: provider.kasLaciTunai,
        kasRekening: provider.rekeningBank,
        totalTunggakan: provider.totalTunggakanPondok,
      );
      if (mounted) {
        setState(() {
          _summary = summary;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPdf({bool share = false}) async {
    AppFeedback.tap();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    if (!provider.isProUser) {
      await PaywallScreen.show(
        context,
        triggerFeature: 'Laporan Eksekutif Pengasuh & Yayasan 1 Halaman (PDF)',
      );
      return;
    }
    final summary = _summary;
    if (summary == null) return;

    setState(() => _exportingPdf = true);
    try {
      final bytes =
          await ExecutiveAnalyticsService.instance.buildExecutiveOnePagePdfBytes(
        pengaturan: provider.pengaturan,
        summary: summary,
      );
      if (share) {
        final dir = await getTemporaryDirectory();
        final file = File(
          p.join(
            dir.path,
            'ringkasan_eksekutif_${DateTime.now().millisecondsSinceEpoch}.pdf',
          ),
        );
        await file.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Ringkasan Eksekutif Yayasan — ${provider.pengaturan.namaPondok}',
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: 'Ringkasan_Eksekutif_${provider.pengaturan.namaPondok}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal ekspor PDF Eksekutif: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    if (!provider.hasProAccess) {
      return AppBackgroundWrapper(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('Laporan Eksekutif Yayasan')),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassCard(
                  borderRadius: 26,
                  padding: const EdgeInsets.all(24),
                  borderColor: const Color(0xFFFBBF24).withValues(alpha: 0.55),
                  gradientColors: const [
                    Color(0xDE241A08),
                    Color(0xE00A1628),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👑', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFBBF24)),
                        ),
                        child: const Text(
                          '🔒 FITUR KHUSUS PRO',
                          style: TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Laporan Eksekutif Pengasuh & Yayasan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Analitik tren arus kas 7 hari & 6 bulan, persentase kepatuhan infak per kamar/kelas, dan cetak ringkasan 1 halaman PDF resmi untuk pengasuh/yayasan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => PaywallScreen.show(
                            context,
                            triggerFeature:
                                'Laporan Eksekutif Pengasuh & Yayasan 1 Halaman (PDF)',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBBF24),
                            foregroundColor: const Color(0xFF030712),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                          label: const Text(
                            'Coba Gratis 14 Hari / Upgrade PRO',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final summary = _summary;

    return ScreenSpotlightHost(
      screenKey: 'tour_executive',
      controller: _spotCtrl,
      steps: const [
        SpotlightStepSpec(
          emoji: '🏛️',
          title: 'Ringkasan Posisi Brankas & Kepatuhan',
          description:
              'Memantau posisi kas pondok secara menyeluruh (Tunai + Bank) serta persentase kepatuhan setoran infak santri bulan berjalan.',
          accent: Color(0xFF34D399),
        ),
        SpotlightStepSpec(
          emoji: '📈',
          title: 'Grafik Tren Arus Kas 7 Hari & 6 Bulan',
          description:
              'Beralih antara tampilan harian 7 hari terakhir dan bulanan 6 bulan terakhir untuk melihat ritme pemasukan vs penarikan santri.',
          accent: Color(0xFF38BDF8),
        ),
        SpotlightStepSpec(
          emoji: '📄',
          title: 'Cetak PDF Resmi 1 Halaman Yayasan',
          description:
              'Unduh dan bagikan ringkasan eksekutif 1 halaman berformat rapi langsung untuk Pengasuh atau Ketua Yayasan.',
          accent: Color(0xFFFBBF24),
        ),
      ],
      child: AppBackgroundWrapper(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Laporan Eksekutif Yayasan'),
            actions: [
              IconButton(
                onPressed: _loadAnalytics,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Muat Ulang Analitik',
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: SpotlightHelpButton(
                    onTap: _spotCtrl.startTour,
                    size: 32,
                    accent: const Color(0xFF34D399),
                  ),
                ),
              ),
            ],
          ),
        body: SafeArea(
          child: _loading || summary == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    // 1. Ringkasan Posisi Kas & Kepatuhan
                    Row(
                      children: [
                        _kpiTile(
                          'Brankas Kas',
                          CurrencyFormatter.format(summary.totalBrankas),
                          'Tunai + Bank',
                          const Color(0xFF34D399),
                        ),
                        const SizedBox(width: 10),
                        _kpiTile(
                          'Kepatuhan Infak',
                          '${summary.overallCompliancePercent.toStringAsFixed(0)}%',
                          '${summary.activeSantriCount} santri aktif',
                          const Color(0xFFFBBF24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2. Grafik Tren Arus Kas (7 Hari / 6 Bulan)
                    GlassCard(
                      borderRadius: 24,
                      padding: const EdgeInsets.all(16),
                      borderColor: const Color(0xFF38BDF8).withOpacity(0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'TREN ARUS KAS PONDOK',
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              ChoiceChip(
                                label: const Text('7 Hari', style: TextStyle(fontSize: 10.5)),
                                selected: !_showMonthly,
                                onSelected: (_) =>
                                    setState(() => _showMonthly = false),
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: const Text('6 Bulan', style: TextStyle(fontSize: 10.5)),
                                selected: _showMonthly,
                                onSelected: (_) =>
                                    setState(() => _showMonthly = true),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Wrap(
                            spacing: 12,
                            children: [
                              _LegendDot(color: Color(0xFF34D399), label: 'Setoran'),
                              _LegendDot(color: Color(0xFFFB7185), label: 'Jajan Keluar'),
                              _LegendDot(color: Color(0xFFFBBF24), label: 'Infak'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _CashflowBarChart(
                            buckets: _showMonthly
                                ? summary.monthlyTrend6m
                                : summary.dailyTrend7d,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. Meteran Kepatuhan Infak per Kategori
                    GlassCard(
                      borderRadius: 24,
                      padding: const EdgeInsets.all(16),
                      borderColor: const Color(0xFF34D399).withOpacity(0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KEPATUHAN INFAK PER KELOMPOK',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...summary.complianceByCategory.map((c) {
                            final frac = (c.percent / 100.0).clamp(0.0, 1.0);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${c.label} (${c.lunasCount}/${c.totalSantri} Lunas)',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        '${c.percent.toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          color: Color(0xFFFDE68A),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: frac,
                                      minHeight: 8,
                                      backgroundColor: Colors.white12,
                                      valueColor: const AlwaysStoppedAnimation(
                                        Color(0xFF34D399),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4. Kartu Kesehatan Kas & Radar Anomali
                    GlassCard(
                      borderRadius: 24,
                      padding: const EdgeInsets.all(16),
                      borderColor: summary.anomalyAlerts.isEmpty
                          ? const Color(0xFF34D399).withOpacity(0.45)
                          : const Color(0xFFF59E0B).withOpacity(0.6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KESEHATAN KAS & RADAR ANOMALI',
                            style: TextStyle(
                              color: Color(0xFFFBBF24),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Opname Terakhir: ${summary.latestOpname == null ? 'Belum ada' : (summary.latestOpname!.isCocok ? 'Cocok ✓' : CurrencyFormatter.format(summary.latestOpname!.selisih))}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                'Void (7h): ${summary.voidCount7d}',
                                style: const TextStyle(
                                  color: Color(0xFFFDA4AF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (summary.anomalyAlerts.isEmpty)
                            const Text(
                              '✅ Kondisi kas sehat dan tidak ada anomali terdeteksi.',
                              style: TextStyle(
                                color: Color(0xFF6EE7B7),
                                fontSize: 11.5,
                              ),
                            )
                          else
                            ...summary.anomalyAlerts.map(
                              (a) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '⚠️ $a',
                                  style: const TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontSize: 11.5,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _exportingPdf
                                      ? null
                                      : () => _exportPdf(share: true),
                                  icon: const Icon(Icons.share_outlined, size: 17),
                                  label: const Text('Bagikan PDF'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _exportingPdf
                                      ? null
                                      : () => _exportPdf(share: false),
                                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                                  label: Text(
                                    provider.isProUser
                                        ? 'PDF 1 Halaman'
                                        : 'PDF 1 Halaman 👑',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
    );
  }

  Widget _kpiTile(String title, String val, String sub, Color accent) {
    return Expanded(
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(14),
        borderColor: accent.withOpacity(0.45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white60, fontSize: 10.5),
            ),
            const SizedBox(height: 4),
            Text(
              val,
              style: TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
      ],
    );
  }
}

class _CashflowBarChart extends StatelessWidget {
  final List<CashflowBucket> buckets;

  const _CashflowBarChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    var peak = 1;
    for (final b in buckets) {
      if (b.maxVal > peak) peak = b.maxVal;
    }

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: buckets.map((b) {
          double h(int v) => v <= 0 ? 3.0 : (v / peak) * 105.0 + 4.0;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _bar(h(b.setoranMasuk), const Color(0xFF34D399)),
                    const SizedBox(width: 2),
                    _bar(h(b.jajanKeluar), const Color(0xFFFB7185)),
                    const SizedBox(width: 2),
                    _bar(h(b.infakMasuk), const Color(0xFFFBBF24)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  b.label,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _bar(double height, Color color) {
    return Container(
      width: 7,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
