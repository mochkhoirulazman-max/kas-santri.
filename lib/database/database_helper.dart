import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/audit_log.dart';
import '../models/cash_opname_log.dart';
import '../models/infak_santri.dart';
import '../models/pengaturan.dart';
import '../models/santri.dart';
import '../models/serah_terima_infak.dart';
import '../models/setoran.dart';
import '../models/transaksi.dart';
import '../utils/time_category_helper.dart';
import 'repositories/backup_audit_repository.dart';
import 'repositories/infak_repository.dart';
import 'repositories/ledger_repository.dart';
import 'repositories/santri_repository.dart';
import 'schema_migrator.dart';

/// Facade utama basis data SQLite Kas-Santri v4.2 yang mendelegasikan operasi ke
/// 5 modul terfokus (`SchemaMigrator`, `SantriRepository`, `LedgerRepository`,
/// `InfakRepository`, dan `BackupAuditRepository`) dengan mempertahankan 100%
/// kompatibilitas API publik `DatabaseHelper.instance`.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  late final SchemaMigrator migrator = const SchemaMigrator();
  late final SantriRepository santriRepo = SantriRepository(() => database);
  late final LedgerRepository ledgerRepo = LedgerRepository(() => database);
  late final InfakRepository infakRepo = InfakRepository(() => database);
  late final BackupAuditRepository backupAuditRepo = BackupAuditRepository(
    () => database,
    migrator,
  );

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kas_santri_v2.db');
    return _database!;
  }

  void setDatabaseForTesting(Database? db) {
    _database = db;
  }

  Future<void> createSchemaForTesting(Database db) => migrator.createDB(db, 4);

  Future<void> createSchemaForTest(Database db) => createSchemaForTesting(db);

  Future<void> upgradeSchemaForTesting(
    Database db,
    int oldVersion,
    int newVersion,
  ) =>
      migrator.upgradeDB(db, oldVersion, newVersion);

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onConfigure: migrator.configureDatabase,
      onCreate: migrator.createDB,
      onUpgrade: migrator.upgradeDB,
      onOpen: migrator.ensureColumnsAndIndexes,
    );
  }

  // ==================== SANTRI & PENGATURAN ====================

  Future<List<Santri>> getAllSantri({bool onlyActive = true}) =>
      santriRepo.getAllSantri(onlyActive: onlyActive);

  Future<Santri?> getSantriById(String id) => santriRepo.getSantriById(id);

  Future<Santri?> getSantriByQrCode(String rawCode) =>
      santriRepo.getSantriByQrCode(rawCode);

  Future<int> insertSantri(Santri santri, {String sumberDompet = 'TUNAI'}) =>
      santriRepo.insertSantri(santri, sumberDompet: sumberDompet);

  Future<int> updateSantri(Santri santri) => santriRepo.updateSantri(santri);

  Future<void> updateSantriFoto(String santriId, String? fotoPath) =>
      santriRepo.updateSantriFoto(santriId, fotoPath);

  Future<void> quickUpdateSantri(
    String santriId, {
    required String namaLengkap,
    required String namaPanggilan,
    required String kamar,
    String? noWaWali,
    required int jatahHarian,
  }) =>
      santriRepo.quickUpdateSantri(
        santriId,
        namaLengkap: namaLengkap,
        namaPanggilan: namaPanggilan,
        kamar: kamar,
        noWaWali: noWaWali,
        jatahHarian: jatahHarian,
      );

  Future<void> toggleSantriStatus(String id, bool active) =>
      santriRepo.toggleSantriStatus(id, active);

  Future<int> deleteSantri(
    String santriId, {
    String sumberDompet = 'TUNAI',
  }) =>
      santriRepo.deleteSantri(santriId, sumberDompet: sumberDompet);

  Future<List<String>> getAllKamars() => santriRepo.getAllKamars();

  Future<int> bulkInsertSantri(
    List<Santri> santriList, {
    String sumberDompet = 'TUNAI',
  }) =>
      santriRepo.bulkInsertSantri(santriList, sumberDompet: sumberDompet);

  Future<int> bulkMoveKamar(List<String> santriIds, String newKamar) =>
      santriRepo.bulkMoveKamar(santriIds, newKamar);

  Future<int> bulkArchiveSantriStatus(
    List<String> santriIds, {
    required String newStatusSantri,
  }) =>
      santriRepo.bulkArchiveSantriStatus(
        santriIds,
        newStatusSantri: newStatusSantri,
      );

  Future<PengaturanAplikasi> getPengaturan() => santriRepo.getPengaturan();

  Future<void> updatePengaturan(PengaturanAplikasi pengaturan) =>
      santriRepo.updatePengaturan(pengaturan);

  // ==================== LEDGER, TRANSAKSI, SETORAN & MULTI-DOMPET ====================

  Future<void> kelolaTunggakan({
    required String santriId,
    required int nominal,
    required String catatan,
    required bool isBayar,
    String sumberDompet = 'TUNAI',
  }) =>
      ledgerRepo.kelolaTunggakan(
        santriId: santriId,
        nominal: nominal,
        catatan: catatan,
        isBayar: isBayar,
        sumberDompet: sumberDompet,
      );

  Future<int> getTotalTunggakanPondok() => ledgerRepo.getTotalTunggakanPondok();

  Future<int> getCountSantriTunggakan() => ledgerRepo.getCountSantriTunggakan();

  Future<SetoranBulanan> catatSetoranBaru({
    required String santriId,
    required int nominalSetoran,
    required int durasiHari,
    required int jatahHarianHitung,
    required TipeSetoran tipeSetoran,
    required DateTime tanggalSetor,
    String? catatan,
    PerlakuanSisaSaldoLalu perlakuanSisa =
        PerlakuanSisaSaldoLalu.gabungBulanBaru,
    OpsiSetoranSusulan? opsiSusulan,
    bool potongTunggakan = true,
    String metodeBayar = 'TUNAI',
  }) =>
      ledgerRepo.catatSetoranBaru(
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

  Future<List<SetoranBulanan>> getSetoranBySantri(String santriId) =>
      ledgerRepo.getSetoranBySantri(santriId);

  Future<List<Map<String, dynamic>>> getAllSetoranByDateRange({
    String? tanggalMulai,
    String? tanggalSelesai,
  }) =>
      ledgerRepo.getAllSetoranByDateRange(
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
      );

  Future<TransaksiHarian> catatPengambilan({
    required String santriId,
    required int nominal,
    String? catatan,
    bool isOverlimit = false,
    OverlimitHandling? overlimitHandling,
    TimeCategory? waktuCategory,
    DateTime? customTimestamp,
  }) =>
      ledgerRepo.catatPengambilan(
        santriId: santriId,
        nominal: nominal,
        catatan: catatan,
        isOverlimit: isOverlimit,
        overlimitHandling: overlimitHandling,
        waktuCategory: waktuCategory,
        customTimestamp: customTimestamp,
      );

  Future<void> voidTransaksi(String transaksiId) =>
      ledgerRepo.voidTransaksi(transaksiId);

  Future<void> editTransaksi(String id, int newNominal, String? note) =>
      ledgerRepo.editTransaksi(id, newNominal, note);

  Future<List<TransaksiHarian>> getBukuMutasiSantri(
    String santriId, {
    String? tanggalMulai,
    String? tanggalSelesai,
  }) =>
      ledgerRepo.getBukuMutasiSantri(
        santriId,
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
      );

  Future<int> getTotalPengambilanHariIni(
    String santriId,
    String tanggalLokal,
  ) =>
      ledgerRepo.getTotalPengambilanHariIni(santriId, tanggalLokal);

  Future<List<TransaksiHarian>> getTransaksiHariIni(
    String santriId,
    String tanggalLokal,
  ) =>
      ledgerRepo.getTransaksiHariIni(santriId, tanggalLokal);

  Future<Map<String, List<TransaksiHarian>>>
      getAllTransaksiPengambilanHariIniMap(String tanggalLokal) =>
          ledgerRepo.getAllTransaksiPengambilanHariIniMap(tanggalLokal);

  Future<Map<String, int>> computeEffectiveDailyQuotaMap({
    required String todayLokal,
    required List<Santri> activeSantri,
    required ModeSisaHarian modeSisaHarian,
  }) =>
      ledgerRepo.computeEffectiveDailyQuotaMap(
        todayLokal: todayLokal,
        activeSantri: activeSantri,
        modeSisaHarian: modeSisaHarian,
      );

  Future<List<TransaksiHarian>> getAllTransaksi({
    String? santriId,
    String? kategoriWaktu,
    String? tanggalMulai,
    String? tanggalSelesai,
    int? limit,
  }) =>
      ledgerRepo.getAllTransaksi(
        santriId: santriId,
        kategoriWaktu: kategoriWaktu,
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
        limit: limit,
      );

  Future<List<Map<String, dynamic>>> getRecentTransactedSantriIds({
    int limit = 6,
  }) =>
      ledgerRepo.getRecentTransactedSantriIds(limit: limit);

  Future<int> getTotalSaldoBrankasFisik() =>
      ledgerRepo.getTotalSaldoBrankasFisik();

  Future<int> getTotalPengeluaranHariIni(String tanggalLokal) =>
      ledgerRepo.getTotalPengeluaranHariIni(tanggalLokal);

  Future<int> getTotalPagiSiangHariIni(String tanggalLokal) =>
      ledgerRepo.getTotalPagiSiangHariIni(tanggalLokal);

  Future<int> getTotalSoreMalamHariIni(String tanggalLokal) =>
      ledgerRepo.getTotalSoreMalamHariIni(tanggalLokal);

  Future<int> getJumlahTransaksiHariIni(String tanggalLokal) =>
      ledgerRepo.getJumlahTransaksiHariIni(tanggalLokal);

  Future<Map<String, int>> getRekapKategoriHariIni(String tanggalLokal) =>
      ledgerRepo.getRekapKategoriHariIni(tanggalLokal);

  Future<List<Map<String, dynamic>>> getDetailTransaksiTanggal(
    String tanggalLokal,
  ) =>
      ledgerRepo.getDetailTransaksiTanggal(tanggalLokal);

  Future<Map<String, int>> getRekapBulanan(int tahun, int bulan) =>
      ledgerRepo.getRekapBulanan(tahun, bulan);

  Future<Map<String, int>> getSaldoDompet() => ledgerRepo.getSaldoDompet();

  Future<void> tarikTunaiKeLaci({required int nominal, String? catatan}) =>
      ledgerRepo.tarikTunaiKeLaci(nominal: nominal, catatan: catatan);

  Future<List<Map<String, dynamic>>> getRecentTarikTunaiLogs({int limit = 5}) =>
      ledgerRepo.getRecentTarikTunaiLogs(limit: limit);

  Future<void> insertCashOpnameLog(CashOpnameLog log) =>
      ledgerRepo.insertCashOpnameLog(log);

  Future<List<CashOpnameLog>> getCashOpnameLogs({int limit = 15}) =>
      ledgerRepo.getCashOpnameLogs(limit: limit);

  Future<List<Map<String, dynamic>>> getTransaksiByDateRange({
    String? tanggalMulai,
    String? tanggalSelesai,
  }) =>
      ledgerRepo.getTransaksiByDateRange(
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
      );

  Future<List<Map<String, dynamic>>> getAllMutasiDompet({
    String? tanggalMulai,
    String? tanggalSelesai,
  }) =>
      ledgerRepo.getAllMutasiDompet(
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
      );

  Future<int> getVoidCountSince(DateTime since) =>
      ledgerRepo.getVoidCountSince(since);

  // ==================== INFAK, SAMBANGAN & SERAH TERIMA ====================

  Future<void> upsertInfakSantri(InfakSantriModel infak) =>
      infakRepo.upsertInfakSantri(infak);

  Future<List<InfakSantriModel>> getInfakByPeriode(String periodeBulan) =>
      infakRepo.getInfakByPeriode(periodeBulan);

  Future<InfakSantriModel?> getInfakBySantriPeriode(
    String santriId,
    String periodeBulan,
  ) =>
      infakRepo.getInfakBySantriPeriode(santriId, periodeBulan);

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
  }) =>
      infakRepo.catatSambanganSmartSplit(
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

  Future<void> insertSerahTerimaInfak(SerahTerimaInfakModel item) =>
      infakRepo.insertSerahTerimaInfak(item);

  Future<void> deleteSerahTerimaInfak(String id) =>
      infakRepo.deleteSerahTerimaInfak(id);

  Future<List<SerahTerimaInfakModel>> getSerahTerimaInfak({
    String? periodeBulan,
  }) =>
      infakRepo.getSerahTerimaInfak(periodeBulan: periodeBulan);

  Future<Map<String, dynamic>> getSaldoKantongInfak() =>
      infakRepo.getSaldoKantongInfak();

  // ==================== BACKUP, SEED & AUDIT LOG ====================

  Future<Map<String, dynamic>> dumpBackupJson() =>
      backupAuditRepo.dumpBackupJson();

  Future<void> restoreFromJson(Map<String, dynamic> data) =>
      backupAuditRepo.restoreFromJson(data);

  Future<void> resetToInitialDemoData() async {
    final currentPengaturan = await getPengaturan();
    await backupAuditRepo.resetToInitialDemoData(currentPengaturan);
  }

  Future<void> seedDemoData({bool force = false}) =>
      backupAuditRepo.seedDemoData(force: force);

  Future<AuditLogEntry> insertAuditLog({
    required String actor,
    required String action,
    String? targetId,
    required String summary,
    DateTime? timestamp,
  }) =>
      backupAuditRepo.insertAuditLog(
        actor: actor,
        action: action,
        targetId: targetId,
        summary: summary,
        timestamp: timestamp,
      );

  Future<List<AuditLogEntry>> getAuditLogs({
    int limit = 200,
    String? actionFilter,
  }) =>
      backupAuditRepo.getAuditLogs(limit: limit, actionFilter: actionFilter);

  Future<AuditLogVerificationResult> verifyAuditLogIntegrity() =>
      backupAuditRepo.verifyAuditLogIntegrity();
}
