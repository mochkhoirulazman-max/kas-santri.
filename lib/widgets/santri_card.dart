import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/santri_status.dart';
import '../providers/theme_wallpaper_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/time_category_helper.dart';
import '../utils/app_feedback.dart';
import 'quick_edit_santri_bottom_sheet.dart';

class SantriCard extends StatelessWidget {
  final SantriStatusHariIni status;
  final bool isTwoCol;
  final VoidCallback onAmbilTap;
  final VoidCallback onTunggakanTap;
  final VoidCallback? onDetailTap;

  const SantriCard({
    Key? key,
    required this.status,
    this.isTwoCol = true,
    required this.onAmbilTap,
    required this.onTunggakanTap,
    this.onDetailTap,
  }) : super(key: key);

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'KS';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  BoxDecoration _getCardDecoration(BadgeStatusHariIni badge, double cardOpacity) {
    List<Color> gradientColors;
    Color borderColor;
    Color shadowColor;
    final darkAlpha = (0.95 * cardOpacity).clamp(0.44, 0.94);

    switch (badge) {
      case BadgeStatusHariIni.utuh:
        gradientColors = [
          const Color(0xFF10B981).withOpacity((0.60 * cardOpacity).clamp(0.22, 0.65)),
          const Color(0xFF06B6D4).withOpacity((0.35 * cardOpacity).clamp(0.14, 0.45)),
          const Color(0xFF0B1322).withOpacity(darkAlpha),
        ];
        borderColor = const Color(0xFF34D399).withOpacity(0.55);
        shadowColor = const Color(0xFF10B981).withOpacity(0.3);
        break;
      case BadgeStatusHariIni.sebagian:
        gradientColors = [
          const Color(0xFF06B6D4).withOpacity((0.60 * cardOpacity).clamp(0.22, 0.65)),
          const Color(0xFF6366F1).withOpacity((0.35 * cardOpacity).clamp(0.14, 0.45)),
          const Color(0xFF0B1322).withOpacity(darkAlpha),
        ];
        borderColor = const Color(0xFF38BDF8).withOpacity(0.6);
        shadowColor = const Color(0xFF06B6D4).withOpacity(0.3);
        break;
      case BadgeStatusHariIni.limitHabis:
        gradientColors = [
          const Color(0xFFF59E0B).withOpacity((0.60 * cardOpacity).clamp(0.22, 0.65)),
          const Color(0xFFEC4899).withOpacity((0.35 * cardOpacity).clamp(0.14, 0.45)),
          const Color(0xFF0B1322).withOpacity(darkAlpha),
        ];
        borderColor = const Color(0xFFFBBF24).withOpacity(0.6);
        shadowColor = const Color(0xFFF59E0B).withOpacity(0.3);
        break;
      case BadgeStatusHariIni.overlimitKritis:
        gradientColors = [
          const Color(0xFFEC4899).withOpacity((0.66 * cardOpacity).clamp(0.24, 0.7)),
          const Color(0xFFA855F7).withOpacity((0.40 * cardOpacity).clamp(0.16, 0.48)),
          const Color(0xFF0B1322).withOpacity(darkAlpha),
        ];
        borderColor = const Color(0xFFFB7185).withOpacity(0.65);
        shadowColor = const Color(0xFFF43F5E).withOpacity(0.35);
        break;
    }

    return BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: RadialGradient(
        center: const Alignment(0.8, -0.8),
        radius: 1.3,
        colors: gradientColors,
        stops: const [0.0, 0.5, 1.0],
      ),
      border: Border.all(color: borderColor, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: shadowColor,
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BadgeStatusHariIni badge, int countAmbil) {
    Color bg;
    Color border;
    Color text;
    String label;

    switch (badge) {
      case BadgeStatusHariIni.utuh:
        bg = const Color(0xFF10B981).withOpacity(0.25);
        border = const Color(0xFF34D399).withOpacity(0.4);
        text = const Color(0xFFA7F3D0);
        label = '🟢 Utuh';
        break;
      case BadgeStatusHariIni.sebagian:
        bg = const Color(0xFF06B6D4).withOpacity(0.25);
        border = const Color(0xFF38BDF8).withOpacity(0.4);
        text = const Color(0xFFBAE6FD);
        label = '${countAmbil}x Ambil';
        break;
      case BadgeStatusHariIni.limitHabis:
        bg = const Color(0xFFF59E0B).withOpacity(0.25);
        border = const Color(0xFFFBBF24).withOpacity(0.4);
        text = const Color(0xFFFDE68A);
        label = '🟡 Habis';
        break;
      case BadgeStatusHariIni.overlimitKritis:
        bg = const Color(0xFFF43F5E).withOpacity(0.3);
        border = const Color(0xFFFB7185).withOpacity(0.5);
        text = const Color(0xFFFECDD3);
        label = '🔴 Over';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildStatusKeaktifanPill(Santri santri) {
    final isPulang = santri.isPulang;
    final bg = isPulang
        ? const Color(0xFF34D399).withOpacity(0.22)
        : const Color(0xFF94A3B8).withOpacity(0.22);
    final border = isPulang
        ? const Color(0xFF6EE7B7).withOpacity(0.55)
        : const Color(0xFFCBD5E1).withOpacity(0.45);
    final textColor =
        isPulang ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        isPulang ? '🏡 Pulang' : '📦 Pindah',
        style: TextStyle(
          color: textColor,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardOpacity = Provider.of<ThemeWallpaperProvider>(context).cardOpacity;
    final santri = status.santri;
    final initials = _getInitials(santri.namaLengkap);
    final sisaJatah = status.sisaJatahHariIni;
    final remainingRatio = status.remainingRatio;
    final badge = status.badgeStatus;
    final txList = status.transaksiHariIni;

    if (!isTwoCol) {
      // 1-Column List Mode
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: _getCardDecoration(badge, cardOpacity),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              AppFeedback.tap();
              if (onDetailTap != null) {
                onDetailTap!();
              } else {
                onAmbilTap();
              }
            },
            borderRadius: BorderRadius.circular(26),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      AppFeedback.tap();
                      QuickEditSantriBottomSheet.show(context, santri);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF34D399), Color(0xFF38BDF8)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: santri.fotoPath != null && santri.fotoPath!.trim().isNotEmpty
                            ? Image(
                                image: ResizeImage(
                                  FileImage(File(santri.fotoPath!)),
                                  width: 180,
                                ),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Color(0xFF04121A),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Color(0xFF04121A),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                      ),
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
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (santri.kamar.trim().isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  santri.kamar.trim(),
                                  style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                            if (santri.isPulang || santri.isPindah) ...[
                              const SizedBox(width: 6),
                              _buildStatusKeaktifanPill(santri),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Sisa: ${CurrencyFormatter.format(sisaJatah < 0 ? 0 : sisaJatah)} • Saldo: ${CurrencyFormatter.format(santri.saldoTotal)}',
                          style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11),
                        ),
                        if (santri.tunggakan > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: InkWell(
                              onTap: () {
                                AppFeedback.tap();
                                onTunggakanTap();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF43F5E).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFB7185).withOpacity(0.4)),
                                ),
                                child: Text(
                                  '🚨 Tunggakan: ${CurrencyFormatter.format(santri.tunggakan)}',
                                  style: const TextStyle(color: Color(0xFFFDA4AF), fontSize: 9.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      AppFeedback.tap();
                      onAmbilTap();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('⚡ Ambil', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 2-Column Grid Mode (Tactile Button Card Aurora Style)
    return Container(
      decoration: _getCardDecoration(badge, cardOpacity),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AppFeedback.tap();
            if (onDetailTap != null) {
              onDetailTap!();
            } else {
              onAmbilTap();
            }
          },
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. Baris Atas: Avatar, Kamar & Status Badge + Ikon Pensil Edit (rapi di dalam padding)
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              AppFeedback.tap();
                              QuickEditSantriBottomSheet.show(context, santri);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0x55FFFFFF), Color(0x15FFFFFF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: santri.fotoPath != null && santri.fotoPath!.trim().isNotEmpty
                                    ? Image(
                                        image: ResizeImage(
                                          FileImage(File(santri.fotoPath!)),
                                          width: 180,
                                        ),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            initials,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          if (santri.kamar.trim().isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  santri.kamar.trim(),
                                  style: const TextStyle(
                                    color: Color(0xFFE2E8F0),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusBadge(badge, status.jumlahAmbilHariIni),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            AppFeedback.tap();
                            QuickEditSantriBottomSheet.show(context, santri);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              size: 11,
                              color: Color(0xFF7DD3FC),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 2. Nama Santri (+ Badge Pulang / Pindah lembut pengganti stabilo manual)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        santri.namaLengkap,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (santri.isPulang || santri.isPindah) ...[
                      const SizedBox(width: 4),
                      _buildStatusKeaktifanPill(santri),
                    ],
                  ],
                ),

                const SizedBox(height: 6),

                // 3. Box Sisa Hari Ini
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF040814).withOpacity(0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'SISA HARI INI',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Text(
                            'dr ${santri.jatahHarian ~/ 1000}rb',
                            style: const TextStyle(
                              color: Color(0xFF67E8F9),
                              fontSize: 8,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(sisaJatah < 0 ? 0 : sisaJatah),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 4,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: remainingRatio, end: remainingRatio),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, _) {
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: val,
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
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // 4. Jejak Pengambilan Pagi/Siang/Sore/Malam
                SizedBox(
                  height: 18,
                  child: txList.isNotEmpty
                      ? ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: txList.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 4),
                          itemBuilder: (ctx, idx) {
                            final tx = txList[idx];
                            final icon = tx.kategoriWaktu == TimeCategory.pagi
                                ? '🌅'
                                : tx.kategoriWaktu == TimeCategory.siang
                                    ? '☀️'
                                    : tx.kategoriWaktu == TimeCategory.sore
                                        ? '🌤️'
                                        : '🌙';
                            final nom = (tx.nominal ~/ 1000).toString();
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Text(
                                '$icon${nom}rb',
                                style: const TextStyle(
                                  color: Color(0xFFBAE6FD),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        )
                      : const Text(
                          '✨ Kuota masih penuh',
                          style: TextStyle(
                            color: Color(0xFFA7F3D0),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

                const SizedBox(height: 6),

                // 5. Total Saldo & Status Tunggakan
                Container(
                  padding: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.12))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Saldo:',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5),
                          ),
                          Text(
                            CurrencyFormatter.format(santri.saldoTotal),
                            style: const TextStyle(
                              color: Color(0xFF6EE7B7),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          AppFeedback.tap();
                          onTunggakanTap();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: santri.tunggakan > 0
                                ? const Color(0xFFF43F5E).withOpacity(0.25)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: santri.tunggakan > 0
                                  ? const Color(0xFFFB7185).withOpacity(0.5)
                                  : Colors.white12,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                santri.tunggakan > 0 ? '🚨 Tunggakan' : '✅ Tunggakan',
                                style: TextStyle(
                                  color: santri.tunggakan > 0
                                      ? const Color(0xFFFECDD3)
                                      : const Color(0xFFCBD5E1),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                santri.tunggakan > 0
                                    ? CurrencyFormatter.format(santri.tunggakan)
                                    : 'Rp 0',
                                style: TextStyle(
                                  color: santri.tunggakan > 0
                                      ? const Color(0xFFFDA4AF)
                                      : Colors.white70,
                                  fontSize: 8.5,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 6. Tombol Aksi Bawah: "⚡ Ambil Uang" & "🚨" (Kelola Tunggakan)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () {
                          AppFeedback.tap();
                          onAmbilTap();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF34D399),
                                Color(0xFF2DD4BF),
                                Color(0xFF38BDF8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '⚡ Ambil Uang',
                                style: TextStyle(
                                  color: Color(0xFF030712),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    InkWell(
                      onTap: () {
                        AppFeedback.tap();
                        onTunggakanTap();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 32,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF040814).withOpacity(0.75),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        alignment: Alignment.center,
                        child: const Text('🚨', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
