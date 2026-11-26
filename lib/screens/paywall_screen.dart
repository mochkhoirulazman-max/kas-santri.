import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../providers/kas_santri_provider.dart';
import '../services/subscription_service.dart';
import '../utils/app_feedback.dart';
import '../widgets/direct_dana_payment_sheet.dart';
import '../widgets/legal_document_sheet.dart';

class PaywallScreen extends StatefulWidget {
  final String? triggerFeature;

  const PaywallScreen({Key? key, this.triggerFeature}) : super(key: key);

  static Future<void> show(BuildContext context, {String? triggerFeature}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaywallScreen(triggerFeature: triggerFeature),
      ),
    );
  }

  static Future<void> showActiveSubscriptionSheet(BuildContext context) async {
    AppFeedback.tap();
    bool isSyncing = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final provider = Provider.of<KasSantriProvider>(ctx);
          final settings = provider.pengaturan;
          final planLabel = SubscriptionService.planDisplayName(settings.proPlan);
          final bottomInset = MediaQuery.of(ctx).padding.bottom;

          return Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 22),
            decoration: const BoxDecoration(
              color: Color(0xFF0E1422),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Color(0xFF34D399), width: 1.5)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFF064E3B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF34D399), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.35),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('👑', style: TextStyle(fontSize: 34)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Status Langganan Aktif',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.isTrialActive
                        ? 'Trial PRO Aktif • Sisa ${provider.trialRemainingDays} Hari'
                        : 'Kas-Santri PRO Aktif ✓ • ${settings.namaPondok}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6EE7B7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                        _statusRow('Paket Aktif', planLabel, const Color(0xFFFDE68A)),
                        if (provider.isTrialActive) ...[
                          const Divider(color: Colors.white12, height: 18),
                          _statusRow(
                            'Sisa Masa Trial',
                            '${provider.trialRemainingDays} Hari Lagi',
                            const Color(0xFF34D399),
                          ),
                        ],
                        if (!kIsPlayStoreBuild && provider.deviceId.isNotEmpty) ...[
                          const Divider(color: Colors.white12, height: 18),
                          _statusRow('ID Perangkat', provider.deviceId, const Color(0xFF67E8F9)),
                        ] else ...[
                          const Divider(color: Colors.white12, height: 18),
                          _statusRow('Entitlement ID', AppConfig.entitlementId, const Color(0xFF67E8F9)),
                        ],
                        const Divider(color: Colors.white12, height: 18),
                        _statusRow('Santri Aktif', '${provider.activeSantriCount} (Tanpa Batas)', const Color(0xFF34D399)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: isSyncing
                          ? null
                          : () async {
                              AppFeedback.tap();
                              setModalState(() => isSyncing = true);
                              if (!kIsPlayStoreBuild) {
                                await provider.syncSubscriptionEntitlement();
                                if (ctx.mounted) {
                                  setModalState(() => isSyncing = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(provider.proStatusSummaryLabel),
                                      backgroundColor: const Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } else {
                                final res = await SubscriptionService.instance.restorePurchases();
                                if (res.success && ctx.mounted) {
                                  await provider.activatePro(plan: res.planKey ?? 'YEARLY');
                                }
                                if (ctx.mounted) {
                                  setModalState(() => isSyncing = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message),
                                      backgroundColor: res.success
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF06B6D4),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        isSyncing ? 'Menyinkronkan...' : 'Sinkronkan Status Pembelian',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: const Color(0xFF030712),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            AppFeedback.tap();
                            Navigator.pop(ctx);
                            PaywallScreen.show(context);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: const Color(0xFFFBBF24).withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            'Lihat Paket PRO',
                            style: TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      if (kIsPlayStoreBuild) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              AppFeedback.tap();
                              final uri = Uri.parse(AppConfig.playStoreSubscriptionsUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              'Kelola Play Store',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _statusRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String _selectedPlan = 'YEARLY'; // YEARLY, MONTHLY, LIFETIME
  String _selectedPaymentMethod = 'QRIS';
  List<SubscriptionPlanOffer> _offers = SubscriptionService.defaultFallbackOffers();
  bool _isProcessingPurchase = false;

  @override
  void initState() {
    super.initState();
    _loadPlayStoreOffers();
  }

  Future<void> _loadPlayStoreOffers() async {
    final loaded = await SubscriptionService.instance.loadOffers();
    if (mounted) {
      setState(() => _offers = loaded);
    }
  }

  SubscriptionPlanOffer get _selectedOffer {
    for (final offer in _offers) {
      if (offer.planKey == _selectedPlan) return offer;
    }
    return _offers.first;
  }

  String get _selectedDurationLabel {
    switch (_selectedPlan) {
      case 'MONTHLY':
        return '1 bulan';
      case 'LIFETIME':
        return 'Selamanya';
      case 'YEARLY':
      default:
        return '12 bulan';
    }
  }

  void _showFloatingSnackBar(
    String message, {
    Color backgroundColor = const Color(0xFF10B981),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _handleStartTrial() async {
    AppFeedback.tap();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final res = await provider.startFreeTrial14Days();
    if (!mounted) return;

    if (!res.success) {
      _showFloatingSnackBar(res.message, backgroundColor: const Color(0xFFF59E0B));
      return;
    }

    AppFeedback.success();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1422),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF34D399), width: 1.5),
        ),
        title: const Row(
          children: [
            Text('🎉 ', style: TextStyle(fontSize: 24)),
            Expanded(
              child: Text(
                'Uji Coba PRO 14 Hari Aktif!',
                style: TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Alhamdulillah! Seluruh fitur Kas-Santri PRO kini terbuka penuh selama 14 hari ke depan:\n\n'
          '• Santri Tanpa Batas\n'
          '• Multi-Dompet Tunai Laci vs Rekening Bank\n'
          '• Kalkulator Cash Opname Fisik\n'
          '• Scan & Cetak Kartu QR Santri\n'
          '• Ekspor Excel & PDF Berkop Logo\n'
          '• WA 1-Klik, Struk Gambar PNG, Biometrik & Google Drive',
          style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                AppFeedback.tap();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: const Color(0xFF030712),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Mulai Gunakan Kas-Santri PRO',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleRestore() async {
    if (_isProcessingPurchase) return;
    AppFeedback.tap();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);

    if (!kIsPlayStoreBuild) {
      setState(() => _isProcessingPurchase = true);
      try {
        await provider.syncSubscriptionEntitlement();
        if (!mounted) return;
        if (provider.activeLicense != null && provider.activeLicense!.isValid) {
          AppFeedback.success();
          _showFloatingSnackBar(
            'Lisensi Kas-Santri PRO aktif di perangkat ini (${provider.proStatusSummaryLabel})',
          );
          Navigator.pop(context);
          return;
        }
      } finally {
        if (mounted) setState(() => _isProcessingPurchase = false);
      }

      if (!mounted) return;
      final activated = await DirectDanaPaymentSheet.show(
        context,
        offer: _selectedOffer,
        focusActivationInput: true,
      );
      if (activated && mounted) {
        _showFloatingSnackBar('Alhamdulillah! Kas-Santri PRO berhasil diaktifkan.');
        Navigator.pop(context);
      }
      return;
    }

    setState(() => _isProcessingPurchase = true);
    try {
      final res = await SubscriptionService.instance.restorePurchases();
      if (res.success && mounted) {
        await provider.activatePro(plan: res.planKey ?? 'YEARLY');
        AppFeedback.success();
        if (mounted) {
          _showFloatingSnackBar(res.message);
          Navigator.pop(context);
        }
        return;
      }

      if (mounted) {
        if (provider.hasProAccess) {
          _showFloatingSnackBar('Lisensi Kas-Santri PRO sudah aktif di perangkat ini!');
        } else {
          _showFloatingSnackBar(res.message, backgroundColor: const Color(0xFF06B6D4));
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessingPurchase = false);
    }
  }

  Future<void> _handleProceedPayment() async {
    if (_isProcessingPurchase) return;
    AppFeedback.tap();
    final offer = _selectedOffer;
    final provider = Provider.of<KasSantriProvider>(context, listen: false);

    // Jalur 1: Direct APK -> Pembayaran langsung DANA 082130678956 / QRIS + Kode Lisensi PRO
    if (!kIsPlayStoreBuild) {
      final activated = await DirectDanaPaymentSheet.show(
        context,
        offer: offer,
      );
      if (activated && mounted) {
        _showFloatingSnackBar('Alhamdulillah! ${offer.title} berhasil diaktifkan.');
        Navigator.pop(context);
      }
      return;
    }

    // Jalur 2: Google Play Store (.aab) -> RevenueCat & Google Play Billing Resmi
    if (SubscriptionService.instance.isConfigured && offer.rcPackage != null) {
      setState(() => _isProcessingPurchase = true);
      try {
        final res = await SubscriptionService.instance.purchasePackage(offer);
        if (!mounted) return;
        if (res.success) {
          await provider.activatePro(plan: res.planKey ?? offer.planKey);
          AppFeedback.success();
          if (mounted) {
            _showFloatingSnackBar(res.message);
            Navigator.pop(context);
          }
        } else if (!res.cancelled) {
          AppFeedback.alert();
          _showFloatingSnackBar(res.message, backgroundColor: const Color(0xFFE11D48));
        }
      } finally {
        if (mounted) setState(() => _isProcessingPurchase = false);
      }
      return;
    }

    // Fallback UI Play Store Sheet (khusus mode Play Store saat offline/debug)
    _openGooglePlaySheet();
  }

  void _openGooglePlaySheet() {
    AppFeedback.tap();
    final offer = _selectedOffer;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final provider = Provider.of<KasSantriProvider>(context, listen: false);
          final namaPondok = provider.pengaturan.namaPondok;
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF171A21),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
            ),
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).padding.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Color(0xFF34D399), size: 22),
                          SizedBox(width: 6),
                          Text(
                            'Google Play',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white10,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white70, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F242E),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0D14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                          ),
                          alignment: Alignment.center,
                          child: const Text('👑', style: TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offer.title,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$namaPondok • ${offer.productId}',
                                style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Termasuk pajak PPN Indonesia',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              offer.priceString,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              _selectedDurationLabel,
                              style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'PILIH METODE PEMBAYARAN',
                    style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 8),
                  _buildPaymentOption(
                    setModalState,
                    id: 'QRIS',
                    badge: 'QRIS',
                    badgeBg: Colors.white,
                    badgeText: Colors.black,
                    title: 'QRIS (Scan Semua Bank/e-Wallet)',
                    subtitle: 'BSI, BRI, BCA, Mandiri, Dana, GoPay',
                  ),
                  _buildPaymentOption(
                    setModalState,
                    id: 'GOPAY',
                    badge: 'GP',
                    badgeBg: const Color(0xFF00AED6),
                    badgeText: Colors.white,
                    title: 'GoPay',
                    subtitle: 'Instan dari saldo GoPay',
                  ),
                  _buildPaymentOption(
                    setModalState,
                    id: 'DANA',
                    badge: 'DN',
                    badgeBg: const Color(0xFF118EEA),
                    badgeText: Colors.white,
                    title: 'DANA',
                    subtitle: 'Hubungkan akun DANA Anda',
                  ),
                  _buildPaymentOption(
                    setModalState,
                    id: 'SHOPEEPAY',
                    badge: 'SP',
                    badgeBg: const Color(0xFFEE4D2D),
                    badgeText: Colors.white,
                    title: 'ShopeePay',
                    subtitle: 'Bayar cepat via ShopeePay',
                  ),
                  _buildPaymentOption(
                    setModalState,
                    id: 'VA_BCA',
                    badge: 'VA',
                    badgeBg: const Color(0xFF1D4ED8),
                    badgeText: Colors.white,
                    title: 'BCA Virtual Account',
                    subtitle: 'Transfer m-Banking / ATM BCA',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (kDebugMode) {
                          _openQrisConfirmSheet();
                        } else {
                          AppFeedback.alert();
                          _showFloatingSnackBar(
                            'Google Play Billing belum terhubung (periksa koneksi internet & konfigurasi RevenueCat API Key).',
                            backgroundColor: const Color(0xFFF59E0B),
                          );
                        }
                      },
                      child: Text(
                        'Bayar dengan $_selectedPaymentMethod — ${offer.priceString}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentOption(
    void Function(void Function()) setModalState, {
    required String id,
    required String badge,
    required Color badgeBg,
    required Color badgeText,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedPaymentMethod == id;
    return GestureDetector(
      onTap: () {
        AppFeedback.tap();
        setModalState(() => _selectedPaymentMethod = id);
        setState(() => _selectedPaymentMethod = id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF064E3B).withOpacity(0.35) : const Color(0xFF1F242E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.white12,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 26,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                badge,
                style: TextStyle(color: badgeText, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF34D399) : Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _openQrisConfirmSheet() {
    AppFeedback.tap();
    final offer = _selectedOffer;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF171A21),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.play_arrow_rounded, color: Color(0xFF34D399), size: 22),
                      SizedBox(width: 6),
                      Text('Google Play (Debug)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF232018),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Selesaikan pembayaran dalam', style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11.5)),
                    Text(
                      '14:58',
                      style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(6)),
                          child: const Text('QRIS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                        const Text(
                          'QR Code Standar\nPembayaran Nasional',
                          style: TextStyle(color: Color(0xFF334155), fontSize: 9.5, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(6)),
                          child: const Text('GPN', style: TextStyle(color: Color(0xFF065F46), fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'GOOGLE PLAY * KAS-SANTRI',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    const Text(
                      'NMID: ID1026008849102 • A01',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 9.5, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.qr_code_2_rounded, size: 132, color: Color(0xFF0F172A)),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('👑', style: TextStyle(fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL BAYAR', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w800)),
                        Text(
                          offer.priceString,
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Pindai kode QRIS di atas via BSI Mobile, BRI, BCA, Mandiri, GoPay, DANA, atau ShopeePay.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 10.5),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34D399),
                    foregroundColor: const Color(0xFF030712),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () async {
                    final provider = Provider.of<KasSantriProvider>(context, listen: false);
                    await provider.activatePro(plan: _selectedPlan);
                    AppFeedback.success();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Alhamdulillah! ${offer.title} aktif di perangkat ini.'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    '✅ Simulasikan Pembayaran Berhasil (Debug)',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final isPro = provider.hasProAccess;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final selectedOffer = _selectedOffer;

    return Scaffold(
      backgroundColor: const Color(0xFF060A12),
      body: SafeArea(
        child: Stack(
          children: [
            // Obsidian-Gold ambient radial glow
            Positioned(
              top: -80,
              left: -60,
              right: -60,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF59E0B).withOpacity(0.22),
                      const Color(0xFF10B981).withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Column(
              children: [
                // Top Bar: Pulihkan | KAS-SANTRI PRO | Close
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: _handleRestore,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Text(
                            'Pulihkan',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E180B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isPro ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isPro ? 'PRO AKTIF ✓' : 'KAS-SANTRI PRO',
                              style: const TextStyle(
                                color: Color(0xFFFDE68A),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          AppFeedback.tap();
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.close, color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Paywall Body
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      // Hero Crown Obsidian-Gold
                      Center(
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0F1A),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFFBBF24), width: 1.6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withOpacity(0.35),
                                blurRadius: 22,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text('👑', style: TextStyle(fontSize: 38)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                            children: [
                              TextSpan(text: 'Kas-Santri ', style: TextStyle(color: Color(0xFFFDE68A))),
                              TextSpan(text: 'PRO', style: TextStyle(color: Color(0xFF34D399))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Bekerja lebih tenang tanpa selisih kas, rekap otomatis, & laporan resmi yayasan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 14),

                      // Interactive 14-Day Free Trial Action Card
                      _buildTrialActionCard(provider),

                      if (widget.triggerFeature != null && widget.triggerFeature!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1A10),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.45)),
                          ),
                          child: Text(
                            '🔒 Aktifkan Kas-Santri PRO untuk membuka:\n${widget.triggerFeature}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // Pilih Paket Terbaik Pondok
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PILIH PAKET TERBAIK PONDOK',
                            style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                          ),
                          Text(
                            'Mendukung QRIS',
                            style: TextStyle(color: Color(0xFF34D399), fontSize: 10.5, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ..._offers.map((offer) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: offer.planKey == 'MONTHLY' ? 16 : 12),
                          child: _buildPlanCard(
                            planKey: offer.planKey,
                            badgeText: offer.badgeText,
                            isPopularBadge: offer.isPopularBadge,
                            title: offer.title,
                            strikePrice: offer.strikePrice,
                            priceText: offer.priceString,
                            periodText: offer.periodText,
                            subtitle: offer.subtitle,
                            subtitleColor: offer.planKey == 'YEARLY'
                                ? const Color(0xFF34D399)
                                : (offer.planKey == 'LIFETIME' ? const Color(0xFFFBBF24) : Colors.white60),
                            tagText: offer.tagText,
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      // 7 Fitur Unggulan Kas-Santri PRO
                      const Text(
                        '7 FITUR UNGGULAN KAS-SANTRI PRO',
                        style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            _buildFeatureItem('♾️', const Color(0xFF7E22CE), 'Santri Tanpa Batas', 'Lepas batas 15 santri — kelola ratusan hingga ribuan santri satu pondok.'),
                            _buildFeatureItem('🏦', const Color(0xFF0369A1), 'Pisah Kas Tunai Laci vs Rekening Bank', 'Bedakan uang fisik di laci & transfer BSI/BRI lengkap fitur Tarik Tunai ke Laci.'),
                            _buildFeatureItem('🧮', const Color(0xFFB45309), 'Kalkulator Cash Opname Malam Hari', 'Hitung lembaran pecahan Rp 100rb–Rp 500 agar bebas selisih tutup kas.'),
                            _buildFeatureItem('📷', const Color(0xFF4338CA), 'Scan QR Kartu Santri (Antrean 1 Detik)', 'Cetak kartu QR santri & pindai pakai kamera HP saat jam antrean padat.'),
                            _buildFeatureItem('📊', const Color(0xFF047857), 'Ekspor Excel (.xlsx) & PDF Berkop Logo', 'Laporan resmi yayasan lengkap kop logo pondok & kolom TTD Pengasuh.'),
                            _buildFeatureItem('💬', const Color(0xFF0F766E), 'WA 1-Klik, Struk Gambar & Saldo Kritis', 'Kirim langsung ke WA wali bebas watermark + pantau santri saldo < 3 hari.'),
                            _buildFeatureItem('☁️', const Color(0xFF6D28D9), 'Auto-Backup Google Drive & Sidik Jari', 'Data uang titipan aman jika HP rusak/ganti pengurus + kunci biometrik.', isLast: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Tabel Perbandingan Gratis vs PRO
                      const Text(
                        'PERBANDINGAN GRATIS VS PRO',
                        style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0A101D),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(flex: 5, child: Text('FITUR UTAMA', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900))),
                                  Expanded(flex: 2, child: Text('GRATIS', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900))),
                                  Expanded(flex: 3, child: Text('👑 PRO', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.w900))),
                                ],
                              ),
                            ),
                            _buildCompareRow('Kuota Santri', 'Maks 15', 'Tanpa Batas'),
                            _buildCompareRow('Tunai vs Bank & Opname', '—', '✓ Lengkap'),
                            _buildCompareRow('Scan QR Kartu Santri', '—', '✓ Aktif'),
                            _buildCompareRow('Ekspor Excel & PDF Logo', '—', '✓ Resmi'),
                            _buildCompareRow('Laporan WA & Struk', 'Salin Teks', '1-Klik + PNG'),
                            _buildCompareRow('Backup Cloud Drive', 'Lokal JSON', '✓ Auto Drive', isLast: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Card Metode Pembayaran + Kebijakan Privasi & Syarat Ketentuan (Offline Legal Reader)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              kIsPlayStoreBuild
                                  ? 'DIDUKUNG GOOGLE PLAY BILLING INDONESIA'
                                  : 'DIDUKUNG PEMBAYARAN LANGSUNG DANA & QRIS',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildChannelBadge('QRIS', Colors.white, Colors.black),
                                _buildChannelBadge('GoPay', const Color(0xFF0A2A3B), const Color(0xFF38BDF8)),
                                _buildChannelBadge(
                                  kIsPlayStoreBuild ? 'DANA' : 'DANA 082130678956',
                                  const Color(0xFF0B2340),
                                  const Color(0xFF60A5FA),
                                ),
                                _buildChannelBadge('ShopeePay', const Color(0xFF331814), const Color(0xFFFB923C)),
                                _buildChannelBadge('VA Bank', const Color(0xFF0A2E25), const Color(0xFF34D399)),
                                if (kIsPlayStoreBuild)
                                  _buildChannelBadge('Alfamart', const Color(0xFF2B1726), const Color(0xFFF472B6))
                                else
                                  _buildChannelBadge('Kode PRO', const Color(0xFF1E180B), const Color(0xFFFBBF24)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              kIsPlayStoreBuild
                                  ? 'Paket Prabayar tidak akan menagih otomatis. Dengan melanjutkan, Anda menyetujui ketentuan di bawah:'
                                  : 'Pembayaran langsung masuk ke DANA 082130678956 a.n. Moch Khoirul Azman & aktivasi kode lisensi instan. Dengan melanjutkan, Anda menyetujui:',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white54, fontSize: 10, height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              children: [
                                InkWell(
                                  onTap: () => LegalDocumentSheet.showTerms(context),
                                  child: const Text(
                                    'Syarat & Ketentuan',
                                    style: TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const Text('•', style: TextStyle(color: Colors.white30)),
                                InkWell(
                                  onTap: () => LegalDocumentSheet.showPrivacy(context),
                                  child: const Text(
                                    'Kebijakan Privasi',
                                    style: TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Sticky Bottom CTA Bar
                Container(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset > 0 ? 12 : 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF070C16),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: InkWell(
                          onTap: _isProcessingPurchase ? null : _handleProceedPayment,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFBBF24), Color(0xFFFDE047), Color(0xFF6EE7B7)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _isProcessingPurchase
                                  ? 'Memproses Google Play...'
                                  : (isPro
                                      ? '👑 Paket PRO Aktif — Ubah / Perpanjang'
                                      : '👑 Lanjut Bayar — ${selectedOffer.priceString}'),
                              style: const TextStyle(
                                color: Color(0xFF030712),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        kIsPlayStoreBuild
                            ? 'Pembayaran resmi via Google Play Billing • Mendukung $_selectedPaymentMethod'
                            : 'Pembayaran Langsung ke DANA 082130678956 • Aktivasi Instan',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialActionCard(KasSantriProvider provider) {
    final trial = provider.trialStatus;
    if (!trial.hasUsedTrial) {
      return InkWell(
        onTap: _handleStartTrial,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF0E1B2E)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF34D399), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.22),
                blurRadius: 14,
              ),
            ],
          ),
          child: const Row(
            children: [
              Text('🎁', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aktifkan Uji Coba PRO Gratis 14 Hari (Tanpa Bayar Dulu)',
                      style: TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Buka seluruh fitur PRO sekarang • 1x per perangkat',
                      style: TextStyle(color: Colors.white70, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF34D399), size: 15),
            ],
          ),
        ),
      );
    }

    if (provider.isTrialActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF064E3B).withOpacity(0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF34D399).withOpacity(0.7)),
        ),
        child: Row(
          children: [
            const Text('⏳', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trial PRO Aktif • Sisa ${provider.trialRemainingDays} Hari',
                    style: const TextStyle(
                      color: Color(0xFF6EE7B7),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Anda dapat langsung upgrade kapan saja dengan memilih paket di bawah.',
                    style: TextStyle(color: Colors.white70, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: const Row(
        children: [
          Text('⌛', style: TextStyle(fontSize: 16)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Uji coba 14 hari sudah digunakan — pilih paket di bawah untuk lanjut PRO',
              style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String planKey,
    String? badgeText,
    bool isPopularBadge = true,
    required String title,
    String? strikePrice,
    required String priceText,
    required String periodText,
    required String subtitle,
    required Color subtitleColor,
    required String tagText,
  }) {
    final isSelected = _selectedPlan == planKey;
    return GestureDetector(
      onTap: () {
        AppFeedback.tap();
        setState(() => _selectedPlan = planKey);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF17140A) : const Color(0xFF0F172A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected ? const Color(0xFFFBBF24) : Colors.white12,
                width: isSelected ? 1.8 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? const Color(0xFFFBBF24) : Colors.white38,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(color: subtitleColor, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          tagText,
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (strikePrice != null)
                      Text(
                        strikePrice,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                          fontFamily: 'monospace',
                        ),
                      ),
                    Text(
                      priceText,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFFFDE047) : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      periodText,
                      style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (badgeText != null)
            Positioned(
              top: -10,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: isPopularBadge
                      ? const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFF34D399)])
                      : null,
                  color: isPopularBadge ? null : const Color(0xFF1F242E),
                  borderRadius: BorderRadius.circular(12),
                  border: isPopularBadge ? null : Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: isPopularBadge ? const Color(0xFF030712) : const Color(0xFFFDE68A),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String emoji, Color bg, String title, String desc, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: bg.withOpacity(0.5)),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 10.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareRow(String label, String freeText, String proText, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 2,
            child: Text(freeText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              proText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(label, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}
