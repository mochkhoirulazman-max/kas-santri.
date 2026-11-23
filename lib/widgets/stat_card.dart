import 'package:flutter/material.dart';
import '../utils/currency_formatter.dart';

class SafeVaultCard extends StatelessWidget {
  final int totalBrankas;
  final int totalKeluarHariIni;
  final int totalKuotaHariIni;
  final int totalTunggakan;
  final int countTunggakan;
  final int jumlahSantri;
  final bool isHidden;
  final VoidCallback onToggleHide;
  final VoidCallback onTunggakanTap;

  const SafeVaultCard({
    Key? key,
    required this.totalBrankas,
    required this.totalKeluarHariIni,
    required this.totalKuotaHariIni,
    required this.totalTunggakan,
    required this.countTunggakan,
    required this.jumlahSantri,
    required this.isHidden,
    required this.onToggleHide,
    required this.onTunggakanTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Serapan Jatah Harian Pondok (%)
    final pct = totalKuotaHariIni > 0
        ? ((totalKeluarHariIni / totalKuotaHariIni) * 100).clamp(0, 100).toInt()
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const RadialGradient(
          center: Alignment(-0.8, -0.8),
          radius: 1.4,
          colors: [
            Color(0x8C10B981), // Emerald glow
            Color(0x6606B6D4), // Cyan glow
            Color(0x40D946EF), // Fuchsia glow
            Color(0xF0081224), // Dark deep base
          ],
          stops: [0.0, 0.45, 0.75, 1.0],
        ),
        border: Border.all(
          color: const Color(0xFF38BDF8).withOpacity(0.48),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFFD946EF).withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 8),
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
                    onTap: onToggleHide,
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

          // Total Uang Fisik Besar
          Text(
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

          const SizedBox(height: 12),

          // Bar Serapan Kuota Harian Pondok
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
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (pct / 100).clamp(0.0, 1.0),
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
                      Text(
                        isHidden ? 'Rp ••••' : CurrencyFormatter.format(totalKeluarHariIni),
                        style: const TextStyle(
                          color: Color(0xFFFCD34D),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                      Text(
                        isHidden ? 'Rp ••••' : CurrencyFormatter.format(totalKuotaHariIni),
                        style: const TextStyle(
                          color: Color(0xFF7DD3FC),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 3. Tunggakan (Bisa diklik untuk filter santri bertunggakan)
              Expanded(
                child: InkWell(
                  onTap: onTunggakanTap,
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
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
                        Text(
                          isHidden ? 'Rp ••••' : CurrencyFormatter.format(totalTunggakan),
                          style: const TextStyle(
                            color: Color(0xFFFDA4AF),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
