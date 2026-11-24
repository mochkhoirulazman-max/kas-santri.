import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kas_santri_provider.dart';
import '../utils/app_feedback.dart';
import '../utils/currency_formatter.dart';
import 'main_navigation_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _namaPondokController = TextEditingController(text: 'PPS MIFTAHUSSUNAN');
  final TextEditingController _namaPengurusController = TextEditingController(text: 'Pengurus Kas & Keuangan');
  final TextEditingController _jatahDefaultController = TextEditingController(text: '10.000');
  int _pembulatanJatah = 500;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _namaPondokController.dispose();
    _namaPengurusController.dispose();
    _jatahDefaultController.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool useSimulationData}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    AppFeedback.success();

    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final jatah = CurrencyFormatter.parse(_jatahDefaultController.text);

    await provider.completeOnboarding(
      namaPondok: _namaPondokController.text,
      namaPengurus: _namaPengurusController.text,
      defaultJatahHarian: jatah > 0 ? jatah : 10000,
      pembulatanJatah: _pembulatanJatah,
      useSimulationData: useSimulationData,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060A12),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -70,
              left: -50,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withOpacity(0.18),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              right: -50,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF06B6D4).withOpacity(0.18),
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF34D399), Color(0xFF38BDF8), Color(0xFFD946EF)],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: Container(
                        color: const Color(0xFF060A12),
                        padding: const EdgeInsets.all(4),
                        child: Image.asset(
                          'logo.jpg',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Color(0xFF34D399),
                            size: 38,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SELAMAT DATANG DI KAS-SANTRI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Atur Identitas Pondok Anda',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pengaturan ini bisa diubah kapan saja melalui menu Sistem.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 22),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.88),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NAMA PONDOK / ASRAMA',
                        style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _namaPondokController,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          hintText: 'Contoh: PPS MIFTAHUSSUNAN',
                          prefixIcon: Icon(Icons.mosque_outlined, color: Color(0xFF34D399), size: 18),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'NAMA PENGURUS / BENDAHARA',
                        style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _namaPengurusController,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Ust. Ahmad / Bendahara Putra',
                          prefixIcon: Icon(Icons.person_outline, color: Color(0xFF38BDF8), size: 18),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'JATAH HARIAN DEFAULT (RP / HARI)',
                        style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _jatahDefaultController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [RibuanInputFormatter()],
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                        decoration: const InputDecoration(
                          prefixText: 'Rp ',
                          prefixStyle: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w900),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'PEMBULATAN OTOMATIS JATAH HARIAN',
                        style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildRoundingChip('Kelipatan Rp 500', 500),
                          const SizedBox(width: 8),
                          _buildRoundingChip('Kelipatan Rp 1.000', 1000),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: const Color(0xFF030712),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: _isSubmitting ? null : () => _finish(useSimulationData: false),
                    child: const Text(
                      '🚀 Mulai Sekarang (Data Bersih)',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: _isSubmitting ? null : () => _finish(useSimulationData: true),
                    child: const Text(
                      '✨ Gunakan Data Simulasi (6 Santri Contoh)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundingChip(String label, int value) {
    final isSelected = _pembulatanJatah == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          setState(() => _pembulatanJatah = value);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFF060B14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF34D399) : Colors.white12,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF34D399) : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
