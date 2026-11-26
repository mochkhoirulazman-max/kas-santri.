import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/santri.dart';
import '../providers/kas_santri_provider.dart';
import '../screens/paywall_screen.dart';
import '../utils/app_feedback.dart';
import '../utils/currency_formatter.dart';

class TunggakanBottomSheet extends StatefulWidget {
  final Santri santri;

  const TunggakanBottomSheet({
    Key? key,
    required this.santri,
  }) : super(key: key);

  static void show(BuildContext context, Santri santri) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TunggakanBottomSheet(santri: santri),
    );
  }

  @override
  State<TunggakanBottomSheet> createState() => _TunggakanBottomSheetState();
}

class _TunggakanBottomSheetState extends State<TunggakanBottomSheet> {
  final TextEditingController _nominalController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();
  bool _isBayarMode = true; // true = Bayar / Cicil, false = Tambah Tunggakan
  String _sumberDompet = 'TUNAI';

  @override
  void initState() {
    super.initState();
    _isBayarMode = widget.santri.tunggakan > 0;
    if (_isBayarMode) {
      _nominalController.text = CurrencyFormatter.formatWithoutSymbol(widget.santri.tunggakan);
    }
  }

  @override
  void dispose() {
    _nominalController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  int get _nominal => CurrencyFormatter.parse(_nominalController.text);

  void _isiLunas() {
    AppFeedback.tap();
    setState(() {
      _nominalController.text = CurrencyFormatter.formatWithoutSymbol(widget.santri.tunggakan);
    });
  }

  Future<void> _submit() async {
    if (_nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nominal tunggakan lebih dari Rp 0!'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    await provider.kelolaTunggakan(
      santriId: widget.santri.id,
      nominal: _nominal,
      catatan: _catatanController.text.trim(),
      isBayar: _isBayarMode,
      sumberDompet: _sumberDompet,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isBayarMode
                ? 'Pembayaran tunggakan ${widget.santri.namaLengkap} (${CurrencyFormatter.format(_nominal)}) berhasil!'
                : 'Tunggakan ${widget.santri.namaLengkap} bertambah ${CurrencyFormatter.format(_nominal)}.',
          ),
          backgroundColor: _isBayarMode ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xF52D0A18), Color(0xF7111024), Color(0xF7091324)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: const Color(0xFFFB7185).withValues(alpha: 0.55), width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF43F5E).withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
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
            // Handle Bar
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

            // Header Modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFB7185).withOpacity(0.4)),
                      ),
                      child: const Text(
                        '🚨 MANAJEMEN TUNGGAKAN',
                        style: TextStyle(
                          color: Color(0xFFFECDD3),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.santri.namaLengkap} (${widget.santri.kamar})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Kartu Total Tunggakan Saat Ini
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF380816), Color(0xFF140D20)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFB7185).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL TUNGGAKAN SAAT INI',
                        style: TextStyle(color: Color(0xFFFDA4AF), fontSize: 9.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(widget.santri.tunggakan),
                        style: const TextStyle(
                          color: Color(0xFFFECDD3),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.santri.tunggakan > 0
                            ? (widget.santri.catatanTunggakan.isNotEmpty
                                ? widget.santri.catatanTunggakan
                                : 'Memiliki tunggakan aktif')
                            : 'Alhamdulillah, tidak ada tunggakan',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                  const Text('📋', style: TextStyle(fontSize: 28)),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Mode Selector: Bayar vs Tambah
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isBayarMode = true),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: _isBayarMode ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFF070B14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isBayarMode ? const Color(0xFF34D399) : Colors.white12,
                          width: _isBayarMode ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '✅ Bayar / Cicil',
                        style: TextStyle(
                          color: _isBayarMode ? const Color(0xFF34D399) : Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isBayarMode = false),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: !_isBayarMode ? const Color(0xFFF43F5E).withOpacity(0.2) : const Color(0xFF070B14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: !_isBayarMode ? const Color(0xFFFB7185) : Colors.white12,
                          width: !_isBayarMode ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '➕ Tambah Tunggakan',
                        style: TextStyle(
                          color: !_isBayarMode ? const Color(0xFFFB7185) : Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Input Nominal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'NOMINAL (RP)',
                  style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
                if (_isBayarMode && widget.santri.tunggakan > 0)
                  InkWell(
                    onTap: _isiLunas,
                    child: const Text(
                      'Isi Lunas Semua',
                      style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nominalController,
              keyboardType: TextInputType.number,
              inputFormatters: [RibuanInputFormatter()],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: TextStyle(
                  color: _isBayarMode ? const Color(0xFF34D399) : const Color(0xFFFB7185),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
                hintText: '50.000',
                filled: true,
                fillColor: const Color(0xFF060A14),
              ),
            ),

            const SizedBox(height: 12),

            if (_isBayarMode) ...[
              const Text(
                'DOMPET PENERIMA PEMBAYARAN',
                style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildDompetChip('💵 Kas Laci Tunai', 'TUNAI', const Color(0xFF34D399)),
                  const SizedBox(width: 8),
                  _buildDompetChip('🏦 Rekening Bank', 'REKENING', const Color(0xFF38BDF8)),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Input Catatan / Keterangan
            const Text(
              'KETERANGAN TUNGGAKAN',
              style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _catatanController,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: _isBayarMode
                    ? 'Contoh: Cicilan uang makan / Pelunasan kekurangan setoran'
                    : 'Contoh: Kasbon obat / Kitab / Belum bayar SPP',
                filled: true,
                fillColor: const Color(0xFF060A14),
              ),
            ),

            const SizedBox(height: 18),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBayarMode ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                  foregroundColor: _isBayarMode ? const Color(0xFF030712) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 6,
                  shadowColor: (_isBayarMode ? const Color(0xFF10B981) : const Color(0xFFF43F5E)).withOpacity(0.4),
                ),
                onPressed: _submit,
                child: Text(
                  _isBayarMode ? '✅ SIMPAN PEMBAYARAN TUNGGAKAN' : '🚨 TAMBAHKAN CATATAN TUNGGAKAN',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildDompetChip(String label, String value, Color accent) {
    final isPro = Provider.of<KasSantriProvider>(context).hasProAccess;
    final isLockedRekening = value == 'REKENING' && !isPro;
    final isSelected = _sumberDompet == value && !isLockedRekening;
    final displayLabel = isLockedRekening ? '$label 👑' : label;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          if (isLockedRekening) {
            PaywallScreen.show(
              context,
              triggerFeature: 'Multi-Dompet: Pisah Kas Laci Tunai vs Rekening Bank',
            );
            setState(() => _sumberDompet = 'TUNAI');
            return;
          }
          setState(() => _sumberDompet = value);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? accent.withOpacity(0.18) : const Color(0xFF060A14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? accent
                  : (isLockedRekening
                      ? const Color(0xFFFBBF24).withValues(alpha: 0.45)
                      : Colors.white12),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            displayLabel,
            style: TextStyle(
              color: isSelected
                  ? accent
                  : (isLockedRekening ? const Color(0xFFFDE68A) : Colors.white60),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
