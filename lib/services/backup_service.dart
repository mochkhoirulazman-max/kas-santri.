import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';

class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  /// Ekspor seluruh database ke file JSON dan panggil Share dialog
  Future<File> exportBackupJson() async {
    final data = await DatabaseHelper.instance.dumpBackupJson();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName = 'kas_santri_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour}${now.minute}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'File Cadangan Data Kas Santri (${now.toLocal()})',
    );

    return file;
  }

  /// Impor database dari file JSON yang dipilih pengguna
  Future<bool> importBackupJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      if (!data.containsKey('santri') && !data.containsKey('pengaturan_aplikasi')) {
        throw Exception('Format file cadangan tidak valid.');
      }

      await DatabaseHelper.instance.restoreFromJson(data);
      return true;
    } catch (e) {
      rethrow;
    }
  }
}
