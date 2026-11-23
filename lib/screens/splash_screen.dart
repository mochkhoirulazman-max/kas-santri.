import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kas_santri_provider.dart';
import '../services/auth_service.dart';
import 'pin_lock_screen.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    await provider.init();

    await Future.delayed(const Duration(milliseconds: 600));

    final shouldLock = await AuthService.instance.shouldLockApp();

    if (!mounted) return;

    if (shouldLock) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PinLockScreen(isUnlockingSession: true),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 64,
                color: Color(0xFF00796B),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'KAS SANTRI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sistem Uang Saku & Titipan Santri Harian',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
