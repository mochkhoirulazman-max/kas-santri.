import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/santri.dart';
import '../providers/kas_santri_provider.dart';

class TambahSantriBottomSheet extends StatefulWidget {
  const TambahSantriBottomSheet({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TambahSantriBottomSheet(),
    );
  }

  @override
  State<TambahSantriBottomSheet> createState() => _TambahSantriBottomSheetState();
}

class _TambahSantriBottomSheetState extends State<TambahSantriBottomSheet> {
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _kamarController = TextEditingController(text: 'Kamar 1');
  final TextEditingController _setoranController = TextEditingController(text: '300000');
  final TextEditingController _jatahController = TextEditingController(text: '10000');
  final TextEditingController _tunggakanController = TextEditingController(text: '0');

  @override
  void dispose() {
    _namaController.dispose();
    _kamarController.dispose();
    _setoranController.dispose();
    _jatahController.dispose();
    _tunggakanController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nama = _namaController.text.trim();
    if (nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama lengkap santri wajib diisi!'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    final kamar = _kamarController.text.trim().isNotEmpty ? _kamarController.text.trim() : 'Kamar 1';
    final setoran = int.tryParse(_setoranController.text.trim()) ?? 0;
    final jatah = int.tryParse(_jatahController.text.trim()) ?? 10000;
    final tunggakan = int.tryParse(_tunggakanController.text.trim()) ?? 0;

    final santri = Santri(
      id: const Uuid().v4(),
      namaLengkap: nama,
      namaPanggilan: nama.split(' ').first,
      kamar: kamar,
      saldoTotal: setoran,
      setoranAwal: setoran,
      jatahHarian: jatah > 0 ? jatah : 10000,
      tunggakan: tunggakan,
      catatanTunggakan: tunggakan > 0 ? 'Tunggakan Awal' : '',
    );

    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    await provider.tambahSantriBaru(santri);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Santri $nama berhasil ditambahkan!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E1422),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Color(0x33FFFFFF), width: 1.5),
        ),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '👦 TAMBAH SANTRI BARU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Text('NAMA LENGKAP SANTRI', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            TextField(
              controller: _namaController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(hintText: 'Contoh: Muhammad Farhan'),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('KAMAR / ASRAMA', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _kamarController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(hintText: 'Kamar 1'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SETORAN AWAL (RP)', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _setoranController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(hintText: '300000'),
                        onChanged: (val) {
                          final v = int.tryParse(val) ?? 0;
                          _jatahController.text = (v ~/ 30).toString();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('JATAH HARIAN (RP/HR)', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _jatahController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFF34D399), fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(hintText: '10000'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TUNGGAKAN AWAL (RP)', style: TextStyle(color: Color(0xFFFDA4AF), fontSize: 10, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _tunggakanController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFFFB7185), fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(hintText: '0'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: const Color(0xFF030712),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 6,
                  shadowColor: const Color(0xFF10B981).withOpacity(0.4),
                ),
                onPressed: _submit,
                child: const Text('SIMPAN DATA SANTRI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
