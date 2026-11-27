import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan status Onboarding awal instal, preferensi tutorial otomatis,
/// dan status Guided Spotlight Tour per layar agar tampil maksimal 1x per menu.
class TutorialService {
  static final TutorialService instance = TutorialService._init();
  TutorialService._init();

  static const String keyHasSeenOnboarding = 'has_seen_onboarding';
  static const String keyHasSeenWalkthrough = 'has_seen_walkthrough';
  static const String keyAutoTourEnabled = 'auto_spotlight_tour_enabled';
  static const String screenTourPrefix = 'seen_tour_';

  /// Daftar lengkap 16 kunci layar untuk Tutorial Sorotan Kontekstual v4.3.
  static const List<String> allScreenTourKeys = <String>[
    'tour_home',
    'tour_setoran',
    'tour_buku_infak',
    'tour_mutasi',
    'tour_rekap',
    'tour_sistem',
    'tour_tabungan',
    'tour_settings',
    'tour_opname',
    'tour_santri_detail',
    'tour_executive',
    'tour_wa_reminder',
    'tour_cetak_qr',
    'tour_import_excel',
    'tour_tahun_ajaran',
    'tour_audit_log',
  ];

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyHasSeenOnboarding) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyHasSeenOnboarding, true);
  }

  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyHasSeenOnboarding, false);
  }

  Future<bool> hasSeenWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyHasSeenWalkthrough) ?? false;
  }

  Future<void> markWalkthroughSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyHasSeenWalkthrough, true);
  }

  Future<void> resetWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyHasSeenWalkthrough, false);
  }

  /// Apakah panduan sorotan otomatis saat pertama kali membuka layar aktif.
  Future<bool> isAutoTourEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyAutoTourEnabled) ?? true;
  }

  Future<void> setAutoTourEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyAutoTourEnabled, enabled);
  }

  /// Cek apakah layar dengan [screenKey] sudah pernah menampilkan tutorial otomatis.
  Future<bool> hasSeenScreenTour(String screenKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$screenTourPrefix$screenKey') ?? false;
  }

  Future<void> markScreenTourSeen(String screenKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$screenTourPrefix$screenKey', true);
    if (screenKey == 'tour_home') {
      await prefs.setBool(keyHasSeenWalkthrough, true);
    }
  }

  /// Menghapus seluruh riwayat tutorial sorotan dan mengaktifkan kembali mode otomatis.
  Future<void> resetAllScreenTours() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyHasSeenWalkthrough, false);
    await prefs.setBool(keyAutoTourEnabled, true);
    for (final key in allScreenTourKeys) {
      await prefs.remove('$screenTourPrefix$key');
    }
  }
}
