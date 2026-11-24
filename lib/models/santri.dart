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
  final String? fotoPath;
  final String qrCode;
  final bool statusAktif;
  final DateTime createdAt;

  static String generateQrCode(String id) {
    final clean = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (clean.isEmpty) return 'KS-SANTRI';
    final suffix = clean.length > 12 ? clean.substring(0, 12) : clean;
    return 'KS-$suffix';
  }

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
    this.fotoPath,
    String? qrCode,
    this.statusAktif = true,
    DateTime? createdAt,
  })  : qrCode = (qrCode != null && qrCode.trim().isNotEmpty)
            ? qrCode.trim()
            : generateQrCode(id),
        createdAt = createdAt ?? DateTime.now();

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
    String? fotoPath,
    String? qrCode,
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
      fotoPath: fotoPath ?? this.fotoPath,
      qrCode: qrCode ?? this.qrCode,
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
      'foto_path': fotoPath,
      'qr_code': qrCode,
      'status_aktif': statusAktif ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Santri.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String;
    return Santri(
      id: id,
      namaLengkap: map['nama_lengkap'] as String,
      namaPanggilan: map['nama_panggilan'] as String? ?? '',
      kamar: map['kamar'] as String,
      noWaWali: map['no_wa_wali'] as String?,
      saldoTotal: (map['saldo_total'] as num?)?.toInt() ?? 0,
      jatahHarian: (map['jatah_harian'] as num?)?.toInt() ?? 10000,
      setoranAwal: (map['setoran_awal'] as num?)?.toInt() ?? 300000,
      tunggakan: (map['tunggakan'] as num?)?.toInt() ?? 0,
      catatanTunggakan: map['catatan_tunggakan'] as String? ?? '',
      fotoPath: map['foto_path'] as String?,
      qrCode: map['qr_code'] as String?,
      statusAktif: (map['status_aktif'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
