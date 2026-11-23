import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'main_navigation_screen.dart';

class PinLockScreen extends StatefulWidget {
  final bool isUnlockingSession;

  const PinLockScreen({Key? key, this.isUnlockingSession = true}) : super(key: key);

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin = '';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tryBiometrics();
  }

  Future<void> _tryBiometrics() async {
    final canBio = await AuthService.instance.isBiometricsAvailable();
    if (canBio) {
      final success = await AuthService.instance.authenticateWithBiometrics();
      if (success && mounted) {
        await _onUnlockSuccess();
      }
    }
  }

  void _onKeyPress(String num) {
    if (_pin.length < 6) {
      setState(() {
        _errorMessage = null;
        _pin += num;
      });

      if (_pin.length >= 4) {
        _verifyInput();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _verifyInput() async {
    final valid = await AuthService.instance.verifyPin(_pin);
    if (valid) {
      await _onUnlockSuccess();
    } else {
      if (_pin.length >= 6) {
        setState(() {
          _errorMessage = 'PIN salah. Silakan coba lagi.';
          _pin = '';
        });
      }
    }
  }

  Future<void> _onUnlockSuccess() async {
    setState(() => _isLoading = true);
    await AuthService.instance.updateLastActive();
    if (!mounted) return;

    if (widget.isUnlockingSession) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Mencegah back button menutup aplikasi tanpa PIN
      child: Scaffold(
        backgroundColor: const Color(0xFF004D40),
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 24),
              // Header
              Column(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 54, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text(
                    'KUNCI APLIKASI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Masukkan PIN Pengurus untuk mengakses Kas',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // Indikator Titik PIN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final isFilled = index < _pin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled ? Colors.amber : Colors.white24,
                          border: Border.all(
                            color: isFilled ? Colors.amberAccent : Colors.white54,
                            width: 1.5,
                          ),
                        ),
                      );
                    }),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),

              // Numpad Lock
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                child: Column(
                  children: [
                    _buildRow(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _buildRow(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _buildRow(['7', '8', '9']),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Biometrik
                        IconButton(
                          icon: const Icon(Icons.fingerprint, color: Colors.white, size: 32),
                          onPressed: _tryBiometrics,
                        ),
                        _buildButton('0'),
                        IconButton(
                          icon: const Icon(Icons.backspace_outlined, color: Colors.white, size: 26),
                          onPressed: _onBackspace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Kas Santri • Mode Keamanan Terpasang',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> values) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: values.map((val) => _buildButton(val)).toList(),
    );
  }

  Widget _buildButton(String text) {
    return InkWell(
      onTap: () => _onKeyPress(text),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
