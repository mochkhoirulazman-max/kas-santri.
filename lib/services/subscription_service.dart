import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/app_config.dart';

class SubscriptionPlanOffer {
  final String planKey; // YEARLY, MONTHLY, LIFETIME
  final String productId;
  final String title;
  final String priceString;
  final int fallbackPriceInt;
  final String periodText;
  final String subtitle;
  final String? strikePrice;
  final String? badgeText;
  final bool isPopularBadge;
  final String tagText;
  final Package? rcPackage;

  const SubscriptionPlanOffer({
    required this.planKey,
    required this.productId,
    required this.title,
    required this.priceString,
    required this.fallbackPriceInt,
    required this.periodText,
    required this.subtitle,
    this.strikePrice,
    this.badgeText,
    this.isPopularBadge = true,
    required this.tagText,
    this.rcPackage,
  });

  SubscriptionPlanOffer copyWith({
    String? priceString,
    Package? rcPackage,
  }) {
    return SubscriptionPlanOffer(
      planKey: planKey,
      productId: productId,
      title: title,
      priceString: priceString ?? this.priceString,
      fallbackPriceInt: fallbackPriceInt,
      periodText: periodText,
      subtitle: subtitle,
      strikePrice: strikePrice,
      badgeText: badgeText,
      isPopularBadge: isPopularBadge,
      tagText: tagText,
      rcPackage: rcPackage ?? this.rcPackage,
    );
  }
}

class SubscriptionPurchaseResult {
  final bool success;
  final bool cancelled;
  final String? planKey;
  final String message;

  const SubscriptionPurchaseResult({
    required this.success,
    this.cancelled = false,
    this.planKey,
    required this.message,
  });
}

