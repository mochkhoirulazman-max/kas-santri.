enum ModeSisaHarian { ketat, akumulasi }

class PengaturanAplikasi {
  final int id;
  final String namaPondok;
  final String namaPengurus;
  final String kontakPengurus;
  final int defaultJatahHarian;
  final int defaultDurasiHari;
  final ModeSisaHarian modeSisaHarian;
  final String? pinKeamanan;
  final bool isBiometricEnabled;
  final int autoLockMinutes;
  final String? logoPath;
  final bool isTwoColGrid;
  final bool hideBalance;

  PengaturanAplikasi({
    this.id = 1,
    this.namaPondok = 'PPS MIFTAHUSSUNAN',
    this.namaPengurus = 'Pengurus Kas & Keuangan',
    this.kontakPengurus = '081234567890',
    this.defaultJatahHarian = 10000,
    this.defaultDurasiHari = 30,
    this.modeSisaHarian = ModeSisaHarian.ketat,
    this.pinKeamanan = '1234',
    this.isBiometricEnabled = false,
    this.autoLockMinutes = 1,
    this.logoPath,
    this.isTwoColGrid = true,
    this.hideBalance = false,
  });

  PengaturanAplikasi copyWith({
    int? id,
    String? namaPondok,
    String? namaPengurus,
    String? kontakPengurus,
    int? defaultJatahHarian,
    int? defaultDurasiHari,
    ModeSisaHarian? modeSisaHarian,
    String? pinKeamanan,
    bool? isBiometricEnabled,
    int? autoLockMinutes,
    String? logoPath,
    bool? isTwoColGrid,
    bool? hideBalance,
  }) {
    return PengaturanAplikasi(
      id: id ?? this.id,
      namaPondok: namaPondok ?? this.namaPondok,
      namaPengurus: namaPengurus ?? this.namaPengurus,
      kontakPengurus: kontakPengurus ?? this.kontakPengurus,
      defaultJatahHarian: defaultJatahHarian ?? this.defaultJatahHarian,
      defaultDurasiHari: defaultDurasiHari ?? this.defaultDurasiHari,
      modeSisaHarian: modeSisaHarian ?? this.modeSisaHarian,
      pinKeamanan: pinKeamanan ?? this.pinKeamanan,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      logoPath: logoPath ?? this.logoPath,
      isTwoColGrid: isTwoColGrid ?? this.isTwoColGrid,
      hideBalance: hideBalance ?? this.hideBalance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_pondok': namaPondok,
      'nama_pengurus': namaPengurus,
      'kontak_pengurus': kontakPengurus,
      'default_jatah_harian': defaultJatahHarian,
      'default_durasi_hari': defaultDurasiHari,
      'mode_sisa_harian': modeSisaHarian == ModeSisaHarian.ketat ? 'KETAT' : 'AKUMULASI',
      'pin_keamanan': pinKeamanan,
      'is_biometric_enabled': isBiometricEnabled ? 1 : 0,
      'auto_lock_minutes': autoLockMinutes,
      'logo_path': logoPath,
      'is_two_col_grid': isTwoColGrid ? 1 : 0,
      'hide_balance': hideBalance ? 1 : 0,
    };
  }

  factory PengaturanAplikasi.fromMap(Map<String, dynamic> map) {
    return PengaturanAplikasi(
      id: (map['id'] as num?)?.toInt() ?? 1,
      namaPondok: map['nama_pondok'] as String? ?? 'PPS MIFTAHUSSUNAN',
      namaPengurus: map['nama_pengurus'] as String? ?? 'Pengurus Kas & Keuangan',
      kontakPengurus: map['kontak_pengurus'] as String? ?? '',
      defaultJatahHarian: (map['default_jatah_harian'] as num?)?.toInt() ?? 10000,
      defaultDurasiHari: (map['default_durasi_hari'] as num?)?.toInt() ?? 30,
      modeSisaHarian: map['mode_sisa_harian'] == 'AKUMULASI'
          ? ModeSisaHarian.akumulasi
          : ModeSisaHarian.ketat,
      pinKeamanan: map['pin_keamanan'] as String? ?? '1234',
      isBiometricEnabled: (map['is_biometric_enabled'] as int?) == 1,
      autoLockMinutes: (map['auto_lock_minutes'] as num?)?.toInt() ?? 1,
      logoPath: map['logo_path'] as String?,
      isTwoColGrid: map['is_two_col_grid'] != null ? (map['is_two_col_grid'] as int) == 1 : true,
      hideBalance: map['hide_balance'] != null ? (map['hide_balance'] as int) == 1 : false,
    );
  }
}
