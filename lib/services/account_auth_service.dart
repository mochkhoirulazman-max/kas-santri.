import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/bendahara_account.dart';
import 'google_drive_backup_service.dart';

class AccountAuthService {
  static final AccountAuthService instance = AccountAuthService._init();
  AccountAuthService._init();

  static const String _keyAccountsJson = 'ks_v32_bendahara_accounts';
  static const String _keyActiveAccountId = 'ks_v32_active_account_id';
  static const String _keyRememberSession = 'ks_v32_remember_session';
  static const String _keyExplicitlyLoggedOut = 'ks_v32_explicitly_logged_out';

  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _generateSalt16Base64() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Hash password dengan random 16-byte salt per akun (`v33:<salt>:<sha256>`).
  static String hashPassword(String usernameOrEmail, String password, {String? salt}) {
    final normalized = usernameOrEmail.trim().toLowerCase();
    final s = salt ?? _generateSalt16Base64();
    final bytes = utf8.encode('ks_v33_pwd:$s:$normalized:$password');
    final digest = sha256.convert(bytes).toString();
    return 'v33:$s:$digest';
  }

  /// Format hash legacy v3.2 untuk kompatibilitas migrasi akun lama.
  static String _hashLegacyV32Password(String usernameOrEmail, String password) {
    final normalized = usernameOrEmail.trim().toLowerCase();
    final bytes = utf8.encode('ks_v32_pwd:$normalized:$password');
    return sha256.convert(bytes).toString();
  }

  static bool verifyPasswordHash({
    required String usernameOrEmail,
    required String password,
    required String? storedHash,
  }) {
    if (storedHash == null || storedHash.isEmpty) return false;
    if (storedHash.startsWith('v33:')) {
      final parts = storedHash.split(':');
      if (parts.length != 3 || parts[1].isEmpty) return false;
      return hashPassword(usernameOrEmail, password, salt: parts[1]) == storedHash;
    }
    return storedHash == _hashLegacyV32Password(usernameOrEmail, password);
  }

  Future<String?> _readSecureOrPref(String key) async {
    try {
      final sec = await _secureStorage.read(key: key);
      if (sec != null && sec.isNotEmpty) return sec;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> _writeSecureAndClearPref(String key, String value) async {
    bool written = false;
    try {
      await _secureStorage.write(key: key, value: value);
      written = true;
    } catch (_) {
      written = false;
    }
    final prefs = await SharedPreferences.getInstance();
    if (written) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  Future<List<BendaharaAccount>> getAllAccounts() async {
    final raw = await _readSecureOrPref(_keyAccountsJson);
    if (raw == null || raw.trim().isEmpty) return [];
    // Migrasi transparan dari SharedPreferences ke SecureStorage jika baru dibaca dari prefs
    await _writeSecureAndClearPref(_keyAccountsJson, raw);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => BendaharaAccount.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAccounts(List<BendaharaAccount> list) async {
    final encoded = jsonEncode(list.map((a) => a.toMap()).toList());
    await _writeSecureAndClearPref(_keyAccountsJson, encoded);
  }

  Future<bool> getRememberSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberSession) ?? true;
  }

  Future<bool> isExplicitlyLoggedOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyExplicitlyLoggedOut) ?? false;
  }

  Future<BendaharaAccount?> getActiveAccount() async {
    final activeId = await _readSecureOrPref(_keyActiveAccountId);
    if (activeId == null || activeId.isEmpty) return null;
    final accounts = await getAllAccounts();
    for (final acc in accounts) {
      if (acc.id == activeId) return acc;
    }
    return null;
  }

  Future<void> _setActiveSession(
    String accountId, {
    required bool rememberSession,
  }) async {
    await _writeSecureAndClearPref(_keyActiveAccountId, accountId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberSession, rememberSession);
    await prefs.setBool(_keyExplicitlyLoggedOut, false);
  }

