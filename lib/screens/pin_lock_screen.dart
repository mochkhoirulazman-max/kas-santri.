import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kas_santri_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_feedback.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricsIfAllowed(silentIfDisabled: true);
    });
  }

  Future<void> _tryBiometricsIfAllowed({bool silentIfDisabled = false}) async {
    if (!mounted) return;
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final bioAllowed = provider.isProUser && provider.pengaturan.isBiometricEnabled;
    if (!bioAllowed) {
      if (!silentIfDisabled && mounted) {
        AppFeedback.alert();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.isProUser
                  ? 'Aktifkan saklar Biometrik di Tab Sistem untuk memakai sidik jari.'
                  : 'Buka kunci dengan sidik jari tersedia khusus Kas-Santri PRO 👑.',
            ),
            backgroundColor: const Color(0xFFF59E0B),
          ),
        );
      }
      return;
    }

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
    AppFeedback.tap();
    setState(() {
      _errorMessage = null;
      _pin += num;
    });

    if (_pin.length >= 4) {
      _verifyInput(autoCheckOnly: _pin.length < 6);
    }
  }

  void _onBackspace() {
    if (_isChecking) return;
    if (_pin.isNotEmpty) {
      AppFeedback.tap();
      setState(() {
        _errorMessage = null;
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _onClear() {
    if (_isChecking) return;
    AppFeedback.tap();
    setState(() {
      _errorMessage = null;
      _pin = '';
    });
  }

  Future<void> _verifyInput({bool autoCheckOnly = false}) async {
    setState(() => _isChecking = true);
    final valid = await AuthService.instance.verifyPin(_pin);
    if (!mounted) return;

    if (valid) {
      await _onUnlockSuccess();
    } else {
      if (_pin.length >= 6 || !autoCheckOnly) {
        AppFeedback.alert();
        setState(() {
          _errorMessage = 'PIN tidak cocok. Silakan coba lagi.';
          _pin = '';
          _isChecking = false;
        });
      } else {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _onUnlockSuccess() async {
    AppFeedback.success();
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
    final provider = Provider.of<KasSantriProvider>(context);
    final namaPondok = provider.pengaturan.namaPondok.toUpperCase();
    final canUseBiometric = provider.isProUser && provider.pengaturan.isBiometricEnabled;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF04070E),
        body: Stack(
          children: [
            // Aurora ambient glow
            Positioned(
              top: -80,
              left: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withOpacity(0.22),
                ),
              ),
            ),
            Positioned(
              bottom: -70,
              right: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF06B6D4).withOpacity(0.20),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: RepaintBoundary(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF072536).withValues(alpha: 0.86),
                            const Color(0xFF0A1428).withValues(alpha: 0.90),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: const Color(0xFF34D399).withValues(alpha: 0.38),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.50),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF10B981).withOpacity(0.25),
                                    const Color(0xFF06B6D4).withOpacity(0.22),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFF34D399).withOpacity(0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.28),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock_rounded,
                                size: 38,
                                color: Color(0xFF34D399),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'KUNCI APLIKASI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$namaPondok • KAS SANTRI',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                              ),
                            ),
                            const SizedBox(height: 12),
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
                                  const Icon(Icons.key_rounded, size: 14, color: Color(0xFFFBBF24)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Masukkan PIN Pengurus (4–6 Digit)',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Indikator 4-6 Titik PIN
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_pin.length > 4 ? _pin.length : 4, (index) {
                                final isFilled = index < _pin.length;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.symmetric(horizontal: 9),
                                  width: isFilled ? 17 : 13,
                                  height: isFilled ? 17 : 13,
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
                                          ? const Color(0xFF38BDF8)
                                          : Colors.white.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: isFilled
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF06B6D4).withOpacity(0.55),
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
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF43F5E).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.5)),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFFDA4AF),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 22),

                            // Numpad
                            _buildRow(['1', '2', '3']),
                            const SizedBox(height: 12),
                            _buildRow(['4', '5', '6']),
                            const SizedBox(height: 12),
                            _buildRow(['7', '8', '9']),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                InkWell(
                                  onTap: () => _tryBiometricsIfAllowed(silentIfDisabled: false),
                                  borderRadius: BorderRadius.circular(34),
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: canUseBiometric
                                          ? const Color(0xFF06B6D4).withOpacity(0.14)
                                          : Colors.white.withOpacity(0.04),
                                      border: Border.all(
                                        color: canUseBiometric
                                            ? const Color(0xFF38BDF8).withOpacity(0.55)
                                            : Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.fingerprint_rounded,
                                      color: canUseBiometric
                                          ? const Color(0xFF38BDF8)
                                          : Colors.white24,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                _buildButton('0'),
                                InkWell(
                                  onTap: _onBackspace,
                                  onLongPress: _onClear,
                                  borderRadius: BorderRadius.circular(34),
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.05),
                                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                                    ),
                                    child: const Icon(
                                      Icons.backspace_outlined,
                                      color: Colors.white70,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            Text(
                              canUseBiometric
                                  ? 'Ketuk ikon sidik jari atau masukkan PIN 4–6 digit'
                                  : 'Keamanan Terpasang • Tekan tahan hapus untuk reset',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.48),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
