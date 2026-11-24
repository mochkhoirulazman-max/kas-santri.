import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pengaturan.dart';
import '../models/santri.dart';
import '../utils/app_feedback.dart';
import '../utils/currency_formatter.dart';

class KartuQrSantriDialog extends StatefulWidget {
  final Santri santri;
  final PengaturanAplikasi pengaturan;

  const KartuQrSantriDialog({
    Key? key,
    required this.santri,
    required this.pengaturan,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required Santri santri,
    required PengaturanAplikasi pengaturan,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => KartuQrSantriDialog(
        santri: santri,
        pengaturan: pengaturan,
      ),
    );
  }

  @override
  State<KartuQrSantriDialog> createState() => _KartuQrSantriDialogState();
}

class _KartuQrSantriDialogState extends State<KartuQrSantriDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _captureAndShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    AppFeedback.tap();
    try {
      final bytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (bytes == null) {
        throw Exception('Gagal menangkap gambar kartu QR.');
      }
      final dir = await getTemporaryDirectory();
      final safeName = widget.santri.namaLengkap
          .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
          .toLowerCase();
      final file = File(p.join(dir.path, 'kartu_qr_$safeName.png'));
      await file.writeAsBytes(bytes);

      AppFeedback.success();
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Kartu QR Kas-Santri — ${widget.santri.namaLengkap} (${widget.santri.kamar})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan kartu QR: $e'),
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
    final s = widget.santri;
    final pondok = widget.pengaturan.namaPondok;
    final logoPath = widget.pengaturan.logoPath;
    final hasCustomLogo = logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync();
    final hasFoto = s.fotoPath != null && s.fotoPath!.isNotEmpty && File(s.fotoPath!).existsSync();

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
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF064E3B), Color(0xFF0F172A), Color(0xFF0E7490)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kop Pondok
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFFBBF24), width: 1.4),
                          ),
                          child: ClipOval(
                            child: hasCustomLogo
                                ? Image.file(File(logoPath), fit: BoxFit.cover)
                                : Image.asset(
                                    'logo.jpg',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.mosque_rounded,
                                      color: Color(0xFF064E3B),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pondok.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFDE68A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const Text(
                                'KARTU SAKU DIGITAL SANTRI',
                                style: TextStyle(
                                  color: Color(0xFF6EE7B7),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1B4B).withOpacity(0.75),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.6)),
                          ),
                          child: Text(
                            s.kamar,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 14),

                    // Identitas Santri
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0xFF0F172A),
                            border: Border.all(color: const Color(0xFF34D399), width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: hasFoto
                                ? Image.file(File(s.fotoPath!), fit: BoxFit.cover)
                                : Center(
                                    child: Text(
                                      s.namaLengkap.isNotEmpty
                                          ? s.namaLengkap[0].toUpperCase()
                                          : 'S',
                                      style: const TextStyle(
                                        color: Color(0xFF34D399),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
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
                              Text(
                                s.namaLengkap,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (s.namaPanggilan.isNotEmpty)
                                Text(
                                  'Panggilan: ${s.namaPanggilan}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                'Jatah Harian: ${CurrencyFormatter.format(s.jatahHarian)}',
                                style: const TextStyle(
                                  color: Color(0xFF67E8F9),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // QR Code Container
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: s.qrCode,
                            version: QrVersions.auto,
                            size: 165,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF064E3B),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.qrCode,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    const Text(
                      'Tunjukkan QR Code ini kepada Pengurus Kas saat pengambilan uang saku.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Tombol Aksi
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
                      _isSharing ? 'Memproses...' : 'Simpan / Bagikan PNG',
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
}
