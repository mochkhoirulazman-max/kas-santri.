import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bendahara_account.dart';
import '../../providers/kas_santri_provider.dart';
import '../../services/account_auth_service.dart';
import '../../services/auth_service.dart';
import '../../services/google_drive_backup_service.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/app_background_wrapper.dart';
import '../main_navigation_screen.dart';
import '../pin_lock_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool isSwitchingAccount;

  const LoginScreen({
    Key? key,
    this.isSwitchingAccount = false,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegisterMode = false;
  bool _rememberSession = true;
  bool _obscurePass = true;
  bool _isBusy = false;
  String? _errorMsg;
  bool _isGoogleFriendlyNotice = false;
  List<BendaharaAccount> _savedLocalAccounts = [];

  final _namaController = TextEditingController();
  final _jabatanController = TextEditingController(text: 'Bendahara Putra');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPassController = TextEditingController();

  static const List<String> _jabatanPresets = [
    'Bendahara Putra',
    'Bendahara Putri',
    'Bendahara Umum',
    'Musyrif Kas',
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    final all = await AccountAuthService.instance.getAllAccounts();
    final local = all
        .where((a) => a.authMode == BendaharaAccount.modeLocal)
        .toList();
    if (mounted) {
      setState(() => _savedLocalAccounts = local);
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _jabatanController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _onAuthenticated(BendaharaAccount account) async {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    await provider.syncActiveAccountToPengaturan(account);

    if (!mounted) return;
    AppFeedback.success();

    if (widget.isSwitchingAccount) {
      Navigator.pop(context, true);
      return;
    }

    final shouldLock = await AuthService.instance.shouldLockApp();
    if (!mounted) return;

    if (shouldLock) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PinLockScreen(isUnlockingSession: true),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  Future<void> _submitLocalAuth() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _errorMsg = null;
      _isGoogleFriendlyNotice = false;
    });
    try {
      final BendaharaAccount account;
      if (_isRegisterMode) {
        if (_passwordController.text != _confirmPassController.text) {
          throw Exception('Konfirmasi password tidak cocok.');
        }
        account = await AccountAuthService.instance.registerLocalAccount(
          namaLengkap: _namaController.text,
          jabatan: _jabatanController.text,
          username: _usernameController.text,
          password: _passwordController.text,
          rememberSession: _rememberSession,
        );
      } else {
        account = await AccountAuthService.instance.loginLocal(
          username: _usernameController.text,
          password: _passwordController.text,
          rememberSession: _rememberSession,
        );
      }
      if (!mounted) return;
      await _onAuthenticated(account);
    } catch (e) {
      AppFeedback.alert();
      if (mounted) {
        setState(() {
          _errorMsg = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _submitGoogleLogin() async {
    if (_isBusy) return;
    AppFeedback.tap();
    setState(() {
      _isBusy = true;
      _errorMsg = null;
      _isGoogleFriendlyNotice = false;
    });
    try {
      final account = await AccountAuthService.instance.loginWithGoogle(
        rememberSession: _rememberSession,
      );
      if (!mounted) return;
      await _onAuthenticated(account);
    } catch (e) {
      AppFeedback.alert();
      final friendly = GoogleDriveBackupService.mapAuthError(e);
      if (mounted) {
        setState(() {
          _isGoogleFriendlyNotice = true;
          _errorMsg = friendly.message;
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _submitOfflineQuickMode() async {
    if (_isBusy) return;
    AppFeedback.tap();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final nameCtrl = TextEditingController(
      text: provider.pengaturan.namaPengurus.trim().isNotEmpty
          ? provider.pengaturan.namaPengurus
          : 'Pengurus Kas & Keuangan',
    );
    final jabCtrl = TextEditingController(text: 'Bendahara Pondok');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '⚡ Mode Offline Cepat',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masuk langsung tanpa sinyal internet atau password. Nama petugas akan tercatat pada struk & serah terima.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Nama Petugas / Bendahara',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: jabCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Jabatan',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Masuk Sekarang'),
          ),
        ],
      ),
    );

    final namaVal = nameCtrl.text;
    final jabVal = jabCtrl.text;
    nameCtrl.dispose();
    jabCtrl.dispose();

    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final account = await AccountAuthService.instance.enterOfflineQuickMode(
        namaLengkap: namaVal,
        jabatan: jabVal,
        rememberSession: true,
      );
      if (!mounted) return;
      await _onAuthenticated(account);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final peng = Provider.of<KasSantriProvider>(context).pengaturan;
    final logoPath = peng.logoPath;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.isSwitchingAccount
          ? AppBar(
              title: const Text(
                'Ganti / Login Akun Bendahara',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF34D399), Color(0xFF38BDF8), Color(0xFFD946EF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.38),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: KasSantriLogoMark(
                        customLogoPath: logoPath,
                        size: 62,
                        circular: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    peng.namaPondok.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRegisterMode ? 'Daftar Akun Bendahara' : 'Masuk Petugas Bendahara',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),

                  GlassCard(
                    borderRadius: 26,
                    padding: const EdgeInsets.all(18),
                    borderColor: const Color(0xFF38BDF8).withValues(alpha: 0.42),
                    gradientColors: const [
                      Color(0xD8072638),
                      Color(0xDE0E1833),
                      Color(0xDA171230),
                    ],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Toggle Login / Daftar
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _modePill(
                                  'Masuk',
                                  selected: !_isRegisterMode,
                                  onTap: () => setState(() {
                                    _isRegisterMode = false;
                                    _errorMsg = null;
                                  }),
                                ),
                              ),
                              Expanded(
                                child: _modePill(
                                  'Daftar Baru',
                                  selected: _isRegisterMode,
                                  onTap: () => setState(() {
                                    _isRegisterMode = true;
                                    _errorMsg = null;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (!_isRegisterMode && _savedLocalAccounts.isNotEmpty) ...[
                          const Text(
                            'Akun Terdaftar di Perangkat Ini:',
                            style: TextStyle(color: Colors.white60, fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _savedLocalAccounts.map((acc) {
                              final label = '${acc.namaLengkap} (${acc.username ?? '-'})';
                              return ActionChip(
                                label: Text(
                                  label,
                                  style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 10.5, fontWeight: FontWeight.w700),
                                ),
                                backgroundColor: const Color(0xFF0A1628),
                                side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                                onPressed: () {
                                  AppFeedback.tap();
                                  setState(() {
                                    _usernameController.text = acc.username ?? acc.email ?? '';
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (_isRegisterMode) ...[
                          TextField(
                            controller: _namaController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Nama Lengkap Bendahara',
                              prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _jabatanController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Jabatan (misal: Bendahara Putra)',
                              prefixIcon: Icon(Icons.badge_outlined, size: 18),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _jabatanPresets.map((j) {
                              return ChoiceChip(
                                label: Text(j, style: const TextStyle(fontSize: 10)),
                                selected: _jabatanController.text.trim() == j,
                                selectedColor: const Color(0xFF10B981).withOpacity(0.28),
                                backgroundColor: Colors.black26,
                                labelStyle: const TextStyle(color: Colors.white70),
                                onSelected: (_) {
                                  AppFeedback.tap();
                                  setState(() => _jabatanController.text = j);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                        ],

                        TextField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Username atau Email',
                            prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePass,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Password (min. 6 karakter)',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18,
                                color: Colors.white60,
                              ),
                              onPressed: () => setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                        ),
                        if (_isRegisterMode) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _confirmPassController,
                            obscureText: _obscurePass,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Konfirmasi Password',
                              prefixIcon: Icon(Icons.lock_reset_rounded, size: 18),
                              isDense: true,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        CheckboxListTile(
                          value: _rememberSession,
                          onChanged: (v) => setState(() => _rememberSession = v ?? true),
                          title: const Text(
                            'Ingat Sesi Login di perangkat ini',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: const Color(0xFF10B981),
                        ),

                        if (_errorMsg != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isGoogleFriendlyNotice
                                    ? [
                                        const Color(0xFF332007).withValues(alpha: 0.78),
                                        const Color(0xFF0A1D33).withValues(alpha: 0.82),
                                      ]
                                    : [
                                        const Color(0xFFF43F5E).withValues(alpha: 0.18),
                                        const Color(0xFF2A0A16).withValues(alpha: 0.45),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _isGoogleFriendlyNotice
                                    ? const Color(0xFFFBBF24).withValues(alpha: 0.50)
                                    : const Color(0xFFF43F5E).withValues(alpha: 0.50),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _isGoogleFriendlyNotice
                                          ? Icons.info_outline_rounded
                                          : Icons.warning_amber_rounded,
                                      size: 16,
                                      color: _isGoogleFriendlyNotice
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFFFECDD3),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _isGoogleFriendlyNotice
                                            ? 'Info Masuk Google OAuth'
                                            : 'Perhatian Login',
                                        style: TextStyle(
                                          color: _isGoogleFriendlyNotice
                                              ? const Color(0xFFFDE68A)
                                              : const Color(0xFFFECDD3),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _errorMsg!,
                                  style: TextStyle(
                                    color: _isGoogleFriendlyNotice
                                        ? Colors.white
                                        : const Color(0xFFFECDD3),
                                    fontSize: 11.5,
                                    height: 1.38,
                                  ),
                                ),
                                if (_isGoogleFriendlyNotice) ...[
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: _isBusy ? null : _submitOfflineQuickMode,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: const Color(0xFF030712),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Text('⚡', style: TextStyle(fontSize: 13)),
                                    label: const Text(
                                      'Masuk Mode Bendahara Lokal',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        ElevatedButton.icon(
                          onPressed: _isBusy ? null : _submitLocalAuth,
                          icon: Icon(_isRegisterMode ? Icons.person_add_alt_1_rounded : Icons.login_rounded, size: 18),
                          label: Text(
                            _isBusy
                                ? 'Memproses...'
                                : (_isRegisterMode ? 'Daftar & Masuk' : 'Masuk Akun Bendahara'),
                          ),
                        ),
                        const SizedBox(height: 10),

                        OutlinedButton.icon(
                          onPressed: _isBusy ? null : _submitGoogleLogin,
                          icon: const Icon(Icons.cloud_done_outlined, size: 17, color: Color(0xFF67E8F9)),
                          label: const Text(
                            'Masuk dengan Google (Sinkron Drive)',
                            style: TextStyle(color: Color(0xFF67E8F9), fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.45)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 8),

                        TextButton.icon(
                          onPressed: _isBusy ? null : _submitOfflineQuickMode,
                          icon: const Text('⚡', style: TextStyle(fontSize: 14)),
                          label: const Text(
                            'Masuk Mode Offline / Bendahara Cepat',
                            style: TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modePill(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        AppFeedback.tap();
        onTap();
      },
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4)])
              : null,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF040914) : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
