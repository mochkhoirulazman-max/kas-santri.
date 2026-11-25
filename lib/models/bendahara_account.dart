class BendaharaAccount {
  static const String modeLocal = 'LOCAL';
  static const String modeGoogle = 'GOOGLE';
  static const String modeOfflineQuick = 'OFFLINE_QUICK';

  final String id;
  final String namaLengkap;
  final String jabatan;
  final String? username;
  final String? email;
  final String? passwordHash;
  final String? fotoPath;
  final String authMode;
  final DateTime createdAt;

  BendaharaAccount({
    required this.id,
    required this.namaLengkap,
    this.jabatan = 'Bendahara Pondok',
    this.username,
    this.email,
    this.passwordHash,
    this.fotoPath,
    this.authMode = modeLocal,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get authModeLabel {
    switch (authMode) {
      case modeGoogle:
        return 'Akun Google + Drive';
      case modeOfflineQuick:
        return 'Mode Offline Cepat';
      case modeLocal:
      default:
        return 'Akun Lokal Terdaftar';
    }
  }

  String get initials {
    final trimmed = namaLengkap.trim();
    if (trimmed.isEmpty) return 'BP';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  BendaharaAccount copyWith({
    String? id,
    String? namaLengkap,
    String? jabatan,
    String? username,
    String? email,
    String? passwordHash,
    String? fotoPath,
    bool clearFoto = false,
    String? authMode,
    DateTime? createdAt,
  }) {
    return BendaharaAccount(
      id: id ?? this.id,
      namaLengkap: namaLengkap ?? this.namaLengkap,
      jabatan: jabatan ?? this.jabatan,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      fotoPath: clearFoto ? null : (fotoPath ?? this.fotoPath),
      authMode: authMode ?? this.authMode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_lengkap': namaLengkap,
      'jabatan': jabatan,
      'username': username,
      'email': email,
      'password_hash': passwordHash,
      'foto_path': fotoPath,
      'auth_mode': authMode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BendaharaAccount.fromMap(Map<String, dynamic> map) {
    return BendaharaAccount(
      id: map['id'].toString(),
      namaLengkap: map['nama_lengkap']?.toString() ?? 'Bendahara Pondok',
      jabatan: map['jabatan']?.toString() ?? 'Bendahara Pondok',
      username: map['username'] as String?,
      email: map['email'] as String?,
      passwordHash: map['password_hash'] as String?,
      fotoPath: map['foto_path'] as String?,
      authMode: map['auth_mode']?.toString() ?? modeLocal,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
