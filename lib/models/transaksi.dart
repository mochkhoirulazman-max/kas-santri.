import '../utils/time_category_helper.dart';

enum TipeTransaksi { pengambilan, setoran }

enum OverlimitHandling { potongBesok, hitungUlangRataRata }

class TransaksiHarian {
  final String id;
  final String santriId;
  final int nominal;
  final DateTime waktuAmbil;
  final String tanggalLokal; // YYYY-MM-DD
  final TimeCategory kategoriWaktu;
  final bool isOverlimit;
  final String? catatan;
  final bool isVoided;
  final OverlimitHandling? overlimitHandling;
  final int saldoSetelahTransaksi;
  final TipeTransaksi tipe;

  TransaksiHarian({
    required this.id,
    required this.santriId,
    required this.nominal,
    required this.waktuAmbil,
    required this.tanggalLokal,
    required this.kategoriWaktu,
    this.isOverlimit = false,
    this.catatan,
    this.isVoided = false,
    this.overlimitHandling,
    this.saldoSetelahTransaksi = 0,
    this.tipe = TipeTransaksi.pengambilan,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'santri_id': santriId,
      'nominal': nominal,
      'waktu_ambil': waktuAmbil.toIso8601String(),
      'tanggal_lokal': tanggalLokal,
      'kategori_waktu': TimeCategoryHelper.toDbString(kategoriWaktu),
      'is_overlimit': isOverlimit ? 1 : 0,
      'catatan': catatan,
      'is_voided': isVoided ? 1 : 0,
      'overlimit_handling': overlimitHandling == OverlimitHandling.potongBesok
          ? 'POTONG_BESOK'
          : overlimitHandling == OverlimitHandling.hitungUlangRataRata
              ? 'HITUNG_ULANG'
              : null,
      'saldo_setelah_transaksi': saldoSetelahTransaksi,
      'tipe': tipe == TipeTransaksi.setoran ? 'SETORAN' : 'PENGAMBILAN',
    };
  }

  factory TransaksiHarian.fromMap(Map<String, dynamic> map) {
    return TransaksiHarian(
      id: map['id'] as String,
      santriId: map['santri_id'] as String,
      nominal: (map['nominal'] as num).toInt(),
      waktuAmbil: map['waktu_ambil'] != null
          ? DateTime.tryParse(map['waktu_ambil'].toString()) ?? DateTime.now()
          : DateTime.now(),
      tanggalLokal: map['tanggal_lokal'] as String? ?? '',
      kategoriWaktu: TimeCategoryHelper.fromDbString(
        map['kategori_waktu'] as String? ?? 'PAGI',
      ),
      isOverlimit: (map['is_overlimit'] as int?) == 1,
      catatan: map['catatan'] as String?,
      isVoided: (map['is_voided'] as int?) == 1,
      overlimitHandling: map['overlimit_handling'] == 'POTONG_BESOK'
          ? OverlimitHandling.potongBesok
          : map['overlimit_handling'] == 'HITUNG_ULANG'
              ? OverlimitHandling.hitungUlangRataRata
              : null,
      saldoSetelahTransaksi: (map['saldo_setelah_transaksi'] as num?)?.toInt() ?? 0,
      tipe: map['tipe'] == 'SETORAN'
          ? TipeTransaksi.setoran
          : TipeTransaksi.pengambilan,
    );
  }
}
