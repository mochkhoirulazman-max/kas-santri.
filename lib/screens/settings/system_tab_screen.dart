import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bendahara_account.dart';
import '../../providers/kas_santri_provider.dart';
import '../../providers/theme_wallpaper_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/app_background_wrapper.dart';
import '../../widgets/panduan_aplikasi_sheet.dart';
import '../auth/login_screen.dart';
import '../paywall_screen.dart';
import '../pin_lock_screen.dart';
import '../rekap/cash_opname_screen.dart';
import '../rekap/executive_dashboard_screen.dart';
import '../rekap/smart_wa_reminder_screen.dart';
import '../santri/cetak_kartu_qr_screen.dart';
import '../santri/import_santri_excel_screen.dart';
import 'audit_log_screen.dart';
import 'pin_settings_screen.dart';
import 'settings_screen.dart';
import 'tahun_ajaran_screen.dart';

class SystemTabScreen extends StatefulWidget {
  final GlobalKey? headerSpotlightKey;

  const SystemTabScreen({
    Key? key,
    this.headerSpotlightKey,
  }) : super(key: key);

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

  Future<void> _openProScreen({
    required bool isPro,
    required String triggerFeature,
    required WidgetBuilder screenBuilder,
  }) async {
    AppFeedback.tap();
    if (!isPro) {
      await PaywallScreen.show(context, triggerFeature: triggerFeature);
      return;
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: screenBuilder));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = Provider.of<KasSantriProvider>(context);
    final cardOpacity = Provider.of<ThemeWallpaperProvider>(context).cardOpacity;
    final peng = provider.pengaturan;
    final acc = provider.activeAccount;
    final isPro = provider.hasProAccess;
    final hasPin = peng.pinKeamanan != null && peng.pinKeamanan!.isNotEmpty;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    final String? fotoPath = acc?.fotoPath;
    final bool hasFoto =
        fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync();

