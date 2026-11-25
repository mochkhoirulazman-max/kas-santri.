enum TipeSetoran { awalBulan, susulanTopUp, susulanTopup, sambanganSplit }

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
    final String tipeStr;
    switch (tipeSetoran) {
      case TipeSetoran.awalBulan:
        tipeStr = 'AWAL_BULAN';
        break;
      case TipeSetoran.sambanganSplit:
        tipeStr = 'SAMBANGAN_SPLIT';
        break;
      case TipeSetoran.susulanTopUp:
      case TipeSetoran.susulanTopup:
        tipeStr = 'SUSULAN_TOPUP';
        break;
    }
    return {
      'id': id,
      'santri_id': santriId,
      'nominal_setoran': nominalSetoran,
      'durasi_hari': durasiHari,
      'jatah_harian_hitung': jatahHarianHitung,
      'tipe_setoran': tipeStr,
      'tanggal_setor': tanggalSetor.toIso8601String().substring(0, 10),
      'catatan': catatan,
      'perlakuan_sisa': perlakuanSisa == PerlakuanSisaSaldoLalu.gabungBulanBaru
          ? 'GABUNG_BULAN_BARU'
          : 'SIMPAN_TABUNGAN',
    };
  }

  factory SetoranBulanan.fromMap(Map<String, dynamic> map) {
    final tipeRaw = map['tipe_setoran']?.toString();
    final TipeSetoran tipe;
    if (tipeRaw == 'SUSULAN_TOPUP') {
      tipe = TipeSetoran.susulanTopup;
    } else if (tipeRaw == 'SAMBANGAN_SPLIT') {
      tipe = TipeSetoran.sambanganSplit;
    } else {
      tipe = TipeSetoran.awalBulan;
    }
    return SetoranBulanan(
      id: map['id'] as String,
      santriId: map['santri_id'] as String,
      nominalSetoran: (map['nominal_setoran'] as num).toInt(),
      durasiHari: (map['durasi_hari'] as num).toInt(),
      jatahHarianHitung: (map['jatah_harian_hitung'] as num).toInt(),
      tipeSetoran: tipe,
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
