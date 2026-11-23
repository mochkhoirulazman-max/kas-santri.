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
  String? _errorMessage;
  bool _isChecking = false;

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
    if (_isChecking || _pin.length >= 6) return;
    setState(() {
      _errorMessage = null;
      _pin += num;
    });

    if (_pin.length == 4) {
      _verifyInput();
    } else if (_pin.length > 4) {
      _verifyInput();
    }
  }

  void _onBackspace() {
    if (_isChecking) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _onClear() {
    if (_isChecking) return;
    setState(() {
      _errorMessage = null;
      _pin = '';
    });
  }

  Future<void> _verifyInput() async {
    setState(() => _isChecking = true);
    final valid = await AuthService.instance.verifyPin(_pin);
    if (!mounted) return;

    if (valid) {
      await _onUnlockSuccess();
    } else {
      // If reached 4 digits and invalid
      if (_pin.length >= 4) {
        setState(() {
          _errorMessage = 'PIN salah. Masukkan 1234';
          _pin = '';
          _isChecking = false;
        });
      } else {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _onUnlockSuccess() async {
    setState(() {
      _errorMessage = null;
      _isChecking = false;
    });
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
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFF060A12),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.4),
              radius: 1.2,
              colors: [
                Color(0xFF0D253A),
                Color(0xFF060A12),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 20),
                // Header Area
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withOpacity(0.2),
                            const Color(0xFF06B6D4).withOpacity(0.2),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.25),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 44,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'KUNCI APLIKASI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'PPS MIFTAHUSSUNAN • KAS SANTRI',
                      style: TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Badge Default PIN
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.key_rounded, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                          Text(
                            'PIN Default: 1234',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Indikator 4 Titik PIN
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < _pin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: isFilled ? 18 : 14,
                          height: isFilled ? 18 : 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isFilled
                                ? const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                                  )
                                : null,
                            color: isFilled ? null : Colors.white.withOpacity(0.12),
                            border: Border.all(
                              color: isFilled
                                  ? const Color(0xFF06B6D4)
                                  : Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: isFilled
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF06B6D4).withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF43F5E).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.4)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFF43F5E),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Numpad Area
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
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
                          // Biometrics / Clear
                          InkWell(
                            onTap: _tryBiometrics,
                            borderRadius: BorderRadius.circular(36),
                            child: Container(
                              width: 68,
                              height: 68,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(
                                Icons.fingerprint_rounded,
                                color: Color(0xFF06B6D4),
                                size: 30,
                              ),
                            ),
                          ),
                          _buildButton('0'),
                          InkWell(
                            onTap: _onBackspace,
                            onLongPress: _onClear,
                            borderRadius: BorderRadius.circular(36),
                            child: Container(
                              width: 68,
                              height: 68,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(
                                Icons.backspace_outlined,
                                color: Colors.white70,
                                size: 24,
                              ),
                            ),
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
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
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
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
