typedef SerahTerimaInfak = SerahTerimaInfakModel;

class SerahTerimaInfakModel {
  final String id;
  final String tanggalSerah; // YYYY-MM-DD
  final String periodeBulan; // YYYY-MM
  final String posInfak; // GABUNGAN, MASAK, LISTRIK, BERAS_UANG, BERAS_FISIK
  final String sumberDompet; // TUNAI, REKENING, GUDANG_BERAS
  final int nominalUang;
  final double jumlahBerasLiter;
  final String penerima;
  final String? catatan;
  final DateTime createdAt;

  SerahTerimaInfakModel({
    required this.id,
    required this.tanggalSerah,
    required this.periodeBulan,
    this.posInfak = 'GABUNGAN',
    this.sumberDompet = 'TUNAI',
    this.nominalUang = 0,
    this.jumlahBerasLiter = 0.0,
    required this.penerima,
    this.catatan,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  SerahTerimaInfakModel copyWith({
    String? id,
    String? tanggalSerah,
    String? periodeBulan,
    String? posInfak,
    String? sumberDompet,
    int? nominalUang,
    double? jumlahBerasLiter,
    String? penerima,
    String? catatan,
    DateTime? createdAt,
  }) {
    return SerahTerimaInfakModel(
      id: id ?? this.id,
      tanggalSerah: tanggalSerah ?? this.tanggalSerah,
      periodeBulan: periodeBulan ?? this.periodeBulan,
      posInfak: posInfak ?? this.posInfak,
      sumberDompet: sumberDompet ?? this.sumberDompet,
      nominalUang: nominalUang ?? this.nominalUang,
      jumlahBerasLiter: jumlahBerasLiter ?? this.jumlahBerasLiter,
      penerima: penerima ?? this.penerima,
      catatan: catatan ?? this.catatan,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tanggal_serah': tanggalSerah,
      'periode_bulan': periodeBulan,
      'pos_infak': posInfak,
      'sumber_dompet': sumberDompet,
      'nominal_uang': nominalUang,
      'jumlah_beras_liter': jumlahBerasLiter,
      'penerima': penerima,
      'catatan': catatan,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SerahTerimaInfakModel.fromMap(Map<String, dynamic> map) {
    return SerahTerimaInfakModel(
      id: map['id'].toString(),
      tanggalSerah: map['tanggal_serah']?.toString() ?? '',
      periodeBulan: map['periode_bulan']?.toString() ?? '',
      posInfak: map['pos_infak']?.toString() ?? 'GABUNGAN',
      sumberDompet: map['sumber_dompet']?.toString() ?? 'TUNAI',
      nominalUang: (map['nominal_uang'] as num?)?.toInt() ?? 0,
      jumlahBerasLiter: (map['jumlah_beras_liter'] as num?)?.toDouble() ?? 0.0,
      penerima: map['penerima']?.toString() ?? '',
      catatan: map['catatan'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
