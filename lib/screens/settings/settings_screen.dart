import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../database/database_helper.dart';
import '../../models/bendahara_account.dart';
import '../../models/pengaturan.dart';
import '../../providers/kas_santri_provider.dart';
import '../../providers/theme_wallpaper_provider.dart';
import '../../services/account_auth_service.dart';
import '../../services/auth_service.dart';
import '../../services/backup_service.dart';
import '../../services/subscription_service.dart';
import '../../utils/app_feedback.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/app_background_wrapper.dart';
import '../../widgets/direct_dana_payment_sheet.dart';
import '../../widgets/legal_document_sheet.dart';
import '../auth/login_screen.dart';
import '../paywall_screen.dart';
import '../pin_lock_screen.dart';
import 'pin_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _namaPondokController;
  late TextEditingController _tahunAjaranController;
  late TextEditingController _defaultJatahController;
  late TextEditingController _defaultDurasiController;
  late TextEditingController _infakMasakController;
  late TextEditingController _infakListrikController;
  late TextEditingController _infakBerasLiterController;
  late TextEditingController _infakBerasUangController;
  bool _isDriveBusy = false;

  @override
  void initState() {
    super.initState();
    final s = Provider.of<KasSantriProvider>(context, listen: false).pengaturan;
    _namaPondokController = TextEditingController(text: s.namaPondok);
    _tahunAjaranController = TextEditingController(text: s.tahunAjaran);
    _defaultJatahController = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(s.defaultJatahHarian),
    );
    _defaultDurasiController = TextEditingController(
      text: s.defaultDurasiHari.toString(),
    );
    _infakMasakController = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(s.defaultInfakMasak),
    );
    _infakListrikController = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(s.defaultInfakListrik),
    );
    final literStr = s.defaultInfakBerasLiter == s.defaultInfakBerasLiter.roundToDouble()
        ? s.defaultInfakBerasLiter.toInt().toString()
        : s.defaultInfakBerasLiter.toString();
    _infakBerasLiterController = TextEditingController(text: literStr);
    _infakBerasUangController = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(s.defaultInfakBerasUang),
    );
  }

  @override
  void dispose() {
    _namaPondokController.dispose();
    _tahunAjaranController.dispose();
    _defaultJatahController.dispose();
    _defaultDurasiController.dispose();
    _infakMasakController.dispose();
    _infakListrikController.dispose();
    _infakBerasLiterController.dispose();
    _infakBerasUangController.dispose();
    super.dispose();
  }

  Future<void> _savePondokDanAturan(
    KasSantriProvider provider,
    PengaturanAplikasi settings,
  ) async {
    AppFeedback.tap();
    final pondok = _namaPondokController.text.trim().isNotEmpty
        ? _namaPondokController.text.trim()
        : settings.namaPondok;
    final ta = _tahunAjaranController.text.trim().isNotEmpty
        ? _tahunAjaranController.text.trim()
        : settings.tahunAjaran;
    final jatah = CurrencyFormatter.parse(_defaultJatahController.text);
    final durasi = int.tryParse(_defaultDurasiController.text.trim()) ?? settings.defaultDurasiHari;
    final masak = CurrencyFormatter.parse(_infakMasakController.text);
    final listrik = CurrencyFormatter.parse(_infakListrikController.text);
    final liter = double.tryParse(
          _infakBerasLiterController.text.trim().replaceAll(',', '.'),
        ) ??
        settings.defaultInfakBerasLiter;
    final berasUang = CurrencyFormatter.parse(_infakBerasUangController.text);

    await provider.savePengaturan(
      settings.copyWith(
        namaPondok: pondok,
        tahunAjaran: ta,
        defaultJatahHarian: jatah > 0 ? jatah : settings.defaultJatahHarian,
        defaultDurasiHari: durasi > 0 ? durasi : settings.defaultDurasiHari,
        defaultInfakMasak: masak > 0 ? masak : settings.defaultInfakMasak,
        defaultInfakListrik: listrik > 0 ? listrik : settings.defaultInfakListrik,
        defaultInfakBerasLiter: liter > 0 ? liter : settings.defaultInfakBerasLiter,
        defaultInfakBerasUang: berasUang > 0 ? berasUang : settings.defaultInfakBerasUang,
      ),
    );
    AppFeedback.success();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan Pondok, Aturan Kas & Tarif Infak tersimpan!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _pickCustomWallpaper(ThemeWallpaperProvider wp) async {
    AppFeedback.tap();
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    if (res != null && res.files.single.path != null) {
      try {
        await wp.setCustomWallpaperFromFile(res.files.single.path!);
        if (mounted) {
          AppFeedback.success();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wallpaper galeri diterapkan secara permanen!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memasang wallpaper: $e'), backgroundColor: const Color(0xFFE11D48)),
          );
        }
      }
    }
  }

  Future<void> _pickLogo(KasSantriProvider provider) async {
    if (!provider.isProUser) {
      AppFeedback.alert();
      await PaywallScreen.show(
        context,
        triggerFeature: 'Upload Logo Pondok & Kop Resmi Yayasan',
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      await provider.updateLogoPath(result.files.single.path);
      if (mounted) {
        AppFeedback.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo pondok berhasil diperbarui!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _showEditBendaharaDialog(KasSantriProvider provider) async {
    AppFeedback.tap();
    final acc = provider.activeAccount;
    final namaCtrl = TextEditingController(text: provider.activeOperatorName);
    final jabatanCtrl = TextEditingController(text: provider.activeOperatorRole);
    String? pickedFoto = acc?.fotoPath;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Edit Profil & Foto Bendahara', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles(type: FileType.image);
                  if (res != null && res.files.single.path != null) {
                    setDlg(() => pickedFoto = res.files.single.path);
                  }
                },
                icon: const Icon(Icons.photo_camera_outlined, size: 16),
                label: Text(pickedFoto != null ? 'Ganti Foto Bendahara' : 'Pilih Foto Bendahara'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: namaCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Nama Bendahara', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: jabatanCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Jabatan', isDense: true),
              ),
            ],
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
        ),
      ),
    );
    final nama = namaCtrl.text.trim();
    final jab = jabatanCtrl.text.trim();
    namaCtrl.dispose();
    jabatanCtrl.dispose();

    if (ok == true && mounted) {
      await provider.updateBendaharaProfile(
        namaLengkap: nama.isNotEmpty ? nama : provider.activeOperatorName,
        jabatan: jab.isNotEmpty ? jab : provider.activeOperatorRole,
        sourceFotoPath: pickedFoto != acc?.fotoPath ? pickedFoto : null,
      );
      if (mounted) {
        AppFeedback.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil Bendahara diperbarui!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    }
  }

  Future<void> _showChangePasswordDialog(KasSantriProvider provider) async {
    final acc = provider.activeAccount;
    if (acc == null || acc.authMode != BendaharaAccount.modeLocal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ganti password hanya berlaku untuk akun login lokal (Username & Password).'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? err;

    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Ganti Password Akun', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Password Lama', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Password Baru (min. 6 karakter)', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Konfirmasi Password Baru', isDense: true),
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: const TextStyle(color: Color(0xFFFDA4AF), fontSize: 11.5)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newCtrl.text != confirmCtrl.text) {
                  setDlg(() => err = 'Konfirmasi password baru tidak cocok.');
                  return;
                }
                try {
                  await AccountAuthService.instance.changePassword(
                    oldPassword: oldCtrl.text,
                    newPassword: newCtrl.text,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  setDlg(() => err = e.toString().replaceFirst('Exception: ', ''));
                }
              },
              child: const Text('Simpan Password'),
            ),
          ],
        ),
      ),
    );
    oldCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();

    if (changed == true && mounted) {
      AppFeedback.success();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password bendahara berhasil diperbarui!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _logoutFromSettings(KasSantriProvider provider) async {
    AppFeedback.tap();
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
    if (provider.pengaturan.pinKeamanan == null || provider.pengaturan.pinKeamanan!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pasang Kunci PIN terlebih dahulu sebelum mengunci aplikasi.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
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

  Future<void> _confirmDisablePinDialog() async {
    final pinController = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Kunci PIN?', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan PIN saat ini untuk mematikan kunci aplikasi:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'PIN Saat Ini (4–6 Digit)', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            onPressed: () async {
              final ok = await AuthService.instance.verifyPin(pinController.text.trim());
              if (!ok) {
                AppFeedback.alert();
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('PIN tidak cocok!'), backgroundColor: Color(0xFFE11D48)),
                  );
                }
                return;
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Matikan PIN'),
          ),
        ],
      ),
    );
    pinController.dispose();

    if (verified == true && mounted) {
      await AuthService.instance.setPin(null);
      if (!mounted) return;
      await Provider.of<KasSantriProvider>(context, listen: false).loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunci PIN dinonaktifkan.'), backgroundColor: Color(0xFFF59E0B)),
        );
      }
    }
  }

  Future<void> _backupJson() async {
    AppFeedback.tap();
    try {
      final dump = await DatabaseHelper.instance.dumpBackupJson();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(dump);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/backup_kas_santri_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonStr);
      AppFeedback.success();
      await Share.shareXFiles([XFile(file.path)], text: 'Backup Kas Santri (.JSON)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal backup: $e'), backgroundColor: const Color(0xFFF43F5E)),
        );
      }
    }
  }

  Future<void> _restoreLocalJson() async {
    AppFeedback.tap();
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result == null || result.files.single.path == null) return;
      final rawJson = await File(result.files.single.path!).readAsString();
      final validation = BackupService.validateJsonString(rawJson);
      if (!validation.isValid || validation.parsedData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(validation.errorMessage ?? 'File JSON tidak valid.'), backgroundColor: const Color(0xFFE11D48)),
          );
        }
        return;
      }
      if (!mounted) return;
      await _showConfirmRestoreDialog(sourceLabel: 'File Lokal (.JSON)', validation: validation);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membaca file backup: $e'), backgroundColor: const Color(0xFFE11D48)),
        );
      }
    }
  }

  Future<void> _showConfirmRestoreDialog({
    required String sourceLabel,
    required BackupValidationResult validation,
    DateTime? cloudModifiedTime,
  }) async {
    final exportedDt = validation.exportedAt != null ? DateTime.tryParse(validation.exportedAt!) : null;
    final dateText = cloudModifiedTime != null
        ? DateFormatter.formatFullDateTime(cloudModifiedTime)
        : (exportedDt != null ? DateFormatter.formatFullDateTime(exportedDt) : '-');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan Data Backup?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        content: Text(
          'Sumber: $sourceLabel\nTanggal: $dateText\n\n'
          '• Santri: ${validation.santriCount} • Setoran: ${validation.setoranCount}\n'
          '• Transaksi: ${validation.transaksiCount} • Mutasi Dompet: ${validation.mutasiDompetCount}\n'
          '• Infak Santri: ${validation.infakCount} • Serah Terima: ${validation.serahTerimaInfakCount}\n\n'
          'Seluruh data lokal saat ini akan ditimpa dengan data backup.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.white70))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Pulihkan')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider = Provider.of<KasSantriProvider>(context, listen: false);
      await provider.restoreFromBackupJson(validation.parsedData!);
      if (mounted) {
        AppFeedback.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alhamdulillah! Data berhasil dipulihkan.'), backgroundColor: Color(0xFF10B981)),
        );
      }
    }
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Data Simulasi?'),
        content: const Text(
          'Seluruh data santri dan transaksi akan dikembalikan ke data awal simulasi PPS Miftahussunan.',
          style: TextStyle(fontSize: 12.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            onPressed: () async {
              final provider = Provider.of<KasSantriProvider>(context, listen: false);
              await provider.resetToInitialData();
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data simulasi berhasil di-reset!'), backgroundColor: Color(0xFF10B981)),
                );
              }
            },
            child: const Text('Ya, Reset Simulasi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final wp = Provider.of<ThemeWallpaperProvider>(context);
    final settings = provider.pengaturan;
    final acc = provider.activeAccount;
    final hasPin = settings.pinKeamanan != null && settings.pinKeamanan!.isNotEmpty;
    final isPro = provider.isProUser;
    final linkedEmail = settings.driveAccountEmail;
    final isLinked = linkedEmail != null && linkedEmail.isNotEmpty;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          '⚙️ Pengaturan Lengkap',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 36 + bottomSafe),
        children: [
          // 1. TAMPILAN & WALLPAPER
          GlassCard(
            borderRadius: 26,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('1. TAMPILAN & WALLPAPER', 'Kaca Transparan & Latar Belakang', const Color(0xFF38BDF8)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 82,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ThemeWallpaperProvider.presets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final spec = ThemeWallpaperProvider.presets[i];
                      final selected = !wp.hasValidCustomWallpaper && wp.preset == spec.preset;
                      return InkWell(
                        onTap: () {
                          AppFeedback.tap();
                          wp.setPreset(spec.preset);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 112,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: spec.gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? spec.accentColor : Colors.white24,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(color: spec.accentColor, shape: BoxShape.circle),
                                  ),
                                  if (selected)
                                    Icon(Icons.check_circle_rounded, color: spec.accentColor, size: 15),
                                ],
                              ),
                              Text(
                                spec.name,
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickCustomWallpaper(wp),
                        icon: const Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFF67E8F9)),
                        label: Text(
                          wp.hasValidCustomWallpaper ? 'Ganti Foto Galeri' : 'Pilih Foto Galeri',
                          style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    if (wp.hasValidCustomWallpaper) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          AppFeedback.tap();
                          wp.clearCustomWallpaper();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: const Color(0xFFF43F5E).withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Hapus Foto', style: TextStyle(color: Color(0xFFFDA4AF), fontSize: 11)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _sliderRow(
                  label: 'Opasitas Transparansi Kartu',
                  valueText: '${(wp.cardOpacity * 100).round()}%',
                  value: wp.cardOpacity,
                  min: 0.35,
                  max: 0.95,
                  onChanged: wp.setCardOpacity,
                ),
                _sliderRow(
                  label: 'Gelap Latar Wallpaper',
                  valueText: '${(wp.wallpaperDim * 100).round()}%',
                  value: wp.wallpaperDim,
                  min: 0.15,
                  max: 0.85,
                  onChanged: wp.setWallpaperDim,
                ),
                _sliderRow(
                  label: 'Blur Latar Wallpaper',
                  valueText: '${wp.wallpaperBlur.toStringAsFixed(0)} px',
                  value: wp.wallpaperBlur,
                  min: 0.0,
                  max: 20.0,
                  onChanged: wp.setWallpaperBlur,
                ),
                const SizedBox(height: 6),
                _switchBox(
                  title: 'Tata Letak Kartu Beranda 2 Kotak',
                  value: settings.isTwoColGrid,
                  onChanged: (_) {
                    AppFeedback.tap();
                    provider.toggleGridMode();
                  },
                ),
                const SizedBox(height: 8),
                _switchBox(
                  title: 'Efek Getar Haptik Sentuhan',
                  value: wp.hapticEnabled,
                  onChanged: (v) {
                    wp.setHapticEnabled(v);
                    AppFeedback.tap();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. PROFIL PONDOK & BENDAHARA
          GlassCard(
            borderRadius: 26,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _sectionHeader(
                        '2. PROFIL PONDOK & BENDAHARA',
                        'Identitas Lembaga & Petugas',
                        const Color(0xFF34D399),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _pickLogo(provider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPro ? const Color(0xFF10B981) : const Color(0xFF1E1B4B),
                        foregroundColor: isPro ? const Color(0xFF04121A) : const Color(0xFFFDE68A),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.camera_alt_outlined, size: 14),
                      label: Text(isPro ? 'Logo' : 'Logo 👑', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _namaPondokController,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(labelText: 'Nama Pondok Pesantren', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _tahunAjaranController,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(labelText: 'Tahun Ajaran Aktif', isDense: true),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.activeOperatorName,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${provider.activeOperatorRole} • ${acc?.authModeLabel ?? 'Offline'}',
                              style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showEditBendaharaDialog(provider),
                        child: const Text('Edit Profil', style: TextStyle(color: Color(0xFF67E8F9), fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. ATURAN KAS & TARIF INFAK
          GlassCard(
            borderRadius: 26,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('3. ATURAN KAS & TARIF INFAK', 'Kebijakan Jatah & Tarif Bulanan', const Color(0xFFFBBF24)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _defaultJatahController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [RibuanInputFormatter()],
                        style: const TextStyle(color: Color(0xFF34D399), fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'Default Jatah/Hr', prefixText: 'Rp ', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _defaultDurasiController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'Durasi Default', suffixText: 'Hari', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: settings.pembulatanJatah == 1000 ? 1000 : 500,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF090E1A),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(labelText: 'Pembulatan Jatah Otomatis', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 500, child: Text('Kelipatan Rp 500 ke bawah', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 1000, child: Text('Kelipatan Rp 1.000 ke bawah', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      AppFeedback.tap();
                      provider.savePengaturan(settings.copyWith(pembulatanJatah: val));
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ModeSisaHarian>(
                  value: settings.modeSisaHarian,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF090E1A),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(labelText: 'Kebijakan Sisa Jatah Harian', isDense: true),
                  items: const [
                    DropdownMenuItem(value: ModeSisaHarian.ketat, child: Text('Mode Ketat (sisa jadi tabungan)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: ModeSisaHarian.akumulasi, child: Text('Mode Akumulasi (sisa tambah kuota besok)', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      AppFeedback.tap();
                      provider.savePengaturan(settings.copyWith(modeSisaHarian: val));
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _infakMasakController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [RibuanInputFormatter()],
                        style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 12.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'Infak Masak', prefixText: 'Rp ', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _infakListrikController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [RibuanInputFormatter()],
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'Infak Listrik', prefixText: 'Rp ', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _infakBerasLiterController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 12.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'Beras Fisik', suffixText: 'Liter', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _infakBerasUangController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [RibuanInputFormatter()],
                        style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'Beras Uang', prefixText: 'Rp ', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _savePondokDanAturan(provider, settings),
                    icon: const Icon(Icons.save_rounded, size: 17),
                    label: const Text('Simpan Identitas, Aturan Kas & Tarif Infak'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 4. KEAMANAN & LOGIN
          GlassCard(
            borderRadius: 26,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('4. KEAMANAN & LOGIN', 'Akun Bendahara, PIN & Biometrik', const Color(0xFFF43F5E)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showChangePasswordDialog(provider),
                        icon: const Icon(Icons.password_rounded, size: 15, color: Color(0xFF67E8F9)),
                        label: const Text('Ganti Password', style: TextStyle(color: Color(0xFF67E8F9), fontSize: 11)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.45))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          AppFeedback.tap();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen(isSwitchingAccount: true)),
                          );
                        },
                        icon: const Icon(Icons.switch_account_outlined, size: 15, color: Color(0xFF34D399)),
                        label: const Text('Ganti Akun', style: TextStyle(color: Color(0xFF34D399), fontSize: 11)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.45))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _logoutFromSettings(provider),
                    icon: const Icon(Icons.logout_rounded, size: 15, color: Color(0xFFFDA4AF)),
                    label: const Text('Logout dari Sesi Aktif', style: TextStyle(color: Color(0xFFFDA4AF), fontSize: 11.5, fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: const Color(0xFFF43F5E).withOpacity(0.45))),
                  ),
                ),
                const SizedBox(height: 12),
                _switchBox(
                  title: 'Aktifkan Kunci PIN (4–6 Digit)',
                  value: hasPin,
                  onChanged: (val) {
                    AppFeedback.tap();
                    if (val && !hasPin) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PinSettingsScreen()));
                    } else if (!val && hasPin) {
                      _confirmDisablePinDialog();
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          AppFeedback.tap();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PinSettingsScreen()));
                        },
                        icon: Icon(hasPin ? Icons.edit_outlined : Icons.lock_outline, size: 15),
                        label: Text(hasPin ? 'Ubah PIN' : 'Pasang PIN', style: const TextStyle(fontSize: 11.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _lockAppNow(provider),
                        icon: const Icon(Icons.lock_clock_outlined, size: 15, color: Color(0xFFFBBF24)),
                        label: const Text('Kunci Sekarang', style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: const Color(0xFFF59E0B).withOpacity(0.5))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: [0, 1, 5, 15].contains(settings.autoLockMinutes) ? settings.autoLockMinutes : 1,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF090E1A),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(labelText: 'Kunci Otomatis Saat Idle', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Langsung terkunci saat ditutup')),
                    DropdownMenuItem(value: 1, child: Text('Setelah 1 Menit tidak aktif')),
                    DropdownMenuItem(value: 5, child: Text('Setelah 5 Menit tidak aktif')),
                    DropdownMenuItem(value: 15, child: Text('Setelah 15 Menit tidak aktif')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      AppFeedback.tap();
                      provider.savePengaturan(settings.copyWith(autoLockMinutes: val));
                    }
                  },
                ),
                const SizedBox(height: 8),
                _switchBox(
                  title: isPro ? 'Buka dengan Sidik Jari / Biometrik' : 'Buka dengan Sidik Jari / Biometrik 👑',
                  value: isPro && settings.isBiometricEnabled,
                  onChanged: (val) async {
                    AppFeedback.tap();
                    if (!isPro) {
                      await PaywallScreen.show(context, triggerFeature: 'Buka Kunci dengan Sidik Jari / Biometrik');
                      return;
                    }
                    if (val && !hasPin) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Aktifkan Kunci PIN terlebih dahulu.'), backgroundColor: Color(0xFFF59E0B)),
                      );
                      return;
                    }
                    if (val) {
                      final avail = await AuthService.instance.isBiometricsAvailable();
                      if (!avail) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sensor biometrik tidak tersedia di perangkat ini.'), backgroundColor: Color(0xFFF59E0B)),
                          );
                        }
                        return;
                      }
                    }
                    await provider.savePengaturan(settings.copyWith(isBiometricEnabled: val));
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 5. DATA & CADANGAN
          GlassCard(
            borderRadius: 26,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('5. DATA & CADANGAN', 'Backup Lokal .JSON & Google Drive PRO', const Color(0xFF67E8F9)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _backupJson,
                        style: OutlinedButton.styleFrom(side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.5))),
                        child: const Text('⬇️ Backup .JSON', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 11.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _restoreLocalJson,
                        style: OutlinedButton.styleFrom(side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.5))),
                        child: const Text('⬆️ Restore .JSON', style: TextStyle(color: Color(0xFF67E8F9), fontSize: 11.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLinked ? '☁️ Drive Terhubung: $linkedEmail' : '☁️ Google Drive: Belum ditautkan',
                        style: TextStyle(color: isLinked ? const Color(0xFF6EE7B7) : Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isDriveBusy
                                  ? null
                                  : () async {
                                      if (!isPro) {
                                        await PaywallScreen.show(context, triggerFeature: 'Auto-Backup & Restore Google Drive');
                                        return;
                                      }
                                      if (!isLinked) {
                                        setState(() => _isDriveBusy = true);
                                        try {
                                          await provider.connectGoogleDrive();
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Gagal menautkan Google: $e'), backgroundColor: const Color(0xFFE11D48)),
                                            );
                                          }
                                        } finally {
                                          if (mounted) setState(() => _isDriveBusy = false);
                                        }
                                      } else {
                                        await provider.disconnectGoogleDrive();
                                      }
                                    },
                              child: Text(isLinked ? 'Lepas Google' : 'Hubungkan Google', style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isDriveBusy
                                  ? null
                                  : () async {
                                      if (!isPro) {
                                        await PaywallScreen.show(context, triggerFeature: 'Auto-Backup & Restore Google Drive');
                                        return;
                                      }
                                      setState(() => _isDriveBusy = true);
                                      try {
                                        final dt = await provider.backupToGoogleDriveNow();
                                        if (mounted) {
                                          AppFeedback.success();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Terunggah ke Drive (${DateFormatter.formatFullDateTime(dt)})'),
                                              backgroundColor: const Color(0xFF10B981),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Gagal upload Drive: $e'), backgroundColor: const Color(0xFFE11D48)),
                                          );
                                        }
                                      } finally {
                                        if (mounted) setState(() => _isDriveBusy = false);
                                      }
                                    },
                              child: Text(_isDriveBusy ? 'Proses...' : 'Backup Drive', style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _switchBox(
                  title: isPro ? 'Auto-Backup Harian Google Drive' : 'Auto-Backup Harian Google Drive 👑',
                  value: isPro && settings.autoDriveBackup,
                  onChanged: (val) async {
                    if (!isPro) {
                      await PaywallScreen.show(context, triggerFeature: 'Auto-Backup Harian Google Drive');
                      return;
                    }
                    if (val && !isLinked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hubungkan akun Google terlebih dahulu.'), backgroundColor: Color(0xFFF59E0B)),
                      );
                      return;
                    }
                    await provider.toggleAutoDriveBackup(val);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isDriveBusy
                            ? null
                            : () async {
                                if (!isPro) {
                                  await PaywallScreen.show(context, triggerFeature: 'Pulihkan Backup dari Google Drive');
                                  return;
                                }
                                setState(() => _isDriveBusy = true);
                                try {
                                  final res = await provider.fetchGoogleDriveBackupForRestore();
                                  if (!mounted) return;
                                  setState(() => _isDriveBusy = false);
                                  await _showConfirmRestoreDialog(
                                    sourceLabel: 'Google Drive (AppData)',
                                    validation: res.validation,
                                    cloudModifiedTime: res.modifiedTime,
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Gagal unduh Drive: $e'), backgroundColor: const Color(0xFFE11D48)),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _isDriveBusy = false);
                                }
                              },
                        child: const Text('📥 Pulihkan Drive', style: TextStyle(color: Color(0xFF67E8F9), fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _confirmReset,
                        style: OutlinedButton.styleFrom(side: BorderSide(color: const Color(0xFFF43F5E).withOpacity(0.5))),
                        child: const Text('🔄 Reset Simulasi', style: TextStyle(color: Color(0xFFFECDD3), fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 6. LISENSI & TENTANG
          GlassCard(
            borderRadius: 26,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('6. LISENSI & TENTANG', 'Status PRO, Aktivasi & Legal', const Color(0xFFD946EF)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  tileColor: Colors.black.withOpacity(0.28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: isPro ? const Color(0xFF34D399).withOpacity(0.5) : const Color(0xFFFBBF24).withOpacity(0.5)),
                  ),
                  leading: const Text('👑', style: TextStyle(fontSize: 22)),
                  title: Text(provider.proStatusSummaryLabel, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                  subtitle: Text(isPro ? 'Ketuk untuk detail langganan' : 'Ketuk untuk Upgrade / Trial 14 Hari', style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white60),
                  onTap: () {
                    AppFeedback.tap();
                    if (isPro) {
                      PaywallScreen.showActiveSubscriptionSheet(context);
                    } else {
                      PaywallScreen.show(context);
                    }
                  },
                ),
                if (!kIsPlayStoreBuild) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        AppFeedback.tap();
                        DirectDanaPaymentSheet.show(
                          context,
                          offer: SubscriptionService.defaultFallbackOffers().first,
                          focusActivationInput: true,
                        );
                      },
                      icon: const Icon(Icons.vpn_key_outlined, size: 15, color: Color(0xFFFDE68A)),
                      label: const Text(
                        'Masukkan Kode Aktivasi PRO',
                        style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: const Color(0xFFFBBF24).withOpacity(0.5))),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => LegalDocumentSheet.showTerms(context),
                        child: const Text('📜 Syarat & Ketentuan', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => LegalDocumentSheet.showPrivacy(context),
                        child: const Text('🛡️ Kebijakan Privasi', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  _switchBox(
                    title: '🛠️ Simulasi Mode PRO (Debug Only)',
                    value: isPro,
                    onChanged: (_) {
                      AppFeedback.tap();
                      provider.toggleProPreview();
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 22),
          Text(
            'Pengembang: Moch Khoirul Azman • Kas-Santri v3.2 • ${settings.namaPondok} • © 2026',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String tag, String title, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tag,
          style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _sliderRow({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
            Text(
              valueText,
              style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w800),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: const Color(0xFF34D399),
            inactiveColor: Colors.white12,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _switchBox({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF34D399),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
