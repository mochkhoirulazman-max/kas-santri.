import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bendahara_account.dart';
import '../models/setoran.dart';
import '../models/transaksi.dart';
import '../models/transaksi_tabungan.dart';
import '../models/pengaturan.dart';
import '../models/santri_status.dart';
import '../models/cash_opname_log.dart';
import '../models/infak_santri.dart';
import '../models/serah_terima_infak.dart';
import '../database/database_helper.dart';
import '../config/app_config.dart';
import '../services/account_auth_service.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/customer_sync_service.dart';
import '../services/google_drive_backup_service.dart';
import '../services/license_service.dart';
import '../services/security_guard_service.dart';
import '../services/subscription_service.dart';
import 'package:uuid/uuid.dart';
import '../utils/date_formatter.dart';
import '../utils/time_category_helper.dart';

class UndoState {
  final TransaksiHarian transaction;
  final Santri santri;
  final int countdown;

  const UndoState({
    required this.transaction,
    required this.santri,
    required this.countdown,
  });
}

class KasSantriProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<Santri> _allSantri = [];
  List<Santri> get allSantri => _allSantri;

  List<SantriStatusHariIni> _santriStatusList = [];
  List<SantriStatusHariIni> get santriStatusList => _santriStatusList;

  List<String> _kamars = [];
  List<String> get kamars => _kamars;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String? _selectedKamar;
  String? get selectedKamar => _selectedKamar;

  String _activeFilter = 'ALL'; // ALL, TUNGGAKAN, UTUH, SEBAGIAN, HABIS
  String get activeFilter => _activeFilter;

  PengaturanAplikasi _pengaturan = PengaturanAplikasi();
  PengaturanAplikasi get pengaturan => _pengaturan;

  BendaharaAccount? _activeAccount;
  BendaharaAccount? get activeAccount => _activeAccount;

  String get activeOperatorName =>
      _activeAccount?.namaLengkap ?? _pengaturan.namaPengurus;

  String get activeOperatorRole =>
      _activeAccount?.jabatan ?? 'Bendahara Pondok';

  /// Helper state global untuk status PRO (dipakai seluruh fitur berlabel 👑)
  bool _isClockTampered = false;
  bool get isClockTampered => _isClockTampered;

  String? _clockTamperMessage;
  String? get clockTamperMessage => _clockTamperMessage;

  bool _isScreenPrivacyEnabled = false;
  bool get isScreenPrivacyEnabled => _isScreenPrivacyEnabled;

  AppIntegrityReport? _integrityReport;
  AppIntegrityReport? get integrityReport => _integrityReport;

  bool _isLicenseRevoked = false;
  bool get isLicenseRevoked => _isLicenseRevoked;

  AppRemoteConfig? _remoteConfig;
  AppRemoteConfig? get remoteConfig => _remoteConfig;

  bool _remoteBannerDismissed = false;
  bool get shouldShowRemoteUpdateBanner =>
      !_remoteBannerDismissed && (_remoteConfig?.hasBannerContent ?? false);

  void dismissRemoteBanner() {
    _remoteBannerDismissed = true;
    notifyListeners();
  }

  final ValueNotifier<int> spotlightTourRequestNotifier = ValueNotifier<int>(0);

  void triggerSpotlightTour() {
    spotlightTourRequestNotifier.value++;
  }

  TrialStatus _trialStatus = const TrialStatus();
  TrialStatus get trialStatus => _trialStatus;

  bool get isProActive =>
      !_isClockTampered &&
      !_isLicenseRevoked &&
      _pengaturan.isPro &&
      _pengaturan.proPlan != 'TRIAL_14D';

  bool get isTrialActive =>
      !_isClockTampered &&
      !_isLicenseRevoked &&
      _trialStatus.isActive &&
      (_pengaturan.proPlan == 'TRIAL_14D' || !_pengaturan.isPro);

  /// Gerbang terpusat akses fitur PRO (aktif jika paket PRO aktif ATAU Uji Coba 14 Hari aktif).
  bool get hasProAccess {
    SubscriptionService.instance.updateAccessState(
      isProActive: isProActive,
      isTrialActive: isTrialActive,
    );
    return SubscriptionService.instance.hasProAccess;
  }

  bool get isProUser => hasProAccess;

  int get trialRemainingDays => _trialStatus.remainingDays;

  LicenseVerificationResult? _activeLicense;
  LicenseVerificationResult? get activeLicense => _activeLicense;

  String _deviceId = '';
  String get deviceId => _deviceId;

  String get proStatusSummaryLabel {
    if (!isProUser) {
      return 'Mode Gratis (Maks $maxFreeSantriQuota Santri)';
    }
    if (isTrialActive) {
      return 'Trial PRO Aktif • Sisa ${_trialStatus.remainingDays} Hari';
    }
    return '${SubscriptionService.planDisplayName(_pengaturan.proPlan)} Aktif ✓';
  }

  static const int maxFreeSantriQuota = AppConfig.maxFreeSantriQuota;

  static bool isFreeQuotaReached({required bool isPro, required int activeCount}) {
    return !isPro && activeCount >= maxFreeSantriQuota;
  }

  int get activeSantriCount => _allSantri.where((s) => s.statusAktif).length;

  bool get hasReachedFreeSantriLimit =>
      isFreeQuotaReached(isPro: isProUser, activeCount: activeSantriCount);

  static const String _keyLastLocalChangeAt = 'kas_santri_last_local_change_at';
  DateTime? _lastLocalChangeAt;

  bool get hasUnbackedUpLocalChanges {
    if (_allSantri.isEmpty && _totalBrankasFisik == 0) return false;
    final lastBackupStr = _pengaturan.lastDriveBackupAt;
    if (lastBackupStr == null || lastBackupStr.isEmpty) return true;
    final lastBackup = DateTime.tryParse(lastBackupStr);
    if (lastBackup == null) return true;
    if (_lastLocalChangeAt == null) return false;
    return _lastLocalChangeAt!.isAfter(lastBackup);
  }

  Future<void> markLocalDataChanged() async {
    final now = DateTime.now();
    _lastLocalChangeAt = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastLocalChangeAt, now.toIso8601String());
    } catch (_) {}
  }

  // Stat Summary
  int _totalBrankasFisik = 0;
  int get totalBrankasFisik => _totalBrankasFisik;

  // Multi-Dompet PRO (Kas Laci Tunai vs Rekening Bank)
  int _kasLaciTunai = 0;
  int get kasLaciTunai => _kasLaciTunai;

  int _rekeningBank = 0;
  int get rekeningBank => _rekeningBank;

  // 3 Kantong Kas v3.0: Kas Infak Pondok & Gudang Beras Fisik
  String _selectedInfakPeriode =
      '${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}';
  String get selectedInfakPeriode => _selectedInfakPeriode;

  List<InfakSantriModel> _infakPeriodeList = [];
  List<InfakSantriModel> get infakPeriodeList => _infakPeriodeList;

  List<SerahTerimaInfakModel> _serahTerimaList = [];
  List<SerahTerimaInfakModel> get serahTerimaList => _serahTerimaList;

  int _kasInfakTunai = 0;
  int get kasInfakTunai => _kasInfakTunai;

  int _kasInfakRekening = 0;
  int get kasInfakRekening => _kasInfakRekening;

  int get totalKasInfakBelumDisetor => _kasInfakTunai + _kasInfakRekening;

  double _stokBerasFisikLiter = 0.0;
  double get stokBerasFisikLiter => _stokBerasFisikLiter;

  // Kantong 4 v4.3: Brankas Tabungan Terpisah Santri
  int _totalBrankasTabungan = 0;
  int get totalBrankasTabungan => _totalBrankasTabungan;

  int _tabunganTunai = 0;
  int get tabunganTunai => _tabunganTunai;

  int _tabunganRekening = 0;
  int get tabunganRekening => _tabunganRekening;

  List<TransaksiTabungan> _transaksiTabunganList = [];
  List<TransaksiTabungan> get transaksiTabunganList => _transaksiTabunganList;

  int get countPenabungAktif =>
      _allSantri.where((s) => s.statusAktif && s.saldoTabungan > 0).length;

  /// Target total uang tunai fisik di laci bendahara (Kantong Jajan + Infak Tunai + Tabungan Tunai)
  int get targetUangFisikDiLaci =>
      _kasLaciTunai + _kasInfakTunai + _tabunganTunai;

  // Cash Opname PRO Logs
  List<CashOpnameLog> _opnameLogs = [];
  List<CashOpnameLog> get opnameLogs => _opnameLogs;

  CashOpnameLog? get latestOpnameToday {
    final todayStr = DateFormatter.toLocalDateString(DateTime.now());
    return _opnameLogs.where((o) => o.tanggalLokal == todayStr).firstOrNull;
  }

  int _totalPengeluaranHariIni = 0;
  int get totalPengeluaranHariIni => _totalPengeluaranHariIni;

  int _totalKuotaHariIni = 0;
  int get totalKuotaHariIni => _totalKuotaHariIni;

  int _totalTunggakanPondok = 0;
  int get totalTunggakanPondok => _totalTunggakanPondok;

  int get countSantriTunggakan =>
      _allSantri.where((s) => s.isAktifDiPondok && s.tunggakan > 0).length;

  int _rekapPagiSiang = 0;
  int get rekapPagiSiang => _rekapPagiSiang;

  int _rekapSoreMalam = 0;
  int get rekapSoreMalam => _rekapSoreMalam;

  // 5-Detik Undo State (Terisolasi di ValueNotifier agar tidak memicu rebuild global setiap detik)
  final ValueNotifier<UndoState?> undoStateNotifier =
      ValueNotifier<UndoState?>(null);

  TransaksiHarian? _lastTransaction;
  TransaksiHarian? get lastTransaction => _lastTransaction;

  Santri? _lastSantri;
  Santri? get lastSantri => _lastSantri;

  Timer? _undoTimer;
  int _undoCountdown = 5;
  int get undoCountdown => _undoCountdown;

  bool get canUndo => _lastTransaction != null && _undoCountdown > 0;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _pengaturan = await _db.getPengaturan();
    if (!_pengaturan.onboardingDone) {
      final existingSantri = await _db.getAllSantri(onlyActive: false);
      if (existingSantri.isNotEmpty) {
        _pengaturan = _pengaturan.copyWith(onboardingDone: true);
        await _db.updatePengaturan(_pengaturan);
      }
    }
    _activeAccount = await AccountAuthService.instance.getActiveAccount();
    if (_activeAccount == null && _pengaturan.onboardingDone) {
      _activeAccount = await AccountAuthService.instance
          .ensureLegacySessionIfNeeded(_pengaturan.namaPengurus);
    }
    if (_activeAccount != null &&
        _activeAccount!.namaLengkap.trim().isNotEmpty &&
        _activeAccount!.namaLengkap != _pengaturan.namaPengurus) {
      _pengaturan = _pengaturan.copyWith(namaPengurus: _activeAccount!.namaLengkap);
      await _db.updatePengaturan(_pengaturan);
    }
    await loadAllData();
    _isScreenPrivacyEnabled =
        await SecurityGuardService.instance.getScreenPrivacyEnabled();
    await SecurityGuardService.instance.applySavedScreenPrivacy();
    _integrityReport = await SecurityGuardService.instance.checkAppIntegrity();
    _isLicenseRevoked = await CustomerSyncService.instance.getCachedRevokedStatus();
    _remoteConfig = await CustomerSyncService.instance.getCachedRemoteConfig();
    await syncSubscriptionEntitlement();

    // Sinkronisasi waktu pasif & telemetri lisensi non-sensitif di latar belakang saat online
    unawaited(_backgroundClockSync());
    unawaited(syncCustomerTelemetryInBackground());

    _isLoading = false;
    notifyListeners();
  }

  Future<CustomerSyncResult> syncCustomerTelemetryInBackground() async {
    try {
      if (_deviceId.isEmpty) {
        _deviceId = await LicenseService.instance.getOrCreateDeviceId();
      }
      final String tier;
      final DateTime? expiry;
      final String channel;
      if (_activeLicense != null && _activeLicense!.isValid) {
        tier = _activeLicense!.planKey ?? 'YEARLY';
        expiry = _activeLicense!.expiryDate;
        channel = 'DANA';
      } else if (_pengaturan.isPro && _pengaturan.proPlan == 'TRIAL_14D') {
        tier = 'TRIAL_14D';
        expiry = _trialStatus.expiresAt;
        channel = 'TRIAL';
      } else if (_pengaturan.isPro && _pengaturan.proPlan != null) {
        tier = _pengaturan.proPlan!;
        expiry = null;
        channel = kIsPlayStoreBuild ? 'PLAY_STORE' : 'DANA';
      } else {
        tier = 'FREE';
        expiry = null;
        channel = 'FREE';
      }

      final res = await CustomerSyncService.instance.syncDeviceInBackground(
        deviceId: _deviceId,
        namaPondok: _pengaturan.namaPondok,
        namaBendahara: activeOperatorName,
        noWaPengurus: _pengaturan.kontakPengurus,
        tier: tier,
        expiryDate: expiry,
        appVersion: AppConfig.appVersion,
        paymentChannel: channel,
      );

      if (res.remoteConfig != null) {
        _remoteConfig = res.remoteConfig;
        notifyListeners();
      }

      if (res.synced && res.isRevoked) {
        await LicenseService.instance.clearLicense();
        _activeLicense = null;
        _isLicenseRevoked = true;
        if (_pengaturan.isPro) {
          await deactivatePro();
        } else {
          notifyListeners();
        }
        await _recordAudit(
          action: 'LISENSI_DICABUT_ADMIN',
          targetId: _deviceId,
          summary:
              'Akses lisensi PRO perangkat $_deviceId dinonaktifkan oleh Admin (Remote Revoke).',
        );
      } else if (res.synced && !res.isRevoked && _isLicenseRevoked) {
        _isLicenseRevoked = false;
        await syncSubscriptionEntitlement();
      }
      return res;
    } catch (_) {
      return const CustomerSyncResult(synced: false);
    }
  }

  Future<void> _backgroundClockSync() async {
    try {
      final res = await SecurityGuardService.instance.checkAndAdvanceClock(
        allowNetworkSync: true,
      );
      if (res.isTampered != _isClockTampered) {
        _isClockTampered = res.isTampered;
        _clockTamperMessage = res.isTampered ? res.message : null;
        if (!res.isTampered) {
          await syncSubscriptionEntitlement();
        } else {
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> syncSubscriptionEntitlement() async {
    try {
      final clockCheck = await SecurityGuardService.instance.checkAndAdvanceClock();
      _isClockTampered = clockCheck.isTampered;
      _clockTamperMessage = clockCheck.isTampered ? clockCheck.message : null;
      final trustedNow = clockCheck.effectiveNow;

      _deviceId = await LicenseService.instance.getOrCreateDeviceId();
      _trialStatus = await SubscriptionService.instance.getTrialStatus(
        fallbackHasUsed: _pengaturan.hasUsedTrial,
        fallbackStartedAt: _pengaturan.trialStartedAt,
        fallbackExpiresAt: _pengaturan.trialExpiresAt,
        now: trustedNow,
      );

      if (_trialStatus.hasUsedTrial &&
          (!_pengaturan.hasUsedTrial || _pengaturan.trialExpiresAt == null)) {
        _pengaturan = _pengaturan.copyWith(
          hasUsedTrial: true,
          trialStartedAt: _trialStatus.startedAt?.toIso8601String(),
          trialExpiresAt: _trialStatus.expiresAt?.toIso8601String(),
        );
        await _db.updatePengaturan(_pengaturan);
      }

      if (!kIsPlayStoreBuild) {
        _activeLicense = await LicenseService.instance.checkSavedLicense(
          now: trustedNow,
        );
        if (_activeLicense != null && _activeLicense!.isValid) {
          await activatePro(plan: _activeLicense!.planKey ?? 'YEARLY');
          return;
        }
      }

      await SubscriptionService.instance.init();
      final status = await SubscriptionService.instance.checkEntitlementStatus();
      if (status.isPro) {
        await activatePro(plan: status.planKey ?? 'YEARLY');
        return;
      }

      if (_trialStatus.isActive) {
        if (!_pengaturan.isPro || _pengaturan.proPlan == null) {
          await activatePro(plan: 'TRIAL_14D');
        } else {
          notifyListeners();
        }
        return;
      }

      if (_pengaturan.proPlan == 'TRIAL_14D' && !_trialStatus.isActive) {
        await deactivatePro();
        return;
      }

      if (!kIsPlayStoreBuild &&
          _activeLicense != null &&
          _activeLicense!.isExpired &&
          _pengaturan.isPro &&
          _pengaturan.proPlan != 'TRIAL_14D') {
        await deactivatePro();
        return;
      }

      // Pada release build (!kDebugMode), pastikan status PRO di DB tidak pernah aktif
      // tanpa lisensi Ed25519 valid, langganan Play Store aktif, atau Trial 14 Hari aktif.
      if (!kDebugMode &&
          _pengaturan.isPro &&
          !status.isPro &&
          !_trialStatus.isActive &&
          (_activeLicense == null || !_activeLicense!.isValid)) {
        await deactivatePro();
        return;
      }

      SubscriptionService.instance.updateAccessState(
        isProActive: isProActive,
        isTrialActive: isTrialActive,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<({bool success, TrialStatus status, String message})> startFreeTrial14Days() async {
    final res = await SubscriptionService.instance.startFreeTrial14Days(
      fallbackHasUsed: _pengaturan.hasUsedTrial,
      fallbackStartedAt: _pengaturan.trialStartedAt,
      fallbackExpiresAt: _pengaturan.trialExpiresAt,
    );
    _trialStatus = res.status;

    if (res.success) {
      final updated = _pengaturan.copyWith(
        isPro: true,
        proPlan: 'TRIAL_14D',
        hasUsedTrial: true,
        trialStartedAt: res.status.startedAt?.toIso8601String(),
        trialExpiresAt: res.status.expiresAt?.toIso8601String(),
      );
      _pengaturan = updated;
      await _db.updatePengaturan(updated);
      unawaited(syncCustomerTelemetryInBackground());
      notifyListeners();
    } else if (res.status.hasUsedTrial && !_pengaturan.hasUsedTrial) {
      final updated = _pengaturan.copyWith(
        hasUsedTrial: true,
        trialStartedAt: res.status.startedAt?.toIso8601String(),
        trialExpiresAt: res.status.expiresAt?.toIso8601String(),
      );
      _pengaturan = updated;
      await _db.updatePengaturan(updated);
      notifyListeners();
    }
    return res;
  }

  Future<LicenseVerificationResult> activateOfflineLicense(String rawCode) async {
    final res = await LicenseService.instance.activateLicense(rawCode);
    _deviceId = await LicenseService.instance.getOrCreateDeviceId();
    if (res.isValid) {
      _activeLicense = res;
      await activatePro(plan: res.planKey ?? 'YEARLY');
      await _recordAudit(
        action: 'AKTIVASI_LISENSI',
        targetId: res.deviceId,
        summary: 'Aktivasi lisensi Ed25519 paket ${res.planKey ?? 'PRO'}.',
      );
      unawaited(syncCustomerTelemetryInBackground());
    }
    return res;
  }

  Future<void> completeOnboarding({
    required String namaPondok,
    required String namaPengurus,
    required int defaultJatahHarian,
    required int pembulatanJatah,
    required bool useSimulationData,
  }) async {
    final updated = _pengaturan.copyWith(
      namaPondok: namaPondok.trim().isNotEmpty ? namaPondok.trim() : 'Nama Pondok',
      namaPengurus: namaPengurus.trim().isNotEmpty ? namaPengurus.trim() : 'Pengurus Kas & Keuangan',
      defaultJatahHarian: defaultJatahHarian > 0 ? defaultJatahHarian : 10000,
      pembulatanJatah: pembulatanJatah,
      onboardingDone: true,
    );
    _pengaturan = updated;
    await _db.updatePengaturan(updated);

    if (useSimulationData) {
      await _db.seedDemoData(force: true);
    }
    await loadAllData();
    unawaited(syncCustomerTelemetryInBackground());
  }

  Future<void> activatePro({required String plan}) async {
    final updated = _pengaturan.copyWith(isPro: true, proPlan: plan);
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    SubscriptionService.instance.updateAccessState(
      isProActive: isProActive,
      isTrialActive: isTrialActive,
    );
    notifyListeners();
  }

  Future<void> deactivatePro() async {
    final updated = _pengaturan.copyWith(isPro: false, clearProPlan: true);
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    SubscriptionService.instance.updateAccessState(
      isProActive: isProActive,
      isTrialActive: isTrialActive,
    );
    notifyListeners();
  }

  /// Toggle uji coba sementara HANYA untuk debug build (dinonaktifkan mutlak pada release build).
  Future<void> toggleProPreview() async {
    if (!kDebugMode) return;
    if (_pengaturan.isPro) {
      await deactivatePro();
    } else {
      await activatePro(plan: 'YEARLY');
    }
  }

  Future<void> loadAllData() async {
    _pengaturan = await _db.getPengaturan();
    _kamars = await _db.getAllKamars();
    _allSantri = await _db.getAllSantri(onlyActive: false);

    final todayStr = DateFormatter.toLocalDateString(DateTime.now());
    final activeSantri = _allSantri.where((s) => s.statusAktif).toList();

    // 1. Batch query transaksi hari ini & kuota efektif untuk seluruh santri aktif (Eliminasi N+1)
    final txHariIniBySantri =
        await _db.getAllTransaksiPengambilanHariIniMap(todayStr);
    final effectiveQuotaBySantri = await _db.computeEffectiveDailyQuotaMap(
      todayLokal: todayStr,
      activeSantri: activeSantri,
      modeSisaHarian: _pengaturan.modeSisaHarian,
    );

    List<SantriStatusHariIni> statuses = [];
    int totalKuota = 0;
    for (final santri in activeSantri) {
      final jatahHariIni =
          effectiveQuotaBySantri[santri.id] ?? santri.jatahHarian;
      totalKuota += jatahHariIni;
      final txHariIni =
          txHariIniBySantri[santri.id] ?? const <TransaksiHarian>[];
      final totalAmbil =
          txHariIni.fold<int>(0, (sum, t) => sum + t.nominal);

      final int sisaJatah = jatahHariIni - totalAmbil;
      final bool hasOverlimit = txHariIni.any((t) => t.isOverlimit);

      statuses.add(
        SantriStatusHariIni(
          santri: santri,
          totalAmbilHariIni: totalAmbil,
          sisaJatahHariIni: sisaJatah,
          jatahHariIni: jatahHariIni,
          transaksiHariIni: txHariIni,
          hasOverlimitToday: hasOverlimit,
        ),
      );
    }
    _santriStatusList = statuses;
    _totalKuotaHariIni = totalKuota;

    // 2. Metrics, Brankas, Multi-Dompet, Kantong Infak & Cash Opname
    _totalBrankasFisik = await _db.getTotalSaldoBrankasFisik();
    final saldoDompet = await _db.getSaldoDompet();
    _kasLaciTunai = saldoDompet['tunai'] ?? 0;
    _rekeningBank = saldoDompet['rekening'] ?? 0;

    final kantongInfak = await _db.getSaldoKantongInfak();
    _kasInfakTunai = (kantongInfak['tunai'] as num?)?.toInt() ?? 0;
    _kasInfakRekening = (kantongInfak['rekening'] as num?)?.toInt() ?? 0;
    _stokBerasFisikLiter = (kantongInfak['beras_stok'] as num?)?.toDouble() ?? 0.0;
    _infakPeriodeList = await _db.getInfakByPeriode(_selectedInfakPeriode);
    _serahTerimaList = await _db.getSerahTerimaInfak();

    final tabunganDompet = await _db.getSaldoBrankasTabungan();
    _tabunganTunai = tabunganDompet['tunai'] ?? 0;
    _tabunganRekening = tabunganDompet['rekening'] ?? 0;
    _totalBrankasTabungan = tabunganDompet['total'] ?? 0;
    _transaksiTabunganList = await _db.getTransaksiTabungan(limit: 120);

    _opnameLogs = await _db.getCashOpnameLogs(limit: 15);
    _totalPengeluaranHariIni = await _db.getTotalPengeluaranHariIni(todayStr);
    _totalTunggakanPondok = await _db.getTotalTunggakanPondok();
    _rekapPagiSiang = await _db.getTotalPagiSiangHariIni(todayStr);
    _rekapSoreMalam = await _db.getTotalSoreMalamHariIni(todayStr);

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastChangeStr = prefs.getString(_keyLastLocalChangeAt);
      if (lastChangeStr != null) {
        _lastLocalChangeAt = DateTime.tryParse(lastChangeStr);
      }
    } catch (_) {}

    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedKamar(String? kamar) {
    _selectedKamar = kamar;
    notifyListeners();
  }

  void setFilter(String filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  Future<void> toggleGridLayout() async {
    final updated = _pengaturan.copyWith(isTwoColGrid: !_pengaturan.isTwoColGrid);
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    notifyListeners();
  }

  Future<void> toggleGridMode() => toggleGridLayout();

  Future<void> toggleHideBalance() async {
    final updated = _pengaturan.copyWith(hideBalance: !_pengaturan.hideBalance);
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    notifyListeners();
  }

  Future<void> updateLogoPath(String? path) async {
    final updated = _pengaturan.copyWith(logoPath: path);
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    notifyListeners();
  }

  List<SantriStatusHariIni> get saldoKritisList {
    final list = _santriStatusList
        .where((item) => item.santri.isAktifDiPondok && item.santri.estimasiHari < 3)
        .toList();
    list.sort((a, b) {
      final hariCmp = a.santri.estimasiHari.compareTo(b.santri.estimasiHari);
      if (hariCmp != 0) return hariCmp;
      return a.santri.saldoTotal.compareTo(b.santri.saldoTotal);
    });
    return list;
  }

  SantriStatusHariIni? findStatusByQrCode(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    for (final item in _santriStatusList) {
      if (item.santri.qrCode.toUpperCase() == code ||
          item.santri.id.toUpperCase() == code) {
        return item;
      }
    }
    return null;
  }

  List<SantriStatusHariIni> get filteredSantriStatusList {
    return _santriStatusList.where((item) {
      // Filter kamar
      final matchesKamar = _selectedKamar == null ||
          _selectedKamar!.isEmpty ||
          item.santri.kamar == _selectedKamar;
      if (!matchesKamar) return false;

      // Filter status / tunggakan
      if (_activeFilter == 'TUNGGAKAN') {
        if (!item.santri.isAktifDiPondok || item.santri.tunggakan <= 0) return false;
      } else if (_activeFilter == 'KRITIS') {
        if (!item.santri.isAktifDiPondok || item.santri.estimasiHari >= 3) return false;
      } else if (_activeFilter == 'UTUH') {
        if (item.badgeStatus != BadgeStatusHariIni.utuh) return false;
      } else if (_activeFilter == 'SEBAGIAN') {
        if (item.badgeStatus != BadgeStatusHariIni.sebagian) return false;
      } else if (_activeFilter == 'HABIS') {
        if (item.badgeStatus != BadgeStatusHariIni.limitHabis &&
            item.badgeStatus != BadgeStatusHariIni.overlimitKritis) {
          return false;
        }
      }

      // Search query
      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.toLowerCase().trim();
      final matchNama = item.santri.namaLengkap.toLowerCase().contains(query);
      final matchPanggilan = item.santri.namaPanggilan.toLowerCase().contains(query);
      final matchKamar = item.santri.kamar.toLowerCase().contains(query);

      return matchNama || matchPanggilan || matchKamar;
    }).toList();
  }

  // ==================== CATAT PENGAMBILAN (3-TAP UX) ====================

  Future<TransaksiHarian> catatPengambilan({
    required Santri santri,
    required int nominal,
    String? catatan,
    bool isOverlimit = false,
    OverlimitHandling? overlimitHandling,
    TimeCategory? waktuCategory,
  }) async {
    final tx = await _db.catatPengambilan(
      santriId: santri.id,
      nominal: nominal,
      catatan: catatan,
      isOverlimit: isOverlimit,
      overlimitHandling: overlimitHandling,
      waktuCategory: waktuCategory,
    );

    // Set 5-second undo (isolasi ke ValueNotifier tanpa notifyListeners global per detik)
    _lastTransaction = tx;
    _lastSantri = santri;
    _undoCountdown = 5;
    undoStateNotifier.value = UndoState(
      transaction: tx,
      santri: santri,
      countdown: _undoCountdown,
    );

    _undoTimer?.cancel();
    _undoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_undoCountdown > 1) {
        _undoCountdown--;
        final currentTx = _lastTransaction;
        final currentSantri = _lastSantri;
        if (currentTx != null && currentSantri != null) {
          undoStateNotifier.value = UndoState(
            transaction: currentTx,
            santri: currentSantri,
            countdown: _undoCountdown,
          );
        }
      } else {
        _undoCountdown = 0;
        _lastTransaction = null;
        _lastSantri = null;
        timer.cancel();
        undoStateNotifier.value = null;
      }
    });

    await markLocalDataChanged();
    await loadAllData();
    return tx;
  }

  Future<void> undoLastTransaction() async {
    if (_lastTransaction == null) return;
    _undoTimer?.cancel();

    final txId = _lastTransaction!.id;
    await _db.voidTransaksi(txId);

    _lastTransaction = null;
    _lastSantri = null;
    _undoCountdown = 0;
    undoStateNotifier.value = null;

    await markLocalDataChanged();
    await loadAllData();
  }

  void dismissUndo() {
    _undoTimer?.cancel();
    _lastTransaction = null;
    _lastSantri = null;
    _undoCountdown = 0;
    undoStateNotifier.value = null;
  }

  // ==================== TUNGGAKAN ====================

  Future<void> kelolaTunggakan({
    required String santriId,
    required int nominal,
    required String catatan,
    required bool isBayar,
    String sumberDompet = 'TUNAI',
  }) async {
    await _db.kelolaTunggakan(
      santriId: santriId,
      nominal: nominal,
      catatan: catatan,
      isBayar: isBayar,
      sumberDompet: sumberDompet,
    );
    await markLocalDataChanged();
    await loadAllData();
  }

  // ==================== MULTI-DOMPET & OPNAME (PRO) ====================

  Future<void> tarikTunaiKeLaci({required int nominal, String? catatan}) async {
    await _db.tarikTunaiKeLaci(nominal: nominal, catatan: catatan);
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<void> simpanCashOpname({
    required int totalSistem,
    required int totalFisik,
    required Map<int, int> rincianPecahan,
    String? catatan,
  }) async {
    final now = DateTime.now();
    final log = CashOpnameLog(
      id: const Uuid().v4(),
      tanggalLokal: DateFormatter.toLocalDateString(now),
      totalSistem: totalSistem,
      totalFisik: totalFisik,
      selisih: totalFisik - totalSistem,
      rincianPecahan: rincianPecahan,
      catatan: catatan,
      createdAt: now,
    );
    await _db.insertCashOpnameLog(log);
    await markLocalDataChanged();
    await loadAllData();
  }

  // ==================== INFAK, SAMBANGAN & SERAH TERIMA (v3.0) ====================

  Future<void> setSelectedInfakPeriode(String periodeYm) async {
    _selectedInfakPeriode = periodeYm;
    _infakPeriodeList = await _db.getInfakByPeriode(_selectedInfakPeriode);
    notifyListeners();
  }

  Future<void> shiftInfakPeriode(int deltaMonths) async {
    final parts = _selectedInfakPeriode.split('-');
    if (parts.length != 2) return;
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    final shifted = DateTime(y, m + deltaMonths, 1);
    final nextYm =
        '${shifted.year.toString().padLeft(4, '0')}-${shifted.month.toString().padLeft(2, '0')}';
    await setSelectedInfakPeriode(nextYm);
  }

  InfakSantriModel? getInfakForSantri(String santriId) {
    return _infakPeriodeList.where((i) => i.santriId == santriId).firstOrNull;
  }

  Future<({
    SetoranBulanan? setoran,
    InfakSantriModel infak,
    int sisaJajan,
    int jatahBaru,
    int nominalPotongTunggakan,
  })> catatSambanganSmartSplit({
    required String santriId,
    required int totalUangDiterima,
    required DateTime tanggalMasuk,
    required String tglHabisYmd,
    required int nominalMasak,
    required bool isMasakBebas,
    required int nominalListrik,
    required bool isListrikBebas,
    required String jenisBeras,
    required double berasLiter,
    required int berasUang,
    required int durasiHari,
    bool potongTunggakan = true,
    String sumberDompet = 'TUNAI',
    String? catatan,
  }) async {
    final res = await _db.catatSambanganSmartSplit(
      santriId: santriId,
      totalUangDiterima: totalUangDiterima,
      tanggalMasuk: tanggalMasuk,
      tglHabisYmd: tglHabisYmd,
      nominalMasak: nominalMasak,
      isMasakBebas: isMasakBebas,
      nominalListrik: nominalListrik,
      isListrikBebas: isListrikBebas,
      jenisBeras: jenisBeras,
      berasLiter: berasLiter,
      berasUang: berasUang,
      durasiHari: durasiHari,
      potongTunggakan: potongTunggakan,
      sumberDompet: sumberDompet,
      catatan: catatan,
    );
    _selectedInfakPeriode = res.infak.periodeBulan;
    await _recordAudit(
      action: 'SAMBANGAN_SMART_SPLIT',
      targetId: santriId,
      summary:
          'Smart Split Sambangan ${res.infak.periodeBulan} diterima Rp$totalUangDiterima (Jajan: Rp${res.sisaJajan}).',
    );
    await markLocalDataChanged();
    await loadAllData();
    return res;
  }

  Future<void> simpanInfakSantri(InfakSantriModel infak) async {
    final statusLunas = InfakSantriModel.hitungStatusLunas(
      nominalMasak: infak.isMasakBebas ? 0 : infak.nominalMasak,
      isMasakBebas: infak.isMasakBebas,
      nominalListrik: infak.isListrikBebas ? 0 : infak.nominalListrik,
      isListrikBebas: infak.isListrikBebas,
      jenisBeras: infak.jenisBeras,
      berasLiter: infak.jenisBeras == InfakSantriModel.berasFisik ? infak.berasLiter : 0.0,
      berasUang: infak.jenisBeras == InfakSantriModel.berasUangVal ? infak.berasUang : 0,
      targetMasak: _pengaturan.defaultInfakMasak,
      targetListrik: _pengaturan.defaultInfakListrik,
      targetBerasLiter: _pengaturan.defaultInfakBerasLiter,
      targetBerasUang: _pengaturan.defaultInfakBerasUang,
    );
    final updatedInfak = infak.copyWith(statusLunas: statusLunas);
    await _db.upsertInfakSantri(updatedInfak);
    await _recordAudit(
      action: 'EDIT_INFAK_MANUAL',
      targetId: infak.santriId,
      summary:
          'Memperbarui catatan infak periode ${infak.periodeBulan} (Status: $statusLunas, Dompet: ${infak.sumberDompet}).',
    );
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<void> catatSerahTerimaInfak(SerahTerimaInfakModel item) async {
    await _db.insertSerahTerimaInfak(item);
    await _recordAudit(
      action: 'SERAH_TERIMA_INFAK',
      targetId: item.id,
      summary:
          'Serah terima infak (${item.posInfak}) Rp${item.nominalUang} & beras ${item.jumlahBerasLiter}L ke ${item.penerima}.',
    );
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<void> hapusSerahTerimaInfak(String id) async {
    await _db.deleteSerahTerimaInfak(id);
    await _recordAudit(
      action: 'HAPUS_SERAH_TERIMA_INFAK',
      targetId: id,
      summary: 'Menghapus catatan serah terima infak ID $id.',
    );
    await markLocalDataChanged();
    await loadAllData();
  }

  // ==================== SETORAN & MUTASI ====================

  Future<void> catatSetoran({
    required String santriId,
    required int nominalSetoran,
    required int durasiHari,
    required int jatahHarianHitung,
    required TipeSetoran tipeSetoran,
    required DateTime tanggalSetor,
    String? catatan,
    PerlakuanSisaSaldoLalu perlakuanSisa = PerlakuanSisaSaldoLalu.gabungBulanBaru,
    OpsiSetoranSusulan? opsiSusulan,
    bool potongTunggakan = true,
    String metodeBayar = 'TUNAI',
  }) async {
    await _db.catatSetoranBaru(
      santriId: santriId,
      nominalSetoran: nominalSetoran,
      durasiHari: durasiHari,
      jatahHarianHitung: jatahHarianHitung,
      tipeSetoran: tipeSetoran,
      tanggalSetor: tanggalSetor,
      catatan: catatan,
      perlakuanSisa: perlakuanSisa,
      opsiSusulan: opsiSusulan,
      potongTunggakan: potongTunggakan,
      metodeBayar: metodeBayar,
    );
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<void> voidTransaksi(String id) async {
    await _db.voidTransaksi(id);
    await _recordAudit(
      action: 'VOID_TRANSAKSI',
      targetId: id,
      summary: 'Membatalkan (Void) transaksi harian ID $id.',
    );
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<void> editTransaksi(String id, int newNominal, String? note) async {
    await _db.editTransaksi(id, newNominal, note);
    await _recordAudit(
      action: 'EDIT_TRANSAKSI',
      targetId: id,
      summary:
          'Mengubah nominal transaksi ID $id menjadi Rp$newNominal${note != null && note.trim().isNotEmpty ? ' ($note)' : ''}.',
    );
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<void> updateJatahKhusus(String santriId, int newJatah) async {
    final santri = _allSantri.firstWhere((s) => s.id == santriId);
    final updated = santri.copyWith(jatahHarian: newJatah);
    await _db.updateSantri(updated);
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<String?> _persistSantriPhotoIfNeeded(
    String santriId,
    String? sourceFotoPath,
  ) async {
    if (sourceFotoPath == null || sourceFotoPath.trim().isEmpty) {
      return null;
    }
    final cleanPath = sourceFotoPath.trim();
    try {
      final src = File(cleanPath);
      if (!await src.exists()) {
        return cleanPath;
      }
      final appDir = await getApplicationDocumentsDirectory();
      final profDir = Directory(p.join(appDir.path, 'profiles'));
      if (p.isWithin(profDir.path, cleanPath)) {
        return cleanPath;
      }
      if (!await profDir.exists()) {
        await profDir.create(recursive: true);
      }
      final ext = p.extension(cleanPath).isNotEmpty
          ? p.extension(cleanPath)
          : '.jpg';
      final safeId = santriId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final dest = p.join(
        profDir.path,
        'santri_${safeId}_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await src.copy(dest);
      return dest;
    } catch (_) {
      return cleanPath;
    }
  }

  Future<void> updateSantriFoto(String santriId, String? fotoPath) async {
    final persistedPath = await _persistSantriPhotoIfNeeded(santriId, fotoPath);
    await _db.updateSantriFoto(santriId, persistedPath);
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<void> quickUpdateSantri(
    String santriId, {
    required String namaLengkap,
    required String namaPanggilan,
    required String kamar,
    String? noWaWali,
    required int jatahHarian,
  }) async {
    await _db.quickUpdateSantri(
      santriId,
      namaLengkap: namaLengkap,
      namaPanggilan: namaPanggilan,
      kamar: kamar,
      noWaWali: noWaWali,
      jatahHarian: jatahHarian,
    );
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<void> saveSantri(Santri santri, {bool isEdit = false, String sumberDompet = 'TUNAI'}) async {
    final persistedFoto = await _persistSantriPhotoIfNeeded(
      santri.id,
      santri.fotoPath,
    );
    final normalizedSantri = persistedFoto != santri.fotoPath
        ? santri.copyWith(fotoPath: persistedFoto)
        : santri;
    if (isEdit) {
      await _db.updateSantri(normalizedSantri);
      await _recordAudit(
        action: 'EDIT_SANTRI',
        targetId: normalizedSantri.id,
        summary: 'Mengubah data santri ${normalizedSantri.namaLengkap} (${normalizedSantri.kamar}).',
      );
    } else {
      await _db.insertSantri(normalizedSantri, sumberDompet: sumberDompet);
    }
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<void> deleteSantri(
    String santriId, {
    String sumberDompet = 'TUNAI',
  }) async {
    final targetSantri =
        _allSantri.where((s) => s.id == santriId).firstOrNull;
    final targetName = targetSantri?.namaLengkap ?? santriId;
    final refundedSaldo = await _db.deleteSantri(
      santriId,
      sumberDompet: sumberDompet,
    );
    await _recordAudit(
      action: 'HAPUS_SANTRI',
      targetId: santriId,
      summary: (refundedSaldo > 0 || (targetSantri?.saldoTabungan ?? 0) > 0)
          ? 'Menghapus permanen santri $targetName (ID: $santriId) dengan pengembalian saldo jajan Rp$refundedSaldo ($sumberDompet) & tabungan Rp${targetSantri?.saldoTabungan ?? 0}.'
          : 'Menghapus permanen data santri $targetName (ID: $santriId).',
    );
    await markLocalDataChanged();
    await loadAllData();
  }

  // ==================== SANTRI BARU & PENGATURAN ====================

  Future<void> tambahSantriBaru(Santri santri, {String sumberDompet = 'TUNAI'}) async {
    await _db.insertSantri(santri, sumberDompet: sumberDompet);
    await markLocalDataChanged();
    await loadAllData();
  }

  // ==================== BRANKAS TABUNGAN TERPISAH (KANTONG 4) ====================

  Future<TransaksiTabungan> setorTabungan({
    required String santriId,
    required int nominal,
    String sumberDompet = 'TUNAI',
    String? catatan,
  }) async {
    final tx = await _db.setorTabungan(
      santriId: santriId,
      nominal: nominal,
      sumberDompet: sumberDompet,
      catatan: catatan,
    );
    await _recordAudit(
      action: 'SETOR_TABUNGAN',
      targetId: santriId,
      summary:
          'Setor tabungan terpisah Rp$nominal ($sumberDompet) untuk ${tx.namaSantri ?? santriId}.',
    );
    await markLocalDataChanged();
    await loadAllData();
    return tx;
  }

  Future<TransaksiTabungan> tarikTabungan({
    required String santriId,
    required int nominal,
    String sumberDompet = 'TUNAI',
    String? catatan,
  }) async {
    final tx = await _db.tarikTabungan(
      santriId: santriId,
      nominal: nominal,
      sumberDompet: sumberDompet,
      catatan: catatan,
    );
    await _recordAudit(
      action: 'TARIK_TABUNGAN',
      targetId: santriId,
      summary:
          'Tarik tabungan terpisah Rp$nominal ($sumberDompet) untuk ${tx.namaSantri ?? santriId}.',
    );
    await markLocalDataChanged();
    await loadAllData();
    return tx;
  }

  Future<TransaksiTabungan> transferJajanKeTabungan({
    required String santriId,
    required int nominal,
    String sumberDompet = 'TUNAI',
    String? catatan,
  }) async {
    final tx = await _db.transferJajanKeTabungan(
      santriId: santriId,
      nominal: nominal,
      sumberDompet: sumberDompet,
      catatan: catatan,
    );
    await _recordAudit(
      action: 'TRANSFER_JAJAN_KE_TABUNGAN',
      targetId: santriId,
      summary:
          'Pindah saldo jajan Rp$nominal -> Brankas Tabungan ($sumberDompet) untuk ${tx.namaSantri ?? santriId}.',
    );
    await markLocalDataChanged();
    await loadAllData();
    return tx;
  }

  Future<TransaksiTabungan> transferTabunganKeJajan({
    required String santriId,
    required int nominal,
    String sumberDompet = 'TUNAI',
    String? catatan,
  }) async {
    final tx = await _db.transferTabunganKeJajan(
      santriId: santriId,
      nominal: nominal,
      sumberDompet: sumberDompet,
      catatan: catatan,
    );
    await _recordAudit(
      action: 'TRANSFER_TABUNGAN_KE_JAJAN',
      targetId: santriId,
      summary:
          'Pindah saldo Brankas Tabungan Rp$nominal -> Saldo Jajan ($sumberDompet) untuk ${tx.namaSantri ?? santriId}.',
    );
    await markLocalDataChanged();
    await loadAllData();
    return tx;
  }

  Future<void> voidTransaksiTabungan(String txId) async {
    await _db.voidTransaksiTabungan(txId);
    await _recordAudit(
      action: 'VOID_TABUNGAN',
      targetId: txId,
      summary: 'Membatalkan (Void) mutasi tabungan $txId.',
    );
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<int> importSantriMassal(
    List<Santri> santriList, {
    String sumberDompet = 'TUNAI',
  }) async {
    if (santriList.isEmpty) return 0;
    final count = await _db.bulkInsertSantri(santriList, sumberDompet: sumberDompet);
    await _recordAudit(
      action: 'IMPORT_EXCEL_SANTRI',
      summary: 'Impor massal $count santri baru dari Excel (Dompet: $sumberDompet).',
    );
    await markLocalDataChanged();
    await loadAllData();
    return count;
  }

  Future<int> pindahKamarMassal(List<String> santriIds, String newKamar) async {
    if (santriIds.isEmpty || newKamar.trim().isEmpty) return 0;
    final count = await _db.bulkMoveKamar(santriIds, newKamar);
    await _recordAudit(
      action: 'MUTASI_KAMAR_MASSAL',
      summary: 'Memindahkan $count santri secara massal ke kamar/kelas "$newKamar".',
    );
    await markLocalDataChanged();
    await loadAllData();
    return count;
  }

  Future<int> tutupBukuArsipSantri(
    List<String> santriIds, {
    required String statusTujuan,
  }) async {
    if (santriIds.isEmpty) return 0;
    final normalized = Santri.normalizeStatusSantri(statusTujuan);
    final count = await _db.bulkArchiveSantriStatus(
      santriIds,
      newStatusSantri: normalized,
    );
    await _recordAudit(
      action: 'TUTUP_BUKU_SANTRI',
      summary: 'Mengarsipkan $count santri dengan status $normalized (Tutup Buku).',
    );
    await markLocalDataChanged();
    await loadAllData();
    return count;
  }

  Future<void> mulaiTahunAjaranBaru(String newTahunAjaran) async {
    final clean = newTahunAjaran.trim();
    if (clean.isEmpty) return;
    final oldTahun = _pengaturan.tahunAjaran;
    final updated = _pengaturan.copyWith(tahunAjaran: clean);
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    await _recordAudit(
      action: 'TAHUN_AJARAN_BARU',
      summary: 'Mengubah Tahun Ajaran aktif dari "$oldTahun" ke "$clean".',
    );
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<void> savePengaturan(PengaturanAplikasi updated) async {
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    await _recordAudit(
      action: 'UBAH_PENGATURAN',
      summary:
          'Memperbarui pengaturan pondok/kas (${updated.namaPondok}, Jatah: Rp${updated.defaultJatahHarian}).',
    );
    await loadAllData();
  }

  Future<void> syncActiveAccountToPengaturan(BendaharaAccount account) async {
    _activeAccount = account;
    _pengaturan = _pengaturan.copyWith(
      namaPengurus: account.namaLengkap,
      driveAccountEmail: account.authMode == BendaharaAccount.modeGoogle &&
              account.email != null &&
              account.email!.isNotEmpty
          ? account.email
          : null,
    );
    await _db.updatePengaturan(_pengaturan);
    notifyListeners();
  }

  Future<void> updateBendaharaProfile({
    String? namaLengkap,
    String? jabatan,
    String? sourceFotoPath,
    bool clearFoto = false,
  }) async {
    String? permanentFotoPath;
    if (sourceFotoPath != null && sourceFotoPath.trim().isNotEmpty) {
      final src = File(sourceFotoPath);
      if (await src.exists()) {
        final appDir = await getApplicationDocumentsDirectory();
        final profDir = Directory(p.join(appDir.path, 'profiles'));
        if (!await profDir.exists()) {
          await profDir.create(recursive: true);
        }
        final ext = p.extension(sourceFotoPath).isNotEmpty
            ? p.extension(sourceFotoPath)
            : '.jpg';
        final dest = p.join(
          profDir.path,
          'bendahara_${DateTime.now().millisecondsSinceEpoch}$ext',
        );
        await src.copy(dest);
        permanentFotoPath = dest;
      }
    }

    if (_activeAccount == null) {
      final created = await AccountAuthService.instance.enterOfflineQuickMode(
        namaLengkap: namaLengkap ?? _pengaturan.namaPengurus,
        jabatan: jabatan ?? 'Bendahara Pondok',
      );
      _activeAccount = created;
    }

    final updatedAcc = await AccountAuthService.instance.updateActiveProfile(
      namaLengkap: namaLengkap,
      jabatan: jabatan,
      fotoPath: permanentFotoPath,
      clearFoto: clearFoto,
    );
    await syncActiveAccountToPengaturan(updatedAcc);
  }

  Future<void> logoutBendahara() async {
    await AccountAuthService.instance.logout();
    _activeAccount = null;
    notifyListeners();
  }

  Future<void> resetToInitialData() async {
    await _db.resetToInitialDemoData();
    await _recordAudit(
      action: 'RESET_DATA',
      summary: 'Mereset seluruh database lokal ke data awal simulasi.',
    );
    await markLocalDataChanged();
    await loadAllData();
  }

  // ==================== BACKUP, RESTORE & GOOGLE DRIVE (PRO) ====================

  Future<void> restoreFromBackupJson(Map<String, dynamic> data) async {
    await _db.restoreFromJson(data);
    final restoredSettings = await _db.getPengaturan();
    await AuthService.instance.syncRestoredPinToSecureStorage(restoredSettings.pinKeamanan);
    await syncSubscriptionEntitlement();
    await _recordAudit(
      action: 'RESTORE_BACKUP',
      summary: 'Memulihkan seluruh data aplikasi dari file cadangan terverifikasi.',
    );
    await loadAllData();
  }

  Future<void> _recordAudit({
    required String action,
    String? targetId,
    required String summary,
  }) async {
    try {
      await _db.insertAuditLog(
        actor: activeOperatorName,
        action: action,
        targetId: targetId,
        summary: summary,
      );
    } catch (_) {
      // Jangan menggagalkan aksi utama jika log audit gagal sementara
    }
  }

  Future<ClockTamperCheckResult> recheckDeviceClock({bool tryNetwork = true}) async {
    final res = await SecurityGuardService.instance.checkAndAdvanceClock(
      allowNetworkSync: tryNetwork,
    );
    _isClockTampered = res.isTampered;
    _clockTamperMessage = res.isTampered ? res.message : null;
    if (!res.isTampered) {
      await syncSubscriptionEntitlement();
    } else {
      notifyListeners();
    }
    return res;
  }

  Future<void> setScreenPrivacyEnabled(bool enabled) async {
    await SecurityGuardService.instance.setScreenPrivacyEnabled(enabled);
    _isScreenPrivacyEnabled = enabled;
    await _recordAudit(
      action: 'PRIVASI_LAYAR',
      summary: enabled
          ? 'Mengaktifkan Mode Privasi Layar (Blokir Screenshot).'
          : 'Menonaktifkan Mode Privasi Layar.',
    );
    notifyListeners();
  }

  Future<String?> connectGoogleDrive() async {
    final account = await GoogleDriveBackupService.instance.signInInteractive();
    if (account == null) return null;
    final updated = _pengaturan.copyWith(driveAccountEmail: account.email);
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    notifyListeners();
    return account.email;
  }

  Future<void> disconnectGoogleDrive() async {
    await GoogleDriveBackupService.instance.signOut();
    final updated = _pengaturan.copyWith(
      clearDriveAccount: true,
      autoDriveBackup: false,
    );
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    notifyListeners();
  }

  Future<DateTime> backupToGoogleDriveNow() async {
    var email = _pengaturan.driveAccountEmail;
    if (email == null || email.isEmpty) {
      email = await connectGoogleDrive();
      if (email == null || email.isEmpty) {
        throw Exception('Akun Google belum ditautkan.');
      }
    }
    final payload = await _db.dumpBackupJson();
    final uploadedAt = await GoogleDriveBackupService.instance.uploadBackupJson(payload);
    final updated = _pengaturan.copyWith(
      lastDriveBackupAt: uploadedAt.toIso8601String(),
      driveAccountEmail: email,
    );
    _pengaturan = updated;
    _lastLocalChangeAt = uploadedAt;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastLocalChangeAt, uploadedAt.toIso8601String());
    } catch (_) {}
    await _db.updatePengaturan(updated);
    notifyListeners();
    return uploadedAt;
  }

  Future<void> toggleAutoDriveBackup(bool enabled) async {
    final updated = _pengaturan.copyWith(autoDriveBackup: enabled);
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    notifyListeners();
  }

  Future<({BackupValidationResult validation, DateTime? modifiedTime})>
      fetchGoogleDriveBackupForRestore() async {
    return await GoogleDriveBackupService.instance.downloadAndValidateBackup();
  }

  Future<void> tryAutoBackupDriveInBackground() async {
    final uploadedAt = await GoogleDriveBackupService.instance.runDailyAutoBackupIfDue(
      settings: _pengaturan,
      dumpPayload: _db.dumpBackupJson,
    );
    if (uploadedAt != null) {
      final updated = _pengaturan.copyWith(
        lastDriveBackupAt: uploadedAt.toIso8601String(),
      );
      _pengaturan = updated;
      _lastLocalChangeAt = uploadedAt;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyLastLocalChangeAt, uploadedAt.toIso8601String());
      } catch (_) {}
      await _db.updatePengaturan(updated);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    spotlightTourRequestNotifier.dispose();
    undoStateNotifier.dispose();
    super.dispose();
  }
}
