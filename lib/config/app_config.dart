class AppConfig {
  /// Public Android SDK API Key dari dashboard RevenueCat.
  /// Bisa diisi langsung saat build via:
  /// `--dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxxxxxxx`
  /// atau ganti defaultValue di bawah sebelum rilis produksi.
  static const String revenueCatAndroidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: 'goog_REPLACE_WITH_YOUR_REVENUECAT_PUBLIC_KEY',
  );

  static const String entitlementId = 'kas_santri_pro';

  static const String productIdYearly = 'kas_santri_pro_yearly_prepaid';
  static const String productIdMonthly = 'kas_santri_pro_monthly_prepaid';
  static const String productIdLifetime = 'kas_santri_pro_lifetime';

  static const int maxFreeSantriQuota = 15;

  /// Tautan halaman resmi pondok/aplikasi (wajib diisi URL valid sebelum rilis Play Store)
  static const String privacyPolicyUrl = 'https://kassantri.pondok.id/kebijakan-privasi';
  static const String termsOfServiceUrl = 'https://kassantri.pondok.id/syarat-ketentuan';
  static const String playStoreSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions';

  static bool get isRevenueCatConfigured =>
      revenueCatAndroidApiKey.trim().isNotEmpty &&
      !revenueCatAndroidApiKey.contains('REPLACE_WITH_YOUR');
}
