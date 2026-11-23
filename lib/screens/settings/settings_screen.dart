import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/pengaturan.dart';
import '../../providers/kas_santri_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/currency_formatter.dart';
import '../pin_lock_screen.dart';
import '../transaksi/riwayat_transaksi_screen.dart';
import 'pin_settings_screen.dart';
import 'backup_restore_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _editProfilDialog(PengaturanAplikasi current) {
    final pondokCtrl = TextEditingController(text: current.namaPondok);
    final pengurusCtrl = TextEditingController(text: current.namaPengurus);
    final kontakCtrl = TextEditingController(text: current.kontakPengurus);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profil Lembaga / Pondok'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pondokCtrl,
              decoration: const InputDecoration(labelText: 'Nama Pondok / Asrama'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pengurusCtrl,
              decoration: const InputDecoration(labelText: 'Nama Pengurus / Musyrif'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: kontakCtrl,
              decoration: const InputDecoration(labelText: 'Nomor Kontak / WhatsApp'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final provider = Provider.of<KasSantriProvider>(context, listen: false);
              final updated = current.copyWith(
                namaPondok: pondokCtrl.text.trim(),
                namaPengurus: pengurusCtrl.text.trim(),
                kontakPengurus: kontakCtrl.text.trim(),
              );
              await provider.savePengaturan(updated);
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _editJatahDialog(PengaturanAplikasi current) {
    final jatahCtrl = TextEditingController(text: current.defaultJatahHarian.toString());
    final durasiCtrl = TextEditingController(text: current.defaultDurasiHari.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atur Standar Jatah Pondok'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: jatahCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Default Jatah Harian (Rp)',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: durasiCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Default Durasi Periode (Hari)',
                suffixText: 'hari',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final jatah = int.tryParse(jatahCtrl.text) ?? current.defaultJatahHarian;
              final durasi = int.tryParse(durasiCtrl.text) ?? current.defaultDurasiHari;
              final provider = Provider.of<KasSantriProvider>(context, listen: false);
              final updated = current.copyWith(
                defaultJatahHarian: jatah,
                defaultDurasiHari: durasi,
              );
              await provider.savePengaturan(updated);
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final p = provider.pengaturan;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. Profil Pondok
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Profil Pondok & Pengurus',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.teal),
                      onPressed: () => _editProfilDialog(p),
                    ),
                  ],
                ),
                Text(p.namaPondok, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Pemegang Kas: ${p.namaPengurus}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                if (p.kontakPengurus.isNotEmpty)
                  Text('Kontak: ${p.kontakPengurus}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 2. Pengaturan Finansial & Jatah
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pengaturan Keuangan Santri',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune, size: 18, color: Colors.teal),
                      onPressed: () => _editJatahDialog(p),
                    ),
                  ],
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Default Jatah Harian'),
                  subtitle: Text(CurrencyFormatter.format(p.defaultJatahHarian)),
                  trailing: Text('Durasi: ${p.defaultDurasiHari} hari', style: const TextStyle(color: Colors.grey)),
                ),
                const Divider(height: 16),
                const Text(
                  'Mode Penanganan Sisa Jatah Harian:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                RadioListTile<ModeSisaHarian>(
                  title: const Text('Mode Ketat (Rekomendasi)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Jatah besok tetap standar (Rp 10.000). Sisa uang harian yang tidak diambil menjadi tabungan santri.', style: TextStyle(fontSize: 11)),
                  value: ModeSisaHarian.ketat,
                  groupValue: p.modeSisaHarian,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF00796B),
                  onChanged: (val) {
                    if (val != null) {
                      provider.savePengaturan(p.copyWith(modeSisaHarian: val));
                    }
                  },
                ),
                RadioListTile<ModeSisaHarian>(
                  title: const Text('Mode Akumulasi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Sisa jatah hari ini yang tidak diambil digulung dan ditambahkan ke kuota besok.', style: TextStyle(fontSize: 11)),
                  value: ModeSisaHarian.akumulasi,
                  groupValue: p.modeSisaHarian,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF00796B),
                  onChanged: (val) {
                    if (val != null) {
                      provider.savePengaturan(p.copyWith(modeSisaHarian: val));
                    }
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 3. Menu Keamanan & Database
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline, color: Color(0xFF00796B)),
                title: const Text('Kunci PIN Aplikasi'),
                subtitle: Text(p.pinKeamanan != null ? 'PIN Terpasang (Aktif)' : 'Belum Ada PIN'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PinSettingsScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: Color(0xFF00796B)),
                title: const Text('Buku Mutasi Kas Seluruh Santri'),
                subtitle: const Text('Lihat semua mutasi & filter riwayat'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RiwayatTransaksiScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.backup_outlined, color: Color(0xFF00796B)),
                title: const Text('Cadangkan & Pulihkan Data'),
                subtitle: const Text('Ekspor/Impor database .json lokal'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackupRestoreScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.orange),
                title: const Text('Kunci Sesi Pengurus'),
                subtitle: const Text('Keluar dari sesi kas santri sekarang'),
                onTap: () async {
                  await AuthService.instance.lockSession();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PinLockScreen(isUnlockingSession: true),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Center(
          child: Column(
            children: [
              const Text(
                'Kas Santri v1.0.0 • Offline-First',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                'Sistem Manajemen Uang Saku & Titipan Santri Harian',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
