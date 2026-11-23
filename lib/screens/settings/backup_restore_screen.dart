import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/kas_santri_provider.dart';
import '../../services/backup_service.dart';
import '../../database/database_helper.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({Key? key}) : super(key: key);

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isProcessing = false;

  Future<void> _handleExport() async {
    setState(() => _isProcessing = true);
    try {
      final file = await BackupService.instance.exportBackupJson();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File cadangan berhasil dibuat: ${file.path.split('/').last}'),
            backgroundColor: const Color(0xFF00796B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleImport() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan Data dari File?'),
        content: const Text(
          'Seluruh data yang ada saat ini akan ditimpa dengan data dari file cadangan yang Anda pilih. Lanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pilih File & Pulihkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final success = await BackupService.instance.importBackupJson();
      if (success) {
        final provider = Provider.of<KasSantriProvider>(context, listen: false);
        await provider.loadAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data kas santri berhasil dipulihkan 100%!'),
              backgroundColor: Color(0xFF00796B),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulihkan file: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleResetDb() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Seluruh Database?'),
        content: const Text(
          'PERINGATAN: Seluruh data santri, setoran, dan riwayat mutasi akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    final db = await DatabaseHelper.instance.database;
    await db.delete('transaksi_harian');
    await db.delete('setoran_bulanan');
    await db.delete('santri');

    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    await provider.loadAllData();

    setState(() => _isProcessing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database telah dibersihkan.'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadangkan & Pulihkan Data'),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info Offline-First
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.cloud_off, color: Color(0xFF00796B), size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Aplikasi Kas Santri 100% Offline-First. Seluruh transaksi tersimpan aman di memori lokal HP pengurus.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF004D40)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Card Ekspor
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cadangkan Data (Backup)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Simpan salinan database ke file .json atau bagikan langsung ke WhatsApp/Google Drive pengurus.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.file_upload_outlined),
                          label: const Text('Ekspor File Cadangan (.JSON)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00796B),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: _handleExport,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Card Pulihkan
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pulihkan Data (Restore)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Pulihkan data santri dan riwayat mutasi dari file cadangan .json jika Anda berganti HP.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.file_download_outlined),
                          label: const Text('Pilih File Cadangan & Pulihkan'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: _handleImport,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Card Reset Data
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reset Data',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Kosongkan semua data transaksi santri untuk memulai tahun ajaran baru dari awal.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          label: const Text('Kosongkan Database', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: _handleResetDb,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
