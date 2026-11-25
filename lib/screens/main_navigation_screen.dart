import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kas_santri_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_feedback.dart';
import 'home_fast_withdrawal_screen.dart';
import 'pin_lock_screen.dart';
import 'setoran/setoran_screen.dart';
import 'transaksi/riwayat_transaksi_screen.dart';
import 'rekap/rekap_laporan_screen.dart';
import 'settings/settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _setoranSubTab = 0;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF060A12),
      body: Stack(
        children: [
          // Main Body Screen (5 tab utama tetap bersih)
          IndexedStack(
            index: _currentIndex,
            children: [
              HomeFastWithdrawalScreen(
                onOpenBukuInfak: () => setState(() {
                  _setoranSubTab = 1;
                  _currentIndex = 1;
                }),
              ),
              SetoranScreen(
                activeSubTab: _setoranSubTab,
                onSubTabChanged: (sub) => setState(() => _setoranSubTab = sub),
                onSaved: () => setState(() => _currentIndex = 0),
              ),
              const RiwayatTransaksiScreen(),
              const RekapLaporanScreen(),
              const SettingsScreen(),
            ],
          ),

          // Floating Glass Bottom Navigation Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 12 + bottomSafe,
            child: Container(
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xE60F172A),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.65),
                    blurRadius: 25,
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
          setState(() => _currentIndex = index);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981).withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: const Color(0xFF34D399).withOpacity(0.4), width: 1)
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
                  color: isSelected ? const Color(0xFF34D399) : Colors.white54,
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
