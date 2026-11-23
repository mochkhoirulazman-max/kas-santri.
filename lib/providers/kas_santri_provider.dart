import 'dart:async';
import 'package:flutter/material.dart';
import '../models/santri.dart';
import '../models/setoran.dart';
import '../models/transaksi.dart';
import '../models/pengaturan.dart';
import '../models/santri_status.dart';
import '../database/database_helper.dart';
import '../utils/date_formatter.dart';

class KasSantriProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<Santri> _allSantri = [];
  List<Santri> get allSantri => _allSantri;

  List<SantriStatusHariIni> _santriStatusList = [];
  List<SantriStatusHariIni> get santriStatusList => _santriStatusList;

  List<Santri> _recentSantri = [];
  List<Santri> get recentSantri => _recentSantri;

  List<String> _kamars = [];
  List<String> get kamars => _kamars;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String? _selectedKamar;
  String? get selectedKamar => _selectedKamar;

  PengaturanAplikasi _pengaturan = PengaturanAplikasi();
  PengaturanAplikasi get pengaturan => _pengaturan;

  // Stat summary
  int _totalBrankasFisik = 0;
  int get totalBrankasFisik => _totalBrankasFisik;

  int _totalPengeluaranHariIni = 0;
  int get totalPengeluaranHariIni => _totalPengeluaranHariIni;

  int _jumlahTransaksiHariIni = 0;
  int get jumlahTransaksiHariIni => _jumlahTransaksiHariIni;

  Map<String, int> _rekapKategoriHariIni = {};
  Map<String, int> get rekapKategoriHariIni => _rekapKategoriHariIni;

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

    // 1. Hitung status hari ini untuk setiap santri
    List<SantriStatusHariIni> statuses = [];
    for (var santri in _allSantri.where((s) => s.statusAktif)) {
      final txHariIni = await _db.getTransaksiHariIni(santri.id, todayStr);
      final totalAmbil = await _db.getTotalPengambilanHariIni(santri.id, todayStr);
      
      int sisaJatah = santri.jatahHarian - totalAmbil;
      if (sisaJatah < 0) sisaJatah = 0;

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

    // 2. Ambil santri yang baru saja / sering bertransaksi
    final recentRows = await _db.getRecentTransactedSantriIds(limit: 6);
    List<Santri> recents = [];
    for (var row in recentRows) {
      final sId = row['santri_id'] as String;
      final match = _allSantri.where((s) => s.id == sId).firstOrNull;
      if (match != null && match.statusAktif) {
        recents.add(match);
      }
    }
    _recentSantri = recents;

    // 3. Ringkasan Kas & Brankas Fisik
    _totalBrankasFisik = await _db.getTotalSaldoBrankasFisik();
    _totalPengeluaranHariIni = await _db.getTotalPengeluaranHariIni(todayStr);
    _jumlahTransaksiHariIni = await _db.getJumlahTransaksiHariIni(todayStr);
    _rekapKategoriHariIni = await _db.getRekapKategoriHariIni(todayStr);

    notifyListeners();
  }

  // Filter santri
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedKamar(String? kamar) {
    _selectedKamar = kamar;
    notifyListeners();
  }

  List<SantriStatusHariIni> get filteredSantriStatusList {
    return _santriStatusList.where((item) {
      final matchesKamar = _selectedKamar == null ||
          _selectedKamar!.isEmpty ||
          item.santri.kamar == _selectedKamar;

      if (!matchesKamar) return false;

      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      final matchNama = item.santri.namaLengkap.toLowerCase().contains(query);
      final matchPanggilan = item.santri.namaPanggilan.toLowerCase().contains(query);
      final matchKamar = item.santri.kamar.toLowerCase().contains(query);

      return matchNama || matchPanggilan || matchKamar;
    }).toList();
  }

  // ==================== CATAT TRANSAKSI CEPAT (3-TAP UX) ====================

  Future<TransaksiHarian> catatPengambilan({
    required Santri santri,
    required int nominal,
    String? catatan,
    bool isOverlimit = false,
    OverlimitHandling? overlimitHandling,
  }) async {
    final tx = await _db.catatPengambilan(
      santriId: santri.id,
      nominal: nominal,
      catatan: catatan,
      isOverlimit: isOverlimit,
      overlimitHandling: overlimitHandling,
    );

    // Siapkan Undo 5 Detik
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

  /// Eksekusi Undo Transaksi dalam rentang 5 detik
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

  // ==================== MUTASI & SETORAN ====================

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

  Future<void> editTransaksi(String id, int nominal, String? catatan) async {
    await _db.editTransaksi(id, nominal, catatan);
    await loadAllData();
  }

  // ==================== KELOLA SANTRI ====================

  Future<void> saveSantri(Santri santri, {bool isEdit = false}) async {
    if (isEdit) {
      await _db.updateSantri(santri);
    } else {
      await _db.insertSantri(santri);
    }
    await loadAllData();
  }

  Future<void> toggleSantriActive(String id, bool active) async {
    await _db.toggleSantriStatus(id, active);
    await loadAllData();
  }

  Future<void> updateJatahKhusus(String santriId, int jatahBaru) async {
    final santri = await _db.getSantriById(santriId);
    if (santri != null) {
      await _db.updateSantri(santri.copyWith(jatahHarian: jatahBaru));
      await loadAllData();
    }
  }

  // ==================== PENGATURAN ====================

  Future<void> savePengaturan(PengaturanAplikasi pengaturan) async {
    await _db.updatePengaturan(pengaturan);
    _pengaturan = pengaturan;
    notifyListeners();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }
}
