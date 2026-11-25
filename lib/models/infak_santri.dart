typedef InfakSantri = InfakSantriModel;

class InfakSantriModel {
  static const String berasBelum = 'BELUM';
  static const String berasFisik = 'FISIK';
  static const String berasUangVal = 'UANG';
  static const String berasBebas = 'BEBAS';

  static const String statusLunasVal = 'LUNAS';
  static const String statusCicilVal = 'CICIL';
  static const String statusBelumVal = 'BELUM';

  final String id;
  final String santriId;
  final String periodeBulan; // YYYY-MM
  final String tahunAjaran;
  final int nominalMasak;
  final bool isMasakBebas;
  final int nominalListrik;
  final bool isListrikBebas;
  final String jenisBeras; // BELUM, FISIK, UANG, BEBAS
  final double berasLiter;
  final int berasUang;
  final String tglMasuk; // YYYY-MM-DD
  final String tglHabis; // YYYY-MM-DD (+1 bulan)
  final String statusLunas; // LUNAS, CICIL, BELUM
  final String sumberDompet; // TUNAI, REKENING
  final String? setoranId;
  final String? catatan;
  final DateTime createdAt;

  InfakSantriModel({
    required this.id,
    required this.santriId,
    required this.periodeBulan,
    this.tahunAjaran = '2026/2027 M / 1448 H',
    this.nominalMasak = 0,
    this.isMasakBebas = false,
    this.nominalListrik = 0,
    this.isListrikBebas = false,
    this.jenisBeras = berasBelum,
    this.berasLiter = 0.0,
    this.berasUang = 0,
    required this.tglMasuk,
    String? tglHabis,
    String? statusLunas,
    this.sumberDompet = 'TUNAI',
    this.setoranId,
    this.catatan,
    DateTime? createdAt,
  })  : tglHabis = (tglHabis != null && tglHabis.isNotEmpty)
            ? tglHabis
            : hitungTglHabis(tglMasuk),
        statusLunas = (statusLunas != null && statusLunas.isNotEmpty)
            ? statusLunas
            : hitungStatusLunas(
                nominalMasak: nominalMasak,
                isMasakBebas: isMasakBebas,
                nominalListrik: nominalListrik,
                isListrikBebas: isListrikBebas,
                jenisBeras: jenisBeras,
                berasLiter: berasLiter,
                berasUang: berasUang,
              ),
        createdAt = createdAt ?? DateTime.now();

  int get totalUangMasuk => nominalMasak + nominalListrik + berasUang;

  static String hitungTglHabis(String tglMasukYmd) {
    final parts = tglMasukYmd.split('-');
    if (parts.length != 3) return tglMasukYmd;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return tglMasukYmd;

    final nextYear = m == 12 ? y + 1 : y;
    final nextMonth = m == 12 ? 1 : m + 1;
    final maxDay = DateTime(nextYear, nextMonth + 1, 0).day;
    final safeDay = d > maxDay ? maxDay : d;
    return '${nextYear.toString().padLeft(4, '0')}-'
        '${nextMonth.toString().padLeft(2, '0')}-'
        '${safeDay.toString().padLeft(2, '0')}';
  }

  static String hitungStatusLunas({
    required int nominalMasak,
    required bool isMasakBebas,
    required int nominalListrik,
    required bool isListrikBebas,
    required String jenisBeras,
    required double berasLiter,
    required int berasUang,
    int targetMasak = 130000,
    int targetListrik = 20000,
    double targetBerasLiter = 15.0,
    int targetBerasUang = 150000,
  }) {
    final masakOk = isMasakBebas || nominalMasak >= targetMasak;
    final listrikOk = isListrikBebas || nominalListrik >= targetListrik;
    final bool berasOk;
    if (jenisBeras == berasBebas) {
      berasOk = true;
    } else if (jenisBeras == berasFisik) {
      berasOk = berasLiter >= targetBerasLiter;
    } else if (jenisBeras == berasUangVal) {
      berasOk = berasUang >= targetBerasUang;
    } else {
      berasOk = false;
    }

    if (masakOk && listrikOk && berasOk) {
      return statusLunasVal;
    }

    final anyPaid = isMasakBebas ||
        nominalMasak > 0 ||
        isListrikBebas ||
        nominalListrik > 0 ||
        jenisBeras == berasBebas ||
        berasLiter > 0 ||
        berasUang > 0;
    return anyPaid ? statusCicilVal : statusBelumVal;
  }

