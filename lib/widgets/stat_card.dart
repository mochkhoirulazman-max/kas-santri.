import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_wallpaper_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/app_feedback.dart';

class SafeVaultCard extends StatelessWidget {
  final int totalBrankas;
  final int totalKeluarHariIni;
  final int totalKuotaHariIni;
  final int totalTunggakan;
  final int countTunggakan;
  final int jumlahSantri;
  final bool isHidden;
  final bool isProUser;
  final int kasLaciTunai;
  final int rekeningBank;
  final VoidCallback onToggleHide;
  final VoidCallback onTunggakanTap;
  final VoidCallback? onTarikTunaiTap;
  final VoidCallback? onUpgradeProTap;

  const SafeVaultCard({
    Key? key,
    required this.totalBrankas,
    required this.totalKeluarHariIni,
    required this.totalKuotaHariIni,
    required this.totalTunggakan,
    required this.countTunggakan,
    required this.jumlahSantri,
    required this.isHidden,
    this.isProUser = false,
    this.kasLaciTunai = 0,
    this.rekeningBank = 0,
    required this.onToggleHide,
    required this.onTunggakanTap,
    this.onTarikTunaiTap,
    this.onUpgradeProTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardOpacity = Provider.of<ThemeWallpaperProvider>(context).cardOpacity;
    // Serapan Jatah Harian Pondok (%)
    final pct = totalKuotaHariIni > 0
        ? ((totalKeluarHariIni / totalKuotaHariIni) * 100).clamp(0, 100).toInt()
        : 0;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.8),
            radius: 1.4,
            colors: [
              const Color(0xFF10B981).withValues(alpha: (0.55 * cardOpacity).clamp(0.22, 0.68)),
              const Color(0xFF06B6D4).withValues(alpha: (0.42 * cardOpacity).clamp(0.18, 0.55)),
              const Color(0xFFD946EF).withValues(alpha: (0.28 * cardOpacity).clamp(0.12, 0.38)),
              const Color(0xFF081224).withValues(alpha: (0.94 * cardOpacity).clamp(0.48, 0.94)),
            ],
            stops: const [0.0, 0.45, 0.75, 1.0],
          ),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.48),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.24),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFFD946EF).withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Atas: Title + Eye icon & Santri Count Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Total Uang Titipan (Brankas)',
                    style: TextStyle(
                      color: Color(0xFFCFFAFE),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      AppFeedback.tap();
                      onToggleHide();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 16,
                        color: const Color(0xFFBAE6FD),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF38BDF8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF34D399).withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$jumlahSantri Santri',
                  style: const TextStyle(
                    color: Color(0xFF04121A),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Total Uang Fisik Besar (FittedBox agar tidak pernah terpotong)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isHidden ? 'Rp ••••••••' : CurrencyFormatter.format(totalBrankas),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                fontFamily: 'monospace',
                shadows: [
                  Shadow(
                    color: Color(0x6610B981),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Bar Serapan Kuota Harian Pondok (Animated)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '⚡ Serapan Jatah Harian Pondok',
                style: TextStyle(
                  color: Color(0xFFE0F2FE),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            height: 7,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF030712).withOpacity(0.75),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF10B981),
                          Color(0xFF06B6D4),
                          Color(0xFFD946EF),
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF06B6D4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 10),

          // 3 Kotak Metrik Bawah
          Row(
            children: [
              // 1. Keluar Hari Ini
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF060B17).withOpacity(0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔥 Keluar Hari Ini',
                        style: TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isHidden ? 'Rp ••••' : CurrencyFormatter.format(totalKeluarHariIni),
                          style: const TextStyle(
                            color: Color(0xFFFCD34D),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 2. Kuota Harian
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF060B17).withOpacity(0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF06B6D4).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎯 Kuota Harian',
                        style: TextStyle(
                          color: Color(0xFFBAE6FD),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isHidden ? 'Rp ••••' : CurrencyFormatter.format(totalKuotaHariIni),
                          style: const TextStyle(
                            color: Color(0xFF7DD3FC),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 3. Tunggakan (Bisa diklik untuk filter santri bertunggakan)
              Expanded(
                child: InkWell(
                  onTap: () {
                    AppFeedback.tap();
                    onTunggakanTap();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3F0B18).withOpacity(0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFB7185).withOpacity(0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF43F5E).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '🚨 Tunggakan',
                              style: TextStyle(
                                color: Color(0xFFFECDD3),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF43F5E),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$countTunggakan',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            isHidden ? 'Rp ••••' : CurrencyFormatter.format(totalTunggakan),
                            style: const TextStyle(
                              color: Color(0xFFFDA4AF),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Baris Mini Multi-Dompet: Kas Laci Tunai vs Rekening Bank (PRO)
          _buildMultiDompetStrip(),
        ],
      ),
      ),
    );
  }

  Widget _buildMultiDompetStrip() {
    final laciText = isHidden
        ? 'Rp ••••'
        : (isProUser ? CurrencyFormatter.format(kasLaciTunai) : 'Rp 666.000');
    final bankText = isHidden
        ? 'Rp ••••'
        : (isProUser ? CurrencyFormatter.format(rekeningBank) : 'Rp 1.000.000');

    final innerRow = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF040812).withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isProUser
              ? const Color(0xFF34D399).withOpacity(0.35)
              : const Color(0xFFFBBF24).withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💵 Kas Laci Tunai',
                  style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 8.5, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    laciText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 8), color: Colors.white12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🏦 Rekening Bank',
                  style: TextStyle(color: Color(0xFF7DD3FC), fontSize: 8.5, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    bankText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isProUser) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                AppFeedback.tap();
                onTarikTunaiTap?.call();
              },
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFF34D399)]),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Text(
                  '⇄ Tarik ke Laci',
                  style: TextStyle(
                    color: Color(0xFF030712),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (isProUser) {
      return innerRow;
    }

    return InkWell(
      onTap: () {
        AppFeedback.tap();
        onUpgradeProTap?.call();
      },
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0.26, child: innerRow),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xEE1E170A), Color(0xEE0B1324)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFBBF24), width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🔒 👑 PRO', style: TextStyle(color: Color(0xFFFDE68A), fontSize: 10, fontWeight: FontWeight.w900)),
                SizedBox(width: 6),
                Text('Pisah Kas Laci vs Bank', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
