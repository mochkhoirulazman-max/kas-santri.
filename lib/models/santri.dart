class Santri {
  final String id;
  final String namaLengkap;
  final String namaPanggilan;
  final String kamar;
  final String? noWaWali;
  final int saldoTotal;
  final int jatahHarian;
  final int setoranAwal;
  final int tunggakan;
  final String catatanTunggakan;
  final bool statusAktif;
  final DateTime createdAt;

  Santri({
    required this.id,
    required this.namaLengkap,
    required this.namaPanggilan,
    required this.kamar,
    this.noWaWali,
    this.saldoTotal = 0,
    this.jatahHarian = 10000,
    this.setoranAwal = 300000,
    this.tunggakan = 0,
    this.catatanTunggakan = '',
    this.statusAktif = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Estimasi berapa hari sisa saldo dapat mencukupi
  /// Estimasi Hari = floor(saldoTotal / jatahHarian)
  int get estimasiHari {
    if (jatahHarian <= 0) return 0;
    if (saldoTotal <= 0) return 0;
    return (saldoTotal / jatahHarian).floor();
  }

  Santri copyWith({
    String? id,
    String? namaLengkap,
    String? namaPanggilan,
    String? kamar,
    String? noWaWali,
    int? saldoTotal,
    int? jatahHarian,
    int? setoranAwal,
    int? tunggakan,
    String? catatanTunggakan,
    bool? statusAktif,
    DateTime? createdAt,
  }) {
    return Santri(
      id: id ?? this.id,
      namaLengkap: namaLengkap ?? this.namaLengkap,
      namaPanggilan: namaPanggilan ?? this.namaPanggilan,
      kamar: kamar ?? this.kamar,
      noWaWali: noWaWali ?? this.noWaWali,
      saldoTotal: saldoTotal ?? this.saldoTotal,
      jatahHarian: jatahHarian ?? this.jatahHarian,
      setoranAwal: setoranAwal ?? this.setoranAwal,
      tunggakan: tunggakan ?? this.tunggakan,
      catatanTunggakan: catatanTunggakan ?? this.catatanTunggakan,
      statusAktif: statusAktif ?? this.statusAktif,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_lengkap': namaLengkap,
      'nama_panggilan': namaPanggilan,
      'kamar': kamar,
      'no_wa_wali': noWaWali,
      'saldo_total': saldoTotal,
      'jatah_harian': jatahHarian,
      'setoran_awal': setoranAwal,
      'tunggakan': tunggakan,
      'catatan_tunggakan': catatanTunggakan,
      'status_aktif': statusAktif ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Santri.fromMap(Map<String, dynamic> map) {
    return Santri(
      id: map['id'] as String,
      namaLengkap: map['nama_lengkap'] as String,
      namaPanggilan: map['nama_panggilan'] as String? ?? '',
      kamar: map['kamar'] as String,
      noWaWali: map['no_wa_wali'] as String?,
      saldoTotal: (map['saldo_total'] as num?)?.toInt() ?? 0,
      jatahHarian: (map['jatah_harian'] as num?)?.toInt() ?? 10000,
      setoranAwal: (map['setoran_awal'] as num?)?.toInt() ?? 300000,
      tunggakan: (map['tunggakan'] as num?)?.toInt() ?? 0,
      catatanTunggakan: map['catatan_tunggakan'] as String? ?? '',
      statusAktif: (map['status_aktif'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