  InfakSantriModel copyWith({
    String? id,
    String? santriId,
    String? periodeBulan,
    String? tahunAjaran,
    int? nominalMasak,
    bool? isMasakBebas,
    int? nominalListrik,
    bool? isListrikBebas,
    String? jenisBeras,
    double? berasLiter,
    int? berasUang,
    String? tglMasuk,
    String? tglHabis,
    String? statusLunas,
    String? sumberDompet,
    String? setoranId,
    String? catatan,
    DateTime? createdAt,
  }) {
    return InfakSantriModel(
      id: id ?? this.id,
      santriId: santriId ?? this.santriId,
      periodeBulan: periodeBulan ?? this.periodeBulan,
      tahunAjaran: tahunAjaran ?? this.tahunAjaran,
      nominalMasak: nominalMasak ?? this.nominalMasak,
      isMasakBebas: isMasakBebas ?? this.isMasakBebas,
      nominalListrik: nominalListrik ?? this.nominalListrik,
      isListrikBebas: isListrikBebas ?? this.isListrikBebas,
      jenisBeras: jenisBeras ?? this.jenisBeras,
      berasLiter: berasLiter ?? this.berasLiter,
      berasUang: berasUang ?? this.berasUang,
      tglMasuk: tglMasuk ?? this.tglMasuk,
      tglHabis: tglHabis ?? this.tglHabis,
      statusLunas: statusLunas ?? this.statusLunas,
      sumberDompet: sumberDompet ?? this.sumberDompet,
      setoranId: setoranId ?? this.setoranId,
      catatan: catatan ?? this.catatan,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'santri_id': santriId,
      'periode_bulan': periodeBulan,
      'tahun_ajaran': tahunAjaran,
      'nominal_masak': nominalMasak,
      'is_masak_bebas': isMasakBebas ? 1 : 0,
      'nominal_listrik': nominalListrik,
      'is_listrik_bebas': isListrikBebas ? 1 : 0,
      'jenis_beras': jenisBeras,
      'beras_liter': berasLiter,
      'beras_uang': berasUang,
      'tgl_masuk': tglMasuk,
      'tgl_habis': tglHabis,
      'status_lunas': statusLunas,
      'sumber_dompet': sumberDompet,
      'setoran_id': setoranId,
      'catatan': catatan,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory InfakSantriModel.fromMap(Map<String, dynamic> map) {
    final tglMasuk = map['tgl_masuk']?.toString() ?? '';
    return InfakSantriModel(
      id: map['id'].toString(),
      santriId: map['santri_id'].toString(),
      periodeBulan: map['periode_bulan']?.toString() ?? '',
      tahunAjaran: map['tahun_ajaran']?.toString() ?? '2026/2027 M / 1448 H',
      nominalMasak: (map['nominal_masak'] as num?)?.toInt() ?? 0,
      isMasakBebas: (map['is_masak_bebas'] as num?)?.toInt() == 1,
      nominalListrik: (map['nominal_listrik'] as num?)?.toInt() ?? 0,
      isListrikBebas: (map['is_listrik_bebas'] as num?)?.toInt() == 1,
      jenisBeras: map['jenis_beras']?.toString() ?? berasBelum,
      berasLiter: (map['beras_liter'] as num?)?.toDouble() ?? 0.0,
      berasUang: (map['beras_uang'] as num?)?.toInt() ?? 0,
      tglMasuk: tglMasuk,
      tglHabis: map['tgl_habis']?.toString(),
      statusLunas: map['status_lunas']?.toString(),
      sumberDompet: map['sumber_dompet']?.toString() ?? 'TUNAI',
      setoranId: map['setoran_id'] as String?,
      catatan: map['catatan'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
