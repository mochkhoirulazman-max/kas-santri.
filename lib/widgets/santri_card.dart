import 'package:flutter/material.dart';
import '../models/santri_status.dart';
import '../utils/currency_formatter.dart';
import 'fast_withdrawal_bottom_sheet.dart';

class SantriCard extends StatelessWidget {
  final SantriStatusHariIni status;
  final VoidCallback? onDetailTap;

  const SantriCard({
    Key? key,
    required this.status,
    this.onDetailTap,
  }) : super(key: key);

  Color _getBadgeColor(BadgeStatusHariIni badge) {
    switch (badge) {
      case BadgeStatusHariIni.utuh:
        return const Color(0xFF2E7D32); // 🟢 Hijau
      case BadgeStatusHariIni.sebagian:
        return const Color(0xFF1976D2); // 🔵 Biru
      case BadgeStatusHariIni.limitHabis:
        return const Color(0xFFF57C00); // 🟡 Kuning / Amber
      case BadgeStatusHariIni.overlimitKritis:
        return const Color(0xFFD32F2F); // 🔴 Merah
    }
  }

  String _getBadgeEmoji(BadgeStatusHariIni badge) {
    switch (badge) {
      case BadgeStatusHariIni.utuh:
        return '🟢';
      case BadgeStatusHariIni.sebagian:
        return '🔵';
      case BadgeStatusHariIni.limitHabis:
        return '🟡';
      case BadgeStatusHariIni.overlimitKritis:
        return '🔴';
    }
  }

  @override
  Widget build(BuildContext context) {
    final santri = status.santri;
    final badgeColor = _getBadgeColor(status.badgeStatus);
    final badgeEmoji = _getBadgeEmoji(status.badgeStatus);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          // Tap 1: Buka Bottom Sheet Ambil Cepat
          FastWithdrawalBottomSheet.show(context, status);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris Atas: Nama, Kamar, & Badge Visual Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF00796B).withOpacity(0.12),
                    foregroundColor: const Color(0xFF00796B),
                    child: Text(
                      santri.namaPanggilan.isNotEmpty
                          ? santri.namaPanggilan[0].toUpperCase()
                          : santri.namaLengkap[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                santri.namaLengkap,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (santri.namaPanggilan.isNotEmpty)
                              Text(
                                ' (${santri.namaPanggilan})',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.meeting_room_outlined, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              santri.kamar,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Badge Visual Status Hari Ini
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: badgeColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(badgeEmoji, style: const TextStyle(fontSize: 10)),
                        const SizedBox(width: 4),
                        Text(
                          status.badgeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress Bar Jatah Hari Ini & Indikator Sisa
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ambil Hari Ini: ${CurrencyFormatter.format(status.totalAmbilHariIni)} / ${CurrencyFormatter.format(status.jatahHariIni)}',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                      ),
                      Text(
                        'Sisa: ${CurrencyFormatter.format(status.sisaJatahHariIni)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: status.progressRatio,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 0.7),
              const SizedBox(height: 8),

              // Baris Bawah: Total Sisa Saldo, Estimasi Hari, & Tombol Aksi
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sisa Saldo Total',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                      ),
                      Row(
                        children: [
                          Text(
                            CurrencyFormatter.format(santri.saldoTotal),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: santri.saldoTotal < 10000
                                  ? Colors.red.shade700
                                  : const Color(0xFF004D40),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(±${santri.estimasiHari} hari)',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (onDetailTap != null)
                        IconButton(
                          icon: const Icon(Icons.history, size: 20, color: Colors.teal),
                          tooltip: 'Buku Mutasi & Detail',
                          visualDensity: VisualDensity.compact,
                          onPressed: onDetailTap,
                        ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.flash_on, size: 14),
                        label: const Text('Ambil'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00796B),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          FastWithdrawalBottomSheet.show(context, status);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
