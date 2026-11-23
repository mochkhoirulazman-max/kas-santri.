import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/santri.dart';
import '../../models/setoran.dart';
import '../../providers/kas_santri_provider.dart';
import '../../utils/currency_formatter.dart';

class SetoranScreen extends StatefulWidget {
  final VoidCallback? onSaved;

  const SetoranScreen({Key? key, this.onSaved}) : super(key: key);

  @override
  State<SetoranScreen> createState() => _SetoranScreenState();
}

class _SetoranScreenState extends State<SetoranScreen> {
  String? _selectedSantriId;
  TipeSetoran _tipeSetoran = TipeSetoran.awalBulan;
  final TextEditingController _nominalController = TextEditingController(text: '300000');
  final TextEditingController _durasiController = TextEditingController(text: '30');
  final TextEditingController _catatanController = TextEditingController();

  @override
  void dispose() {
    _nominalController.dispose();
    _durasiController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  int get _nominal => int.tryParse(_nominalController.text.trim()) ?? 0;
  int get _durasi => int.tryParse(_durasiController.text.trim()) ?? 30;
  int get _hitungJatah => _durasi > 0 ? (_nominal / _durasi).round() : 0;

  void _setQuick(int nominal, int durasi) {
    setState(() {
      _nominalController.text = nominal.toString();
      _durasiController.text = durasi.toString();
    });
  }

  Future<void> _simpan() async {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final santriList = provider.allSantri.where((s) => s.statusAktif).toList();

    final targetId = _selectedSantriId ?? (santriList.isNotEmpty ? santriList.first.id : null);
    if (targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih santri terlebih dahulu!'), backgroundColor: Color(0xFFF43F5E)),
      );
      return;
    }

    if (_nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal setoran harus lebih dari Rp 0!'), backgroundColor: Color(0xFFF43F5E)),
      );
      return;
    }

    final santri = santriList.firstWhere((s) => s.id == targetId);
    final catatan = _catatanController.text.trim().isNotEmpty
        ? _catatanController.text.trim()
        : (_tipeSetoran == TipeSetoran.awalBulan ? 'Setoran Bulanan' : 'Top-Up Susulan');

    await provider.catatSetoran(
      santriId: targetId,
      nominalSetoran: _nominal,
      durasiHari: _durasi,
      jatahHarianHitung: _hitungJatah,
      tipeSetoran: _tipeSetoran,
      tanggalSetor: DateTime.now(),
      catatan: catatan,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Setoran ${santri.namaLengkap} (${CurrencyFormatter.format(_nominal)}) berhasil disimpan!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final santriList = provider.allSantri.where((s) => s.statusAktif).toList();

    if (_selectedSantriId == null && santriList.isNotEmpty) {
      _selectedSantriId = santriList.first.id;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 90),
      children: [
        // Glass Card Container
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'PEMASUKAN KAS',
                        style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Setoran Bulanan & Top-Up',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Otomatis membagi nominal setoran menjadi kuota jatah harian.',
                        style: TextStyle(color: Colors.white54, fontSize: 10.5),
                      ),
                    ],
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('📥', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Pilih Santri
              const Text('PILIH SANTRI', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedSantriId,
                dropdownColor: const Color(0xFF090E1A),
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                decoration: const InputDecoration(isDense: true),
                items: santriList.map((s) {
                  return DropdownMenuItem<String>(
                    value: s.id,
                    child: Text(
                      '${s.namaLengkap} (${s.kamar}) — Saldo: ${CurrencyFormatter.format(s.saldoTotal)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSantriId = val);
                },
              ),

              const SizedBox(height: 14),

              // Jenis Setoran: Awal Bulan vs Susulan
              const Text('JENIS SETORAN', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tipeSetoran = TipeSetoran.awalBulan),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _tipeSetoran == TipeSetoran.awalBulan
                              ? const Color(0xFF10B981).withOpacity(0.2)
                              : const Color(0xFF070B14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _tipeSetoran == TipeSetoran.awalBulan ? const Color(0xFF34D399) : Colors.white12,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '📅 Awal Bulan',
                          style: TextStyle(
                            color: _tipeSetoran == TipeSetoran.awalBulan ? const Color(0xFF34D399) : Colors.white60,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tipeSetoran = TipeSetoran.susulanTopUp),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _tipeSetoran == TipeSetoran.susulanTopUp
                              ? const Color(0xFF06B6D4).withOpacity(0.2)
                              : const Color(0xFF070B14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _tipeSetoran == TipeSetoran.susulanTopUp ? const Color(0xFF38BDF8) : Colors.white12,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '➕ Top-Up Susulan',
                          style: TextStyle(
                            color: _tipeSetoran == TipeSetoran.susulanTopUp ? const Color(0xFF38BDF8) : Colors.white60,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Nominal Setoran (Rp) & Durasi (Hr)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('NOMINAL SETORAN (RP)', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _nominalController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                          decoration: const InputDecoration(isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DURASI (HR)', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _durasiController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                          decoration: const InputDecoration(isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Pintasan Cepat Nominal
              Row(
                children: [
                  _buildQuickBtn('150rb (5rb/hr)', 150000, 30),
                  const SizedBox(width: 6),
                  _buildQuickBtn('300rb (10rb/hr)', 300000, 30),
                  const SizedBox(width: 6),
                  _buildQuickBtn('450rb (15rb/hr)', 450000, 30),
                ],
              ),

              const SizedBox(height: 14),

              // Box Hasil Hitung Jatah Harian
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF04201A), Color(0xFF071426)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HASIL HITUNG JATAH HARIAN',
                          style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${CurrencyFormatter.format(_hitungJatah)} / hari',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const Text('🧮', style: TextStyle(fontSize: 26)),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Catatan
              const Text('CATATAN (OPSIONAL)', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              TextField(
                controller: _catatanController,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                decoration: const InputDecoration(
                  hintText: 'Contoh: Transfer Wali Santri via BSI',
                  isDense: true,
                ),
              ),

              const SizedBox(height: 18),

              // Tombol Simpan
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
                  onPressed: _simpan,
                  child: const Text('💾 SIMPAN SETORAN & UPDATE JATAH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickBtn(String label, int nominal, int durasi) {
    return Expanded(
      child: InkWell(
        onTap: () => _setQuick(nominal, durasi),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF070B14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
