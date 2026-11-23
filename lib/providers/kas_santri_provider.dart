import 'dart:async';
import 'package:flutter/material.dart';
import '../models/santri.dart';
import '../models/setoran.dart';
import '../models/transaksi.dart';
import '../models/pengaturan.dart';
import '../models/santri_status.dart';
import '../database/database_helper.dart';
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

  // Stat Summary
  int _totalBrankasFisik = 0;
  int get totalBrankasFisik => _totalBrankasFisik;

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

    await _db.seedDemoData();
    await loadAllData();

    _isLoading = false;
    notifyListeners();
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

    // 2. Metrics & Brankas
    _totalBrankasFisik = await _db.getTotalSaldoBrankasFisik();
    _totalPengeluaranHariIni = await _db.getTotalPengeluaranHariIni(todayStr);
    _totalTunggakanPondok = await _db.getTotalTunggakanPondok();
    _rekapPagiSiang = await _db.getTotalPagiSiangHariIni(todayStr);
    _rekapSoreMalam = await _db.getTotalSoreMalamHariIni(todayStr);

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
  }) async {
    await _db.kelolaTunggakan(
      santriId: santriId,
      nominal: nominal,
      catatan: catatan,
      isBayar: isBayar,
    );
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
    );
    await loadAllData();
  }

  Future<void> voidTransaksi(String id) async {
    await _db.voidTransaksi(id);
    await loadAllData();
  }

  // ==================== SANTRI BARU & PENGATURAN ====================

  Future<void> tambahSantriBaru(Santri santri) async {
    await _db.insertSantri(santri);
    await loadAllData();
  }

  Future<void> savePengaturan(PengaturanAplikasi updated) async {
    _pengaturan = updated;
    await _db.updatePengaturan(updated);
    await loadAllData();
  }

  Future<void> resetToInitialData() async {
    await _db.resetToInitialDemoData();
    await loadAllData();
  }
}
