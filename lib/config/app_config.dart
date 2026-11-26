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

  /// Konfigurasi pembayaran langsung & admin resmi Kas-Santri
  static const String adminDanaNumber = '082130678956';
  static const String adminWhatsappNumber = '6282130678956';
  static const String adminAccountName = 'Moch Khoirul Azman';
  static const String qrisMerchantName = 'mochdigital, Konter';
  static const String qrisNmid = 'ID1026647010796';

  /// Tautan halaman resmi pondok/aplikasi (GitHub Pages resmi Kas-Santri)
  static const String privacyPolicyUrl =
      'https://mochkhoirulazman-max.github.io/kas-santri./privacy.html';
  static const String termsOfServiceUrl =
      'https://mochkhoirulazman-max.github.io/kas-santri./terms.html';
  static const String playStoreSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions';

  static bool get isRevenueCatConfigured =>
      revenueCatAndroidApiKey.trim().isNotEmpty &&
      !revenueCatAndroidApiKey.contains('REPLACE_WITH_YOUR');

  /// Versi aplikasi & konfigurasi Supabase opsional (disuntik via --dart-define saat build).
  /// APK tetap berjalan 100% offline-first bila SUPABASE_URL & SUPABASE_ANON_KEY kosong.
  static const String appVersion = '4.1.0';
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.trim().startsWith('https://') &&
      supabaseAnonKey.trim().length > 20;
}
