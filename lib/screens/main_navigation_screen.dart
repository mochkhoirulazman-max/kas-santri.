import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kas_santri_provider.dart';
import '../providers/theme_wallpaper_provider.dart';
import '../services/auth_service.dart';
import '../services/tutorial_service.dart';
import '../utils/app_feedback.dart';
import '../widgets/guided_spotlight_tour.dart';
import 'home_fast_withdrawal_screen.dart';
import 'pin_lock_screen.dart';
import 'rekap/rekap_laporan_screen.dart';
import 'setoran/setoran_screen.dart';
import 'settings/system_tab_screen.dart';
import 'transaksi/riwayat_transaksi_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _setoranSubTab = 0;
  String? _preselectedSetoranSantriId;
  late final PageController _pageController;

  // GlobalKey untuk 6 Langkah Guided Spotlight Tour
  final GlobalKey _spotHeaderCrownKey = GlobalKey();
  final GlobalKey _spotVaultKey = GlobalKey();
  final GlobalKey _spotAddSantriKey = GlobalKey();
  final GlobalKey _spotSantriCardsKey = GlobalKey();
  final GlobalKey _spotBottomNavKey = GlobalKey();
  final GlobalKey _spotSystemHeaderKey = GlobalKey();

  late final List<SpotlightStepSpec> _tourSteps;
  bool _isTourActive = false;
  int _tourStepIndex = 0;
  KasSantriProvider? _providerRef;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _tourSteps = [
      SpotlightStepSpec(
        targetKey: _spotHeaderCrownKey,
        tabIndex: 0,
        emoji: '👑',
        title: 'Identitas Pondok & Mahkota PRO',
        description:
            'Ketuk mahkota 👑 untuk coba PRO Gratis 14 Hari atau upgrade paket. Ketuk logo di kiri untuk memasang logo resmi pondok Anda.',
        accent: const Color(0xFFFBBF24),
      ),
      SpotlightStepSpec(
        targetKey: _spotVaultKey,
        tabIndex: 0,
        emoji: '🏦',
        title: 'Brankas Titipan & Multi-Dompet',
        description:
            'Pantau total uang titipan seluruh santri, pemisahan Kas Laci Tunai vs Rekening Bank, pengeluaran hari ini, dan total tunggakan.',
        accent: const Color(0xFF34D399),
      ),
      SpotlightStepSpec(
        targetKey: _spotAddSantriKey,
        tabIndex: 0,
        emoji: '➕',
        title: 'Tombol + Santri Baru',
        description:
            'Tambahkan data santri baru dengan ringkas (saldo awal Rp 0, lalu isi saldo lewat menu Setoran agar tercatat rapi di mutasi).',
        accent: const Color(0xFF6EE7B7),
      ),
      SpotlightStepSpec(
        targetKey: _spotSantriCardsKey,
        tabIndex: 0,
        emoji: '💸',
        title: 'Kartu Santri 2 Kotak & Scan QR',
        description:
            'Ketuk kartu santri untuk mencatat ambil uang harian 3 detik, ketuk 📷 QR untuk mode antrean, atau geser layar kanan/kiri untuk pindah menu.',
        accent: const Color(0xFF38BDF8),
      ),
      SpotlightStepSpec(
        targetKey: _spotBottomNavKey,
        tabIndex: 0,
        emoji: '🧭',
        title: '5 Menu Utama Bawah',
        description:
            'Kas & Ambil (harian), Setoran (Sambangan/Top-Up & Buku Infak), Mutasi (riwayat & void), Rekap WA (laporan wali & yayasan), serta Sistem.',
        accent: const Color(0xFFA78BFA),
      ),
      SpotlightStepSpec(
        targetKey: _spotSystemHeaderKey,
        tabIndex: 4,
        emoji: '⚙️',
        title: 'Tab Sistem & Pengaturan Lengkap',
        description:
            'Gunakan ⚡ Akses Cepat Pengurus untuk Cash Opname, Kartu QR, Wallpaper, Backup, atau ketuk ⚙️ Pengaturan di kanan atas untuk aturan pondok.',
        accent: const Color(0xFF22D3EE),
      ),
    ];

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prov = Provider.of<KasSantriProvider>(context, listen: false);
      _providerRef = prov;
      prov.spotlightTourRequestNotifier.addListener(_onReplaySpotlightRequested);
      prov.tryAutoBackupDriveInBackground();
      _checkFirstTimeWalkthrough();
    });
  }

  @override
  void dispose() {
    _providerRef?.spotlightTourRequestNotifier
        .removeListener(_onReplaySpotlightRequested);
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkFirstTimeWalkthrough() async {
    final seen = await TutorialService.instance.hasSeenWalkthrough();
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 420));
      if (mounted) {
        await _startSpotlightTour();
      }
    }
  }

  void _onReplaySpotlightRequested() {
    if (!mounted) return;
    _startSpotlightTour();
  }

  Future<void> _startSpotlightTour() async {
    await _navigateToTourStep(0);
  }

  Future<void> _navigateToTourStep(int stepIdx) async {
    if (stepIdx < 0 || stepIdx >= _tourSteps.length) {
      await _finishSpotlightTour();
      return;
    }

    final spec = _tourSteps[stepIdx];
    if (_currentIndex != spec.tabIndex) {
      _goToPage(spec.tabIndex);
      await Future.delayed(const Duration(milliseconds: 320));
    }

    if (!mounted) return;
    final targetCtx = spec.targetKey.currentContext;
    if (targetCtx != null && targetCtx.mounted) {
      try {
        await Scrollable.ensureVisible(
          targetCtx,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: 0.20,
        );
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _isTourActive = true;
      _tourStepIndex = stepIdx;
    });
  }

  Future<void> _finishSpotlightTour() async {
    AppFeedback.tap();
    await TutorialService.instance.markWalkthroughSeen();
    if (!mounted) return;
    setState(() {
      _isTourActive = false;
      _tourStepIndex = 0;
    });
    if (_currentIndex != 0) {
      _goToPage(0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AuthService.instance.updateLastActive();
    } else if (state == AppLifecycleState.resumed) {
      _checkLockOnResume();
    }
  }

  Future<void> _checkLockOnResume() async {
    final shouldLock = await AuthService.instance.shouldLockApp();
    if (shouldLock && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PinLockScreen(isUnlockingSession: true)),
      );
    }
  }

  void _goToPage(int index) {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final cardOpacity = Provider.of<ThemeWallpaperProvider>(context).cardOpacity;
    final navBgOpacity = (cardOpacity * 0.95).clamp(0.45, 0.94);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 5 Tab Utama yang mendukung gestur geser kiri/kanan (Swipeable Tabs)
          PageView(
            controller: _pageController,
            physics: _isTourActive
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            onPageChanged: (idx) {
              if (_currentIndex != idx) {
                setState(() => _currentIndex = idx);
              }
            },
            children: [
              HomeFastWithdrawalScreen(
                headerCrownSpotlightKey: _spotHeaderCrownKey,
                vaultSpotlightKey: _spotVaultKey,
                addSantriSpotlightKey: _spotAddSantriKey,
                cardsAreaSpotlightKey: _spotSantriCardsKey,
                onOpenBukuInfak: () {
                  setState(() => _setoranSubTab = 1);
                  _goToPage(1);
                },
                onOpenSetoranForSantri: (santriId) {
                  setState(() {
                    _setoranSubTab = 0;
                    _preselectedSetoranSantriId = santriId;
                  });
                  _goToPage(1);
                },
              ),
              SetoranScreen(
                activeSubTab: _setoranSubTab,
                preselectedSantriId: _preselectedSetoranSantriId,
                onSubTabChanged: (sub) => setState(() => _setoranSubTab = sub),
                onSaved: () => _goToPage(0),
              ),
              const RiwayatTransaksiScreen(),
              const RekapLaporanScreen(),
              SystemTabScreen(
                headerSpotlightKey: _spotSystemHeaderKey,
              ),
            ],
          ),

          // Floating Glass Bottom Navigation Bar (1-satunya BackdropFilter yang diisolasi RepaintBoundary)
          Positioned(
            left: 16,
            right: 16,
            bottom: 12 + bottomSafe,
            child: RepaintBoundary(
              key: _spotBottomNavKey,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    height: 62,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF071A2C).withValues(alpha: navBgOpacity),
                          const Color(0xFF0B1328).withValues(alpha: navBgOpacity),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(0, '💸', 'Kas & Ambil'),
                        _buildNavItem(1, '📥', 'Setoran'),
                        _buildNavItem(2, '📜', 'Mutasi'),
                        _buildNavItem(3, '📊', 'Rekap WA'),
                        _buildNavItem(4, '⚙️', 'Sistem'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Guided Spotlight Tour 6 Langkah
          if (_isTourActive)
            Positioned.fill(
              child: GuidedSpotlightOverlay(
                steps: _tourSteps,
                currentStep: _tourStepIndex,
                onNext: () {
                  AppFeedback.tap();
                  _navigateToTourStep(_tourStepIndex + 1);
                },
                onPrev: () {
                  AppFeedback.tap();
                  if (_tourStepIndex > 0) {
                    _navigateToTourStep(_tourStepIndex - 1);
                  }
                },
                onSkip: _finishSpotlightTour,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String emoji, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          _goToPage(index);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.45), width: 1)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF34D399) : Colors.white60,
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
