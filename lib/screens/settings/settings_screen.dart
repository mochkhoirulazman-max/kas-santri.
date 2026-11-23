import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/pengaturan.dart';
import '../../providers/kas_santri_provider.dart';
import '../../database/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _namaPondokController;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    _namaPondokController = TextEditingController(text: provider.pengaturan.namaPondok);
  }

  @override
  void dispose() {
    _namaPondokController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final provider = Provider.of<KasSantriProvider>(context, listen: false);
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
    try {
      final dump = await DatabaseHelper.instance.dumpBackupJson();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(dump);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/backup_kas_santri_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles([XFile(file.path)], text: 'Backup Kas Santri PPS Miftahussunan');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal backup: $e'), backgroundColor: const Color(0xFFF43F5E)),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 115),
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
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: const Color(0xFF04121A),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 14),
                    label: const Text('Upload Logo', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
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

              // Cadangkan & Reset Data Simulasi
              const Text('CADANGKAN & RESET DATA SIMULASI', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
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
                          border: Border.all(color: Colors.white12),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('⬇️', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 6),
                            Text('Backup (.JSON)', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: _confirmReset,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F0B18).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFB7185).withOpacity(0.4)),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🔄', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 6),
                            Text('Reset Simulasi', style: TextStyle(color: Color(0xFFFECDD3), fontSize: 11, fontWeight: FontWeight.bold)),
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

        const SizedBox(height: 16),

        // 2. KARTU KHUSUS PENGEMBANG BY MOCH KHOIRUL AZMAN (AREA PALING BAWAH MENU SISTEM - WAJIB)
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
