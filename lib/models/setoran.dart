enum TipeSetoran { awalBulan, susulanTopup }

enum OpsiSetoranSusulan { tambahJatahHarian, perpanjangHari }

enum PerlakuanSisaSaldoLalu { gabungBulanBaru, simpanTabungan }

class SetoranBulanan {
  final String id;
  final String santriId;
  final int nominalSetoran;
  final int durasiHari;
  final int jatahHarianHitung;
  final TipeSetoran tipeSetoran;
  final DateTime tanggalSetor;
  final String? catatan;
  final PerlakuanSisaSaldoLalu perlakuanSisa;

  SetoranBulanan({
    required this.id,
    required this.santriId,
    required this.nominalSetoran,
    required this.durasiHari,
    required this.jatahHarianHitung,
    required this.tipeSetoran,
    required this.tanggalSetor,
    this.catatan,
    this.perlakuanSisa = PerlakuanSisaSaldoLalu.gabungBulanBaru,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'santri_id': santriId,
      'nominal_setoran': nominalSetoran,
      'durasi_hari': durasiHari,
      'jatah_harian_hitung': jatahHarianHitung,
      'tipe_setoran': tipeSetoran == TipeSetoran.awalBulan ? 'AWAL_BULAN' : 'SUSULAN_TOPUP',
      'tanggal_setor': tanggalSetor.toIso8601String().substring(0, 10),
      'catatan': catatan,
      'perlakuan_sisa': perlakuanSisa == PerlakuanSisaSaldoLalu.gabungBulanBaru
          ? 'GABUNG_BULAN_BARU'
          : 'SIMPAN_TABUNGAN',
    };
  }

  factory SetoranBulanan.fromMap(Map<String, dynamic> map) {
    return SetoranBulanan(
      id: map['id'] as String,
      santriId: map['santri_id'] as String,
      nominalSetoran: (map['nominal_setoran'] as num).toInt(),
      durasiHari: (map['durasi_hari'] as num).toInt(),
      jatahHarianHitung: (map['jatah_harian_hitung'] as num).toInt(),
      tipeSetoran: map['tipe_setoran'] == 'SUSULAN_TOPUP'
          ? TipeSetoran.susulanTopup
          : TipeSetoran.awalBulan,
      tanggalSetor: map['tanggal_setor'] != null
          ? DateTime.tryParse(map['tanggal_setor'].toString()) ?? DateTime.now()
          : DateTime.now(),
      catatan: map['catatan'] as String?,
      perlakuanSisa: map['perlakuan_sisa'] == 'SIMPAN_TABUNGAN'
          ? PerlakuanSisaSaldoLalu.simpanTabungan
          : PerlakuanSisaSaldoLalu.gabungBulanBaru,
    );
  }
}
