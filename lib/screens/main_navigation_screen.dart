import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kas_santri_provider.dart';
import '../providers/theme_wallpaper_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_feedback.dart';
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
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) {
        Provider.of<KasSantriProvider>(context, listen: false)
            .tryAutoBackupDriveInBackground();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
            physics: const ClampingScrollPhysics(),
            onPageChanged: (idx) {
              if (_currentIndex != idx) {
                setState(() => _currentIndex = idx);
              }
            },
            children: [
              HomeFastWithdrawalScreen(
                onOpenBukuInfak: () {
                  setState(() => _setoranSubTab = 1);
                  _goToPage(1);
                },
              ),
              SetoranScreen(
                activeSubTab: _setoranSubTab,
                onSubTabChanged: (sub) => setState(() => _setoranSubTab = sub),
                onSaved: () => _goToPage(0),
              ),
              const RiwayatTransaksiScreen(),
              const RekapLaporanScreen(),
              const SystemTabScreen(),
            ],
          ),

          // Floating Glass Bottom Navigation Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 12 + bottomSafe,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 62,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(navBgOpacity),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.55),
                        blurRadius: 24,
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
            color: isSelected ? const Color(0xFF10B981).withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: const Color(0xFF34D399).withOpacity(0.45), width: 1)
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