    final quickItems = <_QuickAccessSpec>[
      _QuickAccessSpec(
        emoji: '🧮',
        title: 'Cash Opname',
        subtitle: 'Kalkulator uang fisik',
        accent: const Color(0xFF34D399),
        isProLocked: !isPro,
        onTap: () => CashOpnameScreen.show(context),
      ),
      _QuickAccessSpec(
        emoji: '📈',
        title: 'Laporan Yayasan',
        subtitle: 'Laporan Eksekutif Pengasuh',
        accent: const Color(0xFFFBBF24),
        isProLocked: !isPro,
        onTap: () => _openProScreen(
          isPro: isPro,
          triggerFeature: 'Laporan Eksekutif Pengasuh & Yayasan 1 Halaman (PDF)',
          screenBuilder: (_) => const ExecutiveDashboardScreen(),
        ),
      ),
      _QuickAccessSpec(
        emoji: '🔔',
        title: 'Pengingat WA',
        subtitle: 'Pusat Antrean Pengingat WA',
        accent: const Color(0xFF2DD4BF),
        isProLocked: !isPro,
        onTap: () => _openProScreen(
          isPro: isPro,
          triggerFeature: 'Pusat Antrean Pengingat WA Cerdas (1-Klik Anti-Spam)',
          screenBuilder: (_) => const SmartWaReminderScreen(),
        ),
      ),
      _QuickAccessSpec(
        emoji: '🪪',
        title: 'Kartu QR PDF',
        subtitle: 'Cetak massal Kartu QR Santri',
        accent: const Color(0xFF38BDF8),
        isProLocked: !isPro,
        onTap: () => _openProScreen(
          isPro: isPro,
          triggerFeature: 'Cetak Massal Kartu Santri QR Siap Laminating (PDF A4)',
          screenBuilder: (_) => const CetakKartuQrScreen(),
        ),
      ),
      _QuickAccessSpec(
        emoji: '📥',
        title: 'Import Excel',
        subtitle: 'Import massal data santri',
        accent: const Color(0xFF6EE7B7),
        isProLocked: !isPro,
        onTap: () => _openProScreen(
          isPro: isPro,
          triggerFeature: 'Import Massal Santri dari Excel (.xlsx)',
          screenBuilder: (_) => const ImportSantriExcelScreen(),
        ),
      ),
      _QuickAccessSpec(
        emoji: '🎓',
        title: 'Tahun Ajaran',
        subtitle: 'Mutasi Kamar/Kelas & Lulus',
        accent: const Color(0xFF818CF8),
        isProLocked: !isPro,
        onTap: () => _openProScreen(
          isPro: isPro,
          triggerFeature:
              'Manajemen Tahun Ajaran, Mutasi Kamar/Kelas & Tutup Buku Alumni',
          screenBuilder: (_) => const TahunAjaranScreen(),
        ),
      ),
      _QuickAccessSpec(
        emoji: '🛡️',
        title: 'Jejak Audit',
        subtitle: 'Log keamanan anti-curang',
        accent: const Color(0xFF67E8F9),
        isProLocked: !isPro,
        onTap: () => _openProScreen(
          isPro: isPro,
          triggerFeature: 'Jejak Audit Keamanan Anti-Curang (Read-Only)',
          screenBuilder: (_) => const AuditLogScreen(),
        ),
      ),
      _QuickAccessSpec(
        emoji: '🎨',
        title: 'Wallpaper & Tema',
        subtitle: 'Ganti wallpaper & kaca',
        accent: const Color(0xFFE879F9),
        isProLocked: false,
        onTap: () => QuickWallpaperThemeSheet.show(context),
      ),
      _QuickAccessSpec(
        emoji: '💾',
        title: 'Backup & Restore',
        subtitle: 'Cadangkan / pulihkan data',
        accent: const Color(0xFF22D3EE),
        isProLocked: false,
        onTap: () => QuickBackupRestoreSheet.show(context),
      ),
      _QuickAccessSpec(
        emoji: '📖',
        title: 'Panduan Aplikasi',
        subtitle: 'Putar ulang tutorial aplikasi',
        accent: const Color(0xFFFDE047),
        isProLocked: false,
        onTap: () => PanduanAplikasiSheet.show(context),
      ),
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 120 + bottomSafe),
        children: [
          // Header Tab Sistem + Tombol Gerigi ⚙️ (SettingsScreen)
          Container(
            key: widget.headerSpotlightKey,
            child: Row(
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
                    borderColor: const Color(0xFF38BDF8).withValues(alpha: 0.45),
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
          ),

          const SizedBox(height: 16),

          // Kartu Profil Pengurus Bendahara (Vibrant Glass)
          GlassCard(
            borderRadius: 28,
            padding: const EdgeInsets.all(18),
            borderColor: const Color(0xFF34D399).withValues(alpha: 0.45),
            gradientColors: const [
              Color(0xD608352D),
              Color(0xDC0B182C),
              Color(0xD8141530),
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
                                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF34D399).withValues(alpha: 0.45),
                                  ),
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
                          side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
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
                          side: BorderSide(color: const Color(0xFFF43F5E).withValues(alpha: 0.5)),
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
              if (isPro) {
                PaywallScreen.showActiveSubscriptionSheet(context);
              } else {
                PaywallScreen.show(context);
              }
            },
            borderRadius: BorderRadius.circular(24),
            child: GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(16),
              borderColor: isPro
                  ? const Color(0xFF34D399).withValues(alpha: 0.48)
                  : const Color(0xFFFBBF24).withValues(alpha: 0.55),
              gradientColors: const [Color(0xD8241908), Color(0xDC091928)],
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isPro
                            ? const Color(0xFF34D399).withValues(alpha: 0.45)
                            : const Color(0xFFFBBF24).withValues(alpha: 0.55),
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
                            color: isPro ? const Color(0xFF34D399) : const Color(0xFFFDE68A),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPro
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

          const SizedBox(height: 16),

          // Bagian ⚡ Akses Cepat Pengurus (10 Kartu Grid Kaca Berwarna Lega)
          GlassCard(
            borderRadius: 26,
            padding: const EdgeInsets.all(16),
            borderColor: const Color(0xFF38BDF8).withValues(alpha: 0.40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚡ AKSES CEPAT PENGURUS',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pintasan Fitur Utama Bendahara Pondok',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isPro)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFBBF24).withValues(alpha: 0.55),
                          ),
                        ),
                        child: const Text(
                          '👑 Mode Gratis',
                          style: TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: quickItems.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.52,
                  ),
                  itemBuilder: (ctx, index) {
                    final spec = quickItems[index];
                    return _buildVibrantQuickCard(spec, cardOpacity);
                  },
                ),

                const SizedBox(height: 12),

                // Baris Cepat Keamanan 1-Ketuk (Kunci PIN & Privasi Layar)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _lockAppNow(provider),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF07111F).withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFBBF24).withValues(alpha: 0.38),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(hasPin ? '🔒' : '🔓', style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  hasPin ? 'Kunci PIN Layar' : 'Pasang PIN',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          AppFeedback.tap();
                          await provider.setScreenPrivacyEnabled(!provider.isScreenPrivacyEnabled);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF07111F).withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: provider.isScreenPrivacyEnabled
                                  ? const Color(0xFF34D399).withValues(alpha: 0.5)
                                  : const Color(0xFFFB7185).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                provider.isScreenPrivacyEnabled ? '🙈' : '👁️',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  provider.isScreenPrivacyEnabled
                                      ? 'Anti-SS Aktif'
                                      : 'Privasi Layar',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: provider.isScreenPrivacyEnabled
                                        ? const Color(0xFF6EE7B7)
                                        : const Color(0xFFFECDD3),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
              'Pengembang: Moch Khoirul Azman • Kas-Santri v4.1 • ${peng.namaPondok} • © 2026',
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

  Widget _buildVibrantQuickCard(_QuickAccessSpec spec, double cardOpacity) {
    final topColor = Color.lerp(const Color(0xFF071324), spec.accent, 0.24)!
        .withValues(alpha: (0.86 * cardOpacity).clamp(0.48, 0.90));
    final bottomColor = const Color(0xFF091120)
        .withValues(alpha: (0.90 * cardOpacity).clamp(0.52, 0.94));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: spec.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [topColor, bottomColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: spec.accent.withValues(alpha: 0.45),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: spec.accent.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: spec.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: spec.accent.withValues(alpha: 0.45),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(spec.emoji, style: const TextStyle(fontSize: 17)),
                  ),
                  if (spec.isProLocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFFDE047)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '🔒 PRO',
                        style: TextStyle(
                          color: Color(0xFF030712),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: spec.accent.withValues(alpha: 0.75),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessSpec {
  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;
  final bool isProLocked;
  final VoidCallback onTap;

  const _QuickAccessSpec({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.isProLocked,
    required this.onTap,
  });
}
