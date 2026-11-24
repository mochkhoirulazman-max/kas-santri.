import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../utils/app_feedback.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({Key? key}) : super(key: key);

  static Future<String?> scan(BuildContext context) async {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const QrScannerScreen(),
      ),
    );
  }

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _hasScanned = false;
  bool _torchEnabled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _hasScanned = true;
        AppFeedback.tap();
        Navigator.of(context).pop(raw.trim());
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: SafeArea(
        child: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),

            // Overlay bingkai scan
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF34D399),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.35),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),

            // Header bar
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Material(
                    color: const Color(0xFF0F172A).withOpacity(0.85),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        AppFeedback.tap();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Text('📷', style: TextStyle(fontSize: 15)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Scan QR Kartu Santri',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: _torchEnabled
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF0F172A).withOpacity(0.85),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: Icon(
                        _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _torchEnabled ? const Color(0xFF030712) : Colors.white,
                      ),
                      onPressed: () async {
                        AppFeedback.tap();
                        await _controller.toggleTorch();
                        if (mounted) {
                          setState(() => _torchEnabled = !_torchEnabled);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: const Color(0xFF0F172A).withOpacity(0.85),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
                      onPressed: () async {
                        AppFeedback.tap();
                        await _controller.switchCamera();
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Footer hint
            Positioned(
              left: 20,
              right: 20,
              bottom: 28,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '⚡ MODE ANTREAN KILAT (< 1 DETIK)',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Arahkan kamera ke QR Code pada kartu santri. Modal Ambil Uang akan otomatis terbuka.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