  /// Menjamin pengguna upgrade lama (onboardingDone = true) tetap langsung masuk tanpa terkunci
  Future<BendaharaAccount?> ensureLegacySessionIfNeeded(
    String fallbackNamaPengurus,
  ) async {
    final active = await getActiveAccount();
    if (active != null) return active;

    final explicitlyLoggedOut = await isExplicitlyLoggedOut();
    if (explicitlyLoggedOut) return null;

    return await enterOfflineQuickMode(
      namaLengkap: fallbackNamaPengurus.trim().isNotEmpty
          ? fallbackNamaPengurus.trim()
          : 'Pengurus Kas & Keuangan',
      jabatan: 'Bendahara Pondok',
      rememberSession: true,
    );
  }

  Future<BendaharaAccount> registerLocalAccount({
    required String namaLengkap,
    required String jabatan,
    required String username,
    required String password,
    bool rememberSession = true,
  }) async {
    final cleanName = namaLengkap.trim();
    final cleanJabatan =
        jabatan.trim().isNotEmpty ? jabatan.trim() : 'Bendahara Pondok';
    final cleanUser = username.trim().toLowerCase();

    if (cleanName.isEmpty) {
      throw Exception('Nama lengkap bendahara wajib diisi.');
    }
    if (cleanUser.length < 3) {
      throw Exception('Username atau email minimal 3 karakter.');
    }
    if (password.length < 6) {
      throw Exception('Password minimal 6 karakter.');
    }

    final accounts = await getAllAccounts();
    final duplicate = accounts.any(
      (a) =>
          a.authMode == BendaharaAccount.modeLocal &&
          ((a.username?.toLowerCase() == cleanUser) ||
              (a.email?.toLowerCase() == cleanUser)),
    );
    if (duplicate) {
      throw Exception('Username / email "$cleanUser" sudah terdaftar.');
    }

    final account = BendaharaAccount(
      id: const Uuid().v4(),
      namaLengkap: cleanName,
      jabatan: cleanJabatan,
      username: cleanUser,
      email: cleanUser.contains('@') ? cleanUser : null,
      passwordHash: hashPassword(cleanUser, password),
      authMode: BendaharaAccount.modeLocal,
    );

    accounts.add(account);
    await _saveAccounts(accounts);
    await _setActiveSession(account.id, rememberSession: rememberSession);
    return account;
  }

  Future<BendaharaAccount> loginLocal({
    required String username,
    required String password,
    bool rememberSession = true,
  }) async {
    final cleanUser = username.trim().toLowerCase();
    if (cleanUser.isEmpty || password.isEmpty) {
      throw Exception('Username/email dan password wajib diisi.');
    }

    final accounts = await getAllAccounts();

    for (var i = 0; i < accounts.length; i++) {
      final acc = accounts[i];
      if (acc.authMode != BendaharaAccount.modeLocal) continue;
      final matchUser = (acc.username?.toLowerCase() == cleanUser) ||
          (acc.email?.toLowerCase() == cleanUser);
      if (matchUser &&
          verifyPasswordHash(
            usernameOrEmail: cleanUser,
            password: password,
            storedHash: acc.passwordHash,
          )) {
        var resolved = acc;
        // Auto-upgrade hash legacy ke random 16-byte salted v3.3
        if (acc.passwordHash == null || !acc.passwordHash!.startsWith('v33:')) {
          resolved = acc.copyWith(passwordHash: hashPassword(cleanUser, password));
          accounts[i] = resolved;
          await _saveAccounts(accounts);
        }
        await _setActiveSession(resolved.id, rememberSession: rememberSession);
        return resolved;
      }
    }

    throw Exception('Username/email atau password salah.');
  }

  Future<BendaharaAccount> loginWithGoogle({
    bool rememberSession = true,
  }) async {
    final googleAccount = await GoogleDriveBackupService.instance.signInInteractive();
    if (googleAccount == null) {
      throw Exception('Login Google dibatalkan atau gagal tersambung.');
    }

    final email = googleAccount.email.trim().toLowerCase();
    final displayName = (googleAccount.displayName?.trim().isNotEmpty == true)
        ? googleAccount.displayName!.trim()
        : email.split('@').first;

    final accounts = await getAllAccounts();
    final existingIdx = accounts.indexWhere(
      (a) =>
          a.authMode == BendaharaAccount.modeGoogle &&
          a.email?.toLowerCase() == email,
    );

    final BendaharaAccount account;
    if (existingIdx >= 0) {
      account = accounts[existingIdx].copyWith(
        namaLengkap: displayName,
        email: email,
      );
      accounts[existingIdx] = account;
    } else {
      account = BendaharaAccount(
        id: const Uuid().v4(),
        namaLengkap: displayName,
        jabatan: 'Bendahara Pondok',
        email: email,
        username: email,
        authMode: BendaharaAccount.modeGoogle,
      );
      accounts.add(account);
    }

    await _saveAccounts(accounts);
    await _setActiveSession(account.id, rememberSession: rememberSession);
    return account;
  }

