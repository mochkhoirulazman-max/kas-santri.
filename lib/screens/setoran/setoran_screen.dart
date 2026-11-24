import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/santri.dart';
import '../../models/setoran.dart';
import '../../providers/kas_santri_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/app_feedback.dart';

class SetoranScreen extends StatefulWidget {
  final VoidCallback? onSaved;

  const SetoranScreen({Key? key, this.onSaved}) : super(key: key);

  @override
  State<SetoranScreen> createState() => _SetoranScreenState();
}

class _SetoranScreenState extends State<SetoranScreen> {
  String? _selectedSantriId;
  TipeSetoran _tipeSetoran = TipeSetoran.awalBulan;
  bool _potongTunggakan = true;
  String _sumberDompet = 'TUNAI'; // 'TUNAI' atau 'REKENING'
  final TextEditingController _nominalController = TextEditingController(text: '300.000');
  final TextEditingController _durasiController = TextEditingController(text: '30');
  final TextEditingController _catatanController = TextEditingController();

  @override
  void dispose() {
    _nominalController.dispose();
    _durasiController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  int get _nominal => CurrencyFormatter.parse(_nominalController.text);
  int get _durasi => int.tryParse(_durasiController.text.trim()) ?? 30;

  int _nominalBersih(Santri? santri) {
    int net = _nominal;
    if (_potongTunggakan && santri != null && santri.tunggakan > 0) {
      net = (_nominal - santri.tunggakan).clamp(0, double.infinity).toInt();
    }
    return net;
  }

  int _hitungJatahPresisi(Santri? santri, {int kelipatan = 500}) {
    if (_durasi <= 0) return 0;
    return CurrencyFormatter.hitungJatahHarianBulat(
      _nominalBersih(santri),
      _durasi,
      kelipatan: kelipatan,
    );
  }

  void _setQuick(int nominal, int durasi) {
    AppFeedback.tap();
    setState(() {
      _nominalController.text = CurrencyFormatter.formatWithoutSymbol(nominal);
      _durasiController.text = durasi.toString();
    });
  }

  Future<void> _simpan() async {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final santriList = provider.allSantri.where((s) => s.statusAktif).toList();

    final targetId = _selectedSantriId ?? (santriList.isNotEmpty ? santriList.first.id : null);
    if (targetId == null) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih santri terlebih dahulu!'), backgroundColor: Color(0xFFF43F5E)),
      );
      return;
    }

    if (_nominal <= 0) {
      AppFeedback.alert();
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
      jatahHarianHitung: _hitungJatahPresisi(
        santri,
        kelipatan: provider.pengaturan.pembulatanJatah,
      ),
      tipeSetoran: _tipeSetoran,
      tanggalSetor: DateTime.now(),
      catatan: catatan,
      potongTunggakan: _potongTunggakan,
      metodeBayar: _sumberDompet,
    );

    AppFeedback.success();
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
    final selectedSantri = santriList.where((s) => s.id == _selectedSantriId).firstOrNull;
    final kelipatan = provider.pengaturan.pembulatanJatah;
    final netMasuk = _nominalBersih(selectedSantri);
    final jatahBulat = _hitungJatahPresisi(selectedSantri, kelipatan: kelipatan);
    final selisihPembulatan = CurrencyFormatter.hitungSelisihPembulatan(netMasuk, _durasi, jatahBulat);
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 120 + bottomSafe),
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
                // Header (bebas overflow kanan atas)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Otomatis membagi nominal setoran menjadi kuota jatah harian.',
                            style: TextStyle(color: Colors.white54, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
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
                isExpanded: true,
                dropdownColor: const Color(0xFF090E1A),
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                decoration: const InputDecoration(isDense: true),
                items: santriList.map((s) {
                  return DropdownMenuItem<String>(
                    value: s.id,
                    child: Text(
                      '${s.namaLengkap} (${s.kamar}) — Saldo: ${CurrencyFormatter.format(s.saldoTotal)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    AppFeedback.tap();
                    setState(() => _selectedSantriId = val);
                  }
                },
              ),

              if (selectedSantri != null && selectedSantri.tunggakan > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF450A1A).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFB7185).withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('🚨', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tunggakan Aktif: ${CurrencyFormatter.format(selectedSantri.tunggakan)}',
                                  style: const TextStyle(color: Color(0xFFFECDD3), fontSize: 11.5, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _potongTunggakan
                                      ? 'Tunggakan dipotong dari setoran ini. Sisa bersih masuk saldo: ${CurrencyFormatter.format(netMasuk)}.'
                                      : 'Setoran masuk utuh ke saldo (${CurrencyFormatter.format(_nominal)}), tunggakan tidak dipotong.',
                                  style: const TextStyle(color: Color(0xFFFDA4AF), fontSize: 9.5, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Potong tunggakan dari setoran ini',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Switch(
                              value: _potongTunggakan,
                              activeColor: const Color(0xFF34D399),
                              onChanged: (val) {
                                AppFeedback.tap();
                                setState(() => _potongTunggakan = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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

              // Sumber Dompet Masuk: Tunai vs Rekening
              const Text('DOMPET TUJUAN MASUK', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildDompetChip('💵 Kas Laci Tunai', 'TUNAI', const Color(0xFF34D399)),
                  const SizedBox(width: 8),
                  _buildDompetChip('🏦 Rekening Bank', 'REKENING', const Color(0xFF38BDF8)),
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
                          inputFormatters: [RibuanInputFormatter()],
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                          decoration: const InputDecoration(prefixText: 'Rp ', isDense: true),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HASIL HITUNG JATAH HARIAN',
                            style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${CurrencyFormatter.format(jatahBulat)} / hari',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            selisihPembulatan > 0
                                ? 'Pembulatan ke bawah kelipatan ${CurrencyFormatter.format(kelipatan)} • Sisa ${CurrencyFormatter.format(selisihPembulatan)} tetap utuh di saldo'
                                : 'Dibulatkan kelipatan ${CurrencyFormatter.format(kelipatan)} agar praktis saat penarikan',
                            style: const TextStyle(color: Colors.white60, fontSize: 9.5, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: const Color(0xFF030712),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 6,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shadowColor: const Color(0xFF10B981).withOpacity(0.4),
                  ),
                  onPressed: _simpan,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '💾 SIMPAN SETORAN & UPDATE JATAH',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
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

  Widget _buildDompetChip(String label, String value, Color accent) {
    final isSelected = _sumberDompet == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          setState(() => _sumberDompet = value);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? accent.withOpacity(0.18) : const Color(0xFF070B14),
            borderRadius: BorderRadius.circular(14),
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
