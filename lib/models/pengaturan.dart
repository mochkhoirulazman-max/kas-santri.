enum ModeSisaHarian { ketat, akumulasi }

typedef PengaturanModel = PengaturanAplikasi;

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
  final int pembulatanJatah;
  final bool isPro;
  final String? proPlan;
  final bool onboardingDone;
  final String? lastDriveBackupAt;
  final bool autoDriveBackup;
  final String? driveAccountEmail;
  final String? trialStartedAt;
  final String? trialExpiresAt;
  final bool hasUsedTrial;
  final String tahunAjaran;
  final int defaultInfakMasak;
  final int defaultInfakListrik;
  final double defaultInfakBerasLiter;
  final int defaultInfakBerasUang;

  PengaturanAplikasi({
    this.id = 1,
    this.namaPondok = 'Nama Pondok',
    this.namaPengurus = 'Pengurus Kas & Keuangan',
    this.kontakPengurus = '081234567890',
    this.defaultJatahHarian = 10000,
    this.defaultDurasiHari = 30,
    this.modeSisaHarian = ModeSisaHarian.ketat,
    this.pinKeamanan,
    this.isBiometricEnabled = false,
    this.autoLockMinutes = 1,
    this.logoPath,
    this.isTwoColGrid = true,
    this.hideBalance = false,
    this.pembulatanJatah = 500,
    this.isPro = false,
    this.proPlan,
    this.onboardingDone = false,
    this.lastDriveBackupAt,
    this.autoDriveBackup = false,
    this.driveAccountEmail,
    this.trialStartedAt,
    this.trialExpiresAt,
    this.hasUsedTrial = false,
    this.tahunAjaran = '2026/2027 M / 1448 H',
    this.defaultInfakMasak = 130000,
    this.defaultInfakListrik = 20000,
    this.defaultInfakBerasLiter = 15.0,
    this.defaultInfakBerasUang = 150000,
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
    bool clearPin = false,
    bool? isBiometricEnabled,
    int? autoLockMinutes,
    String? logoPath,
    bool? isTwoColGrid,
    bool? hideBalance,
    int? pembulatanJatah,
    bool? isPro,
    String? proPlan,
    bool clearProPlan = false,
    bool? onboardingDone,
    String? lastDriveBackupAt,
    bool clearLastDriveBackup = false,
    bool? autoDriveBackup,
    String? driveAccountEmail,
    bool clearDriveAccount = false,
    String? trialStartedAt,
    String? trialExpiresAt,
    bool? hasUsedTrial,
    String? tahunAjaran,
    int? defaultInfakMasak,
    int? defaultInfakListrik,
    double? defaultInfakBerasLiter,
    int? defaultInfakBerasUang,
  }) {
    return PengaturanAplikasi(
      id: id ?? this.id,
      namaPondok: namaPondok ?? this.namaPondok,
      namaPengurus: namaPengurus ?? this.namaPengurus,
      kontakPengurus: kontakPengurus ?? this.kontakPengurus,
      defaultJatahHarian: defaultJatahHarian ?? this.defaultJatahHarian,
      defaultDurasiHari: defaultDurasiHari ?? this.defaultDurasiHari,
      modeSisaHarian: modeSisaHarian ?? this.modeSisaHarian,
      pinKeamanan: clearPin ? null : (pinKeamanan ?? this.pinKeamanan),
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      logoPath: logoPath ?? this.logoPath,
      isTwoColGrid: isTwoColGrid ?? this.isTwoColGrid,
      hideBalance: hideBalance ?? this.hideBalance,
      pembulatanJatah: pembulatanJatah ?? this.pembulatanJatah,
      isPro: isPro ?? this.isPro,
      proPlan: clearProPlan ? null : (proPlan ?? this.proPlan),
      onboardingDone: onboardingDone ?? this.onboardingDone,
      lastDriveBackupAt: clearLastDriveBackup
          ? null
          : (lastDriveBackupAt ?? this.lastDriveBackupAt),
      autoDriveBackup: autoDriveBackup ?? this.autoDriveBackup,
      driveAccountEmail: clearDriveAccount
          ? null
          : (driveAccountEmail ?? this.driveAccountEmail),
      trialStartedAt: trialStartedAt ?? this.trialStartedAt,
      trialExpiresAt: trialExpiresAt ?? this.trialExpiresAt,
      hasUsedTrial: hasUsedTrial ?? this.hasUsedTrial,
      tahunAjaran: tahunAjaran ?? this.tahunAjaran,
      defaultInfakMasak: defaultInfakMasak ?? this.defaultInfakMasak,
      defaultInfakListrik: defaultInfakListrik ?? this.defaultInfakListrik,
      defaultInfakBerasLiter: defaultInfakBerasLiter ?? this.defaultInfakBerasLiter,
      defaultInfakBerasUang: defaultInfakBerasUang ?? this.defaultInfakBerasUang,
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
      'pembulatan_jatah': pembulatanJatah,
      'is_pro': isPro ? 1 : 0,
      'pro_plan': proPlan,
      'onboarding_done': onboardingDone ? 1 : 0,
      'last_drive_backup_at': lastDriveBackupAt,
      'auto_drive_backup': autoDriveBackup ? 1 : 0,
      'drive_account_email': driveAccountEmail,
      'trial_started_at': trialStartedAt,
      'trial_expires_at': trialExpiresAt,
      'has_used_trial': hasUsedTrial ? 1 : 0,
      'tahun_ajaran': tahunAjaran,
      'default_infak_masak': defaultInfakMasak,
      'default_infak_listrik': defaultInfakListrik,
      'default_infak_beras_liter': defaultInfakBerasLiter,
      'default_infak_beras_uang': defaultInfakBerasUang,
    };
  }

  factory PengaturanAplikasi.fromMap(Map<String, dynamic> map) {
    final pinRaw = map['pin_keamanan'] as String?;
    final driveEmailRaw = map['drive_account_email'] as String?;
    final lastBackupRaw = map['last_drive_backup_at'] as String?;
    final trialStartedRaw = map['trial_started_at'] as String?;
    final trialExpiresRaw = map['trial_expires_at'] as String?;
    final taRaw = map['tahun_ajaran'] as String?;
    return PengaturanAplikasi(
      id: (map['id'] as num?)?.toInt() ?? 1,
      namaPondok: map['nama_pondok'] as String? ?? 'Nama Pondok',
      namaPengurus: map['nama_pengurus'] as String? ?? 'Pengurus Kas & Keuangan',
      kontakPengurus: map['kontak_pengurus'] as String? ?? '',
      defaultJatahHarian: (map['default_jatah_harian'] as num?)?.toInt() ?? 10000,
      defaultDurasiHari: (map['default_durasi_hari'] as num?)?.toInt() ?? 30,
      modeSisaHarian: map['mode_sisa_harian'] == 'AKUMULASI'
          ? ModeSisaHarian.akumulasi
          : ModeSisaHarian.ketat,
      pinKeamanan: (pinRaw != null && pinRaw.isNotEmpty) ? pinRaw : null,
      isBiometricEnabled: (map['is_biometric_enabled'] as int?) == 1,
      autoLockMinutes: (map['auto_lock_minutes'] as num?)?.toInt() ?? 1,
      logoPath: map['logo_path'] as String?,
      isTwoColGrid: map['is_two_col_grid'] != null ? (map['is_two_col_grid'] as int) == 1 : true,
      hideBalance: map['hide_balance'] != null ? (map['hide_balance'] as int) == 1 : false,
      pembulatanJatah: (map['pembulatan_jatah'] as num?)?.toInt() ?? 500,
      isPro: (map['is_pro'] as int?) == 1,
      proPlan: map['pro_plan'] as String?,
      onboardingDone: (map['onboarding_done'] as int?) == 1,
      lastDriveBackupAt:
          (lastBackupRaw != null && lastBackupRaw.isNotEmpty) ? lastBackupRaw : null,
      autoDriveBackup: (map['auto_drive_backup'] as int?) == 1,
      driveAccountEmail:
          (driveEmailRaw != null && driveEmailRaw.isNotEmpty) ? driveEmailRaw : null,
      trialStartedAt:
          (trialStartedRaw != null && trialStartedRaw.isNotEmpty) ? trialStartedRaw : null,
      trialExpiresAt:
          (trialExpiresRaw != null && trialExpiresRaw.isNotEmpty) ? trialExpiresRaw : null,
      hasUsedTrial: (map['has_used_trial'] as int?) == 1,
      tahunAjaran: (taRaw != null && taRaw.trim().isNotEmpty)
          ? taRaw.trim()
          : '2026/2027 M / 1448 H',
      defaultInfakMasak: (map['default_infak_masak'] as num?)?.toInt() ?? 130000,
      defaultInfakListrik: (map['default_infak_listrik'] as num?)?.toInt() ?? 20000,
      defaultInfakBerasLiter:
          (map['default_infak_beras_liter'] as num?)?.toDouble() ?? 15.0,
      defaultInfakBerasUang:
          (map['default_infak_beras_uang'] as num?)?.toInt() ?? 150000,
    );
  }
}
