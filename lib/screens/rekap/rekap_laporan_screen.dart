import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/santri_status.dart';
import '../../providers/kas_santri_provider.dart';
import '../../providers/theme_wallpaper_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/time_category_helper.dart';
import '../../utils/app_feedback.dart';
import '../../services/report_service.dart';
import '../../services/yayasan_export_service.dart';
import '../../widgets/searchable_santri_picker.dart';
import '../../widgets/struk_gambar_dialog.dart';
import '../paywall_screen.dart';
import '../santri/santri_detail_screen.dart';
import 'cash_opname_screen.dart';
import 'executive_dashboard_screen.dart';
import 'smart_wa_reminder_screen.dart';

class RekapLaporanScreen extends StatefulWidget {
  const RekapLaporanScreen({Key? key}) : super(key: key);

  @override
  State<RekapLaporanScreen> createState() => _RekapLaporanScreenState();
}

class _RekapLaporanScreenState extends State<RekapLaporanScreen>
    with AutomaticKeepAliveClientMixin {
  String? _selectedSantriId;
  ExportPeriod _exportPeriod = ExportPeriod.bulanIni;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _isExporting = false;
  bool _showWaPreview = false;

  @override
  bool get wantKeepAlive => true;

  String _generateWaText(
    SantriStatusHariIni status,
    String namaPondok, {
    bool isProUser = false,
  }) {
    final santri = status.santri;
    final todayStr = DateFormatter.toLocalDateString(DateTime.now());
    final txList = status.transaksiHariIni;

    final rincianList = txList.isNotEmpty
        ? txList.map((t) {
            final kat = TimeCategoryHelper.getDbString(t.kategoriWaktu);
            final jam = '${t.waktuAmbil.hour.toString().padLeft(2, '0')}:${t.waktuAmbil.minute.toString().padLeft(2, '0')}';
            final nom = CurrencyFormatter.format(t.nominal);
            final note = t.catatan != null && t.catatan!.isNotEmpty ? t.catatan! : 'Jajan Harian';
            return '   • $kat ($jam): $nom ($note)';
          }).join('\n')
        : '   • _Belum ada pengambilan uang saku hari ini_';

    final infoTunggakan = santri.tunggakan > 0
        ? '🚨 *Catatan Administrasi/Tunggakan:* ${CurrencyFormatter.format(santri.tunggakan)} (${santri.catatanTunggakan.isNotEmpty ? santri.catatanTunggakan : 'Talangan Kas Pondok'})'
        : '✅ *Status Administrasi:* Bersih / Tidak Ada Tunggakan';

    return '''*Assalamu’alaikum Warahmatullahi Wabarakatuh* 🌸

Yth. *Bapak/Ibu Wali Santri*
dari ananda tercinta: *${santri.namaLengkap}* (Kamar / Kelas: ${santri.kamar})
di Tempat.

Semoga Bapak/Ibu sekeluarga senantiasa berada dalam lindungan, rahmat, dan keberkahan dari Allah Subhanahu wa Ta'ala.

Izin menyampaikan laporan mutasi keluar-masuk uang saku ananda per hari ini ($todayStr):

📊 *RINGKASAN UANG SAKU HARI INI:*
• Jatah Harian Ananda: *${CurrencyFormatter.format(santri.jatahHarian)} / hari*
• Pengambilan Hari Ini: *${CurrencyFormatter.format(status.totalAmbilHariIni)}*
• Sisa Kuota Hari Ini: *${CurrencyFormatter.format(status.sisaJatahHariIni < 0 ? 0 : status.sisaJatahHariIni)}*

📝 *RINCIAN PENGAMBILAN HARI INI:*
$rincianList

💰 *STATUS SALDO TITIPAN SANTRI:*
• Sisa Saldo Titipan: *${CurrencyFormatter.format(santri.saldoTotal)}*
• Estimasi Ketahanan: ±*${santri.estimasiHari} hari* ke depan
$infoTunggakan

Demikian laporan ini kami sampaikan dengan penuh amanah demi kenyamanan ananda dalam menuntut ilmu di *$namaPondok*. 

Apabila Bapak/Ibu hendak menitipkan setoran tambahan atau mengonfirmasi keperluan ananda, silakan hubungi pengurus kas pondok.

*Jazakumullah Khairan Katsiran*
*Wassalamu’alaikum Warahmatullahi Wabarakatuh* 🙏

Salam hormat & ta'dzim,
*Pengurus Kas & Keuangan Santri*
*$namaPondok*${isProUser ? '' : '\n\n_Dicatat dengan Kas-Santri_'}''';
  }

  Future<void> _sendWaDirect(Santri santri, String message) async {
    AppFeedback.tap();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    if (!provider.isProUser) {
      await PaywallScreen.show(
        context,
        triggerFeature: 'Kirim Laporan WhatsApp 1-Klik & Tanpa Watermark',
      );
      return;
    }
    final phone = ReportService.normalizeWaPhone(santri.noWaWali);
    if (phone.isEmpty) {
      AppFeedback.alert();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nomor WhatsApp wali ${santri.namaLengkap} belum diisi. Lengkapi terlebih dahulu di menu Edit Data Santri.',
            ),
            backgroundColor: const Color(0xFFF59E0B),
          ),
        );
      }
      return;
    }
    final launched = await ReportService.instance.openWhatsAppDirect(
      rawPhone: phone,
      message: message,
    );
    if (!launched && mounted) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka aplikasi WhatsApp di perangkat ini.'),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
    }
  }

  Future<void> _runOfficialExport({required bool isExcel}) async {
    if (_isExporting) return;
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
    setState(() => _isExporting = true);
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
          period: _exportPeriod,
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
          period: _exportPeriod,
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
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _copyWaText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Laporan WhatsApp berhasil disalin ke papan klip!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    AppFeedback.tap();
    final now = DateTime.now().toLocal();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(
        start: _customStart ?? now.subtract(const Duration(days: 6)),
        end: _customEnd ?? now,
      ),
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
        _exportPeriod = ExportPeriod.rentangKhusus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = Provider.of<KasSantriProvider>(context);
    final cardOpacity = Provider.of<ThemeWallpaperProvider>(context).cardOpacity;
    final statusList = provider.santriStatusList;

    if (_selectedSantriId == null && statusList.isNotEmpty) {
      _selectedSantriId = statusList.first.santri.id;
    }

    final selectedStatus = statusList.where((s) => s.santri.id == _selectedSantriId).firstOrNull ??
        (statusList.isNotEmpty ? statusList.first : null);

    final waPreviewText = selectedStatus != null
        ? _generateWaText(
            selectedStatus,
            provider.pengaturan.namaPondok,
            isProUser: provider.isProUser,
          )
        : '';
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final opnameToday = provider.latestOpnameToday;
    final latestOpname = provider.opnameLogs.isNotEmpty ? provider.opnameLogs.first : null;

    final Color opnameBadgeColor;
    final String opnameBadgeText;
    if (opnameToday == null) {
      opnameBadgeColor = const Color(0xFF38BDF8);
      opnameBadgeText = 'Siap Opname';
    } else if (opnameToday.isCocok) {
      opnameBadgeColor = const Color(0xFF34D399);
      opnameBadgeText = 'Cocok (Terverifikasi Fisik ✓)';
    } else {
      opnameBadgeColor = opnameToday.selisih < 0 ? const Color(0xFFFB7185) : const Color(0xFFFBBF24);
      opnameBadgeText = 'Selisih ${CurrencyFormatter.format(opnameToday.selisih)}';
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 115 + bottomSafe),
        children: [
          // 0. Pintasan Eksekutif & Pengingat WA Cerdas v4.0 (PRO)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    AppFeedback.tap();
                    if (!provider.hasProAccess) {
                      PaywallScreen.show(
                        context,
                        triggerFeature: 'Laporan Eksekutif Pengasuh & Yayasan',
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExecutiveDashboardScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xCC064E3B), Color(0xCC0F172A)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF34D399).withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.hasProAccess
                              ? '📊 Eksekutif Yayasan'
                              : '📊 Eksekutif 🔒 PRO',
                          style: const TextStyle(
                            color: Color(0xFF6EE7B7),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Tren kas & PDF 1 halaman',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () {
                    AppFeedback.tap();
                    if (!provider.hasProAccess) {
                      PaywallScreen.show(
                        context,
                        triggerFeature: 'Pusat Antrean Pengingat WA Cerdas',
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SmartWaReminderScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xCC1E170A), Color(0xCC0F172A)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.hasProAccess
                              ? '📲 Antrean WA Cerdas'
                              : '📲 Pengingat WA 🔒 PRO',
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Kritis, Infak & Tunggakan',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Audit Kas Harian Card (Vibrant Cyan -> Blue Glass)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF072638).withValues(alpha: (0.88 * cardOpacity).clamp(0.45, 0.92)),
                  const Color(0xFF0E1B3A).withValues(alpha: (0.90 * cardOpacity).clamp(0.48, 0.94)),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AUDIT KAS HARIAN',
                            style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Rekap Pengeluaran Sesi Waktu',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: opnameBadgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: opnameBadgeColor.withOpacity(0.45)),
                      ),
                      child: Text(
                        opnameBadgeText,
                        style: TextStyle(color: opnameBadgeColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 14),

              // 3 Kolom Rekap Audit
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF060B14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          const Text('🌅 Pagi & Siang', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              CurrencyFormatter.format(provider.rekapPagiSiang),
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF060B14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          const Text('🌙 Sore & Malam', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              CurrencyFormatter.format(provider.rekapSoreMalam),
                              style: const TextStyle(color: Color(0xFFD946EF), fontSize: 11.5, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF060B14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Text('🏦 Sisa Brankas', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              CurrencyFormatter.format(provider.totalBrankasFisik),
                              style: const TextStyle(color: Color(0xFF34D399), fontSize: 11.5, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Tombol Kalkulator Cash Opname Fisik (PRO)
              SizedBox(
                width: double.infinity,
                child: InkWell(
                  onTap: () {
                    AppFeedback.tap();
                    if (provider.isProUser) {
                      CashOpnameScreen.show(context);
                    } else {
                      PaywallScreen.show(
                        context,
                        triggerFeature: 'Kalkulator Cash Opname Fisik Malam Hari',
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E170A), Color(0xFF0A1628)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.55)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '🧮 Hitung Pecahan Uang Fisik (Opname) 👑',
                              style: TextStyle(
                                color: Color(0xFFFDE68A),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (latestOpname != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF060B14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Opname terakhir (${latestOpname.tanggalLokal}): Fisik ${CurrencyFormatter.format(latestOpname.totalFisik)}',
                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        latestOpname.isCocok ? 'Cocok ✓' : 'Selisih ${CurrencyFormatter.format(latestOpname.selisih)}',
                        style: TextStyle(
                          color: latestOpname.isCocok ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 1B. Ekspor Laporan Resmi Yayasan (Royal Gold -> Amber / Emerald Glass)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2B1C08).withValues(alpha: (0.86 * cardOpacity).clamp(0.45, 0.92)),
                const Color(0xFF07242A).withValues(alpha: (0.90 * cardOpacity).clamp(0.48, 0.94)),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: provider.isProUser
                  ? const Color(0xFF34D399).withValues(alpha: 0.45)
                  : const Color(0xFFFBBF24).withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DOKUMEN RESMI YAYASAN',
                          style: TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Laporan Resmi Yayasan',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: provider.isProUser
                          ? const Color(0xFF064E3B)
                          : const Color(0xFF1E1B4B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: provider.isProUser
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFBBF24),
                      ),
                    ),
                    child: Text(
                      provider.isProUser ? '✓ PRO' : '👑 PRO',
                      style: TextStyle(
                        color: provider.isProUser
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFFFDE68A),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ExportPeriod.values.map((period) {
                    final selected = _exportPeriod == period;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          YayasanExportService.periodLabel(
                            period,
                            customStart: _customStart,
                            customEnd: _customEnd,
                          ),
                          style: TextStyle(
                            color: selected ? const Color(0xFF030712) : Colors.white70,
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
                            _pickCustomRange();
                          } else {
                            setState(() => _exportPeriod = period);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : () => _runOfficialExport(isExcel: true),
                      icon: const Text('📊', style: TextStyle(fontSize: 14)),
                      label: Text(
                        provider.isProUser ? 'Excel (.xlsx)' : 'Excel (.xlsx) 👑',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF064E3B),
                        foregroundColor: const Color(0xFF6EE7B7),
                        side: const BorderSide(color: Color(0xFF10B981), width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : () => _runOfficialExport(isExcel: false),
                      icon: const Text('📄', style: TextStyle(fontSize: 14)),
                      label: Text(
                        provider.isProUser ? 'PDF Berkop' : 'PDF Berkop 👑',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1B4B),
                        foregroundColor: const Color(0xFF67E8F9),
                        side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Transparansi Wali Santri & Generator Laporan WA (Emerald -> Cyan Glass)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF063B2F).withValues(alpha: (0.86 * cardOpacity).clamp(0.45, 0.92)),
                const Color(0xFF0A1D36).withValues(alpha: (0.90 * cardOpacity).clamp(0.48, 0.94)),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF34D399).withValues(alpha: 0.40),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRANSPARANSI WALI SANTRI',
                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              const SizedBox(height: 2),
              const Text(
                'Kirim Laporan Mutasi ke WhatsApp',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
              ),

              const SizedBox(height: 12),

              // Searchable Picker Santri (anti dropdown kosong)
              SearchableSantriField(
                selectedSantri: selectedStatus?.santri,
                placeholder: statusList.isEmpty
                    ? 'Belum ada santri aktif'
                    : 'Cari & pilih santri...',
                onTap: () async {
                  if (statusList.isEmpty) return;
                  final santris = statusList.map((e) => e.santri).toList();
                  final picked = await SearchableSantriPicker.show(
                    context,
                    santriList: santris,
                    selectedSantriId: selectedStatus?.santri.id,
                    title: 'Pilih Santri untuk Laporan WA',
                  );
                  if (picked != null && mounted) {
                    setState(() => _selectedSantriId = picked);
                  }
                },
              ),

              const SizedBox(height: 12),

              // Tombol Aksi Utama Langsung Terlihat: Kirim WA 1-Klik & Salin Teks
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: ElevatedButton.icon(
                      onPressed: selectedStatus == null
                          ? null
                          : () => _sendWaDirect(selectedStatus.santri, waPreviewText),
                      icon: const Text('💬', style: TextStyle(fontSize: 15)),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          provider.isProUser ? 'Kirim WhatsApp' : 'Kirim WA 👑',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: const Color(0xFF030712),
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: selectedStatus == null
                          ? null
                          : () => _copyWaText(waPreviewText),
                      icon: const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF67E8F9)),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Salin Teks',
                          style: TextStyle(color: Color(0xFF67E8F9), fontSize: 11.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.55)),
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Baris Struk Gambar PNG & Toggle Expandable Pratinjau
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: selectedStatus == null
                          ? null
                          : () {
                              AppFeedback.tap();
                              if (!provider.isProUser) {
                                PaywallScreen.show(
                                  context,
                                  triggerFeature: 'Struk Gambar PNG Resmi Tanpa Watermark',
                                );
                                return;
                              }
                              StrukGambarDialog.show(
                                context,
                                status: selectedStatus,
                                pengaturan: provider.pengaturan,
                              );
                            },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1B4B).withOpacity(0.45),
                        side: BorderSide(
                          color: provider.isProUser
                              ? const Color(0xFF38BDF8).withOpacity(0.6)
                              : const Color(0xFFFBBF24).withOpacity(0.6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          provider.isProUser ? '🖼️ Struk Gambar PNG' : '🖼️ Struk PNG 👑',
                          style: TextStyle(
                            color: provider.isProUser ? const Color(0xFF67E8F9) : const Color(0xFFFDE68A),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        AppFeedback.tap();
                        setState(() => _showWaPreview = !_showWaPreview);
                      },
                      icon: Icon(
                        _showWaPreview ? Icons.expand_less_rounded : Icons.visibility_outlined,
                        size: 16,
                        color: Colors.white70,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _showWaPreview ? 'Tutup Pratinjau' : 'Pratinjau Pesan',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white12),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: selectedStatus == null
                      ? null
                      : () {
                          AppFeedback.tap();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SantriDetailScreen(
                                santriId: selectedStatus.santri.id,
                              ),
                            ),
                          );
                        },
                  icon: const Text('📄', style: TextStyle(fontSize: 14)),
                  label: const Text(
                    'Lihat Buku Mutasi Lengkap Santri Ini',
                    style: TextStyle(
                      color: Color(0xFF6EE7B7),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF064E3B).withValues(alpha: 0.35),
                    side: const BorderSide(color: Color(0xFF34D399)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              if (_showWaPreview && waPreviewText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF060B14).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SelectableText(
                    waPreviewText,
                    style: const TextStyle(
                      color: Color(0xFF67E8F9),
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. Prioritas Saldo Kritis (< 3 Hari) - PRO
        _buildSaldoKritisCard(provider, cardOpacity),
      ],
    ),
    );
  }

  Widget _buildSaldoKritisCard(KasSantriProvider provider, double cardOpacity) {
    final kritisList = provider.saldoKritisList;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF33140A).withValues(alpha: (0.86 * cardOpacity).clamp(0.45, 0.92)),
            const Color(0xFF180C24).withValues(alpha: (0.90 * cardOpacity).clamp(0.48, 0.94)),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: kritisList.isNotEmpty
              ? const Color(0xFFF59E0B).withValues(alpha: 0.50)
              : const Color(0xFFFB7185).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DETEKSI DINI SALDO',
                      style: TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Prioritas Saldo Kritis (< 3 Hari)',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF451A03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.6)),
                ),
                child: Text(
                  provider.isProUser ? '${kritisList.length} Santri' : '👑 PRO',
                  style: const TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!provider.isProUser)
            InkWell(
              onTap: () {
                AppFeedback.tap();
                PaywallScreen.show(
                  context,
                  triggerFeature: 'Pantau Saldo Kritis (< 3 Hari) & Pengingat WA',
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF060B14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.45)),
                ),
                child: const Row(
                  children: [
                    Text('🔒', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pantau otomatis santri dengan ketahanan saldo < 3 hari & kirim pengingat sopan ke WA wali sekali ketuk.',
                        style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (kritisList.isEmpty)
            const Text(
              'Alhamdulillah, seluruh santri saat ini memiliki ketahanan saldo minimal 3 hari ke depan.',
              style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 11.5),
            )
          else
            ...kritisList.map((item) {
              final s = item.santri;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF060B14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s.namaLengkap} (${s.kamar})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sisa ${CurrencyFormatter.format(s.saldoTotal)} • Est. ${s.estimasiHari} hr',
                            style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final msg = ReportService.instance.generateCriticalReminderText(
                          santri: s,
                          namaPondok: provider.pengaturan.namaPondok,
                          namaPengurus: provider.pengaturan.namaPengurus,
                        );
                        _sendWaDirect(s, msg);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: const Color(0xFF030712),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('💬 Ingatkan', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
