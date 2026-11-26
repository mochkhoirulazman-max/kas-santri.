class TransaksiTabungan {
  static const String tipeSetor = 'SETOR_TABUNGAN';
  static const String tipeTarik = 'TARIK_TABUNGAN';
  static const String tipeTransferDariJajan = 'TRANSFER_DARI_JAJAN';
  static const String tipeTransferKeJajan = 'TRANSFER_KE_JAJAN';

  final String id;
  final String santriId;
  final String tipe;
  final int nominal;
  final String sumberDompet;
  final int saldoTabunganSetelah;
  final String tanggalLokal;
  final String? catatan;
  final bool isVoided;
  final DateTime createdAt;

  // Kolom opsional hasil JOIN untuk tampilan daftar mutasi
  final String? namaSantri;
  final String? kamarSantri;

  const TransaksiTabungan({
    required this.id,
    required this.santriId,
    required this.tipe,
    required this.nominal,
    this.sumberDompet = 'TUNAI',
    this.saldoTabunganSetelah = 0,
    required this.tanggalLokal,
    this.catatan,
    this.isVoided = false,
    required this.createdAt,
    this.namaSantri,
    this.kamarSantri,
  });

  bool get isMasuk =>
      tipe == tipeSetor || tipe == tipeTransferDariJajan;

  bool get isTransfer =>
      tipe == tipeTransferDariJajan || tipe == tipeTransferKeJajan;

  String get tipeLabel {
    switch (tipe) {
      case tipeSetor:
        return 'Setor Tabungan';
      case tipeTarik:
        return 'Tarik Tabungan';
      case tipeTransferDariJajan:
        return 'Pindah Jajan → Tabungan';
      case tipeTransferKeJajan:
        return 'Pindah Tabungan → Jajan';
      default:
        return tipe;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'santri_id': santriId,
      'tipe': tipe,
      'nominal': nominal,
      'sumber_dompet': sumberDompet,
      'saldo_tabungan_setelah': saldoTabunganSetelah,
      'tanggal_lokal': tanggalLokal,
      'catatan': catatan,
      'is_void': isVoided ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransaksiTabungan.fromMap(Map<String, dynamic> map) {
    final dompetRaw = (map['sumber_dompet'] as String? ?? 'TUNAI').toUpperCase();
    final normalizedDompet =
        (dompetRaw == 'REKENING' || dompetRaw == 'BANK' || dompetRaw == 'TRANSFER')
            ? 'REKENING'
            : 'TUNAI';
    return TransaksiTabungan(
      id: map['id'] as String,
      santriId: map['santri_id'] as String,
      tipe: map['tipe'] as String? ?? tipeSetor,
      nominal: (map['nominal'] as num?)?.toInt() ?? 0,
      sumberDompet: normalizedDompet,
      saldoTabunganSetelah:
          (map['saldo_tabungan_setelah'] as num?)?.toInt() ?? 0,
      tanggalLokal: map['tanggal_lokal'] as String? ?? '',
      catatan: map['catatan'] as String?,
      isVoided: (map['is_void'] as num?)?.toInt() == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      namaSantri: map['nama_santri'] as String?,
      kamarSantri: map['kamar_santri'] as String?,
    );
  }
}
