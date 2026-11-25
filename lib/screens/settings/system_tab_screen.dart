import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bendahara_account.dart';
import '../../providers/kas_santri_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/app_background_wrapper.dart';
import '../../widgets/encrypted_backup_helper.dart';
import '../auth/login_screen.dart';
import '../paywall_screen.dart';
import '../pin_lock_screen.dart';
import '../rekap/executive_dashboard_screen.dart';
import '../rekap/smart_wa_reminder_screen.dart';
import '../santri/cetak_kartu_qr_screen.dart';
import '../santri/import_santri_excel_screen.dart';
import 'audit_log_screen.dart';
import 'pin_settings_screen.dart';
import 'settings_screen.dart';
import 'tahun_ajaran_screen.dart';

class SystemTabScreen extends StatefulWidget {
  const SystemTabScreen({Key? key}) : super(key: key);

  @override
  State<SystemTabScreen> createState() => _SystemTabScreenState();
}

class _SystemTabScreenState extends State<SystemTabScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _pickBendaharaPhoto(KasSantriProvider provider) async {
    AppFeedback.tap();
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      await provider.updateBendaharaProfile(
        sourceFotoPath: result.files.single.path,
      );
      if (mounted) {
        AppFeedback.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil bendahara berhasil diperbarui!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _showEditProfileDialog(KasSantriProvider provider) async {
    AppFeedback.tap();
    final acc = provider.activeAccount;
    final namaCtrl = TextEditingController(text: provider.activeOperatorName);
    final jabatanCtrl = TextEditingController(text: provider.activeOperatorRole);
    String? pickedFoto = acc?.fotoPath;
    bool clearFoto = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final hasFoto = !clearFoto &&
              pickedFoto != null &&
              pickedFoto!.isNotEmpty &&
              File(pickedFoto!).existsSync();
          return AlertDialog(
            title: const Text(
              'Edit Profil Bendahara',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final res = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      if (res != null && res.files.single.path != null) {
                        setDialogState(() {
                          pickedFoto = res.files.single.path;
                          clearFoto = false;
                        });
                      }
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: const Color(0xFF0A1D28),
                          backgroundImage:
                              hasFoto ? FileImage(File(pickedFoto!)) : null,
                          child: hasFoto
                              ? null
                              : Text(
                                  acc?.initials ?? 'BP',
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 13,
                              color: Color(0xFF040914),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasFoto)
                    TextButton(
                      onPressed: () => setDialogState(() => clearFoto = true),
                      child: const Text(
                        'Hapus Foto',
                        style: TextStyle(color: Color(0xFFFB7185), fontSize: 11),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: namaCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap Bendahara',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: jabatanCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Jabatan (misal: Bendahara Putra)',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );

    final namaVal = namaCtrl.text.trim();
    final jabatanVal = jabatanCtrl.text.trim();
    namaCtrl.dispose();
    jabatanCtrl.dispose();

    if (saved == true && mounted) {
      await provider.updateBendaharaProfile(
        namaLengkap: namaVal.isNotEmpty ? namaVal : provider.activeOperatorName,
        jabatan: jabatanVal.isNotEmpty ? jabatanVal : provider.activeOperatorRole,
        sourceFotoPath: (!clearFoto && pickedFoto != acc?.fotoPath) ? pickedFoto : null,
        clearFoto: clearFoto,
      );
      if (mounted) {
        AppFeedback.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil Bendahara berhasil diperbarui!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _handleLogout(KasSantriProvider provider) async {
    AppFeedback.tap();
    final hasUnsaved = provider.hasUnbackedUpLocalChanges;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          hasUnsaved ? '⚠️ Ada Data Belum Dicadangkan' : 'Logout / Ganti Akun?',
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
        ),
        content: Text(
          hasUnsaved
              ? 'Terdapat data transaksi lokal yang belum dicadangkan ke Google Drive. Data santri di perangkat ini tetap aman saat Anda ganti akun, namun sebaiknya cadangkan dahulu.\n\nTetap keluar dari akun bendahara saat ini?'
              : 'Anda akan keluar dari sesi bendahara saat ini dan diarahkan ke layar Login / Ganti Akun. Data kas santri tetap tersimpan aman di perangkat.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar / Ganti Akun'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    await provider.logoutBendahara();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _lockAppNow(KasSantriProvider provider) async {
    AppFeedback.tap();
    final hasPin =
        provider.pengaturan.pinKeamanan != null && provider.pengaturan.pinKeamanan!.isNotEmpty;
    if (!hasPin) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PinSettingsScreen()),
      );
      return;
    }
    await AuthService.instance.lockSession();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PinLockScreen(isUnlockingSession: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = Provider.of<KasSantriProvider>(context);
    final peng = provider.pengaturan;
    final acc = provider.activeAccount;
    final hasPin = peng.pinKeamanan != null && peng.pinKeamanan!.isNotEmpty;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    final String? fotoPath = acc?.fotoPath;
    final bool hasFoto =
        fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 120 + bottomSafe),
        children: [
          // Header Tab Sistem + Tombol Gerigi (Settings)
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SISTEM & AKUN',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Profil Pengurus Bendahara',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  AppFeedback.tap();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  borderColor: const Color(0xFF38BDF8).withOpacity(0.45),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings_rounded, color: Color(0xFF67E8F9), size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Pengaturan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Kartu Profil Pengurus Bendahara (Glass Premium)
          GlassCard(
            borderRadius: 28,
            padding: const EdgeInsets.all(18),
            borderColor: const Color(0xFF34D399).withOpacity(0.45),
            gradientColors: const [
              Color(0xCC0B2228),
              Color(0xCC0F172A),
              Color(0xCC131B2E),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _pickBendaharaPhoto(provider),
                      child: Stack(
                        children: [
                          Container(
                            width: 66,
                            height: 66,
                            padding: const EdgeInsets.all(2.5),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF34D399), Color(0xFF38BDF8), Color(0xFFD946EF)],
                              ),
                            ),
                            child: CircleAvatar(
                              backgroundColor: const Color(0xFF07101E),
                              backgroundImage: hasFoto ? FileImage(File(fotoPath)) : null,
                              child: hasFoto
                                  ? null
                                  : Text(
                                      acc?.initials ?? 'BP',
                                      style: const TextStyle(
                                        color: Color(0xFF34D399),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF060A12), width: 1.5),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 12,
                                color: Color(0xFF040914),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.activeOperatorName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${provider.activeOperatorRole} • ${peng.namaPondok}',
                            style: const TextStyle(
                              color: Color(0xFF67E8F9),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF34D399).withOpacity(0.45)),
                                ),
                                child: Text(
                                  acc?.authMode == BendaharaAccount.modeGoogle
                                      ? '☁️ ${acc!.authModeLabel}'
                                      : (acc?.authMode == BendaharaAccount.modeLocal
                                          ? '✓ ${acc!.authModeLabel}'
                                          : '⚡ Mode Offline Cepat'),
                                  style: const TextStyle(
                                    color: Color(0xFF6EE7B7),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (acc?.username != null && acc!.username!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '@${acc.username}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditProfileDialog(provider),
                        icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF67E8F9)),
                        label: const Text(
                          'Edit Profil',
                          style: TextStyle(color: Color(0xFF67E8F9), fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleLogout(provider),
                        icon: const Icon(Icons.logout_rounded, size: 15, color: Color(0xFFFDA4AF)),
                        label: const Text(
                          'Logout / Ganti Akun',
                          style: TextStyle(color: Color(0xFFFDA4AF), fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: const Color(0xFFF43F5E).withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Kartu Ringkas Status Lisensi
          InkWell(
            onTap: () {
              AppFeedback.tap();
              if (provider.isProUser) {
                PaywallScreen.showActiveSubscriptionSheet(context);
              } else {
                PaywallScreen.show(context);
              }
            },
            borderRadius: BorderRadius.circular(24),
            child: GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(16),
              borderColor: provider.isProUser
                  ? const Color(0xFF34D399).withOpacity(0.45)
                  : const Color(0xFFFBBF24).withOpacity(0.5),
              gradientColors: const [Color(0xCC1E170A), Color(0xCC091926)],
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: provider.isProUser
                            ? const Color(0xFF34D399).withOpacity(0.45)
                            : const Color(0xFFFBBF24).withOpacity(0.5),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text('👑', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.proStatusSummaryLabel,
                          style: TextStyle(
                            color: provider.isProUser ? const Color(0xFF34D399) : const Color(0xFFFDE68A),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.isProUser
                              ? 'Semua fitur PRO terbuka penuh • Ketuk untuk detail'
                              : 'Ketuk untuk coba GRATIS 14 Hari atau upgrade PRO',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white60),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Kartu Cepat Cadangan, Keamanan & Pengaturan Tampilan
          GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AKSES CEPAT SISTEM',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _quickTile(
                      emoji: '🔐',
                      title: 'Backup .KSBAK',
                      subtitle: 'AES-256 terenkripsi',
                      accent: const Color(0xFF34D399),
                      onTap: () => EncryptedBackupHelper.backupEncryptedKsbak(context),
                    ),
                    const SizedBox(width: 10),
                    _quickTile(
                      emoji: '⬆️',
                      title: 'Restore Backup',
                      subtitle: '.JSON / .KSBAK',
                      accent: const Color(0xFF38BDF8),
                      onTap: () => EncryptedBackupHelper.restoreBackupAnyFormat(context, provider),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _quickTile(
                      emoji: hasPin ? '🔒' : '🔓',
                      title: hasPin ? 'Kunci PIN' : 'Pasang PIN',
                      subtitle: hasPin ? 'Ketuk kunci layar' : 'Belum aktif',
                      accent: const Color(0xFFFBBF24),
                      onTap: () => _lockAppNow(provider),
                    ),
                    const SizedBox(width: 10),
                    _quickTile(
                      emoji: '🛡️',
                      title: 'Jejak Audit',
                      subtitle: 'Log anti-ubah',
                      accent: const Color(0xFF67E8F9),
                      onTap: () {
                        AppFeedback.tap();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AuditLogScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _quickTile(
                      emoji: provider.isScreenPrivacyEnabled ? '🙈' : '👁️',
                      title: provider.isScreenPrivacyEnabled ? 'Privasi Aktif' : 'Privasi Layar',
                      subtitle: provider.isScreenPrivacyEnabled ? 'Screenshot diblokir' : 'Blokir screenshot',
                      accent: const Color(0xFFF43F5E),
                      onTap: () async {
                        AppFeedback.tap();
                        await provider.setScreenPrivacyEnabled(!provider.isScreenPrivacyEnabled);
                      },
                    ),
                    const SizedBox(width: 10),
                    _quickTile(
                      emoji: '🎨',
                      title: 'Pengaturan',
                      subtitle: 'Tarif, Tema & Drive',
                      accent: const Color(0xFFD946EF),
                      onTap: () {
                        AppFeedback.tap();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _quickTile(
                      emoji: '🪪',
                      title: provider.isProUser ? 'Kartu QR PDF' : 'Kartu QR 👑',
                      subtitle: '8 kartu / A4 siap cetak',
                      accent: const Color(0xFF34D399),
                      onTap: () {
                        AppFeedback.tap();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CetakKartuQrScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _quickTile(
                      emoji: '🎓',
                      title: 'Tahun Ajaran',
                      subtitle: 'Mutasi & Tutup Buku',
                      accent: const Color(0xFF38BDF8),
                      onTap: () {
                        AppFeedback.tap();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TahunAjaranScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _quickTile(
                      emoji: '📊',
                      title: provider.isProUser ? 'Laporan Yayasan' : 'Eksekutif 👑',
                      subtitle: 'Analitik & PDF 1 hal',
                      accent: const Color(0xFFFBBF24),
                      onTap: () {
                        AppFeedback.tap();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ExecutiveDashboardScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _quickTile(
                      emoji: '📲',
                      title: 'Pengingat WA',
                      subtitle: 'Antrean wali santri',
                      accent: const Color(0xFF6EE7B7),
                      onTap: () {
                        AppFeedback.tap();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SmartWaReminderScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _quickTile(
                      emoji: '📥',
                      title: 'Import Excel',
                      subtitle: 'Massal 100–500 santri',
                      accent: const Color(0xFF67E8F9),
                      onTap: () {
                        AppFeedback.tap();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ImportSantriExcelScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Footer pengembang minimalis & halus di paling bawah
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Pengembang: Moch Khoirul Azman • Kas-Santri v4.0 • ${peng.namaPondok} • © 2026',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickTile({
    required String emoji,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
