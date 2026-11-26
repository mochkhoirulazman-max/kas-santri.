import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_config.dart';
import '../database/database_helper.dart';
import '../providers/kas_santri_provider.dart';
import '../screens/paywall_screen.dart';
import '../services/backup_service.dart';
import '../services/cloud_backup_service.dart';
import '../utils/app_feedback.dart';
import '../utils/date_formatter.dart';

/// Helper terpusat untuk Backup & Restore Lokal (`.JSON` gratis / `.KSBAK` AES-256 PRO)
/// melalui Android SAF (`saveFile`) + Share, serta Cloud Backup Online (Supabase Cloud Vault).
class EncryptedBackupHelper {
  static Future<T> _runWithLoading<T>(
    BuildContext context,
    String message,
    Future<T> Function() task,
  ) async {
    var dialogOpen = false;
    if (context.mounted) {
      dialogOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: const Color(0xFF0E1628),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
              ),
            ),
            content: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Color(0xFF34D399),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      return await task();
    } finally {
      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  static Future<String?> _promptBackupPassword(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String actionLabel,
    bool confirmField = false,
  }) async {
    final pwdCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var obscure = true;
    String? errorMsg;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF0E1628),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pwdCtrl,
                obscureText: obscure,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Password Enkripsi (min. 4 karakter)',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    onPressed: () => setDlg(() => obscure = !obscure),
                  ),
                ),
              ),
              if (confirmField) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscure,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Ulangi Password Enkripsi',
                    isDense: true,
                  ),
                ),
              ],
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMsg!,
                  style: const TextStyle(
                    color: Color(0xFFFDA4AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                final p1 = pwdCtrl.text;
                if (p1.trim().length < 4) {
                  setDlg(() => errorMsg = 'Password minimal 4 karakter.');
                  return;
                }
                if (confirmField && p1 != confirmCtrl.text) {
                  setDlg(() => errorMsg = 'Konfirmasi password tidak sama.');
                  return;
                }
                Navigator.pop(ctx, p1);
              },
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
    pwdCtrl.dispose();
    confirmCtrl.dispose();
    return result;
  }

  static Future<({Uint8List bytes, String fileName})?> _prepareLocalPayload(
    BuildContext context, {
    required bool encrypted,
  }) async {
    if (encrypted) {
      final provider = Provider.of<KasSantriProvider>(context, listen: false);
      if (!provider.hasProAccess) {
        AppFeedback.alert();
        await PaywallScreen.show(
          context,
          triggerFeature: 'Backup Terenkripsi Militer AES-256 (.KSBAK)',
        );
        return null;
      }
      final password = await _promptBackupPassword(
        context,
        title: 'Buat Backup Terenkripsi (.KSBAK)',
        subtitle:
            'File akan dikunci dengan AES-256-GCM + PBKDF2-SHA256. Simpan password ini baik-baik karena tidak bisa dipulihkan jika lupa.',
        actionLabel: 'Enkripsi Data',
        confirmField: true,
      );
      if (password == null || !context.mounted) return null;

      final bytes = await _runWithLoading<Uint8List>(
        context,
        'Mengenkripsi cadangan .KSBAK di latar belakang...',
        () async {
          final dump = await DatabaseHelper.instance.dumpBackupJson();
          return BackupService.encryptBackupToKsbak(
            backupData: dump,
            password: password,
          );
        },
      );
      return (
        bytes: bytes,
        fileName:
            'backup_kas_santri_${DateTime.now().millisecondsSinceEpoch}.ksbak',
      );
    }

    final bytes = await _runWithLoading<Uint8List>(
      context,
      'Menyiapkan file cadangan .JSON...',
      () async {
        final dump = await DatabaseHelper.instance.dumpBackupJson();
        final jsonStr = const JsonEncoder.withIndent('  ').convert(dump);
        return Uint8List.fromList(utf8.encode(jsonStr));
      },
    );
    return (
      bytes: bytes,
      fileName:
          'backup_kas_santri_${DateTime.now().millisecondsSinceEpoch}.json',
    );
  }

  static Future<void> saveLocalBackupToDevice(
    BuildContext context, {
    required bool encrypted,
  }) async {
    AppFeedback.tap();
    try {
      final payload = await _prepareLocalPayload(context, encrypted: encrypted);
      if (payload == null || !context.mounted) return;
      final sizeKb = (payload.bytes.length / 1024).toStringAsFixed(1);

      String? savedPath;
      try {
        savedPath = await FilePicker.platform.saveFile(
          dialogTitle: encrypted
              ? 'Simpan Backup Terenkripsi (.KSBAK)'
              : 'Simpan Backup Standar (.JSON)',
          fileName: payload.fileName,
          bytes: payload.bytes,
        );
      } catch (_) {
        // Fallback ke direktori dokumen internal bila SAF saveFile tidak tersedia
        final docs = await getApplicationDocumentsDirectory();
        final backupDir = Directory(p.join(docs.path, 'backups'));
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }
        final fallbackFile = File(p.join(backupDir.path, payload.fileName));
        await fallbackFile.writeAsBytes(payload.bytes, flush: true);
        savedPath = fallbackFile.path;
      }

      if (savedPath == null || !context.mounted) return;
      AppFeedback.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Backup tersimpan ($sizeKb KB): ${p.basename(savedPath)}',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      AppFeedback.alert();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan backup ke memori HP: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  static Future<void> shareLocalBackupFile(
    BuildContext context, {
    required bool encrypted,
  }) async {
    AppFeedback.tap();
    try {
      final payload = await _prepareLocalPayload(context, encrypted: encrypted);
      if (payload == null || !context.mounted) return;
      final sizeKb = (payload.bytes.length / 1024).toStringAsFixed(1);

      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, payload.fileName));
      await file.writeAsBytes(payload.bytes, flush: true);

      AppFeedback.success();
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/octet-stream')],
        text: encrypted
            ? 'Backup Terenkripsi Kas-Santri (.KSBAK • $sizeKb KB)'
            : 'Backup Kas-Santri (.JSON • $sizeKb KB)',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📤 Siap dibagikan: ${payload.fileName} ($sizeKb KB)',
            ),
            backgroundColor: const Color(0xFF0E7490),
          ),
        );
      }
    } catch (e) {
      AppFeedback.alert();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan file backup: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  static Future<void> _showExportDestinationSheet(
    BuildContext context, {
    required bool encrypted,
  }) async {
    if (encrypted) {
      final provider = Provider.of<KasSantriProvider>(context, listen: false);
      if (!provider.hasProAccess) {
        AppFeedback.alert();
        await PaywallScreen.show(
          context,
          triggerFeature: 'Backup Terenkripsi Militer AES-256 (.KSBAK)',
        );
        return;
      }
    }
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xF5072536), Color(0xF80A1428)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                encrypted
                    ? 'Pilih Tujuan Backup Terenkripsi (.KSBAK)'
                    : 'Pilih Tujuan Backup Standar (.JSON)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    saveLocalBackupToDevice(context, encrypted: encrypted);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: const Color(0xFF030712),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.save_alt_rounded, size: 18),
                  label: const Text(
                    '💾 Simpan ke Memori HP',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    shareLocalBackupFile(context, encrypted: encrypted);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF67E8F9),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text(
                    '📤 Bagikan File (WA / Drive / Telegram)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> backupPlainJson(BuildContext context) async {
    AppFeedback.tap();
    await _showExportDestinationSheet(context, encrypted: false);
  }

  static Future<void> backupEncryptedKsbak(BuildContext context) async {
    AppFeedback.tap();
    await _showExportDestinationSheet(context, encrypted: true);
  }

  static Future<void> restoreBackupAnyFormat(
    BuildContext context,
    KasSantriProvider provider,
  ) async {
    AppFeedback.tap();
    try {
      // Gunakan FileType.any agar file .ksbak tidak berwarna abu-abu di File Picker Android
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      Uint8List? bytes = picked.bytes;
      if (bytes == null && picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File backup kosong atau gagal dibaca.'),
              backgroundColor: Color(0xFFE11D48),
            ),
          );
        }
        return;
      }

      final fileNameLower = picked.name.toLowerCase();
      final isKsbak = fileNameLower.endsWith('.ksbak') ||
          BackupService.isEncryptedKsbakBytes(bytes);

      final BackupValidationResult validation;
      if (isKsbak) {
        if (!context.mounted) return;
        if (!provider.hasProAccess) {
          AppFeedback.alert();
          await PaywallScreen.show(
            context,
            triggerFeature: 'Buka & Pulihkan Backup Terenkripsi AES-256 (.KSBAK)',
          );
          return;
        }
        final password = await _promptBackupPassword(
          context,
          title: 'Buka Backup Terenkripsi (.KSBAK)',
          subtitle:
              'Masukkan password enkripsi yang dipakai saat membuat file .ksbak ini.',
          actionLabel: 'Buka & Verifikasi',
        );
        if (password == null || !context.mounted) return;

        final ksbakBytes = bytes;
        validation = await _runWithLoading<BackupValidationResult>(
          context,
          'Membuka enkripsi & memverifikasi .KSBAK...',
          () => BackupService.decryptAndValidateKsbak(
            bytes: ksbakBytes,
            password: password,
          ),
        );
      } else {
        final rawJson = utf8.decode(bytes, allowMalformed: true);
        validation = BackupService.validateJsonString(rawJson);
      }

      if (!context.mounted) return;
      await _confirmAndApplyRestore(
        context,
        provider: provider,
        sourceLabel: isKsbak ? 'File Lokal Terenkripsi (.KSBAK)' : 'File Lokal (.JSON)',
        validation: validation,
      );
    } catch (e) {
      AppFeedback.alert();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memulihkan backup: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  static Future<void> _confirmAndApplyRestore(
    BuildContext context, {
    required KasSantriProvider provider,
    required String sourceLabel,
    required BackupValidationResult validation,
  }) async {
    if (!validation.isValid || validation.parsedData == null) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            validation.errorMessage ?? 'File backup tidak valid atau rusak.',
          ),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
      return;
    }

    final exportedDt = validation.exportedAt != null
        ? DateTime.tryParse(validation.exportedAt!)
        : null;
    final dateText = exportedDt != null
        ? DateFormatter.formatFullDateTime(exportedDt)
        : '-';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1628),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF38BDF8)),
        ),
        title: const Text(
          'Pulihkan Data Backup?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'Sumber: $sourceLabel\n'
          'Tanggal Backup: $dateText\n\n'
          '• Santri: ${validation.santriCount} • Setoran: ${validation.setoranCount}\n'
          '• Transaksi: ${validation.transaksiCount} • Mutasi: ${validation.mutasiDompetCount}\n'
          '• Infak: ${validation.infakCount} • Serah Terima: ${validation.serahTerimaInfakCount}\n'
          '• Tabungan Terpisah: ${validation.transaksiTabunganCount}\n\n'
          'Data lokal saat ini akan diganti dengan data backup.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
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
            child: const Text(
              'Ya, Pulihkan',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await _runWithLoading<void>(
        context,
        'Memulihkan seluruh data pondok...',
        () => provider.restoreFromBackupJson(validation.parsedData!),
      );
      if (context.mounted) {
        AppFeedback.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alhamdulillah! Data backup berhasil dipulihkan.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  static Future<void> _showCloudNotConfiguredDialog(BuildContext context) async {
    AppFeedback.alert();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1628),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFFBBF24)),
        ),
        title: const Text(
          '☁️ Cloud Vault Belum Tersambung',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          'Server Cloud Backup Online (SUPABASE_URL & SUPABASE_ANON_KEY) belum dipasang pada build APK ini.\n\n'
          'Tenang, seluruh data Anda tetap aman memakai Simpan ke Memori HP atau Bagikan File (.KSBAK / .JSON) ke WhatsApp / Google Drive Anda.',
          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.white60)),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              shareLocalBackupFile(context, encrypted: false);
            },
            child: const Text('📤 Bagikan .JSON'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: const Color(0xFF030712),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              saveLocalBackupToDevice(context, encrypted: false);
            },
            child: const Text('💾 Simpan ke HP'),
          ),
        ],
      ),
    );
  }

  static Future<void> showCloudBackupDialog(
    BuildContext context,
    KasSantriProvider provider,
  ) async {
    AppFeedback.tap();
    if (!AppConfig.isSupabaseConfigured) {
      await _showCloudNotConfiguredDialog(context);
      return;
    }

    final lastMeta = await CloudBackupService.instance.getLastMeta();
    if (!context.mounted) return;

    final suggestedKey = lastMeta?.backupKey ??
        CloudBackupService.normalizeBackupKey(
          provider.pengaturan.namaPondok.isNotEmpty
              ? '${provider.pengaturan.namaPondok}_2026'
              : provider.deviceId,
        );
    final keyCtrl = TextEditingController(text: suggestedKey);
    final pwdCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var obscure = true;
    String? errorMsg;

    final formResult = await showDialog<({String key, String password})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF0E1628),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFF38BDF8)),
          ),
          title: const Text(
            '☁️ Cadangkan ke Cloud Online',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Data dienkripsi AES-256-GCM di HP Anda sebelum diunggah ke Cloud Vault. Buat Kode Pondok & Password untuk memulihkan saat ganti HP.',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    labelText: 'Kode Backup Pondok (min. 4 karakter)',
                    hintText: 'Contoh: PONDOK_ALIKHLAS_2026',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pwdCtrl,
                  obscureText: obscure,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Password Enkripsi (min. 4 karakter)',
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      onPressed: () => setDlg(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscure,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Ulangi Password Enkripsi',
                    isDense: true,
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMsg!,
                    style: const TextStyle(color: Color(0xFFFDA4AF), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: const Color(0xFF030712),
              ),
              onPressed: () {
                final k = CloudBackupService.normalizeBackupKey(keyCtrl.text);
                if (k.length < 4) {
                  setDlg(() => errorMsg = 'Kode Backup Pondok minimal 4 karakter.');
                  return;
                }
                if (pwdCtrl.text.trim().length < 4) {
                  setDlg(() => errorMsg = 'Password enkripsi minimal 4 karakter.');
                  return;
                }
                if (pwdCtrl.text != confirmCtrl.text) {
                  setDlg(() => errorMsg = 'Konfirmasi password tidak cocok.');
                  return;
                }
                Navigator.pop(ctx, (key: k, password: pwdCtrl.text));
              },
              child: const Text('Enkripsi & Unggah', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
    keyCtrl.dispose();
    pwdCtrl.dispose();
    confirmCtrl.dispose();

    if (formResult == null || !context.mounted) return;

    final res = await _runWithLoading<CloudBackupUploadResult>(
      context,
      'Mengenkripsi & mengunggah ke Cloud Online...',
      () async {
        final dump = await DatabaseHelper.instance.dumpBackupJson();
        return CloudBackupService.instance.uploadEncryptedBackup(
          backupKey: formResult.key,
          password: formResult.password,
          deviceId: provider.deviceId,
          namaPondok: provider.pengaturan.namaPondok,
          backupData: dump,
        );
      },
    );

    if (!context.mounted) return;
    if (res.success) {
      AppFeedback.success();
      final sizeKb = (res.sizeBytes / 1024).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '☁️ Cadangan Online sukses! Kode: ${res.backupKey} ($sizeKb KB)',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
    }
  }

  static Future<void> showCloudRestoreDialog(
    BuildContext context,
    KasSantriProvider provider,
  ) async {
    AppFeedback.tap();
    if (!AppConfig.isSupabaseConfigured) {
      await _showCloudNotConfiguredDialog(context);
      return;
    }

    final lastMeta = await CloudBackupService.instance.getLastMeta();
    if (!context.mounted) return;

    final keyCtrl = TextEditingController(text: lastMeta?.backupKey ?? '');
    final pwdCtrl = TextEditingController();
    var obscure = true;
    String? errorMsg;

    final formResult = await showDialog<({String key, String password})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF0E1628),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFF38BDF8)),
          ),
          title: const Text(
            '☁️ Pulihkan dari Cloud Online',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan Kode Backup Pondok & Password Enkripsi yang Anda buat saat mencadangkan online.',
                style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(
                  labelText: 'Kode Backup Pondok',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pwdCtrl,
                obscureText: obscure,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Password Enkripsi',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    onPressed: () => setDlg(() => obscure = !obscure),
                  ),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMsg!,
                  style: const TextStyle(color: Color(0xFFFDA4AF), fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF030712),
              ),
              onPressed: () {
                final k = CloudBackupService.normalizeBackupKey(keyCtrl.text);
                if (k.length < 4) {
                  setDlg(() => errorMsg = 'Masukkan Kode Backup minimal 4 karakter.');
                  return;
                }
                if (pwdCtrl.text.isEmpty) {
                  setDlg(() => errorMsg = 'Masukkan password enkripsi.');
                  return;
                }
                Navigator.pop(ctx, (key: k, password: pwdCtrl.text));
              },
              child: const Text('Unduh & Buka', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
    keyCtrl.dispose();
    pwdCtrl.dispose();

    if (formResult == null || !context.mounted) return;

    final res = await _runWithLoading<CloudBackupDownloadResult>(
      context,
      'Mengunduh & membuka enkripsi dari Cloud Online...',
      () => CloudBackupService.instance.downloadAndDecryptBackup(
        backupKey: formResult.key,
        password: formResult.password,
      ),
    );

    if (!context.mounted) return;
    if (!res.success || res.validation == null) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
      return;
    }

    await _confirmAndApplyRestore(
      context,
      provider: provider,
      sourceLabel: 'Cloud Vault Online (${res.backupKey})',
      validation: res.validation!,
    );
  }
}
