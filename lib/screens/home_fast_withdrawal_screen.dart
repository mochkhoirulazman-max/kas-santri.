import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../providers/kas_santri_provider.dart';
import '../widgets/app_background_wrapper.dart';
import '../widgets/guided_spotlight_tour.dart';
import '../widgets/stat_card.dart';
import '../widgets/santri_card.dart';
import '../widgets/fast_withdrawal_bottom_sheet.dart';
import '../widgets/tunggakan_bottom_sheet.dart';
import '../widgets/tambah_santri_bottom_sheet.dart';
import '../widgets/tarik_tunai_bottom_sheet.dart';
import '../utils/app_feedback.dart';
import 'paywall_screen.dart';
import 'santri/qr_scanner_screen.dart';
import 'tabungan/brankas_tabungan_screen.dart';

class HomeFastWithdrawalScreen extends StatefulWidget {
  final VoidCallback? onOpenBukuInfak;
  final ValueChanged<String>? onOpenSetoranForSantri;
  final VoidCallback? onShowHomeHelp;
  final GlobalKey? headerCrownSpotlightKey;
  final GlobalKey? vaultSpotlightKey;
  final GlobalKey? addSantriSpotlightKey;
  final GlobalKey? cardsAreaSpotlightKey;

  const HomeFastWithdrawalScreen({
    Key? key,
    this.onOpenBukuInfak,
    this.onOpenSetoranForSantri,
    this.onShowHomeHelp,
    this.headerCrownSpotlightKey,
    this.vaultSpotlightKey,
    this.addSantriSpotlightKey,
    this.cardsAreaSpotlightKey,
  }) : super(key: key);

  @override
  State<HomeFastWithdrawalScreen> createState() => _HomeFastWithdrawalScreenState();
}

