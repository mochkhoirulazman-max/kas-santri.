import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/infak_santri.dart';
import '../../models/pengaturan.dart';
import '../../models/santri.dart';
import '../../providers/kas_santri_provider.dart';
import '../../providers/theme_wallpaper_provider.dart';
import '../../services/report_service.dart';
import '../../services/yayasan_export_service.dart';
import '../../utils/app_feedback.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/guided_spotlight_tour.dart';
import '../../widgets/infak_edit_bottom_sheet.dart';
import '../../widgets/serah_terima_bottom_sheet.dart';
import '../paywall_screen.dart';

class BukuInfakView extends StatefulWidget {
  final bool isActiveTab;
  final ScreenSpotlightController? spotlightController;

  const BukuInfakView({
    Key? key,
    this.isActiveTab = true,
    this.spotlightController,
  }) : super(key: key);

  @override
  State<BukuInfakView> createState() => _BukuInfakViewState();
}

class _BukuInfakViewState extends State<BukuInfakView> {
  final ScreenSpotlightController _fallbackSpotCtrl = ScreenSpotlightController();
  final GlobalKey _spotInfakVaultKey = GlobalKey();
  String _selectedKategori = 'ALL'; // ALL, SANTRIYIN, SANTRIYAT, SANTRI_BARU
  String _selectedStatusFilter = 'ALL'; // ALL, BELUM, CICIL, JATUH_TEMPO, PULANG_PINDAH
  bool _isExporting = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  String _formatPeriodeLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = (int.tryParse(parts[1]) ?? 1).clamp(1, 12);
    return '${_bulanNames[m]} $y';
  }

  bool _isJatuhTempoSoon(InfakSantriModel? infak) {
    if (infak == null || infak.tglHabis.isEmpty) return false;
    final habis = DateFormatter.parseLocalDate(infak.tglHabis);
    final today = DateFormatter.parseLocalDate(DateFormatter.toLocalDateString(DateTime.now()));
    final diff = habis.difference(today).inDays;
    return diff <= 3;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final cardOpacity = Provider.of<ThemeWallpaperProvider>(context).cardOpacity;
    final peng = provider.pengaturan;
    final periode = provider.selectedInfakPeriode;
    final isPro = provider.isProUser;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    final allSantri = provider.allSantri.where((s) => s.statusAktif).toList();
    final byKategori = _selectedKategori == 'ALL'
        ? allSantri
        : allSantri.where((s) => s.kategoriSantri == _selectedKategori).toList();

    int totalMasak = 0;
    int totalListrik = 0;
    int totalBerasUang = 0;
    double totalBerasLiter = 0.0;
    int countLunas = 0;
    int countAktifTarget = 0;

    for (final s in byKategori) {
      if (s.isAktifDiPondok) countAktifTarget++;
      final inf = provider.getInfakForSantri(s.id);
      if (inf != null) {
        if (!inf.isMasakBebas) totalMasak += inf.nominalMasak;
        if (!inf.isListrikBebas) totalListrik += inf.nominalListrik;
        if (inf.jenisBeras == InfakSantriModel.berasUangVal) {
          totalBerasUang += inf.berasUang;
        } else if (inf.jenisBeras == InfakSantriModel.berasFisik) {
          totalBerasLiter += inf.berasLiter;
        }
        if (s.isAktifDiPondok && inf.statusLunas == InfakSantriModel.statusLunasVal) {
          countLunas++;
        }
      }
    }

    final q = _searchQuery.trim().toLowerCase();
    final filteredSantri = byKategori.where((s) {
      if (q.isNotEmpty) {
        final match = s.namaLengkap.toLowerCase().contains(q) ||
            s.namaPanggilan.toLowerCase().contains(q) ||
            s.kamar.toLowerCase().contains(q);
        if (!match) return false;
      }
      final inf = provider.getInfakForSantri(s.id);
      final isPulangOrPindah = s.isPulang || s.isPindah;
      if (_selectedStatusFilter == 'PULANG_PINDAH') {
        return isPulangOrPindah;
      }
      if (_selectedStatusFilter == 'BELUM') {
        return !isPulangOrPindah &&
            (inf == null || inf.statusLunas == InfakSantriModel.statusBelumVal);
      }
      if (_selectedStatusFilter == 'CICIL') {
        return !isPulangOrPindah &&
            inf != null &&
            inf.statusLunas == InfakSantriModel.statusCicilVal;
      }
      if (_selectedStatusFilter == 'JATUH_TEMPO') {
        return !isPulangOrPindah && _isJatuhTempoSoon(inf);
      }
      return true;
    }).toList();

    final berasStokStr = provider.stokBerasFisikLiter ==
            provider.stokBerasFisikLiter.roundToDouble()
        ? provider.stokBerasFisikLiter.toInt().toString()
        : provider.stokBerasFisikLiter.toStringAsFixed(1);
    final totalLiterStr = totalBerasLiter == totalBerasLiter.roundToDouble()
        ? totalBerasLiter.toInt().toString()
        : totalBerasLiter.toStringAsFixed(1);

    return ScreenSpotlightHost(
      screenKey: 'tour_buku_infak',
      isActive: widget.isActiveTab,
      controller: widget.spotlightController ?? _fallbackSpotCtrl,
      steps: [
        SpotlightStepSpec(
          targetKey: _spotInfakVaultKey,
          emoji: '🏛️',
          title: 'Kas Infak Pondok & Gudang Beras',
          description:
              'Memantau total uang infak (Masak + Listrik + Pengganti Beras) dan stok fisik beras liter yang terkumpul tetapi belum diserahterimakan ke pengurus dapur.',
          accent: const Color(0xFF34D399),
        ),
        const SpotlightStepSpec(
          emoji: '🌾',
          title: 'Filter Status Lunas, Cicil & Jatuh Tempo',
          description:
              'Gunakan tab filter dan kotak pencarian di bawah kartu untuk melihat santri yang belum setor, masih nyicil, jatuh tempo (H-3), atau sedang pulang/pindah.',
          accent: Color(0xFFFBBF24),
        ),
        const SpotlightStepSpec(
          emoji: '🤝',
          title: 'Serah Terima Dapur & Edit Cepat',
          description:
              'Ketuk kartu santri untuk ubah rincian infak/bebas biaya, atau gunakan tombol Serah Terima di atas untuk mencatat penyerahan uang & beras ke pengelola dapur pondok.',
          accent: Color(0xFF38BDF8),
        ),
      ],
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Kartu Kas Infak Pondok & Gudang Beras + Serah Terima (Vibrant Emerald-Gold Glass)
                  Container(
                    key: _spotInfakVaultKey,
                    padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF064E3B).withValues(alpha: (0.88 * cardOpacity).clamp(0.45, 0.92)),
                        const Color(0xFF0B253A).withValues(alpha: (0.90 * cardOpacity).clamp(0.48, 0.94)),
                        const Color(0xFF281C08).withValues(alpha: (0.86 * cardOpacity).clamp(0.45, 0.92)),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF34D399).withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.16),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('🏛️', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Kas Infak Pondok & Gudang Beras',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'BELUM DISETOR',
                              style: TextStyle(color: Color(0xFFFDE68A), fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF042F26).withValues(alpha: 0.72),
                                    const Color(0xFF071626).withValues(alpha: 0.78),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.32)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('💰 Kas Infak Uang', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      CurrencyFormatter.format(provider.totalKasInfakBelumDisetor),
                                      style: const TextStyle(
                                        color: Color(0xFF34D399),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isPro
                                        ? 'Tunai: ${CurrencyFormatter.format(provider.kasInfakTunai)} • Bank: ${CurrencyFormatter.format(provider.kasInfakRekening)}'
                                        : 'Rincian Tunai vs Bank 🔒 PRO',
                                    style: TextStyle(
                                      color: isPro ? Colors.white60 : const Color(0xFFFDE68A),
                                      fontSize: 9,
                                      fontWeight: isPro ? FontWeight.normal : FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 118,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF332006).withValues(alpha: 0.72),
                                  const Color(0xFF0B1324).withValues(alpha: 0.78),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🌾 Beras Gudang', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                const SizedBox(height: 2),
                                Text(
                                  '$berasStokStr Liter',
                                  style: const TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Siap serah dapur',
                                  style: TextStyle(color: Colors.white60, fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                AppFeedback.tap();
                                if (!isPro) {
                                  PaywallScreen.show(
                                    context,
                                    triggerFeature: 'Serah Terima Kas Infak & Beras ke Dapur / Yayasan',
                                  );
                                  return;
                                }
                                SerahTerimaFormSheet.show(context);
                              },
                              icon: const Text('🤝', style: TextStyle(fontSize: 14)),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isPro
                                      ? 'Serah Terima ke Dapur / Yayasan'
                                      : 'Serah Terima Infak 👑',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFBBF24),
                                foregroundColor: const Color(0xFF030712),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              onPressed: () {
                                AppFeedback.tap();
                                if (!isPro) {
                                  PaywallScreen.show(
                                    context,
                                    triggerFeature: 'Riwayat & Berita Acara Serah Terima Infak',
                                  );
                                  return;
                                }
                                SerahTerimaHistorySheet.show(context);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isPro ? const Color(0xFF67E8F9) : const Color(0xFFFDE68A),
                                side: BorderSide(
                                  color: isPro ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isPro ? '📜 Riwayat' : '📜 Riwayat 👑',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 1b. Tombol Ekspor Resmi PRO: PDF Buku Infak & Excel 4-Sheet
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isExporting
                            ? null
                            : () {
                                AppFeedback.tap();
                                if (!isPro) {
                                  PaywallScreen.show(
                                    context,
                                    triggerFeature: 'Cetak PDF Resmi Buku Infak',
                                  );
                                  return;
                                }
                                _showPdfScopeSheet(context, provider, allSantri);
                              },
                        icon: const Text('📄', style: TextStyle(fontSize: 14)),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isExporting
                                ? 'Menyiapkan...'
                                : (isPro ? 'PDF Buku Infak' : 'PDF Buku Infak 👑'),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isExporting
                            ? null
                            : () {
                                AppFeedback.tap();
                                if (!isPro) {
                                  PaywallScreen.show(
                                    context,
                                    triggerFeature: 'Ekspor Excel 4-Sheet Buku Infak',
                                  );
                                  return;
                                }
                                _exportExcel4Sheet(provider, allSantri);
                              },
                        icon: const Text('📊', style: TextStyle(fontSize: 14)),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isExporting
                                ? 'Menyiapkan...'
                                : (isPro ? 'Excel 4-Sheet' : 'Excel 4-Sheet 👑'),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 2. Pemilih Bulan & Tahun Ajaran (Cyan -> Indigo Glass)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF09253A).withValues(alpha: (0.85 * cardOpacity).clamp(0.45, 0.90)),
                        const Color(0xFF141838).withValues(alpha: (0.85 * cardOpacity).clamp(0.45, 0.90)),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          AppFeedback.tap();
                          provider.shiftInfakPeriode(-1);
                        },
                        icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _formatPeriodeLabel(periode),
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'TA ${DateFormatter.formatAcademicYearForPeriode(periode, configuredTa: peng.tahunAjaran)}',
                              style: const TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          AppFeedback.tap();
                          provider.shiftInfakPeriode(1);
                        },
                        icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 2b. Pencarian Santri Instan di Buku Infak
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Cari nama santri / panggilan / kamar/kelas...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF34D399)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 17, color: Colors.white54),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),

                const SizedBox(height: 10),

                // 3. Filter Kelompok Santri (Semua | Santriyin | Santriyat | Santri Baru)
                Row(
                  children: [
                    _kelompokTab('Semua', 'ALL'),
                    const SizedBox(width: 6),
                    _kelompokTab('Santriyin', Santri.kategoriSantriyin),
                    const SizedBox(width: 6),
                    _kelompokTab('Santriyat', Santri.kategoriSantriyat),
                    const SizedBox(width: 6),
                    _kelompokTab('Santri Baru', Santri.kategoriSantriBaru),
                  ],
                ),

                const SizedBox(height: 10),

                // 4. 4 Kartu Ringkasan Instan (Vibrant Glass)
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.55,
                  children: [
                    _summaryBox('🍛 Total Masak', CurrencyFormatter.format(totalMasak), const Color(0xFF34D399), cardOpacity),
                    _summaryBox('⚡ Total Listrik', CurrencyFormatter.format(totalListrik), const Color(0xFF38BDF8), cardOpacity),
                    _summaryBox(
                      '🌾 Beras (L + Rp)',
                      '$totalLiterStr L • ${CurrencyFormatter.format(totalBerasUang)}',
                      const Color(0xFFFDE68A),
                      cardOpacity,
                    ),
                    _summaryBox(
                      '✅ Progres Lunas',
                      '$countLunas / $countAktifTarget Santri',
                      const Color(0xFFA78BFA),
                      cardOpacity,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 5. Filter Status Pil
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _statusFilterPill('Semua', 'ALL', isPro: isPro),
                      _statusFilterPill('Belum Bayar', 'BELUM', isPro: isPro),
                      _statusFilterPill('Cicil / Kurang', 'CICIL', isPro: isPro),
                      _statusFilterPill(
                        isPro ? '⏰ Jatuh Tempo <=3 Hr' : '⏰ Jatuh Tempo <=3 Hr 👑',
                        'JATUH_TEMPO',
                        isProGated: true,
                        isPro: isPro,
                      ),
                      _statusFilterPill('Pulang / Pindah', 'PULANG_PINDAH', isPro: isPro),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),

        // 6. Daftar Santri Buku Infak (Virtualized SliverList + RepaintBoundary)
        if (filteredSantri.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 120 + bottomSafe),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF06382E).withValues(alpha: 0.65),
                      const Color(0xFF0A1628).withValues(alpha: 0.72),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.30)),
                ),
                child: const Column(
                  children: [
                    Text('🌾', style: TextStyle(fontSize: 30)),
                    SizedBox(height: 8),
                    Text(
                      'Belum ada santri pada filter ini',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 120 + bottomSafe),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) {
                  final s = filteredSantri[idx];
                  final inf = provider.getInfakForSantri(s.id);
                  return RepaintBoundary(
                    child: _buildInfakSantriCard(
                      context,
                      s,
                      inf,
                      periode,
                      peng,
                      isPro,
                      cardOpacity,
                    ),
                  );
                },
                childCount: filteredSantri.length,
              ),
            ),
          ),
      ],
    ),
    );
  }

  Future<void> _exportPdfWithScope(
    KasSantriProvider provider,
    List<Santri> allSantri,
    InfakPrintScope scope,
  ) async {
    setState(() => _isExporting = true);
    try {
      await YayasanExportService.instance.exportPdfBukuInfak(
        pengaturan: provider.pengaturan,
        periodeBulan: provider.selectedInfakPeriode,
        santriList: allSantri,
        scope: scope,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat PDF Buku Infak: $e'),
          backgroundColor: const Color(0xFF991B1B),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportExcel4Sheet(
    KasSantriProvider provider,
    List<Santri> allSantri,
  ) async {
    setState(() => _isExporting = true);
    try {
      await YayasanExportService.instance.exportExcelBukuInfak(
        pengaturan: provider.pengaturan,
        periodeBulan: provider.selectedInfakPeriode,
        santriList: allSantri,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengekspor Excel 4-Sheet: $e'),
          backgroundColor: const Color(0xFF991B1B),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showPdfScopeSheet(
    BuildContext context,
    KasSantriProvider provider,
    List<Santri> allSantri,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final bottomPad = MediaQuery.of(sheetCtx).padding.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📄 Pilih Kelompok Cetak PDF Buku Infak',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Periode ${_formatPeriodeLabel(provider.selectedInfakPeriode)} • TA ${provider.pengaturan.tahunAjaran}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                ),
                const SizedBox(height: 14),
                _pdfScopeOption(
                  sheetCtx,
                  emoji: '👦',
                  title: 'Santriyin',
                  subtitle: 'Cetak khusus daftar infak Santriyin',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _exportPdfWithScope(provider, allSantri, InfakPrintScope.santriyin);
                  },
                ),
                _pdfScopeOption(
                  sheetCtx,
                  emoji: '👧',
                  title: 'Santriyat',
                  subtitle: 'Cetak khusus daftar infak Santriyat',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _exportPdfWithScope(provider, allSantri, InfakPrintScope.santriyat);
                  },
                ),
                _pdfScopeOption(
                  sheetCtx,
                  emoji: '🆕',
                  title: 'Santri Baru',
                  subtitle: 'Cetak khusus daftar infak Santri Baru',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _exportPdfWithScope(provider, allSantri, InfakPrintScope.santriBaru);
                  },
                ),
                _pdfScopeOption(
                  sheetCtx,
                  emoji: '📚',
                  title: 'Semua Kelompok (Terpisah per Halaman)',
                  subtitle: '3 halaman terpisah: Santriyin, Santriyat & Santri Baru',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _exportPdfWithScope(provider, allSantri, InfakPrintScope.semuaTerpisah);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pdfScopeOption(
    BuildContext context, {
    required String emoji,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF060B14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 20)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF34D399)),
        onTap: onTap,
      ),
    );
  }

  Widget _kelompokTab(String label, String value) {
    final selected = _selectedKategori == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          setState(() => _selectedKategori = value);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF34D399) : Colors.white12,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? const Color(0xFF6EE7B7) : Colors.white60,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryBox(String label, String value, Color accent, double cardOpacity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(const Color(0xFF081426), accent, 0.22)!
                .withValues(alpha: (0.86 * cardOpacity).clamp(0.45, 0.90)),
            const Color(0xFF0A1222)
                .withValues(alpha: (0.88 * cardOpacity).clamp(0.48, 0.92)),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusFilterPill(
    String label,
    String keyVal, {
    bool isProGated = false,
    required bool isPro,
  }) {
    final selected = _selectedStatusFilter == keyVal;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          if (isProGated && !isPro) {
            PaywallScreen.show(
              context,
              triggerFeature: 'Filter Jatuh Tempo Infak (<= 3 Hari)',
            );
            return;
          }
          setState(() => _selectedStatusFilter = keyVal);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF38BDF8).withOpacity(0.2) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? const Color(0xFF38BDF8) : Colors.white12,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF7DD3FC) : Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfakSantriCard(
    BuildContext context,
    Santri s,
    InfakSantriModel? inf,
    String periode,
    PengaturanAplikasi peng,
    bool isPro,
    double cardOpacity,
  ) {
    final String badgeText;
    final Color badgeColor;
    if (s.isPulang) {
      badgeText = 'PULANG';
      badgeColor = const Color(0xFF34D399);
    } else if (s.isPindah) {
      badgeText = 'PINDAH';
      badgeColor = const Color(0xFF94A3B8);
    } else if (inf == null || inf.statusLunas == InfakSantriModel.statusBelumVal) {
      badgeText = 'BELUM';
      badgeColor = const Color(0xFFF43F5E);
    } else if (inf.statusLunas == InfakSantriModel.statusCicilVal) {
      badgeText = 'CICIL';
      badgeColor = const Color(0xFFFBBF24);
    } else {
      badgeText = 'LUNAS';
      badgeColor = const Color(0xFF10B981);
    }

    final masakStr = inf == null
        ? '-'
        : (inf.isMasakBebas ? '✓ Bebas' : CurrencyFormatter.format(inf.nominalMasak));
    final listrikStr = inf == null
        ? '-'
        : (inf.isListrikBebas ? '✓ Bebas' : CurrencyFormatter.format(inf.nominalListrik));
    final String berasStr;
    if (inf == null || inf.jenisBeras == InfakSantriModel.berasBelum) {
      berasStr = 'Belum';
    } else if (inf.jenisBeras == InfakSantriModel.berasBebas) {
      berasStr = '✓ Bebas';
    } else if (inf.jenisBeras == InfakSantriModel.berasFisik) {
      final l = inf.berasLiter;
      berasStr = '${l == l.roundToDouble() ? l.toInt() : l} L';
    } else {
      berasStr = CurrencyFormatter.format(inf.berasUang);
    }

    final topTint = Color.lerp(const Color(0xFF081426), badgeColor, 0.20)!
        .withValues(alpha: (0.86 * cardOpacity).clamp(0.45, 0.90));
    final bottomTint = const Color(0xFF0A1222)
        .withValues(alpha: (0.90 * cardOpacity).clamp(0.48, 0.92));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [topTint, bottomTint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AppFeedback.tap();
            InfakEditBottomSheet.show(
              context,
              santri: s,
              periodeBulan: periode,
              existingInfak: inf,
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.namaLengkap,
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.kategoriLabel}${s.kamar.trim().isNotEmpty ? ' • ${s.kamar}' : ''}',
                            style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: badgeColor),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _miniPos('Masak', masakStr),
                    _miniPos('Listrik', listrikStr),
                    _miniPos('Beras', berasStr),
                  ],
                ),
                if (inf != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📅 ${inf.tglMasuk} → ${inf.tglHabis}',
                        style: const TextStyle(color: Color(0xFF7DD3FC), fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.w700),
                      ),
                      if (inf.catatan != null && inf.catatan!.isNotEmpty)
                        Flexible(
                          child: Text(
                            inf.catatan!,
                            style: const TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Ketuk untuk catat / lengkapi pembayaran infak bulan ini →',
                    style: TextStyle(color: Colors.white54, fontSize: 10.5),
                  ),
                ],
                if (!s.isPulang &&
                    !s.isPindah &&
                    (_selectedStatusFilter == 'JATUH_TEMPO' ||
                        _isJatuhTempoSoon(inf) ||
                        inf == null ||
                        inf.statusLunas != InfakSantriModel.statusLunasVal)) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        AppFeedback.tap();
                        if (!isPro) {
                          PaywallScreen.show(
                            context,
                            triggerFeature: 'Pengingat Jatuh Tempo Infak via WA',
                          );
                          return;
                        }
                        final phone = ReportService.normalizeWaPhone(s.noWaWali);
                        if (phone.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nomor WA wali belum diisi di profil santri ini.'),
                              backgroundColor: Color(0xFF991B1B),
                            ),
                          );
                          return;
                        }
                        final msg = ReportService.instance.generateInfakReminderText(
                          santri: s,
                          pengaturan: peng,
                          periodeBulan: periode,
                          infak: inf,
                        );
                        final ok = await ReportService.instance.openWhatsAppDirect(
                          rawPhone: s.noWaWali,
                          message: msg,
                        );
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tidak dapat membuka WhatsApp di perangkat ini.'),
                              backgroundColor: Color(0xFF991B1B),
                            ),
                          );
                        }
                      },
                      icon: const Text('💬', style: TextStyle(fontSize: 13)),
                      label: Text(
                        isPro ? 'Ingatkan Wali via WA' : 'Ingatkan Wali via WA 👑',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF34D399),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniPos(String label, String val) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF060B14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
            const SizedBox(height: 2),
            Text(
              val,
              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
