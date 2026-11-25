import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/santri.dart';
import '../providers/kas_santri_provider.dart';
import '../screens/paywall_screen.dart';
import '../utils/app_feedback.dart';
import '../utils/currency_formatter.dart';

class TambahSantriBottomSheet extends StatefulWidget {
  const TambahSantriBottomSheet({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
  final TextEditingController _setoranController = TextEditingController(text: '300.000');
  final TextEditingController _jatahController = TextEditingController(text: '10.000');
  final TextEditingController _tunggakanController = TextEditingController(text: '0');
  String _sumberDompet = 'TUNAI';
  String _kategoriSantri = Santri.kategoriSantriyin;
  String _statusSantri = Santri.statusAktifVal;

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
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama lengkap santri wajib diisi!'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    final kamar = _kamarController.text.trim().isNotEmpty ? _kamarController.text.trim() : 'Kamar 1';
    final setoran = CurrencyFormatter.parse(_setoranController.text);
    final jatah = CurrencyFormatter.parse(_jatahController.text);
    final tunggakan = CurrencyFormatter.parse(_tunggakanController.text);

    final santri = Santri(
      id: const Uuid().v4(),
      namaLengkap: nama,
      namaPanggilan: nama.split(' ').first,
      kategoriSantri: _kategoriSantri,
      statusSantri: _statusSantri,
      kamar: kamar,
      saldoTotal: setoran,
      setoranAwal: setoran,
      jatahHarian: jatah > 0 ? jatah : 10000,
      tunggakan: tunggakan,
      catatanTunggakan: tunggakan > 0 ? 'Tunggakan Awal' : '',
    );

    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    if (provider.hasReachedFreeSantriLimit) {
      AppFeedback.alert();
      if (mounted) {
        Navigator.pop(context);
        PaywallScreen.show(
          context,
          triggerFeature:
              'Santri Tanpa Batas — Kuota Mode Gratis maksimal ${KasSantriProvider.maxFreeSantriQuota} santri aktif telah tercapai.',
        );
      }
      return;
    }
    await provider.tambahSantriBaru(santri, sumberDompet: _sumberDompet);
    AppFeedback.success();

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
    final kelipatan = Provider.of<KasSantriProvider>(context, listen: false).pengaturan.pembulatanJatah;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
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
          bottom: MediaQuery.of(context).viewInsets.bottom + bottomSafe + 24,
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
                        inputFormatters: [RibuanInputFormatter()],
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(prefixText: 'Rp ', hintText: '300.000'),
                        onChanged: (val) {
                          final v = CurrencyFormatter.parse(val);
                          final jatah = CurrencyFormatter.hitungJatahHarianBulat(v, 30, kelipatan: kelipatan);
                          _jatahController.text = jatah > 0 ? CurrencyFormatter.formatWithoutSymbol(jatah) : '0';
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
                        inputFormatters: [RibuanInputFormatter()],
                        style: const TextStyle(color: Color(0xFF34D399), fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(prefixText: 'Rp ', hintText: '10.000'),
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
                        inputFormatters: [RibuanInputFormatter()],
                        style: const TextStyle(color: Color(0xFFFB7185), fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(prefixText: 'Rp ', hintText: '0'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Text('KELOMPOK SANTRI (BUKU INFAK)', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildPillChoice(
                  label: 'Santriyin',
                  value: Santri.kategoriSantriyin,
                  selectedValue: _kategoriSantri,
                  accent: const Color(0xFF38BDF8),
                  onSelect: (v) => setState(() => _kategoriSantri = v),
                ),
                const SizedBox(width: 6),
                _buildPillChoice(
                  label: 'Santriyat',
                  value: Santri.kategoriSantriyat,
                  selectedValue: _kategoriSantri,
                  accent: const Color(0xFFD946EF),
                  onSelect: (v) => setState(() => _kategoriSantri = v),
                ),
                const SizedBox(width: 6),
                _buildPillChoice(
                  label: 'Santri Baru',
                  value: Santri.kategoriSantriBaru,
                  selectedValue: _kategoriSantri,
                  accent: const Color(0xFFFBBF24),
                  onSelect: (v) => setState(() => _kategoriSantri = v),
                ),
              ],
            ),

            const SizedBox(height: 10),

            const Text('STATUS KEAKTIFAN SANTRI', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildPillChoice(
                  label: 'Aktif',
                  value: Santri.statusAktifVal,
                  selectedValue: _statusSantri,
                  accent: const Color(0xFF10B981),
                  onSelect: (v) => setState(() => _statusSantri = v),
                ),
                const SizedBox(width: 6),
                _buildPillChoice(
                  label: 'Pulang / Izin',
                  value: Santri.statusPulangVal,
                  selectedValue: _statusSantri,
                  accent: const Color(0xFF34D399),
                  onSelect: (v) => setState(() => _statusSantri = v),
                ),
                const SizedBox(width: 6),
                _buildPillChoice(
                  label: 'Pindah / Boyong',
                  value: Santri.statusPindahVal,
                  selectedValue: _statusSantri,
                  accent: const Color(0xFF94A3B8),
                  onSelect: (v) => setState(() => _statusSantri = v),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Text('SUMBER DOMPET SETORAN AWAL', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildDompetChip('💵 Kas Laci Tunai', 'TUNAI', const Color(0xFF34D399)),
                const SizedBox(width: 8),
                _buildDompetChip('🏦 Rekening Bank', 'REKENING', const Color(0xFF38BDF8)),
              ],
            ),

            const SizedBox(height: 18),

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
    ),
    );
  }

  Widget _buildPillChoice({
    required String label,
    required String value,
    required String selectedValue,
    required Color accent,
    required ValueChanged<String> onSelect,
  }) {
    final isSelected = selectedValue == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          onSelect(value);
        },
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? accent.withOpacity(0.18) : const Color(0xFF060A14),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: isSelected ? accent : Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? accent : Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDompetChip(String label, String value, Color accent) {
    final isSelected = _sumberDompet == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          setState(() => _sumberDompet = value);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? accent.withOpacity(0.18) : const Color(0xFF060A14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? accent : Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? accent : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
