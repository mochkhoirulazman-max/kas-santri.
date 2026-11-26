import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../providers/kas_santri_provider.dart';
import '../screens/paywall_screen.dart';
import '../services/backup_service.dart';
import '../utils/app_feedback.dart';
import '../utils/date_formatter.dart';

/// Helper terpusat untuk ekspor backup terenkripsi `.ksbak` (AES-256-GCM)
/// dan pemulihan gabungan file `.json` maupun `.ksbak` berpassword.
class EncryptedBackupHelper {
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
          title: Text(
            title,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
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
    return result;
  }

  static Future<void> backupEncryptedKsbak(BuildContext context) async {
    AppFeedback.tap();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    if (!provider.hasProAccess) {
      AppFeedback.alert();
      await PaywallScreen.show(
        context,
        triggerFeature: 'Backup Terenkripsi Militer AES-256 (.KSBAK)',
      );
      return;
    }
    final password = await _promptBackupPassword(
      context,
      title: 'Buat Backup Terenkripsi (.KSBAK)',
      subtitle:
          'File akan dikunci dengan AES-256-GCM + PBKDF2-SHA256. Simpan password ini baik-baik karena tidak bisa dipulihkan jika lupa.',
      actionLabel: 'Enkripsi & Bagikan',
      confirmField: true,
    );
    if (password == null || !context.mounted) return;

    try {
      final dump = await DatabaseHelper.instance.dumpBackupJson();
      final encryptedBytes = await BackupService.encryptBackupToKsbak(
        backupData: dump,
        password: password,
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(
          dir.path,
          'backup_kas_santri_${DateTime.now().millisecondsSinceEpoch}.ksbak',
        ),
      );
      await file.writeAsBytes(encryptedBytes, flush: true);
      AppFeedback.success();
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Backup Terenkripsi Kas-Santri (.KSBAK)',
      );
    } catch (e) {
      AppFeedback.alert();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat backup .ksbak: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  static Future<void> restoreBackupAnyFormat(
    BuildContext context,
    KasSantriProvider provider,
  ) async {
    AppFeedback.tap();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'ksbak'],
      );
      if (result == null || result.files.single.path == null) return;
      final filePath = result.files.single.path!;
      final Uint8List bytes = await File(filePath).readAsBytes();
      final isKsbak = filePath.toLowerCase().endsWith('.ksbak') ||
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
          subtitle: 'Masukkan password enkripsi yang dipakai saat membuat file .ksbak ini.',
          actionLabel: 'Buka & Verifikasi',
        );
        if (password == null) return;
        validation = await BackupService.decryptAndValidateKsbak(
          bytes: bytes,
          password: password,
        );
      } else {
        final rawJson = await File(filePath).readAsString();
        validation = BackupService.validateJsonString(rawJson);
      }

      if (!context.mounted) return;
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
          title: const Text(
            'Pulihkan Data Backup?',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
          ),
          content: Text(
            'Format: ${isKsbak ? 'Terenkripsi (.KSBAK)' : 'Standar (.JSON)'}\n'
            'Tanggal Backup: $dateText\n\n'
            '• Santri: ${validation.santriCount} • Setoran: ${validation.setoranCount}\n'
            '• Transaksi: ${validation.transaksiCount} • Mutasi: ${validation.mutasiDompetCount}\n'
            '• Infak: ${validation.infakCount} • Serah Terima: ${validation.serahTerimaInfakCount}\n\n'
            'Data lokal saat ini akan diganti dengan data backup.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Pulihkan'),
            ),
          ],
        ),
      );

      if (confirm == true && context.mounted) {
        await provider.restoreFromBackupJson(validation.parsedData!);
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
}
