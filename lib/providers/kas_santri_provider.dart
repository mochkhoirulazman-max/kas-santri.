import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/santri.dart';
import '../models/setoran.dart';
import '../models/transaksi.dart';
import '../models/pengaturan.dart';
import '../models/santri_status.dart';
import '../models/cash_opname_log.dart';
import '../database/database_helper.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/google_drive_backup_service.dart';
import '../services/subscription_service.dart';
import 'package:uuid/uuid.dart';
import '../utils/date_formatter.dart';
import '../utils/time_category_helper.dart';

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

  /// Helper state global untuk status PRO (dipakai seluruh fitur berlabel 👑)
  bool get isProUser => _pengaturan.isPro;

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

  int get countSantriTunggakan => _allSantri.where((s) => s.statusAktif && s.tunggakan > 0).length;

  int _rekapPagiSiang = 0;
  int get rekapPagiSiang => _rekapPagiSiang;

  int _rekapSoreMalam = 0;
  int get rekapSoreMalam => _rekapSoreMalam;

  // 5-Detik Undo State
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
    await loadAllData();
    await syncSubscriptionEntitlement();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> syncSubscriptionEntitlement() async {
    try {
      await SubscriptionService.instance.init();
      final status = await SubscriptionService.instance.checkEntitlementStatus();
      if (status.isPro && !_pengaturan.isPro) {
        await activatePro(plan: status.planKey ?? 'YEARLY');
      }
    } catch (_) {}
  }

  Future<void> completeOnboarding({
    required String namaPondok,
    required String namaPengurus,
    required int defaultJatahHarian,
    required int pembulatanJatah,
    required bool useSimulationData,
  }) async {
    final updated = _pengaturan.copyWith(
      namaPondok: namaPondok.trim().isNotEmpty ? namaPondok.trim() : 'PPS MIFTAHUSSUNAN',
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
  }

  Future<void> activatePro({required String plan}) async {
    final updated = _pengaturan.copyWith(isPro: true, proPlan: plan);
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    notifyListeners();
  }

  Future<void> deactivatePro() async {
    final updated = _pengaturan.copyWith(isPro: false, clearProPlan: true);
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    notifyListeners();
  }

  /// Toggle uji coba sementara untuk menguji fitur PRO vs Gratis secara cepat
  Future<void> toggleProPreview() async {
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

    // 1. Status hari ini untuk setiap santri aktif
    List<SantriStatusHariIni> statuses = [];
    int totalKuota = 0;
    for (var santri in _allSantri.where((s) => s.statusAktif)) {
      totalKuota += santri.jatahHarian;
      final txHariIni = await _db.getTransaksiHariIni(santri.id, todayStr);
      final totalAmbil = await _db.getTotalPengambilanHariIni(santri.id, todayStr);

      int sisaJatah = santri.jatahHarian - totalAmbil;
      final hasOverlimit = txHariIni.any((t) => t.isOverlimit);

      statuses.add(
        SantriStatusHariIni(
          santri: santri,
          totalAmbilHariIni: totalAmbil,
          sisaJatahHariIni: sisaJatah,
          jatahHariIni: santri.jatahHarian,
          transaksiHariIni: txHariIni,
          hasOverlimitToday: hasOverlimit,
        ),
      );
    }
    _santriStatusList = statuses;
    _totalKuotaHariIni = totalKuota;

    // 2. Metrics, Brankas, Multi-Dompet & Cash Opname
    _totalBrankasFisik = await _db.getTotalSaldoBrankasFisik();
    final saldoDompet = await _db.getSaldoDompet();
    _kasLaciTunai = saldoDompet['tunai'] ?? 0;
    _rekeningBank = saldoDompet['rekening'] ?? 0;
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
        .where((item) => item.santri.estimasiHari < 3)
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
        if (item.santri.tunggakan <= 0) return false;
      } else if (_activeFilter == 'KRITIS') {
        if (item.santri.estimasiHari >= 3) return false;
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

    // Set 5-second undo
    _lastTransaction = tx;
    _lastSantri = santri;
    _undoCountdown = 5;

    _undoTimer?.cancel();
    _undoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_undoCountdown > 1) {
        _undoCountdown--;
        notifyListeners();
      } else {
        _undoCountdown = 0;
        _lastTransaction = null;
        _lastSantri = null;
        timer.cancel();
        notifyListeners();
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

    await markLocalDataChanged();
    await loadAllData();
  }

  void dismissUndo() {
    _undoTimer?.cancel();
    _lastTransaction = null;
    _lastSantri = null;
    _undoCountdown = 0;
    notifyListeners();
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
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<void> editTransaksi(String id, int newNominal, String? note) async {
    await _db.editTransaksi(id, newNominal, note);
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

  Future<void> updateSantriFoto(String santriId, String? fotoPath) async {
    await _db.updateSantriFoto(santriId, fotoPath);
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
    if (isEdit) {
      await _db.updateSantri(santri);
    } else {
      await _db.insertSantri(santri, sumberDompet: sumberDompet);
    }
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<void> deleteSantri(String santriId) async {
    await _db.deleteSantri(santriId);
    await markLocalDataChanged();
    await loadAllData();
  }

  // ==================== SANTRI BARU & PENGATURAN ====================

  Future<void> tambahSantriBaru(Santri santri, {String sumberDompet = 'TUNAI'}) async {
    await _db.insertSantri(santri, sumberDompet: sumberDompet);
    await markLocalDataChanged();
    await loadAllData();
  }

  Future<void> savePengaturan(PengaturanAplikasi updated) async {
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    await loadAllData();
  }

  Future<void> resetToInitialData() async {
    await _db.resetToInitialDemoData();
    await markLocalDataChanged();
    await loadAllData();
  }

  // ==================== BACKUP, RESTORE & GOOGLE DRIVE (PRO) ====================

  Future<void> restoreFromBackupJson(Map<String, dynamic> data) async {
    await _db.restoreFromJson(data);
    final restoredSettings = await _db.getPengaturan();
    await AuthService.instance.syncRestoredPinToSecureStorage(restoredSettings.pinKeamanan);
    await loadAllData();
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
}