  Future<BendaharaAccount> enterOfflineQuickMode({
    required String namaLengkap,
    String jabatan = 'Bendahara Pondok',
    bool rememberSession = true,
  }) async {
    final cleanName = namaLengkap.trim().isNotEmpty
        ? namaLengkap.trim()
        : 'Bendahara Cepat (Offline)';
    final cleanJabatan =
        jabatan.trim().isNotEmpty ? jabatan.trim() : 'Bendahara Pondok';

    final accounts = await getAllAccounts();
    final existingIdx = accounts.indexWhere(
      (a) => a.authMode == BendaharaAccount.modeOfflineQuick,
    );

    final BendaharaAccount account;
    if (existingIdx >= 0) {
      account = accounts[existingIdx].copyWith(
        namaLengkap: cleanName,
        jabatan: cleanJabatan,
      );
      accounts[existingIdx] = account;
    } else {
      account = BendaharaAccount(
        id: const Uuid().v4(),
        namaLengkap: cleanName,
        jabatan: cleanJabatan,
        authMode: BendaharaAccount.modeOfflineQuick,
      );
      accounts.add(account);
    }

    await _saveAccounts(accounts);
    await _setActiveSession(account.id, rememberSession: rememberSession);
    return account;
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final active = await getActiveAccount();
    if (active == null || active.authMode != BendaharaAccount.modeLocal) {
      throw Exception('Ganti password hanya tersedia untuk akun login lokal.');
    }
    final userKey = (active.username ?? active.email ?? '').trim().toLowerCase();
    if (!verifyPasswordHash(
      usernameOrEmail: userKey,
      password: oldPassword,
      storedHash: active.passwordHash,
    )) {
      throw Exception('Password lama tidak cocok.');
    }
    if (newPassword.length < 6) {
      throw Exception('Password baru minimal 6 karakter.');
    }

    final accounts = await getAllAccounts();
    final idx = accounts.indexWhere((a) => a.id == active.id);
    if (idx < 0) {
      throw Exception('Akun aktif tidak ditemukan.');
    }
    accounts[idx] = accounts[idx].copyWith(
      passwordHash: hashPassword(userKey, newPassword),
    );
    await _saveAccounts(accounts);
  }

  Future<BendaharaAccount> updateActiveProfile({
    String? namaLengkap,
    String? jabatan,
    String? fotoPath,
    bool clearFoto = false,
  }) async {
    final active = await getActiveAccount();
    if (active == null) {
      throw Exception('Belum ada sesi bendahara yang aktif.');
    }

    final accounts = await getAllAccounts();
    final idx = accounts.indexWhere((a) => a.id == active.id);
    if (idx < 0) {
      throw Exception('Akun bendahara tidak ditemukan.');
    }

    final updated = accounts[idx].copyWith(
      namaLengkap: namaLengkap != null && namaLengkap.trim().isNotEmpty
          ? namaLengkap.trim()
          : accounts[idx].namaLengkap,
      jabatan: jabatan != null && jabatan.trim().isNotEmpty
          ? jabatan.trim()
          : accounts[idx].jabatan,
      fotoPath: fotoPath,
      clearFoto: clearFoto,
    );
    accounts[idx] = updated;
    await _saveAccounts(accounts);
    return updated;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActiveAccountId);
    await prefs.setBool(_keyExplicitlyLoggedOut, true);
  }

  Future<void> clearAllForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccountsJson);
    await prefs.remove(_keyActiveAccountId);
    await prefs.remove(_keyRememberSession);
    await prefs.remove(_keyExplicitlyLoggedOut);
  }
}
