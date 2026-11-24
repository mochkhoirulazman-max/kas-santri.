import 'santri.dart';
export 'santri.dart';
import 'transaksi.dart';
import '../utils/currency_formatter.dart';
import '../utils/time_category_helper.dart';

enum BadgeStatusHariIni {
  utuh, // 🟢 Belum ambil hari ini
  sebagian, // 🔵 Sudah ambil sebagian, masih ada sisa jatah
  limitHabis, // 🟡 Jatah hari ini sudah Rp 0
  overlimitKritis, // 🔴 Overlimit atau saldo hampir habis/habis
}

class SantriStatusHariIni {
  final Santri santri;
  final int totalAmbilHariIni;
  final int sisaJatahHariIni;
  final int jatahHariIni;
  final List<TransaksiHarian> transaksiHariIni;
  final bool hasOverlimitToday;

  SantriStatusHariIni({
    required this.santri,
    required this.totalAmbilHariIni,
    required this.sisaJatahHariIni,
    required this.jatahHariIni,
    required this.transaksiHariIni,
    this.hasOverlimitToday = false,
  });

  int get jumlahAmbilHariIni => transaksiHariIni.length;

  BadgeStatusHariIni get badgeStatus {
    if (hasOverlimitToday || santri.saldoTotal <= 0 || santri.saldoTotal < santri.jatahHarian) {
      return BadgeStatusHariIni.overlimitKritis;
    }
    if (totalAmbilHariIni == 0) {
      return BadgeStatusHariIni.utuh;
    }
    if (sisaJatahHariIni > 0) {
      return BadgeStatusHariIni.sebagian;
    }
    return BadgeStatusHariIni.limitHabis;
  }

  String get badgeLabel {
    switch (badgeStatus) {
      case BadgeStatusHariIni.utuh:
        return 'Utuh';
      case BadgeStatusHariIni.sebagian:
        return 'Sebagian';
      case BadgeStatusHariIni.limitHabis:
        return 'Limit Habis';
      case BadgeStatusHariIni.overlimitKritis:
        if (hasOverlimitToday) return 'Overlimit';
        return 'Saldo Kritis';
    }
  }

  /// Progress rasio jatah hari ini (0.0 sampai 1.0)
  double get progressRatio {
    if (jatahHariIni <= 0) return 1.0;
    final ratio = totalAmbilHariIni / jatahHariIni;
    if (ratio > 1.0) return 1.0;
    if (ratio < 0.0) return 0.0;
    return ratio;
  }

  /// Rasio sisa kuota hari ini: 1.0 (100% penuh saat utuh) lalu menyusut ke 0.0 saat terpakai
  double get remainingRatio {
    if (jatahHariIni <= 0) return 0.0;
    final ratio = sisaJatahHariIni / jatahHariIni;
    return ratio.clamp(0.0, 1.0);
  }

  /// Ringkasan teks pengambilan hari ini, contoh:
  /// "Hari ini sudah ambil 2x: Pagi 2rb, Siang 5rb"
  String get ringkasanAmbilHariIni {
    if (transaksiHariIni.isEmpty) {
      return 'Belum ambil hari ini';
    }
    final rincian = transaksiHariIni.map((t) {
      final kat = TimeCategoryHelper.getLabel(t.kategoriWaktu);
      final nom = CurrencyFormatter.formatCompact(t.nominal);
      return '$kat $nom';
    }).join(', ');

    return 'Sudah ambil ${transaksiHariIni.length}x: $rincian';
  }
}