class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._init();
  SubscriptionService._init();

  bool _isConfigured = false;
  bool get isConfigured => _isConfigured;

  static String planKeyFromProductId(String? productId) {
    if (productId == AppConfig.productIdMonthly) return 'MONTHLY';
    if (productId == AppConfig.productIdLifetime) return 'LIFETIME';
    return 'YEARLY';
  }

  static String planDisplayName(String? planKey) {
    switch (planKey) {
      case 'MONTHLY':
        return 'Pro Bulanan (1 Bulan)';
      case 'LIFETIME':
        return 'Pro Selamanya (Lifetime)';
      case 'YEARLY':
      default:
        return 'Pro Tahun Ajaran (12 Bulan)';
    }
  }

  static List<SubscriptionPlanOffer> defaultFallbackOffers() {
    return const [
      SubscriptionPlanOffer(
        planKey: 'YEARLY',
        productId: AppConfig.productIdYearly,
        title: 'Pro Tahun Ajaran (12 Bulan)',
        priceString: 'Rp 179.000',
        fallbackPriceInt: 179000,
        periodText: '/ tahun',
        subtitle: 'Setara Rp 14.900/bulan',
        strikePrice: 'Rp 300.000',
        badgeText: '🔥 PALING LARIS • HEMAT 40%',
        isPopularBadge: true,
        tagText: 'Prabayar • Bisa QRIS & VA Bank',
      ),
      SubscriptionPlanOffer(
        planKey: 'MONTHLY',
        productId: AppConfig.productIdMonthly,
        title: 'Pro Bulanan (1 Bulan)',
        priceString: 'Rp 25.000',
        fallbackPriceInt: 25000,
        periodText: '/ bulan',
        subtitle: 'Cocok untuk coba dulu 1 bulan',
        tagText: 'Prabayar • Tidak perpanjang otomatis',
      ),
      SubscriptionPlanOffer(
        planKey: 'LIFETIME',
        productId: AppConfig.productIdLifetime,
        title: 'Pro Selamanya (Lifetime)',
        priceString: 'Rp 399.000',
        fallbackPriceInt: 399000,
        periodText: 'sekali bayar',
        subtitle: 'Sekali beli untuk akun pondok',
        badgeText: '👑 SEKALI BAYAR',
        isPopularBadge: false,
        tagText: 'Aktif permanen • Bebas biaya tahunan',
      ),
    ];
  }

  Future<void> init() async {
    if (_isConfigured) return;
    if (!AppConfig.isRevenueCatConfigured) return;
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      await Purchases.configure(
        PurchasesConfiguration(AppConfig.revenueCatAndroidApiKey),
      );
      _isConfigured = true;
    } catch (_) {
      _isConfigured = false;
    }
  }

  /// Mengambil paket dari Play Store via RevenueCat dengan fallback harga default lokal
  Future<List<SubscriptionPlanOffer>> loadOffers() async {
    final baseOffers = defaultFallbackOffers();
    await init();
    if (!_isConfigured) return baseOffers;

    try {
      final offerings = await Purchases.getOfferings();
      final available = offerings.current?.availablePackages ?? const <Package>[];
      if (available.isEmpty) return baseOffers;

      return baseOffers.map((offer) {
        Package? matched;
        for (final pkg in available) {
          if (pkg.storeProduct.identifier == offer.productId) {
            matched = pkg;
            break;
          }
        }
        if (matched == null) return offer;
        return offer.copyWith(
          priceString: matched.storeProduct.priceString,
          rcPackage: matched,
        );
      }).toList();
    } catch (_) {
      return baseOffers;
    }
  }

  Future<({bool isPro, String? planKey})> checkEntitlementStatus() async {
    await init();
    if (!_isConfigured) return (isPro: false, planKey: null);

    try {
      final info = await Purchases.getCustomerInfo();
      final entitlement = info.entitlements.active[AppConfig.entitlementId];
      if (entitlement == null) {
        return (isPro: false, planKey: null);
      }
      return (
        isPro: true,
        planKey: planKeyFromProductId(entitlement.productIdentifier),
      );
    } catch (_) {
      return (isPro: false, planKey: null);
    }
  }

  Future<SubscriptionPurchaseResult> purchasePackage(
    SubscriptionPlanOffer offer,
  ) async {
    await init();
    if (!_isConfigured) {
      return const SubscriptionPurchaseResult(
        success: false,
        message:
            'Google Play Billing belum aktif (API Key RevenueCat belum dikonfigurasi).',
      );
    }
    if (offer.rcPackage == null) {
      return SubscriptionPurchaseResult(
        success: false,
        message:
            'Paket ${offer.productId} belum tersedia di Offering Google Play Console saat ini.',
      );
    }

    try {
      final result = await Purchases.purchase(
        PurchaseParams.package(offer.rcPackage!),
      );
      final entitlement =
          result.customerInfo.entitlements.active[AppConfig.entitlementId];
      if (entitlement != null) {
        return SubscriptionPurchaseResult(
          success: true,
          planKey: planKeyFromProductId(entitlement.productIdentifier),
          message: 'Alhamdulillah! ${offer.title} berhasil diaktifkan.',
        );
      }
      return const SubscriptionPurchaseResult(
        success: false,
        message: 'Pembelian diproses, namun entitlement PRO belum aktif.',
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const SubscriptionPurchaseResult(
          success: false,
          cancelled: true,
          message: 'Pembayaran dibatalkan oleh pengguna.',
        );
      }
      return SubscriptionPurchaseResult(
        success: false,
        message: e.message ?? 'Terjadi kendala saat memproses Google Play Billing.',
      );
    } catch (e) {
      return SubscriptionPurchaseResult(
        success: false,
        message: 'Gagal memulai pembayaran Google Play: $e',
      );
    }
  }

  Future<SubscriptionPurchaseResult> restorePurchases() async {
    await init();
    if (!_isConfigured) {
      return const SubscriptionPurchaseResult(
        success: false,
        message:
            'Sinkronisasi Google Play Billing membutuhkan koneksi internet & API Key RevenueCat aktif.',
      );
    }

    try {
      final info = await Purchases.restorePurchases();
      final entitlement = info.entitlements.active[AppConfig.entitlementId];
      if (entitlement != null) {
        final planKey = planKeyFromProductId(entitlement.productIdentifier);
        return SubscriptionPurchaseResult(
          success: true,
          planKey: planKey,
          message:
              'Alhamdulillah! Langganan ${planDisplayName(planKey)} berhasil dipulihkan.',
        );
      }
      return const SubscriptionPurchaseResult(
        success: false,
        message: 'Belum ditemukan pembelian PRO aktif pada akun Google Play ini.',
      );
    } catch (e) {
      return SubscriptionPurchaseResult(
        success: false,
        message: 'Gagal memulihkan pembelian Google Play: $e',
      );
    }
  }
}
