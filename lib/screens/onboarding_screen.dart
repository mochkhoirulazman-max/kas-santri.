import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kas_santri_provider.dart';
import '../services/account_auth_service.dart';
import '../services/tutorial_service.dart';
import '../utils/app_feedback.dart';
import '../utils/currency_formatter.dart';
import '../widgets/app_background_wrapper.dart';
import 'main_navigation_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isReplayMode;

  const OnboardingScreen({
    Key? key,
    this.isReplayMode = false,
  }) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  late final TextEditingController _namaPondokController;
  late final TextEditingController _namaPengurusController;
  late final TextEditingController _jatahDefaultController;

  int _currentSlide = 0;
  int _pembulatanJatah = 500;
  bool _useSimulationData = false;
  bool _isSubmitting = false;

  static const List<_OnboardingSlideSpec> _introSlides = [
    _OnboardingSlideSpec(
      emoji: '🕌',
      badge: 'SELAMAT DATANG DI KAS-SANTRI',
      title: 'Selamat Datang di Kas-Santri',
      description:
          'Kelola uang jajan santri, infak bulanan, dan brankas pondok tanpa pusing & tanpa selisih.',
      highlights: [
        '✨ Tampilan bening modern yang lega & tidak bikin mata lelah',
        '🔒 Aman 100% offline di HP pengurus maupun cadangan cloud',
        '⚡ Dirancang khusus mengikuti ritme harian bendahara pesantren',
      ],
      accent: Color(0xFF34D399),
      secondaryAccent: Color(0xFF06B6D4),
    ),
    _OnboardingSlideSpec(
      emoji: '⚡',
      badge: 'TRANSAKSI HARIAN KILAT',
      title: 'Ambil Uang 3 Detik & Scan QR',
      description:
          'Ketuk kartu 2 kotak atau pindai QR santri saat antrean padat; sisa jatah harian terhitung otomatis.',
      highlights: [
        '⊞ Pilihan tampilan 2 Kotak ringkas atau 1 Baris detail',
        '📷 Pindai Kartu QR santri langsung membuka nominal siap cair',
        '↩️ Salah pencet? Tersedia tombol Undo otomatis 5 detik',
      ],
      accent: Color(0xFF38BDF8),
      secondaryAccent: Color(0xFF818CF8),
    ),
    _OnboardingSlideSpec(
      emoji: '🎁',
      badge: 'SMART SPLIT & BUKU INFAK',
      title: 'Setoran Sambangan & Buku Infak',
      description:
          'Uang sambangan wali langsung terbagi otomatis ke Infak Masak, Listrik, Beras (Liter/Rp), dan Saldo Jajan.',
      highlights: [
        '🎁 Mode Sambangan memotong pos infak & tunggakan otomatis',
        '➕ Mode Top-Up Jajan murni menambah saldo saku & jatah harian',
        '🌾 Buku Infak memantau beras gudang & serah terima yayasan',
      ],
      accent: Color(0xFFFBBF24),
      secondaryAccent: Color(0xFF10B981),
    ),
    _OnboardingSlideSpec(
      emoji: '📲',
      badge: 'AKUNTABEL & TRANSPARAN',
      title: 'Bebas Selisih & 1-Klik WA Wali',
      description:
          'Cek Cash Opname malam hari, kirim laporan mutasi santun ke WA orang tua, & cetak PDF/Excel resmi yayasan.',
      highlights: [
        '🧮 Kalkulator pecahan fisik Cash Opname mencegah uang selisih',
        '💬 Pesan WhatsApp otomatis santun lengkap rincian keluar-masuk',
        '📄 Cetak Laporan PDF berkop pondok & Excel multi-sheet rapi',
      ],
      accent: Color(0xFFE879F9),
      secondaryAccent: Color(0xFF38BDF8),
    ),
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final peng = provider.pengaturan;
    final initialPondok =
        (peng.namaPondok.trim().isNotEmpty && peng.namaPondok != 'Nama Pondok')
            ? peng.namaPondok
            : (widget.isReplayMode ? peng.namaPondok : '');
    _namaPondokController = TextEditingController(text: initialPondok);
    _namaPengurusController = TextEditingController(
      text: peng.namaPengurus.trim().isNotEmpty
          ? peng.namaPengurus
          : 'Pengurus Kas & Keuangan',
    );
    _jatahDefaultController = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(
        peng.defaultJatahHarian > 0 ? peng.defaultJatahHarian : 10000,
      ),
    );
    _pembulatanJatah = peng.pembulatanJatah == 1000 ? 1000 : 500;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _namaPondokController.dispose();
    _namaPengurusController.dispose();
    _jatahDefaultController.dispose();
    super.dispose();
  }

  void _goToSlide(int index) {
    AppFeedback.tap();
    _pageController.animateToPage(
      index.clamp(0, 4),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleSkip() {
    AppFeedback.tap();
    if (widget.isReplayMode) {
      Navigator.pop(context);
      return;
    }
    _goToSlide(4);
  }

  Future<void> _submitSetup() async {
    if (_isSubmitting) return;
    final rawPondok = _namaPondokController.text.trim();
    final finalNamaPondok = rawPondok.isNotEmpty ? rawPondok : 'Nama Pondok';
    final finalPengurus = _namaPengurusController.text.trim().isNotEmpty
        ? _namaPengurusController.text.trim()
        : 'Pengurus Kas & Keuangan';
    final parsedJatah = CurrencyFormatter.parse(_jatahDefaultController.text);
    final finalJatah = parsedJatah > 0 ? parsedJatah : 10000;

    setState(() => _isSubmitting = true);
    AppFeedback.success();

    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    await TutorialService.instance.markOnboardingSeen();

    if (widget.isReplayMode) {
      await provider.savePengaturan(
        provider.pengaturan.copyWith(
          namaPondok: finalNamaPondok,
          namaPengurus: finalPengurus,
          defaultJatahHarian: finalJatah,
          pembulatanJatah: _pembulatanJatah,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    await provider.completeOnboarding(
      namaPondok: finalNamaPondok,
      namaPengurus: finalPengurus,
      defaultJatahHarian: finalJatah,
      pembulatanJatah: _pembulatanJatah,
      useSimulationData: _useSimulationData,
    );

    final quickAcc = await AccountAuthService.instance.enterOfflineQuickMode(
      namaLengkap: finalPengurus,
      jabatan: 'Bendahara Pondok',
      rememberSession: true,
    );
    await provider.syncActiveAccountToPengaturan(quickAcc);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar: Indikator Slide + Tombol Lewati
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF071525).withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'Slide ${_currentSlide + 1} / 5',
                        style: const TextStyle(
                          color: Color(0xFF67E8F9),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_currentSlide < 4 || widget.isReplayMode)
                      TextButton(
                        onPressed: _handleSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        child: Text(
                          widget.isReplayMode ? 'Tutup ✕' : 'Lewati →',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 5 Slide PageView
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const ClampingScrollPhysics(),
                  onPageChanged: (idx) => setState(() => _currentSlide = idx),
                  children: [
                    ..._introSlides.map(_buildFeatureSlide),
                    _buildSetupPondokSlide(),
                  ],
                ),
              ),

              // Bottom Controls: Dots + Back/Next (untuk slide 1-4)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (idx) {
                        final active = idx == _currentSlide;
                        return GestureDetector(
                          onTap: () => _goToSlide(idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 26 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: active
                                  ? const LinearGradient(
                                      colors: [Color(0xFF34D399), Color(0xFF38BDF8)],
                                    )
                                  : null,
                              color: active ? null : Colors.white24,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }),
                    ),
                    if (_currentSlide < 4) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (_currentSlide > 0) ...[
                            OutlinedButton(
                              onPressed: () => _goToSlide(_currentSlide - 1),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                '← Kembali',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _goToSlide(_currentSlide + 1),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: const Color(0xFF030712),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _currentSlide == 3
                                    ? 'Lanjut ke Setup Pondok →'
                                    : 'Lanjut →',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureSlide(_OnboardingSlideSpec spec) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  spec.accent.withValues(alpha: 0.30),
                  spec.secondaryAccent.withValues(alpha: 0.22),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: spec.accent.withValues(alpha: 0.65),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: spec.accent.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(spec.emoji, style: const TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: spec.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: spec.accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              spec.badge,
              style: TextStyle(
                color: spec.accent,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            spec.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            spec.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(18),
            borderColor: spec.accent.withValues(alpha: 0.42),
            gradientColors: [
              Color.lerp(const Color(0xFF071628), spec.accent, 0.20)!
                  .withValues(alpha: 0.85),
              const Color(0xDE091222),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: spec.highlights.map((line) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    line,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupPondokSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF34D399), Color(0xFF38BDF8), Color(0xFFD946EF)],
              ),
            ),
            child: const KasSantriLogoMark(size: 62, borderRadius: 17),
          ),
          const SizedBox(height: 12),
          const Text(
            'SETUP CEPAT PONDOK ANDA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF34D399),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Setup Cepat Pondok Anda',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lengkapi identitas dasar di bawah ini (dapat diubah kapan saja di menu Sistem).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          const SizedBox(height: 16),

          GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(18),
            borderColor: const Color(0xFF34D399).withValues(alpha: 0.45),
            gradientColors: const [
              Color(0xD8063B2F),
              Color(0xDE0B192E),
              Color(0xDA151232),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NAMA PONDOK PESANTREN',
                  style: TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _namaPondokController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Nama Pondok (cth: PP Al-Hikmah)',
                    prefixIcon: Icon(
                      Icons.mosque_outlined,
                      color: Color(0xFF34D399),
                      size: 18,
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'NAMA PENGURUS BENDAHARA',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _namaPengurusController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Contoh: Ust. Ahmad / Bendahara Putra',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: Color(0xFF38BDF8),
                      size: 18,
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'JATAH HARIAN DEFAULT (RP / HARI)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
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
                    prefixStyle: TextStyle(
                      color: Color(0xFF34D399),
                      fontWeight: FontWeight.w900,
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'PEMBULATAN JATAH HARIAN',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildRoundingChip('Kelipatan Rp 500', 500),
                    const SizedBox(width: 8),
                    _buildRoundingChip('Kelipatan Rp 1.000', 1000),
                  ],
                ),
                if (!widget.isReplayMode) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF060E1C).withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '✨ Sertakan 6 Santri Contoh (Simulasi)',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Switch(
                          value: _useSimulationData,
                          activeColor: const Color(0xFF34D399),
                          onChanged: (val) {
                            AppFeedback.tap();
                            setState(() => _useSimulationData = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: const Color(0xFF030712),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _isSubmitting ? null : _submitSetup,
              child: Text(
                _isSubmitting
                    ? 'Menyiapkan Kas-Santri...'
                    : '🚀 Mulai Pakai Kas-Santri',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
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
            color: isSelected
                ? const Color(0xFF10B981).withValues(alpha: 0.22)
                : const Color(0xFF060B14),
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

class _OnboardingSlideSpec {
  final String emoji;
  final String badge;
  final String title;
  final String description;
  final List<String> highlights;
  final Color accent;
  final Color secondaryAccent;

  const _OnboardingSlideSpec({
    required this.emoji,
    required this.badge,
    required this.title,
    required this.description,
    required this.highlights,
    required this.accent,
    required this.secondaryAccent,
  });
}