class _HomeFastWithdrawalScreenState extends State<HomeFastWithdrawalScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _showBanner = true;
  late AnimationController _crownGlowController;
  Timer? _clockTimer;
  final ValueNotifier<DateTime> _clockNotifier =
      ValueNotifier<DateTime>(DateTime.now().toLocal());

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _crownGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _clockNotifier.value = DateTime.now().toLocal();
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _clockNotifier.dispose();
    _crownGlowController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    if (!provider.isProUser) {
      AppFeedback.alert();
      await PaywallScreen.show(
        context,
        triggerFeature: 'Kustomisasi Logo Pondok Resmi',
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      await provider.updateLogoPath(result.files.single.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo pondok berhasil diperbarui!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _scanQrAndOpenWithdrawal() async {
    AppFeedback.tap();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    if (!provider.isProUser) {
      await PaywallScreen.show(
        context,
        triggerFeature: 'Scan QR Kartu Santri (Mode Antrean Kilat 1 Detik)',
      );
      return;
    }

    final scannedCode = await QrScannerScreen.scan(context);
    if (scannedCode == null || !mounted) return;

    final status = provider.findStatusByQrCode(scannedCode);
    if (status == null) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR Code "$scannedCode" tidak cocok dengan santri aktif.'),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
      return;
    }

    AppFeedback.success();
    FastWithdrawalBottomSheet.show(context, status);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = Provider.of<KasSantriProvider>(context);
    final isTwoCol = provider.pengaturan.isTwoColGrid;
    final isPro = provider.hasProAccess;
    if (isPro && _crownGlowController.isAnimating) {
      _crownGlowController.stop();
    } else if (!isPro && !_crownGlowController.isAnimating) {
      _crownGlowController.repeat(reverse: true);
    }
    final filteredList = provider.filteredSantriStatusList;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          // Status bar info & Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                children: [
                  // Status bar mobile real-time (waktu lokal perangkat)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ValueListenableBuilder<DateTime>(
                        valueListenable: _clockNotifier,
                        builder: (_, nowDt, __) {
                          final nowStr = DateFormat('dd MMM yyyy • HH:mm', 'id_ID')
                              .format(nowDt.toLocal());
                          return Text(
                            nowStr,
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          );
                        },
                      ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.circle, size: 6, color: Color(0xFF34D399)),
                                SizedBox(width: 4),
                                Text(
                                  'Sistem Aktif',
                                  style: TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Header Utama: Logo, Judul & Tombol "+ Santri" + Ikon Mahkota Freemium
                      Container(
                        key: widget.headerCrownSpotlightKey,
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  // Logo Tap-to-Change
                                  InkWell(
                                    onTap: _pickLogo,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF34D399), Color(0xFF38BDF8), Color(0xFFD946EF)],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: KasSantriLogoMark(
                                        customLogoPath: provider.pengaturan.logoPath,
                                        size: 40,
                                        borderRadius: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'KAS & KEUANGAN SANTRI',
                                          style: TextStyle(
                                            color: Color(0xFF34D399),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.1,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          provider.pengaturan.namaPondok,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.2,
                                          ),
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

                            // Tombol "+ Santri" & Ikon Mahkota Freemium (👑)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  key: widget.addSantriSpotlightKey,
                                  style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: const Color(0xFF04121A),
                                ),
                                onPressed: () {
                                  if (provider.hasReachedFreeSantriLimit) {
                                    AppFeedback.alert();
                                    PaywallScreen.show(
                                      context,
                                      triggerFeature:
                                          'Santri Tanpa Batas — Kuota Mode Gratis maksimal ${KasSantriProvider.maxFreeSantriQuota} santri aktif telah tercapai.',
                                    );
                                    return;
                                  }
                                  AppFeedback.tap();
                                  TambahSantriBottomSheet.show(
                                    context,
                                    onOpenSetoran: widget.onOpenSetoranForSantri,
                                  );
                                },
                                child: const Text(
                                  '+ Santri',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(width: 6),
                              RepaintBoundary(
                                child: AnimatedBuilder(
                                  animation: _crownGlowController,
                                  builder: (context, child) {
                                    final glowOpacity = isPro
                                        ? 0.35
                                        : (0.25 + (_crownGlowController.value * 0.35));
                                    return InkWell(
                                      onTap: () {
                                        AppFeedback.tap();
                                        if (isPro) {
                                          PaywallScreen.showActiveSubscriptionSheet(context);
                                        } else {
                                          PaywallScreen.show(context);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(13),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF1E170A), Color(0xFF0A0E17)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(13),
                                              border: Border.all(
                                                color: isPro
                                                    ? const Color(0xFF34D399)
                                                    : const Color(0xFFFBBF24).withOpacity(0.85),
                                                width: 1.3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (isPro
                                                          ? const Color(0xFF10B981)
                                                          : const Color(0xFFF59E0B))
                                                      .withOpacity(glowOpacity),
                                                  blurRadius: 10,
                                                  spreadRadius: 0.5,
                                                ),
                                              ],
                                            ),
                                            alignment: Alignment.center,
                                            child: const Text('👑', style: TextStyle(fontSize: 16)),
                                          ),
                                          Positioned(
                                            top: -5,
                                            right: -4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                gradient: isPro
                                                    ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)])
                                                    : const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFDE047)]),
                                                borderRadius: BorderRadius.circular(7),
                                                border: Border.all(color: const Color(0xFF060A12), width: 1),
                                              ),
                                              child: Text(
                                                isPro ? '✓' : 'PRO',
                                                style: const TextStyle(
                                                  color: Color(0xFF030712),
                                                  fontSize: 7.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (widget.onShowHomeHelp != null) ...[
                                const SizedBox(width: 6),
                                SpotlightHelpButton(
                                  onTap: widget.onShowHomeHelp!,
                                  size: 34,
                                  accent: const Color(0xFF38BDF8),
                                ),
                              ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Hero Card: Total Uang Titipan (Brankas Fisik)
            SliverToBoxAdapter(
              child: Container(
                key: widget.vaultSpotlightKey,
                child: SafeVaultCard(
                  totalBrankas: provider.totalBrankasFisik,
                  totalKeluarHariIni: provider.totalPengeluaranHariIni,
                  totalKuotaHariIni: provider.totalKuotaHariIni,
                  totalTunggakan: provider.totalTunggakanPondok,
                  countTunggakan: provider.countSantriTunggakan,
                  jumlahSantri: provider.allSantri.where((s) => s.statusAktif).length,
                  isHidden: provider.pengaturan.hideBalance,
                  isProUser: provider.isProUser,
                  kasLaciTunai: provider.kasLaciTunai,
                  rekeningBank: provider.rekeningBank,
                  onToggleHide: provider.toggleHideBalance,
                  onTunggakanTap: () => provider.setFilter('TUNGGAKAN'),
                  onTarikTunaiTap: () => TarikTunaiBottomSheet.show(context),
                  onUpgradeProTap: () => PaywallScreen.show(
                    context,
                    triggerFeature: 'Multi-Dompet: Pisah Kas Laci Tunai vs Rekening Bank',
                  ),
                ),
              ),
            ),

            // Banner Panduan Tombol Kartu 2 Kotak & Tunggakan
            if (provider.isClockTampered)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xE63B0A18), Color(0xE6260B1D)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.65)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: Color(0xFFFDA4AF), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          provider.clockTamperMessage ??
                              'Jam perangkat tidak sinkron. Aktifkan Tanggal & Waktu Otomatis untuk melanjutkan.',
                          style: const TextStyle(
                            color: Color(0xFFFFE4E6),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () async {
                          AppFeedback.tap();
                          await provider.recheckDeviceClock(tryNetwork: true);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF43F5E).withOpacity(0.25),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Cek Ulang',
                          style: TextStyle(
                            color: Color(0xFFFECDD3),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (provider.shouldShowRemoteUpdateBanner && provider.remoteConfig != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xE6052E26), Color(0xE61E170A)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: Color(0xFFFBBF24), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.remoteConfig!.isUpdateAvailable(AppConfig.appVersion)
                                  ? 'Pembaruan Tersedia (v${provider.remoteConfig!.latestVersion})'
                                  : (provider.remoteConfig!.announcementTitle.isNotEmpty
                                      ? provider.remoteConfig!.announcementTitle
                                      : 'Info Kas-Santri'),
                              style: const TextStyle(
                                color: Color(0xFFFDE68A),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (provider.remoteConfig!.announcementBody.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                provider.remoteConfig!.announcementBody,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (provider.remoteConfig!.updateUrl.startsWith('https://'))
                        TextButton(
                          onPressed: () async {
                            AppFeedback.tap();
                            final uri = Uri.tryParse(provider.remoteConfig!.updateUrl);
                            if (uri != null) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFFBBF24).withOpacity(0.2),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Lihat',
                            style: TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      IconButton(
                        onPressed: () => provider.dismissRemoteBanner(),
                        icon: const Icon(Icons.close, size: 15, color: Colors.white54),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),

            if (_showBanner)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xE6052E26), Color(0xE6081E2E), Color(0xE6260B24)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'TOMBOL KARTU 2 KOTAK & FITUR TUNGGAKAN',
                              style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Ketuk kartu santri untuk Ambil Uang Harian, atau ketuk tombol 🚨 Tunggakan untuk mencatat/melunasi tunggakan santri.',
                              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 10.5, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _showBanner = false),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 14, color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bar Pencarian & Switcher 2 Kotak vs 1 Baris
            SliverToBoxAdapter(
              child: Padding(
                key: filteredList.isEmpty ? widget.cardsAreaSpotlightKey : null,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Cari nama santri atau kamar/kelas...',
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF38BDF8)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                                  onPressed: () {
                                    _searchController.clear();
                                    provider.setSearchQuery('');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        ),
                        onChanged: (val) => provider.setSearchQuery(val),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _scanQrAndOpenWithdrawal,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isPro
                              ? const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF0E7490)])
                              : null,
                          color: isPro ? null : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isPro
                                ? const Color(0xFF34D399).withOpacity(0.7)
                                : const Color(0xFFFBBF24).withOpacity(0.55),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📷', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              isPro ? 'QR' : 'QR 👑',
                              style: TextStyle(
                                color: isPro ? const Color(0xFF6EE7B7) : const Color(0xFFFDE68A),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        AppFeedback.tap();
                        provider.toggleGridLayout();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Text('⊞', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            Text(
                              isTwoCol ? '2 Kotak' : '1 Baris',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Filter Pills Horizontal
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    _buildFilterPill('✨ Semua', 'ALL', provider),
                    if (widget.onOpenBukuInfak != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () {
                            AppFeedback.tap();
                            widget.onOpenBukuInfak!.call();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF064E3B).withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF34D399).withOpacity(0.75)),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '🌾 Infak',
                              style: TextStyle(
                                color: Color(0xFF6EE7B7),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          AppFeedback.tap();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BrankasTabunganScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C4A6E).withOpacity(0.60),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF2DD4BF).withOpacity(0.80)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '🏦 Tabungan',
                            style: TextStyle(
                              color: Color(0xFF5EEAD4),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildFilterPill(
                      isPro ? '⚠️ Saldo Kritis (<3 Hr)' : '⚠️ Saldo Kritis (<3 Hr) 👑',
                      'KRITIS',
                      provider,
                      isProGated: true,
                      isAmber: true,
                    ),
                    _buildFilterPill('🚨 Ada Tunggakan', 'TUNGGAKAN', provider, isRed: true),
                    _buildFilterPill('🟢 Utuh', 'UTUH', provider),
                    _buildFilterPill('🔵 Sebagian', 'SEBAGIAN', provider),
                    _buildFilterPill('🟡 Limit Habis', 'HABIS', provider),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 6)),

            // Daftar Kartu Santri
            if (filteredList.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🔍', style: TextStyle(fontSize: 32)),
                        SizedBox(height: 8),
                        Text('Santri Tidak Ditemukan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Coba kata kunci pencarian atau filter lainnya.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              )
            else if (isTwoCol)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 115 + bottomSafe),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.52,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final status = filteredList[idx];
                      return RepaintBoundary(
                        key: idx == 0 ? widget.cardsAreaSpotlightKey : null,
                        child: SantriCard(
                          status: status,
                          isTwoCol: true,
                          onAmbilTap: () => FastWithdrawalBottomSheet.show(context, status),
                          onTunggakanTap: () => TunggakanBottomSheet.show(context, status.santri),
                        ),
                      );
                    },
                    childCount: filteredList.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(0, 4, 0, 115 + bottomSafe),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final status = filteredList[idx];
                      return RepaintBoundary(
                        key: idx == 0 ? widget.cardsAreaSpotlightKey : null,
                        child: SantriCard(
                          status: status,
                          isTwoCol: false,
                          onAmbilTap: () => FastWithdrawalBottomSheet.show(context, status),
                          onTunggakanTap: () => TunggakanBottomSheet.show(context, status.santri),
                        ),
                      );
                    },
                    childCount: filteredList.length,
                  ),
                ),
              ),
          ],
        ),
    );
  }

  Widget _buildFilterPill(
    String label,
    String filterKey,
    KasSantriProvider provider, {
    bool isRed = false,
    bool isAmber = false,
    bool isProGated = false,
  }) {
    final isSelected = provider.activeFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          if (isProGated && !provider.isProUser) {
            PaywallScreen.show(
              context,
              triggerFeature: 'Pantau Santri Saldo Kritis (< 3 Hari)',
            );
            return;
          }
          provider.setFilter(filterKey);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? (isRed
                    ? const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFD946EF)])
                    : (isAmber
                        ? const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF97316)])
                        : const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF38BDF8)])))
                : null,
            color: isSelected
                ? null
                : (isRed
                    ? const Color(0xFF3F0A18).withOpacity(0.5)
                    : (isAmber ? const Color(0xFF451A03).withOpacity(0.55) : const Color(0xFF0F172A))),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isRed
                      ? const Color(0xFFFB7185).withOpacity(0.4)
                      : (isAmber ? const Color(0xFFFBBF24).withOpacity(0.45) : Colors.white12)),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isRed
                              ? const Color(0xFFF43F5E)
                              : (isAmber ? const Color(0xFFF59E0B) : const Color(0xFF10B981)))
                          .withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF030712)
                  : (isRed
                      ? const Color(0xFFFECDD3)
                      : (isAmber ? const Color(0xFFFDE68A) : Colors.white70)),
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
