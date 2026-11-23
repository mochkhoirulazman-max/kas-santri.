import 'package:flutter/material.dart';
import '../utils/currency_formatter.dart';

class SafeVaultCard extends StatelessWidget {
  final int totalBrankas;
  final int totalKeluarHariIni;
  final int jumlahTransaksi;
  final VoidCallback? onAuditTap;

  const SafeVaultCard({
    Key? key,
    required this.totalBrankas,
    required this.totalKeluarHariIni,
    required this.jumlahTransaksi,
    this.onAuditTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00796B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF004D40).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Label Brankas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'TOTAL UANG TITIPAN (BRANKAS FISIK)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (onAuditTap != null)
                InkWell(
                  onTap: onAuditTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.fact_check_outlined, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Audit',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Nilai Utama Brankas Fisik
          Text(
            CurrencyFormatter.format(totalBrankas),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '⚠️ Total uang tunai di dompet/laci/rekening wajib sama persis dengan angka ini',
            style: TextStyle(color: Colors.white60, fontSize: 10.5),
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 12),

          // Pengeluaran Hari Ini & Jumlah Transaksi
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keluar Hari Ini',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(totalKeluarHariIni),
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: Colors.white.withOpacity(0.2)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transaksi Hari Ini',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$jumlahTransaksi Santri',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
