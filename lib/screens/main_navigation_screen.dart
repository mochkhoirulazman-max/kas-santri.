import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kas_santri_provider.dart';
import '../services/auth_service.dart';
import '../widgets/undo_snackbar.dart';
import 'home_fast_withdrawal_screen.dart';
import 'santri/santri_list_screen.dart';
import 'setoran/setoran_screen.dart';
import 'rekap/rekap_laporan_screen.dart';
import 'settings/settings_screen.dart';
import 'pin_lock_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeFastWithdrawalScreen(),
    SantriListScreen(),
    SetoranScreen(),
    RekapLaporanScreen(),
    SettingsScreen(),
  ];

  Future<void> _lockAppNow() async {
    await AuthService.instance.lockSession();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PinLockScreen(isUnlockingSession: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.pengaturan.namaPondok,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Pengurus: ${provider.pengaturan.namaPengurus}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_clock_outlined),
            tooltip: 'Kunci Aplikasi Sekarang',
            onPressed: _lockAppNow,
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Banner Undo 5 Detik di Bagian Bawah Layar (PRD Non-Fungsional Guard)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: UndoBottomBanner(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.flash_on_outlined),
            selectedIcon: Icon(Icons.flash_on, color: Color(0xFF00796B)),
            label: 'Ambil Cepat',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: Color(0xFF00796B)),
            label: 'Santri',
          ),
          NavigationDestination(
            icon: Icon(Icons.input_rounded),
            selectedIcon: Icon(Icons.input_rounded, color: Color(0xFF00796B)),
            label: 'Setoran',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: Color(0xFF00796B)),
            label: 'Rekap',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Color(0xFF00796B)),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
