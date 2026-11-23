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

  PengaturanAplikasi({
    this.id = 1,
    this.namaPondok = 'Pondok Pesantren Nurul Huda',
    this.namaPengurus = 'Ustadz Ahmad',
    this.kontakPengurus = '081234567890',
    this.defaultJatahHarian = 10000,
    this.defaultDurasiHari = 30,
    this.modeSisaHarian = ModeSisaHarian.ketat,
    this.pinKeamanan,
    this.isBiometricEnabled = false,
    this.autoLockMinutes = 1,
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
    };
  }

  factory PengaturanAplikasi.fromMap(Map<String, dynamic> map) {
    return PengaturanAplikasi(
      id: (map['id'] as num?)?.toInt() ?? 1,
      namaPondok: map['nama_pondok'] as String? ?? 'Pondok Pesantren Nurul Huda',
      namaPengurus: map['nama_pengurus'] as String? ?? 'Ustadz Ahmad',
      kontakPengurus: map['kontak_pengurus'] as String? ?? '',
      defaultJatahHarian: (map['default_jatah_harian'] as num?)?.toInt() ?? 10000,
      defaultDurasiHari: (map['default_durasi_hari'] as num?)?.toInt() ?? 30,
      modeSisaHarian: map['mode_sisa_harian'] == 'AKUMULASI'
          ? ModeSisaHarian.akumulasi
          : ModeSisaHarian.ketat,
      pinKeamanan: map['pin_keamanan'] as String?,
      isBiometricEnabled: (map['is_biometric_enabled'] as int?) == 1,
      autoLockMinutes: (map['auto_lock_minutes'] as num?)?.toInt() ?? 1,
    );
  }
}
