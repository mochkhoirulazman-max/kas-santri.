import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/transaksi.dart';
import '../../providers/kas_santri_provider.dart';
import '../../providers/theme_wallpaper_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/time_category_helper.dart';
import '../../utils/app_feedback.dart';
import '../../services/yayasan_export_service.dart';
import '../../widgets/guided_spotlight_tour.dart';
import '../../widgets/searchable_santri_picker.dart';
import '../paywall_screen.dart';

class RiwayatTransaksiScreen extends StatefulWidget {
  final bool isActiveTab;

  const RiwayatTransaksiScreen({
    Key? key,
    this.isActiveTab = true,
  }) : super(key: key);

  @override
  State<RiwayatTransaksiScreen> createState() => _RiwayatTransaksiScreenState();
}

class _RiwayatTransaksiScreenState extends State<RiwayatTransaksiScreen>
    with AutomaticKeepAliveClientMixin {
  final ScreenSpotlightController _spotCtrl = ScreenSpotlightController();
  final GlobalKey _spotFilterKey = GlobalKey();
  final GlobalKey _spotDateFilterKey = GlobalKey();
  String _selectedSantriId = 'ALL';
  String _selectedWaktu = 'ALL';
  ExportPeriod _dateFilter = ExportPeriod.semua;
  DateTime? _customStart;
  DateTime? _customEnd;
  List<TransaksiHarian> _list = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _exportFromMutasi({required bool isExcel}) async {
    AppFeedback.tap();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    if (!provider.isProUser) {
      await PaywallScreen.show(
        context,
        triggerFeature: isExcel
            ? 'Ekspor Laporan Excel Multi-Sheet (.xlsx)'
            : 'Ekspor Laporan Resmi PDF Berkop Logo',
      );
      return;
    }
    try {
      if (isExcel) {
        await YayasanExportService.instance.exportExcelMultiSheet(
          pengaturan: provider.pengaturan,
          santriList: provider.allSantri,
          totalBrankasFisik: provider.totalBrankasFisik,
          kasLaciTunai: provider.kasLaciTunai,
          rekeningBank: provider.rekeningBank,
          totalTunggakanPondok: provider.totalTunggakanPondok,
          opnameLogs: provider.opnameLogs,
          period: _dateFilter,
          customStart: _customStart,
          customEnd: _customEnd,
        );
      } else {
        await YayasanExportService.instance.exportPdfResmiYayasan(
          pengaturan: provider.pengaturan,
          santriList: provider.allSantri,
          totalBrankasFisik: provider.totalBrankasFisik,
          kasLaciTunai: provider.kasLaciTunai,
          rekeningBank: provider.rekeningBank,
          totalTunggakanPondok: provider.totalTunggakanPondok,
          period: _dateFilter,
          customStart: _customStart,
          customEnd: _customEnd,
        );
      }
      AppFeedback.success();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor laporan: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final range = YayasanExportService.resolveRange(
      _dateFilter,
      customStart: _customStart,
      customEnd: _customEnd,
    );
    final results = await DatabaseHelper.instance.getAllTransaksi(
      santriId: _selectedSantriId,
      kategoriWaktu: _selectedWaktu,
      tanggalMulai: range.mulai,
      tanggalSelesai: range.selesai,
    );
    if (mounted) {
      setState(() {
        _list = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickCustomDateRange() async {
    AppFeedback.tap();
    final now = DateTime.now().toLocal();
    final initialRange = DateTimeRange(
      start: _customStart ?? now.subtract(const Duration(days: 6)),
      end: _customEnd ?? now,
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: initialRange,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF10B981),
              onPrimary: Color(0xFF040914),
              surface: Color(0xFF0F172A),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _customStart = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _customEnd = DateTime(picked.end.year, picked.end.month, picked.end.day);
        _dateFilter = ExportPeriod.rentangKhusus;
      });
      await _fetch();
    }
  }

  void _confirmVoid(TransaksiHarian tx, String namaSantri) {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final santri =
        provider.allSantri.where((s) => s.id == tx.santriId).firstOrNull;
    final isSetoran = tx.tipe == TipeTransaksi.setoran;
    final saldoSaatIni = santri?.saldoTotal ?? 0;
    final bool isSaldoSetoranTerpakai = isSetoran && saldoSaatIni < tx.nominal;
    final int estimasiTalangan =
        isSaldoSetoranTerpakai ? (tx.nominal - saldoSaatIni) : 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isSetoran ? 'Batalkan Setoran Ini?' : 'Batalkan Transaksi Ini?',
        ),
        content: Text(
          isSaldoSetoranTerpakai
              ? 'Setoran $namaSantri sebesar ${CurrencyFormatter.format(tx.nominal)} akan dibatalkan.\n\n'
                  '⚠️ Perhatian: Saldo santri saat ini tinggal ${CurrencyFormatter.format(saldoSaatIni)} karena sebagian uang setoran sudah terpakai jajan. Selisih yang sudah terpakai (hingga ${CurrencyFormatter.format(estimasiTalangan)}) akan otomatis tercatat sebagai Tunggakan / Talangan Kas Pondok agar Brankas & Multi-Dompet tetap 100% seimbang.'
              : 'Transaksi $namaSantri sebesar ${CurrencyFormatter.format(tx.nominal)} akan dibatalkan dan saldo santri serta mutasi dompet akan disesuaikan otomatis.',
          style: const TextStyle(fontSize: 12.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            onPressed: () async {
              final provider = Provider.of<KasSantriProvider>(context, listen: false);
              await provider.voidTransaksi(tx.id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              await _fetch();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaksi dibatalkan & saldo dikembalikan.'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            child: const Text('Ya, Batalkan Transaksi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = Provider.of<KasSantriProvider>(context);
    final cardOpacity = Provider.of<ThemeWallpaperProvider>(context).cardOpacity;
    final santriList = provider.allSantri.where((s) => s.statusAktif).toList();
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return ScreenSpotlightHost(
      screenKey: 'tour_mutasi',
      isActive: widget.isActiveTab,
      controller: _spotCtrl,
      steps: [
        SpotlightStepSpec(
          targetKey: _spotFilterKey,
          emoji: '🔍',
          title: 'Filter Santri & Kategori Waktu',
          description:
              'Saring mutasi keluar-masuk untuk satu santri tertentu atau berdasarkan sesi waktu (Pagi, Siang, Sore, Malam, maupun Setoran masuk).',
          accent: const Color(0xFF38BDF8),
        ),
        SpotlightStepSpec(
          targetKey: _spotDateFilterKey,
          emoji: '📅',
          title: 'Rentang Tanggal & Ekspor PDF / Excel',
          description:
              'Pilih Hari Ini, Bulan Ini, atau Rentang Tanggal Khusus untuk mengecek mutasi dan langsung mengunduh laporan PDF / Excel resmi.',
          accent: const Color(0xFF34D399),
        ),
        const SpotlightStepSpec(
          emoji: '🛡️',
          title: 'Edit / Batalkan (Void) Transaksi Aman',
          description:
              'Salah ketik nominal atau santri? Ketuk kartu transaksi di bawah untuk mengubah nominal atau membatalkan (Void). Saldo & Kas Laci otomatis tersinkron tanpa selisih.',
          accent: Color(0xFFFB7185),
        ),
      ],
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
        onRefresh: () async {
          await provider.loadAllData();
          await _fetch();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF072536).withValues(alpha: (0.88 * cardOpacity).clamp(0.45, 0.92)),
                        const Color(0xFF0E1B38).withValues(alpha: (0.90 * cardOpacity).clamp(0.48, 0.94)),
                        const Color(0xFF1A1033).withValues(alpha: (0.86 * cardOpacity).clamp(0.45, 0.92)),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.40),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.16),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BUKU MUTASI DIGITAL',
                                style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Riwayat Keluar & Masuk',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF060B14).withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                  '${_list.length} catatan',
                                  style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SpotlightHelpButton(
                                onTap: _spotCtrl.startTour,
                                size: 30,
                                accent: const Color(0xFF38BDF8),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Filter Santri (Searchable) & Filter Waktu
                      Row(
                        key: _spotFilterKey,
                        children: [
                          Expanded(
                            flex: 6,
                            child: SearchableSantriField(
                              compact: true,
                              isAllSelected: _selectedSantriId == 'ALL',
                              allLabel: 'Semua Santri',
                              selectedSantri: santriList
                                  .where((s) => s.id == _selectedSantriId)
                                  .firstOrNull,
                              onTap: () async {
                                final picked = await SearchableSantriPicker.show(
                                  context,
                                  santriList: santriList,
                                  selectedSantriId: _selectedSantriId,
                                  allowAllOption: true,
                                  allOptionLabel: 'Semua Santri',
                                  title: 'Filter Mutasi per Santri',
                                );
                                if (picked != null && mounted) {
                                  setState(() => _selectedSantriId = picked);
                                  _fetch();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: DropdownButtonFormField<String>(
                              value: _selectedWaktu,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF090E1A),
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'ALL', child: Text('Semua Waktu')),
                                DropdownMenuItem(value: 'PAGI', child: Text('🌅 Pagi')),
                                DropdownMenuItem(value: 'SIANG', child: Text('☀️ Siang')),
                                DropdownMenuItem(value: 'SORE', child: Text('🌤️ Sore')),
                                DropdownMenuItem(value: 'MALAM', child: Text('🌙 Malam')),
                                DropdownMenuItem(value: 'SETORAN', child: Text('📥 Setoran')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedWaktu = val);
                                  _fetch();
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Filter Rentang Tanggal Lokal Akurat
                      SizedBox(
                        key: _spotDateFilterKey,
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: ExportPeriod.values.map((period) {
                            final selected = _dateFilter == period;
                            final label = period == ExportPeriod.rentangKhusus
                                ? (_dateFilter == ExportPeriod.rentangKhusus &&
                                        _customStart != null &&
                                        _customEnd != null
                                    ? '📅 ${DateFormatter.toLocalDateString(_customStart!)} → ${DateFormatter.toLocalDateString(_customEnd!)}'
                                    : '📅 Rentang Khusus')
                                : (period == ExportPeriod.semua
                                    ? 'Semua Tanggal'
                                    : YayasanExportService.periodLabel(period));
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  label,
                                  style: TextStyle(
                                    color: selected ? const Color(0xFF040914) : Colors.white70,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                selected: selected,
                                selectedColor: const Color(0xFF34D399),
                                backgroundColor: const Color(0xFF060B14),
                                side: BorderSide(color: selected ? Colors.transparent : Colors.white12),
                                onSelected: (_) {
                                  AppFeedback.tap();
                                  if (period == ExportPeriod.rentangKhusus) {
                                    _pickCustomDateRange();
                                  } else {
                                    setState(() => _dateFilter = period);
                                    _fetch();
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Tombol Pintasan Ekspor Resmi PRO
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _exportFromMutasi(isExcel: true),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFF064E3B).withValues(alpha: 0.45),
                                side: BorderSide(
                                  color: provider.isProUser
                                      ? const Color(0xFF34D399).withValues(alpha: 0.6)
                                      : const Color(0xFFFBBF24).withValues(alpha: 0.5),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                provider.isProUser ? '📊 Excel (.xlsx)' : '📊 Excel 👑',
                                style: TextStyle(
                                  color: provider.isProUser ? const Color(0xFF6EE7B7) : const Color(0xFFFDE68A),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _exportFromMutasi(isExcel: false),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E1B4B).withValues(alpha: 0.45),
                                side: BorderSide(
                                  color: provider.isProUser
                                      ? const Color(0xFF38BDF8).withValues(alpha: 0.6)
                                      : const Color(0xFFFBBF24).withValues(alpha: 0.5),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                provider.isProUser ? '📄 PDF Resmi' : '📄 PDF Resmi 👑',
                                style: TextStyle(
                                  color: provider.isProUser ? const Color(0xFF67E8F9) : const Color(0xFFFDE68A),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (_list.isEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 115 + bottomSafe),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF082236).withValues(alpha: 0.65),
                          const Color(0xFF0A1224).withValues(alpha: 0.72),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.30)),
                    ),
                    child: const Center(
                      child: Text(
                        'Belum ada catatan mutasi transaksi.',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 115 + bottomSafe),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final tx = _list[idx];
                      final santri = santriList.where((s) => s.id == tx.santriId).firstOrNull;
                      final namaSantri = santri != null ? santri.namaLengkap : 'Santri';
                      final isMasuk = tx.tipe == TipeTransaksi.setoran;
                      final katStr = TimeCategoryHelper.getDbString(tx.kategoriWaktu);
                      final jamStr = '${tx.waktuAmbil.hour.toString().padLeft(2, '0')}:${tx.waktuAmbil.minute.toString().padLeft(2, '0')}';

                      final Color rowAccent = isMasuk
                          ? const Color(0xFF34D399)
                          : (tx.isOverlimit
                              ? const Color(0xFFFB7185)
                              : const Color(0xFF38BDF8));

                      return RepaintBoundary(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.lerp(const Color(0xFF081426), rowAccent, 0.18)!
                                    .withValues(alpha: (0.86 * cardOpacity).clamp(0.45, 0.90)),
                                const Color(0xFF091120)
                                    .withValues(alpha: (0.90 * cardOpacity).clamp(0.48, 0.92)),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: rowAccent.withValues(alpha: 0.36)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: rowAccent.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: rowAccent.withValues(alpha: 0.45),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(isMasuk ? '📥' : '💸', style: const TextStyle(fontSize: 16)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            namaSantri,
                                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.black45,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.white12),
                                                ),
                                                child: Text(
                                                  '$katStr • $jamStr',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              if (tx.isOverlimit)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: const Color(0xFFFB7185).withValues(alpha: 0.5)),
                                                  ),
                                                  child: const Text(
                                                    'Overlimit',
                                                    style: TextStyle(color: Color(0xFFFDA4AF), fontSize: 8.5, fontWeight: FontWeight.w800),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            tx.catatan != null && tx.catatan!.isNotEmpty ? tx.catatan! : (isMasuk ? 'Setoran' : 'Jajan Harian'),
                                            style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '${isMasuk ? '+' : '-'}${CurrencyFormatter.format(tx.nominal)}',
                                      style: TextStyle(
                                        color: isMasuk ? const Color(0xFF34D399) : const Color(0xFFFCD34D),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  InkWell(
                                    onTap: () {
                                      AppFeedback.tap();
                                      _confirmVoid(tx, namaSantri);
                                    },
                                    child: const Text(
                                      'Void / Batal',
                                      style: TextStyle(
                                        color: Color(0xFFFB7185),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _list.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }
}
