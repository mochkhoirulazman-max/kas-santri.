import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../providers/kas_santri_provider.dart';
import '../services/license_service.dart';
import '../services/subscription_service.dart';
import '../utils/app_feedback.dart';

class DirectDanaPaymentSheet extends StatefulWidget {
  final SubscriptionPlanOffer offer;
  final bool focusActivationInput;

  const DirectDanaPaymentSheet({
    Key? key,
    required this.offer,
    this.focusActivationInput = false,
  }) : super(key: key);

  static Future<bool> show(
    BuildContext context, {
    required SubscriptionPlanOffer offer,
    bool focusActivationInput = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DirectDanaPaymentSheet(
        offer: offer,
        focusActivationInput: focusActivationInput,
      ),
    );
    return result == true;
  }

  @override
  State<DirectDanaPaymentSheet> createState() => _DirectDanaPaymentSheetState();
}

class _DirectDanaPaymentSheetState extends State<DirectDanaPaymentSheet> {
  final TextEditingController _licenseController = TextEditingController();
  final FocusNode _licenseFocus = FocusNode();

  String _deviceId = 'Memuat...';
  bool _isActivating = false;
  bool _isSharingQris = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
    if (widget.focusActivationInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _licenseFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _licenseFocus.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceId() async {
    final id = await LicenseService.instance.getOrCreateDeviceId();
    if (mounted) {
      setState(() => _deviceId = id);
    }
  }

  void _showSnack(String message, {Color color = const Color(0xFF10B981)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _copyText(String text, String label) async {
    AppFeedback.tap();
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('$label ($text) berhasil disalin!');
  }

  Future<void> _shareQrisImage() async {
    if (_isSharingQris) return;
    AppFeedback.tap();
    setState(() => _isSharingQris = true);
    try {
      final assetPath = SubscriptionService.qrisAssetForPlan(widget.offer.planKey);
      final bytes = await rootBundle.load(assetPath);
      final dir = await getTemporaryDirectory();
      final fileName = 'qris_kas_santri_${widget.offer.planKey.toLowerCase()}.jpg';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'QRIS Pembayaran Kas-Santri PRO — ${widget.offer.title} (${widget.offer.priceString})\nMerchant: ${AppConfig.qrisMerchantName}',
      );
    } catch (e) {
      _showSnack(
        'Gagal membagikan gambar QRIS ($e). Silakan transfer ke DANA ${AppConfig.adminDanaNumber}.',
        color: const Color(0xFFF59E0B),
      );
    } finally {
      if (mounted) setState(() => _isSharingQris = false);
    }
  }

  Future<void> _openWhatsAppAdmin() async {
    AppFeedback.tap();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final namaPondok = provider.pengaturan.namaPondok;
    final idPerangkat = _deviceId;

    final message = '''Assalamu'alaikum Admin Kas-Santri (${AppConfig.adminAccountName}),

Saya ingin mengonfirmasi pembayaran & meminta Kode Aktivasi Kas-Santri PRO:
• Nama Pondok: $namaPondok
• Paket Dipilih: ${widget.offer.title}
• Nominal Transfer: ${widget.offer.priceString}
• Tujuan: DANA / QRIS ${AppConfig.adminDanaNumber}
• ID Perangkat: $idPerangkat

Berikut saya lampirkan bukti transfernya. Terima kasih.''';

    final uri = Uri.parse(
      'https://wa.me/${AppConfig.adminWhatsappNumber}?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: message));
      _showSnack(
        'WhatsApp tidak ditemukan. Pesan konfirmasi telah disalin—kirim ke ${AppConfig.adminDanaNumber}.',
        color: const Color(0xFFF59E0B),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    AppFeedback.tap();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim() ?? '';
    if (raw.isEmpty) {
      _showSnack('Clipboard masih kosong.', color: const Color(0xFFF59E0B));
      return;
    }
    setState(() {
      _licenseController.text = LicenseService.normalizeLicenseCode(raw);
      _inlineError = null;
    });
  }

  Future<void> _activateLicenseCode() async {
    if (_isActivating) return;
    AppFeedback.tap();
    setState(() {
      _isActivating = true;
      _inlineError = null;
    });

    try {
      final provider = Provider.of<KasSantriProvider>(context, listen: false);
      final res = await provider.activateOfflineLicense(_licenseController.text);
      if (!mounted) return;
      if (res.isValid) {
        AppFeedback.success();
        Navigator.pop(context, true);
      } else {
        AppFeedback.alert();
        setState(() => _inlineError = res.message);
      }
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final qrisAsset = SubscriptionService.qrisAssetForPlan(widget.offer.planKey);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.93,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0E1422),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFFFBBF24), width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            viewInsetsBottom + bottomInset + 22,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF118EEA), Color(0xFF0EA5E9)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text('💳', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pembayaran Langsung DANA & QRIS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Aktivasi instan khusus aplikasi Direct APK',
                          style: TextStyle(color: Color(0xFF67E8F9), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      AppFeedback.tap();
                      Navigator.pop(context, false);
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 1. Ringkasan Paket & Nominal Persis
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF17140A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.55)),
                ),
                child: Row(
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.offer.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${widget.offer.subtitle} • ${widget.offer.periodText}',
                            style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.offer.priceString,
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Tujuan Pembayaran DANA Resmi
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF091B30),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF118EEA).withOpacity(0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF118EEA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'DANA RESMI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'a.n. ${AppConfig.adminAccountName}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(
                          child: SelectableText(
                            AppConfig.adminDanaNumber,
                            style: TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _copyText(AppConfig.adminDanaNumber, 'Nomor DANA'),
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text(
                            'Salin Nomor',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF118EEA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '💡 Bisa juga transfer langsung dari Bank (BSI, BRI, BCA, Mandiri, SeaBank) maupun GoPay / OVO / ShopeePay ke nomor DANA di atas.',
                      style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Kartu QRIS DANA Bisnis Asli Sesuai Nominal Paket
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF060B14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ATAU PINDAI QRIS DANA BISNIS',
                                style: TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${AppConfig.qrisMerchantName} • NMID: ${AppConfig.qrisNmid}',
                                style: TextStyle(color: Colors.white60, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isSharingQris ? null : _shareQrisImage,
                          icon: _isSharingQris
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.share_rounded, size: 15),
                          label: const Text(
                            'Simpan / Bagikan',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF34D399),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: Colors.white,
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: Image.asset(
                          qrisAsset,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              children: [
                                const Icon(Icons.qr_code_2_rounded,
                                    size: 56, color: Color(0xFF0F172A)),
                                const SizedBox(height: 6),
                                Text(
                                  'Transfer manual ke DANA ${AppConfig.adminDanaNumber} (${widget.offer.priceString})',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'QRIS otomatis mendukung BSI Mobile, BRI, BCA, Mandiri, GoPay, DANA, OVO & ShopeePay.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. ID Perangkat Unik (KS-XXXX-XXXX)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.perm_device_info_rounded,
                        color: Color(0xFF38BDF8), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ID PERANGKAT PONDOK (Sertakan saat WA Admin)',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            _deviceId,
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyText(_deviceId, 'ID Perangkat'),
                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF38BDF8)),
                      tooltip: 'Salin ID Perangkat',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 5. Tombol Konfirmasi WA 1-Klik
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _openWhatsAppAdmin,
                  icon: const Text('💬', style: TextStyle(fontSize: 16)),
                  label: const Text(
                    'Kirim Bukti & Minta Kode via WhatsApp',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: const Color(0xFF030712),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 6. Input Kode Aktivasi Lisensi PRO Offline
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF060B14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _inlineError != null
                        ? const Color(0xFFF43F5E)
                        : const Color(0xFFFBBF24).withOpacity(0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sudah Punya Kode Aktivasi PRO?',
                      style: TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tempel kode dari WhatsApp Admin (contoh: KSPRO-Y1-20271125-XXXXXXXX) untuk langsung membuka seluruh fitur PRO.',
                      style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _licenseController,
                            focusNode: _licenseFocus,
                            textCapitalization: TextCapitalization.characters,
                            onChanged: (_) {
                              if (_inlineError != null) {
                                setState(() => _inlineError = null);
                              }
                            },
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                            ),
                            decoration: InputDecoration(
                              hintText: 'KSPRO-Y1-YYYYMMDD-XXXXXXXX',
                              hintStyle: const TextStyle(
                                color: Colors.white24,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFFBBF24)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _pasteFromClipboard,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF38BDF8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Tempel',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    if (_inlineError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4C0519).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF43F5E)),
                        ),
                        child: Text(
                          _inlineError!,
                          style: const TextStyle(
                            color: Color(0xFFFECDD3),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _isActivating ? null : _activateLicenseCode,
                        icon: _isActivating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.lock_open_rounded, size: 18),
                        label: Text(
                          _isActivating
                              ? 'Memverifikasi Kode...'
                              : '🔓 Aktifkan Kas-Santri PRO',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFBBF24),
                          foregroundColor: const Color(0xFF030712),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
