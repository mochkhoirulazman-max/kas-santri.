import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/pengaturan.dart';
import '../../providers/kas_santri_provider.dart';
import '../../database/database_helper.dart';
import '../../services/auth_service.dart';
import '../../services/backup_service.dart';
import '../../utils/app_feedback.dart';
import '../../utils/date_formatter.dart';
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
  late TextEditingController _namaPengurusController;
  bool _isDriveBusy = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    _namaPondokController = TextEditingController(text: provider.pengaturan.namaPondok);
    _namaPengurusController = TextEditingController(text: provider.pengaturan.namaPengurus);
  }

  @override
  void dispose() {
    _namaPondokController.dispose();
    _namaPengurusController.dispose();
    super.dispose();
  }

  Future<void> _lockAppNow() async {
    AppFeedback.tap();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
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

  Future<void> _pickLogo() async {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo pondok berhasil diperbarui!'),
            backgroundColor: Color(0xFF10B981),
          ),
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
      await Share.shareXFiles([XFile(file.path)], text: 'Backup Kas Santri PPS Miftahussunan');
    } catch (e) {
      AppFeedback.alert();
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final rawJson = await file.readAsString();
      final validation = BackupService.validateJsonString(rawJson);
      if (!validation.isValid || validation.parsedData == null) {
        AppFeedback.alert();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(validation.errorMessage ?? 'File JSON backup tidak valid.'),
              backgroundColor: const Color(0xFFE11D48),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      await _showConfirmRestoreDialog(
        sourceLabel: 'File Lokal (.JSON)',
        validation: validation,
      );
    } catch (e) {
      AppFeedback.alert();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membaca file backup: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  Future<void> _showConfirmRestoreDialog({
    required String sourceLabel,
    required BackupValidationResult validation,
    DateTime? cloudModifiedTime,
  }) async {
    final exportedDt = validation.exportedAt != null
        ? DateTime.tryParse(validation.exportedAt!)
        : null;
    final dateText = cloudModifiedTime != null
        ? DateFormatter.formatFullDateTime(cloudModifiedTime)
        : (exportedDt != null ? DateFormatter.formatFullDateTime(exportedDt) : '-');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
        ),
        title: const Text(
          'Pulihkan Data Backup?',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sumber: $sourceLabel\nTanggal Backup: $dateText',
              style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF060B14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                '• Data Santri: ${validation.santriCount}\n'
                '• Setoran Bulanan: ${validation.setoranCount}\n'
                '• Transaksi Harian: ${validation.transaksiCount}\n'
                '• Log Tunggakan: ${validation.tunggakanLogCount}\n'
                '• Mutasi Dompet: ${validation.mutasiDompetCount}\n'
                '• Cash Opname: ${validation.cashOpnameCount}',
                style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.45),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Seluruh data lokal saat ini akan ditimpa dengan data dari backup di atas.',
              style: TextStyle(color: Color(0xFFFDA4AF), fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: const Color(0xFF030712),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Pulihkan Sekarang', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider = Provider.of<KasSantriProvider>(context, listen: false);
      await provider.restoreFromBackupJson(validation.parsedData!);
      if (mounted) {
        AppFeedback.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alhamdulillah! Data berhasil dipulihkan dari backup.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _confirmDisablePinDialog() async {
    final pinController = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFF43F5E), width: 1.2),
        ),
        title: const Text(
          'Nonaktifkan Kunci PIN?',
          style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan PIN saat ini untuk mematikan kunci pengaman aplikasi:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'PIN Saat Ini (4–6 Digit)',
                prefixIcon: Icon(Icons.lock_open),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
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
      await Provider.of<KasSantriProvider>(context, listen: false).loadAllData();
      if (mounted) {
        AppFeedback.tap();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunci PIN dinonaktifkan.'),
            backgroundColor: Color(0xFFF59E0B),
          ),
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
          'Seluruh data santri dan transaksi akan dikembalikan ke kondisi awal prototipe PPS Miftahussunan.',
          style: TextStyle(fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            onPressed: () async {
              final provider = Provider.of<KasSantriProvider>(context, listen: false);
              await provider.resetToInitialData();
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data simulasi berhasil di-reset ke kondisi awal!'),
                    backgroundColor: Color(0xFF10B981),
                  ),
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
    final settings = provider.pengaturan;
    final hasPin = settings.pinKeamanan != null && settings.pinKeamanan!.isNotEmpty;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 120 + bottomSafe),
        children: [
        // 1. Konfigurasi Pondok
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'KONFIGURASI PONDOK',
                          style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Identitas, Logo & Kebijakan Kas',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _pickLogo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: provider.isProUser ? const Color(0xFF10B981) : const Color(0xFF1E1B4B),
                      foregroundColor: provider.isProUser ? const Color(0xFF04121A) : const Color(0xFFFDE68A),
                      side: provider.isProUser
                          ? null
                          : const BorderSide(color: Color(0xFFFBBF24), width: 1.1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 14),
                    label: Text(
                      provider.isProUser ? 'Upload Logo' : 'Upload Logo 👑',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Nama Pondok Pesantren
              const Text('NAMA PONDOK PESANTREN', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              TextField(
                controller: _namaPondokController,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(isDense: true),
                onSubmitted: (val) async {
                  if (val.trim().isNotEmpty) {
                    await provider.savePengaturan(settings.copyWith(namaPondok: val.trim()));
                  }
                },
              ),

              const SizedBox(height: 12),

              // Nama Pengurus
              const Text('NAMA PENGURUS / BENDAHARA', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              TextField(
                controller: _namaPengurusController,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(isDense: true),
                onSubmitted: (val) async {
                  if (val.trim().isNotEmpty) {
                    await provider.savePengaturan(settings.copyWith(namaPengurus: val.trim()));
                  }
                },
              ),

              const SizedBox(height: 14),

              // Pembulatan Jatah Harian Otomatis
              const Text('PEMBULATAN JATAH HARIAN OTOMATIS', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                value: settings.pembulatanJatah == 1000 ? 1000 : 500,
                isExpanded: true,
                dropdownColor: const Color(0xFF090E1A),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(
                    value: 500,
                    child: Text('Kelipatan Rp 500 ke bawah (Contoh: Rp 8.000/hari)', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 1000,
                    child: Text('Kelipatan Rp 1.000 ke bawah (Contoh: Rp 8.000/hari)', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    AppFeedback.tap();
                    provider.savePengaturan(settings.copyWith(pembulatanJatah: val));
                  }
                },
              ),

              const SizedBox(height: 14),

              // Kebijakan Sisa Jatah Harian
              const Text('KEBIJAKAN SISA JATAH HARIAN', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              DropdownButtonFormField<ModeSisaHarian>(
                value: settings.modeSisaHarian,
                isExpanded: true,
                dropdownColor: const Color(0xFF090E1A),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(
                    value: ModeSisaHarian.ketat,
                    child: Text('Mode Ketat (Tiap hari kuota tetap, sisa jadi tabungan)', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: ModeSisaHarian.akumulasi,
                    child: Text('Mode Akumulasi (Sisa hari ini ditambah ke kuota besok)', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    provider.savePengaturan(settings.copyWith(modeSisaHarian: val));
                  }
                },
              ),

              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white12),
              const SizedBox(height: 14),

              // Cadangkan & Pulihkan Data Lokal (.JSON) & Reset Simulasi
              const Text('CADANGKAN & PULIHKAN DATA LOKAL (.JSON)', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _backupJson,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF060B14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('⬇️', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 6),
                            Text('Backup (.JSON)', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: _restoreLocalJson,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF060B14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.45)),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('⬆️', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 6),
                            Text('Restore (.JSON)', style: TextStyle(color: Color(0xFF67E8F9), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _confirmReset,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F0B18).withOpacity(0.42),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFB7185).withOpacity(0.35)),
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🔄', style: TextStyle(fontSize: 11)),
                      SizedBox(width: 6),
                      Text('Reset Simulasi Awal', style: TextStyle(color: Color(0xFFFECDD3), fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. KARTU KEAMANAN & KUNCI APLIKASI (PIN 4-6 DIGIT, BIOMETRIK, AUTO LOCK)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KEAMANAN & KUNCI APLIKASI',
                          style: TextStyle(color: Color(0xFFFBBF24), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kunci PIN 4–6 Digit & Biometrik',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasPin ? const Color(0xFF10B981).withOpacity(0.18) : Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: hasPin ? const Color(0xFF34D399) : Colors.white24),
                    ),
                    child: Text(
                      hasPin ? '🔒 PIN Aktif' : 'Belum Dipasang',
                      style: TextStyle(
                        color: hasPin ? const Color(0xFF34D399) : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF060B14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Aktifkan Kunci PIN (4–6 Digit)',
                        style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Switch(
                      value: hasPin,
                      activeColor: const Color(0xFF34D399),
                      onChanged: (val) {
                        AppFeedback.tap();
                        if (val && !hasPin) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PinSettingsScreen()),
                          );
                        } else if (!val && hasPin) {
                          _confirmDisablePinDialog();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(hasPin ? Icons.edit_outlined : Icons.lock_outline, size: 15),
                      label: Text(
                        hasPin ? 'Ubah PIN' : 'Pasang PIN (4–6 Digit)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: const Color(0xFF030712),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        AppFeedback.tap();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PinSettingsScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.lock_clock_outlined, size: 15, color: Color(0xFFFBBF24)),
                      label: const Text(
                        '🔒 Kunci Sekarang',
                        style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _lockAppNow,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('KUNCI OTOMATIS SAAT IDLE', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                value: [0, 1, 5, 15].contains(settings.autoLockMinutes) ? settings.autoLockMinutes : 1,
                isExpanded: true,
                dropdownColor: const Color(0xFF090E1A),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(isDense: true),
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
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF060B14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: provider.isProUser ? Colors.white12 : const Color(0xFFFBBF24).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        provider.isProUser
                            ? 'Buka dengan Sidik Jari / Biometrik'
                            : 'Buka dengan Sidik Jari / Biometrik 👑',
                        style: TextStyle(
                          color: provider.isProUser ? Colors.white : const Color(0xFFFDE68A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: provider.isProUser && settings.isBiometricEnabled,
                      activeColor: const Color(0xFF34D399),
                      onChanged: (val) async {
                        AppFeedback.tap();
                        if (!provider.isProUser) {
                          await PaywallScreen.show(
                            context,
                            triggerFeature: 'Buka Kunci dengan Sidik Jari / Biometrik',
                          );
                          return;
                        }
                        if (val && !hasPin) {
                          AppFeedback.alert();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Aktifkan Kunci PIN 4–6 digit terlebih dahulu.'),
                              backgroundColor: Color(0xFFF59E0B),
                            ),
                          );
                          return;
                        }
                        if (val) {
                          final available = await AuthService.instance.isBiometricsAvailable();
                          if (!available) {
                            AppFeedback.alert();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sensor sidik jari / biometrik tidak tersedia atau belum diatur di perangkat ini.'),
                                  backgroundColor: Color(0xFFF59E0B),
                                ),
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
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  AppFeedback.tap();
                  if (provider.isProUser) {
                    PaywallScreen.showActiveSubscriptionSheet(context);
                  } else {
                    PaywallScreen.show(context);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E170A), Color(0xFF091926)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: settings.isPro ? const Color(0xFF34D399) : const Color(0xFFFBBF24).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('👑', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.isTrialActive
                                  ? provider.proStatusSummaryLabel
                                  : (settings.isPro
                                      ? 'Kas-Santri PRO Aktif ✓'
                                      : 'Upgrade ke Kas-Santri PRO'),
                              style: TextStyle(
                                color: settings.isPro ? const Color(0xFF34D399) : const Color(0xFFFDE68A),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              provider.isTrialActive
                                  ? 'Ketuk untuk lihat sisa hari & opsi upgrade (${settings.namaPondok})'
                                  : (settings.isPro
                                      ? 'Ketuk untuk lihat Status Langganan Aktif (${settings.namaPondok})'
                                      : 'Buka Santri Tanpa Batas, Opname Kas, Scan QR & Ekspor PDF'),
                              style: const TextStyle(color: Colors.white60, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white54),
                    ],
                  ),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF060B14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🛠️ Simulasi Mode PRO (Debug Only)',
                              style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11.5, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Hanya tampil pada build Debug untuk menguji fitur Gratis vs PRO',
                              style: TextStyle(color: Colors.white54, fontSize: 9.5),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: provider.isProUser,
                        activeColor: const Color(0xFFFBBF24),
                        onChanged: (_) {
                          AppFeedback.tap();
                          provider.toggleProPreview();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2B. KARTU CLOUD BACKUP GOOGLE DRIVE (PRO)
        _buildGoogleDriveBackupCard(provider, settings),

        const SizedBox(height: 16),

        // 3. KARTU KHUSUS PENGEMBANG BY MOCH KHOIRUL AZMAN (AREA PALING BAWAH MENU SISTEM - WAJIB)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [
                Color(0xCC091326),
                Color(0xCC0F172A),
                Color(0xCC1E1B4B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFF38BDF8).withOpacity(0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06B6D4).withOpacity(0.35),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar & Developer Title
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF34D399), Color(0xFF38BDF8), Color(0xFFD946EF)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withOpacity(0.5),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF040814),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'MKA',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                          ),
                          child: const Text(
                            'OFFICIAL DEVELOPER CREDIT',
                            style: TextStyle(
                              color: Color(0xFFBAE6FD),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'PENGEMBANG APLIKASI BY MOCH KHOIRUL AZMAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Detail List Info Developer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF060B14).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _buildCreditRow('Instansi Pondok', 'PPS MIFTAHUSSUNAN', const Color(0xFF34D399)),
                    const Divider(color: Colors.white12, height: 16),
                    _buildCreditRow('Hari & Tanggal Dibuat', 'Senin, 23 November 2026', const Color(0xFF7DD3FC)),
                    const Divider(color: Colors.white12, height: 16),
                    _buildCreditRow('Versi & Tema UI', 'v2.5 • Aurora Tactile 2-Grid', const Color(0xFFF0ABFC)),
                    const Divider(color: Colors.white12, height: 16),
                    _buildCreditRow('Lisensi & Hak Cipta', '© 2026 Moch Khoirul Azman', Colors.white),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              const Center(
                child: Text(
                  'Dirancang khusus untuk mempermudah manajemen keluar-masuk uang saku harian, setoran bulanan, dan tunggakan santri secara cepat & akurat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFBAE6FD),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildGoogleDriveBackupCard(
    KasSantriProvider provider,
    PengaturanAplikasi settings,
  ) {
    final isPro = provider.isProUser;
    final linkedEmail = settings.driveAccountEmail;
    final isLinked = linkedEmail != null && linkedEmail.isNotEmpty;
    final lastBackupDt = settings.lastDriveBackupAt != null
        ? DateTime.tryParse(settings.lastDriveBackupAt!)
        : null;
    final lastBackupLabel = lastBackupDt != null
        ? DateFormatter.formatFullDateTime(lastBackupDt)
        : 'Belum pernah dicadangkan';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isPro
              ? const Color(0xFF38BDF8).withOpacity(0.4)
              : const Color(0xFFFBBF24).withOpacity(0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLOUD BACKUP AMAN (APPDATA)',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '☁️ Cloud Backup Google Drive 👑',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPro ? const Color(0xFF064E3B) : const Color(0xFF1E1B4B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPro ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                  ),
                ),
                child: Text(
                  isPro ? '✓ PRO' : '👑 PRO',
                  style: TextStyle(
                    color: isPro ? const Color(0xFF6EE7B7) : const Color(0xFFFDE68A),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status Akun & Backup Terakhir
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF060B14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLinked
                      ? 'Akun Terhubung: $linkedEmail'
                      : 'Akun Google: Belum ditautkan (Mode Offline 100% Aktif)',
                  style: TextStyle(
                    color: isLinked ? const Color(0xFF6EE7B7) : Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Backup Terakhir: $lastBackupLabel',
                  style: const TextStyle(color: Color(0xFF7DD3FC), fontSize: 11),
                ),
                if (isPro && isLinked && provider.hasUnbackedUpLocalChanges) ...[
                  const SizedBox(height: 6),
                  const Text(
                    '⚠️ Terdapat data lokal terbaru yang belum dicadangkan ke Drive.',
                    style: TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Hubungkan / Keluar Akun Google & Cadangkan Sekarang
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isDriveBusy
                      ? null
                      : () async {
                          AppFeedback.tap();
                          if (!isPro) {
                            await PaywallScreen.show(
                              context,
                              triggerFeature: 'Auto-Backup & Restore Google Drive',
                            );
                            return;
                          }
                          if (!isLinked) {
                            setState(() => _isDriveBusy = true);
                            try {
                              final email = await provider.connectGoogleDrive();
                              if (mounted && email != null) {
                                AppFeedback.success();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Berhasil terhubung ke $email'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              }
                            } catch (e) {
                              AppFeedback.alert();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Offline / gagal menautkan akun: $e'),
                                    backgroundColor: const Color(0xFFE11D48),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isDriveBusy = false);
                            }
                          } else {
                            if (provider.hasUnbackedUpLocalChanges) {
                              final proceed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF0F172A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                                  ),
                                  title: const Text(
                                    'Ada Data Belum Dicadangkan',
                                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                                  ),
                                  content: const Text(
                                    'Masih ada perubahan data lokal terbaru yang belum dicadangkan ke Google Drive. Tetap keluar dari akun Google?',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Batal', style: TextStyle(color: Colors.white70)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Tetap Keluar'),
                                    ),
                                  ],
                                ),
                              );
                              if (proceed != true) return;
                            }
                            await provider.disconnectGoogleDrive();
                            if (mounted) {
                              AppFeedback.tap();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Akun Google dilepas. Data lokal tetap aman offline.'),
                                  backgroundColor: Color(0xFF38BDF8),
                                ),
                              );
                            }
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isLinked
                          ? const Color(0xFFFB7185).withOpacity(0.55)
                          : const Color(0xFF38BDF8).withOpacity(0.55),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isLinked ? '🚪 Keluar Google' : '🔗 Hubungkan Google',
                    style: TextStyle(
                      color: isLinked ? const Color(0xFFFECDD3) : const Color(0xFF67E8F9),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isDriveBusy
                      ? null
                      : () async {
                          AppFeedback.tap();
                          if (!isPro) {
                            await PaywallScreen.show(
                              context,
                              triggerFeature: 'Auto-Backup & Restore Google Drive',
                            );
                            return;
                          }
                          setState(() => _isDriveBusy = true);
                          try {
                            final dt = await provider.backupToGoogleDriveNow();
                            if (mounted) {
                              AppFeedback.success();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Backup berhasil diunggah ke Google Drive (${DateFormatter.formatFullDateTime(dt)})',
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (e) {
                            AppFeedback.alert();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal cadangkan ke Drive (pastikan internet aktif): $e'),
                                  backgroundColor: const Color(0xFFE11D48),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isDriveBusy = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: const Color(0xFF030712),
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _isDriveBusy ? 'Memproses...' : '☁️ Cadangkan Sekarang',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Saklar Auto-Backup Harian
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF060B14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Auto-Backup Harian (Latar Belakang)',
                    style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: isPro && settings.autoDriveBackup,
                  activeColor: const Color(0xFF34D399),
                  onChanged: (val) async {
                    AppFeedback.tap();
                    if (!isPro) {
                      await PaywallScreen.show(
                        context,
                        triggerFeature: 'Auto-Backup Harian Google Drive',
                      );
                      return;
                    }
                    if (val && !isLinked) {
                      AppFeedback.alert();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hubungkan akun Google terlebih dahulu sebelum mengaktifkan Auto-Backup Harian.'),
                          backgroundColor: Color(0xFFF59E0B),
                        ),
                      );
                      return;
                    }
                    await provider.toggleAutoDriveBackup(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Tombol Pulihkan dari Google Drive
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Text('📥', style: TextStyle(fontSize: 13)),
              label: const Text(
                'Pulihkan dari Google Drive',
                style: TextStyle(color: Color(0xFF67E8F9), fontSize: 11.5, fontWeight: FontWeight.w900),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF060B14),
                side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.45)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isDriveBusy
                  ? null
                  : () async {
                      AppFeedback.tap();
                      if (!isPro) {
                        await PaywallScreen.show(
                          context,
                          triggerFeature: 'Pulihkan Backup dari Google Drive',
                        );
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
                        AppFeedback.alert();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal mengunduh backup dari Drive: $e'),
                              backgroundColor: const Color(0xFFE11D48),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isDriveBusy = false);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditRow(String label, String value, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10.5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFamily: label.contains('Tanggal') || label.contains('Versi') ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}
