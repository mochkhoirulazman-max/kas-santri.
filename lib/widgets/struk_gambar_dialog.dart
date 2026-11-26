import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pengaturan.dart';
import '../models/santri_status.dart';
import '../providers/kas_santri_provider.dart';
import '../screens/paywall_screen.dart';
import '../utils/app_feedback.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../utils/time_category_helper.dart';

class StrukGambarDialog extends StatefulWidget {
  final SantriStatusHariIni status;
  final PengaturanAplikasi pengaturan;

  const StrukGambarDialog({
    Key? key,
    required this.status,
    required this.pengaturan,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required SantriStatusHariIni status,
    required PengaturanAplikasi pengaturan,
  }) async {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    if (!provider.hasProAccess) {
      AppFeedback.alert();
      await PaywallScreen.show(
        context,
        triggerFeature: 'Bagikan Struk Gambar PNG Resmi Tanpa Watermark',
      );
      return;
    }
    await showDialog(
      context: context,
      builder: (_) => StrukGambarDialog(
        status: status,
        pengaturan: pengaturan,
      ),
    );
  }

  @override
  State<StrukGambarDialog> createState() => _StrukGambarDialogState();
}

class _StrukGambarDialogState extends State<StrukGambarDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _captureAndShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    AppFeedback.tap();
    try {
      final bytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (bytes == null) {
        throw Exception('Gagal merender gambar struk.');
      }
      final dir = await getTemporaryDirectory();
      final safeName = widget.status.santri.namaLengkap
          .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
          .toLowerCase();
      final file = File(p.join(dir.path, 'struk_kas_$safeName.png'));
      await file.writeAsBytes(bytes);

      AppFeedback.success();
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Struk Mutasi Kas Santri — ${widget.status.santri.namaLengkap} (${widget.pengaturan.namaPondok})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan struk: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status.santri;
    final txList = widget.status.transaksiHariIni;
    final pondok = widget.pengaturan.namaPondok;
    final logoPath = widget.pengaturan.logoPath;
    final hasCustomLogo = logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync();
    final todayStr = DateFormatter.formatDisplayDate(DateTime.now());

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
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF10B981), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kop Struk Resmi Pondok
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF059669), width: 1.5),
                          ),
                          child: ClipOval(
                            child: hasCustomLogo
                                ? Image.file(File(logoPath), fit: BoxFit.cover)
                                : Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF065F46), Color(0xFF0E7490)],
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.mosque_rounded,
                                      color: Color(0xFFFDE68A),
                                      size: 24,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pondok.toUpperCase(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF064E3B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                'STRUK LAPORAN UANG SAKU SANTRI',
                                style: TextStyle(
                                  color: Color(0xFF0F766E),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              Text(
                                todayStr,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFCBD5E1), thickness: 1.2),
                    const SizedBox(height: 10),

                    // Identitas Santri
                    _rowItem('Nama Santri', s.namaLengkap, boldValue: true),
                    _rowItem('Kamar / Kelas', s.kamar),
                    _rowItem('Jatah Harian', '${CurrencyFormatter.format(s.jatahHarian)} / hari'),

                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Column(
                        children: [
                          _rowItem(
                            'Sisa Saldo Titipan',
                            CurrencyFormatter.format(s.saldoTotal),
                            boldValue: true,
                            valueColor: const Color(0xFF065F46),
                          ),
                          _rowItem(
                            'Estimasi Ketahanan',
                            '± ${s.estimasiHari} hari',
                            valueColor: const Color(0xFF0F766E),
                          ),
                          _rowItem(
                            'Diambil Hari Ini',
                            CurrencyFormatter.format(widget.status.totalAmbilHariIni),
                          ),
                          _rowItem(
                            'Status Tunggakan',
                            s.tunggakan > 0
                                ? CurrencyFormatter.format(s.tunggakan)
                                : 'Bebas Tunggakan ✓',
                            boldValue: s.tunggakan > 0,
                            valueColor: s.tunggakan > 0
                                ? const Color(0xFFBE123C)
                                : const Color(0xFF059669),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      'RINCIAN PENGAMBILAN HARI INI',
                      style: TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (txList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Belum ada pengambilan uang saku hari ini.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ...txList.map((tx) {
                        final jam =
                            '${tx.waktuAmbil.hour.toString().padLeft(2, '0')}:${tx.waktuAmbil.minute.toString().padLeft(2, '0')}';
                        final kat = TimeCategoryHelper.getDbString(tx.kategoriWaktu);
                        final ket = (tx.catatan != null && tx.catatan!.isNotEmpty)
                            ? tx.catatan!
                            : 'Jajan Harian';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$kat ($jam) • $ket',
                                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(tx.nominal),
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFCBD5E1), thickness: 1),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pengurus: ${widget.pengaturan.namaPengurus}',
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'SAH • TANPA WATERMARK',
                          style: TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      AppFeedback.tap();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSharing ? null : _captureAndShare,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.share_rounded, size: 18),
                    label: Text(
                      _isSharing ? 'Memproses...' : 'Bagikan Struk PNG',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: const Color(0xFF030712),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _rowItem(
    String label,
    String value, {
    bool boldValue = false,
    Color valueColor = const Color(0xFF0F172A),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF475569), fontSize: 11),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor,
                fontSize: 11.5,
                fontWeight: boldValue ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
