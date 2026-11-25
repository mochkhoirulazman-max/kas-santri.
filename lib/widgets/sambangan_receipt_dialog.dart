import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/infak_santri.dart';
import '../models/santri.dart';
import '../providers/kas_santri_provider.dart';
import '../screens/paywall_screen.dart';
import '../services/report_service.dart';
import '../utils/app_feedback.dart';
import '../utils/currency_formatter.dart';

class SambanganReceiptDialog extends StatefulWidget {
  final Santri santri;
  final InfakSantriModel infak;
  final int totalDiterima;
  final int sisaJajan;
  final int jatahBaru;
  final int nominalPotongTunggakan;

  const SambanganReceiptDialog({
    Key? key,
    required this.santri,
    required this.infak,
    required this.totalDiterima,
    required this.sisaJajan,
    required this.jatahBaru,
    this.nominalPotongTunggakan = 0,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required Santri santri,
    required InfakSantriModel infak,
    required int totalDiterima,
    required int sisaJajan,
    required int jatahBaru,
    int nominalPotongTunggakan = 0,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => SambanganReceiptDialog(
        santri: santri,
        infak: infak,
        totalDiterima: totalDiterima,
        sisaJajan: sisaJajan,
        jatahBaru: jatahBaru,
        nominalPotongTunggakan: nominalPotongTunggakan,
      ),
    );
  }

  @override
  State<SambanganReceiptDialog> createState() => _SambanganReceiptDialogState();
}

class _SambanganReceiptDialogState extends State<SambanganReceiptDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  String _berasSummary() {
    if (widget.infak.jenisBeras == InfakSantriModel.berasBebas) {
      return '✓ Bebas Beras';
    }
    if (widget.infak.jenisBeras == InfakSantriModel.berasFisik) {
      final l = widget.infak.berasLiter;
      final str = l == l.roundToDouble() ? l.toInt().toString() : l.toString();
      return '🌾 Fisik $str Liter';
    }
    if (widget.infak.jenisBeras == InfakSantriModel.berasUang) {
      return CurrencyFormatter.format(widget.infak.berasUang);
    }
    return '⏳ Belum Setor';
  }

  Future<void> _copyWaText(KasSantriProvider provider) async {
    AppFeedback.tap();
    final text = ReportService.instance.generateSambanganReceiptText(
      santri: widget.santri,
      infak: widget.infak,
      pengaturan: provider.pengaturan,
      totalDiterima: widget.totalDiterima,
      sisaJajan: widget.sisaJajan,
      jatahBaru: widget.jatahBaru,
      nominalPotongTunggakan: widget.nominalPotongTunggakan,
      isProUser: provider.isProUser,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teks struk pembagian Sambangan disalin ke Clipboard!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendWaOneClick(KasSantriProvider provider) async {
    AppFeedback.tap();
    if (!provider.isProUser) {
      await PaywallScreen.show(
        context,
        triggerFeature: 'Kirim Struk Sambangan 1-Klik ke WA Wali',
      );
      return;
    }

    final text = ReportService.instance.generateSambanganReceiptText(
      santri: widget.santri,
      infak: widget.infak,
      pengaturan: provider.pengaturan,
      totalDiterima: widget.totalDiterima,
      sisaJajan: widget.sisaJajan,
      jatahBaru: widget.jatahBaru,
      nominalPotongTunggakan: widget.nominalPotongTunggakan,
      isProUser: true,
    );

    final launched = await ReportService.instance.openWhatsAppDirect(
      rawPhone: widget.santri.noWaWali,
      message: text,
    );
    if (!launched && mounted) {
      await Share.share(text, subject: 'Struk Sambangan - ${widget.santri.namaLengkap}');
    }
  }

  Future<void> _sharePng(KasSantriProvider provider) async {
    AppFeedback.tap();
    if (!provider.isProUser) {
      await PaywallScreen.show(
        context,
        triggerFeature: 'Bagikan Struk Gambar PNG Bebas Watermark',
      );
      return;
    }
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final bytes = await _screenshotController.capture(pixelRatio: 2.5);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/struk_sambangan_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Struk Setoran Sambangan — ${widget.santri.namaLengkap}',
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final isPro = provider.isProUser;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Screenshot(
              controller: _screenshotController,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A1424), Color(0xFF071B1E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF34D399).withOpacity(0.65),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF34D399)),
                          ),
                          alignment: Alignment.center,
                          child: const Text('🎁', style: TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.pengaturan.namaPondok.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Struk Pembagian Sambangan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF34D399)),
                          ),
                          child: Text(
                            widget.infak.statusLunas,
                            style: const TextStyle(
                              color: Color(0xFF6EE7B7),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 20),
                    _row('Santri', '${widget.santri.namaLengkap} (${widget.santri.kategoriLabel})'),
                    _row('Total Diterima', CurrencyFormatter.format(widget.totalDiterima), isBold: true, color: const Color(0xFFFDE68A)),
                    _row('Sumber Dompet', widget.infak.sumberDompet),
                    const Divider(color: Colors.white12, height: 16),
                    _row(
                      'Infak Masak',
                      widget.infak.isMasakBebas
                          ? '✓ Bebas'
                          : CurrencyFormatter.format(widget.infak.nominalMasak),
                    ),
                    _row(
                      'Infak Listrik',
                      widget.infak.isListrikBebas
                          ? '✓ Bebas'
                          : CurrencyFormatter.format(widget.infak.nominalListrik),
                    ),
                    _row('Infak Beras', _berasSummary()),
                    _row('Masa Berlaku', '${widget.infak.tglMasuk} s.d. ${widget.infak.tglHabis}'),
                    if (widget.nominalPotongTunggakan > 0)
                      _row(
                        'Potong Tunggakan',
                        CurrencyFormatter.format(widget.nominalPotongTunggakan),
                        color: const Color(0xFFFB7185),
                      ),
                    const Divider(color: Colors.white12, height: 16),
                    _row(
                      'Masuk Saldo Jajan',
                      CurrencyFormatter.format(widget.sisaJajan),
                      isBold: true,
                      color: const Color(0xFF34D399),
                    ),
                    _row(
                      'Jatah Harian Baru',
                      '${CurrencyFormatter.format(widget.jatahBaru)} / hari',
                      color: const Color(0xFF67E8F9),
                    ),
                    if (!isPro) ...[
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Dicatat dengan Kas-Santri',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1422),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _copyWaText(provider),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text(
                        '📋 Salin Teks Struk WA (Gratis)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: const Color(0xFF67E8F9),
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _sendWaOneClick(provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: const Color(0xFF030712),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            isPro ? '💬 Kirim WA 1-Klik' : '💬 WA 1-Klik 👑',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSharing ? null : () => _sharePng(provider),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFDE68A),
                            side: const BorderSide(color: Color(0xFFFBBF24)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            isPro ? '🖼️ Struk PNG' : '🖼️ PNG 👑',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      AppFeedback.tap();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Selesai & Tutup',
                      style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false, Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: isBold ? 13 : 11.5,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
