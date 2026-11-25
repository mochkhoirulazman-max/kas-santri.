import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Flag compile-time pembeda jalur distribusi:
/// - `false` (default): Build Direct APK (pembayaran langsung ke DANA 082130678956 + Kode Lisensi PRO)
/// - `true`: Build Google Play Store AAB (Google Play Billing resmi tanpa menu DANA/kode luar)
const bool kIsPlayStoreBuild = bool.fromEnvironment(
  'PLAY_STORE_BUILD',
  defaultValue: false,
);

class TrialStatus {
  final bool hasUsedTrial;
  final bool isActive;
  final bool isExpired;
  final int remainingDays;
  final DateTime? startedAt;
  final DateTime? expiresAt;

  const TrialStatus({
    this.hasUsedTrial = false,
    this.isActive = false,
    this.isExpired = false,
    this.remainingDays = 0,
    this.startedAt,
    this.expiresAt,
  });
}

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

  static const int trialDurationDays = 14;
  static const String _keyTrialStartedAt = 'kas_santri_trial_started_at_v1';
  static const String _keyTrialExpiresAt = 'kas_santri_trial_expires_at_v1';
  static const String _keyHasUsedTrial = 'kas_santri_has_used_trial_v1';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _isConfigured = false;
  bool get isConfigured => _isConfigured;

  static String qrisAssetForPlan(String planKey) {
    switch (planKey.toUpperCase()) {
      case 'MONTHLY':
        return 'assets/qris_dana_25k.jpg';
      case 'LIFETIME':
        return 'assets/qris_dana_399k.jpg';
      case 'YEARLY':
      default:
        return 'assets/qris_dana_179k.jpg';
    }
  }

  static TrialStatus evaluateTrial({
    required bool hasUsedTrial,
    DateTime? startedAt,
    DateTime? expiresAt,
    DateTime? now,
  }) {
    if (!hasUsedTrial || expiresAt == null) {
      return TrialStatus(
        hasUsedTrial: hasUsedTrial,
        isActive: false,
        isExpired: false,
        remainingDays: 0,
        startedAt: startedAt,
        expiresAt: expiresAt,
      );
    }

    final refNow = now ?? DateTime.now();
    if (refNow.isBefore(expiresAt)) {
      final diffSeconds = expiresAt.difference(refNow).inSeconds;
      final days = (diffSeconds / 86400).ceil().clamp(1, trialDurationDays);
      return TrialStatus(
        hasUsedTrial: true,
        isActive: true,
        isExpired: false,
        remainingDays: days,
        startedAt: startedAt,
        expiresAt: expiresAt,
      );
    }

    return TrialStatus(
      hasUsedTrial: true,
      isActive: false,
      isExpired: true,
      remainingDays: 0,
      startedAt: startedAt,
      expiresAt: expiresAt,
    );
  }

  Future<TrialStatus> getTrialStatus({
    bool? fallbackHasUsed,
    String? fallbackStartedAt,
    String? fallbackExpiresAt,
  }) async {
    String? startedRaw;
    String? expiresRaw;
    String? usedRaw;

    try {
      startedRaw = await _secureStorage.read(key: _keyTrialStartedAt);
      expiresRaw = await _secureStorage.read(key: _keyTrialExpiresAt);
      usedRaw = await _secureStorage.read(key: _keyHasUsedTrial);
    } catch (_) {}

    if (usedRaw == null || expiresRaw == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        startedRaw ??= prefs.getString(_keyTrialStartedAt);
        expiresRaw ??= prefs.getString(_keyTrialExpiresAt);
        if (usedRaw == null && prefs.containsKey(_keyHasUsedTrial)) {
          usedRaw = (prefs.getBool(_keyHasUsedTrial) ?? false) ? '1' : '0';
        }
      } catch (_) {}
    }

    final hasUsed = usedRaw == '1' || (fallbackHasUsed ?? false);
    final startedAt = DateTime.tryParse(startedRaw ?? fallbackStartedAt ?? '');
    final expiresAt = DateTime.tryParse(expiresRaw ?? fallbackExpiresAt ?? '');

    if (hasUsed && expiresAt != null) {
      await _persistTrialData(
        startedAt: startedAt ?? expiresAt.subtract(const Duration(days: trialDurationDays)),
        expiresAt: expiresAt,
      );
    }

    return evaluateTrial(
      hasUsedTrial: hasUsed,
      startedAt: startedAt,
      expiresAt: expiresAt,
    );
  }

  Future<void> _persistTrialData({
    required DateTime startedAt,
    required DateTime expiresAt,
  }) async {
    final sStr = startedAt.toIso8601String();
    final eStr = expiresAt.toIso8601String();
    try {
      await _secureStorage.write(key: _keyTrialStartedAt, value: sStr);
      await _secureStorage.write(key: _keyTrialExpiresAt, value: eStr);
      await _secureStorage.write(key: _keyHasUsedTrial, value: '1');
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTrialStartedAt, sStr);
      await prefs.setString(_keyTrialExpiresAt, eStr);
      await prefs.setBool(_keyHasUsedTrial, true);
    } catch (_) {}
  }

  Future<({bool success, TrialStatus status, String message})> startFreeTrial14Days({
    bool? fallbackHasUsed,
    String? fallbackStartedAt,
    String? fallbackExpiresAt,
  }) async {
    final current = await getTrialStatus(
      fallbackHasUsed: fallbackHasUsed,
      fallbackStartedAt: fallbackStartedAt,
      fallbackExpiresAt: fallbackExpiresAt,
    );

    if (current.hasUsedTrial) {
      if (current.isActive) {
        return (
          success: false,
          status: current,
          message: 'Uji coba PRO 14 hari sudah aktif (sisa ${current.remainingDays} hari).',
        );
      }
      return (
        success: false,
        status: current,
        message: 'Uji coba gratis 14 hari sudah pernah digunakan pada perangkat ini.',
      );
    }

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: trialDurationDays));
    await _persistTrialData(startedAt: now, expiresAt: expiresAt);
    final activeStatus = evaluateTrial(
      hasUsedTrial: true,
      startedAt: now,
      expiresAt: expiresAt,
      now: now,
    );

    return (
      success: true,
      status: activeStatus,
      message: 'Uji Coba PRO 14 Hari Aktif! Seluruh fitur premium terbuka penuh.',
    );
  }

  static String planKeyFromProductId(String? productId) {
    if (productId == AppConfig.productIdMonthly) return 'MONTHLY';
    if (productId == AppConfig.productIdLifetime) return 'LIFETIME';
    return 'YEARLY';
  }

  static String planDisplayName(String? planKey) {
    switch (planKey) {
      case 'TRIAL_14D':
        return 'Uji Coba Gratis (14 Hari)';
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
      final dynamic result = await Purchases.purchasePackage(offer.rcPackage!);
      final CustomerInfo customerInfo = result is CustomerInfo
          ? result
          : (result.customerInfo as CustomerInfo);
      final entitlement =
          customerInfo.entitlements.active[AppConfig.entitlementId];
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
