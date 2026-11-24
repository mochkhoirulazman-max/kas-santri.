import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kas_santri_provider.dart';
import '../utils/app_feedback.dart';
import '../utils/currency_formatter.dart';

class TarikTunaiBottomSheet extends StatefulWidget {
  const TarikTunaiBottomSheet({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TarikTunaiBottomSheet(),
    );
  }

  @override
  State<TarikTunaiBottomSheet> createState() => _TarikTunaiBottomSheetState();
}

class _TarikTunaiBottomSheetState extends State<TarikTunaiBottomSheet> {
  final TextEditingController _nominalController = TextEditingController(text: '100.000');
  final TextEditingController _catatanController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nominalController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  int get _nominal => CurrencyFormatter.parse(_nominalController.text);

  void _addChip(int amount, int maxBank) {
    AppFeedback.tap();
    final next = (_nominal + amount).clamp(0, maxBank);
    setState(() {
      _nominalController.text = next > 0 ? CurrencyFormatter.formatWithoutSymbol(next) : '0';
    });
  }

  void _setAllBank(int maxBank) {
    AppFeedback.tap();
    setState(() {
      _nominalController.text = maxBank > 0 ? CurrencyFormatter.formatWithoutSymbol(maxBank) : '0';
    });
  }

  Future<void> _submit() async {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final bank = provider.rekeningBank;
    final nominal = _nominal;

    if (nominal <= 0) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nominal tarik tunai lebih dari Rp 0!'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    if (nominal > bank) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saldo Rekening Bank tidak mencukupi (tersedia ${CurrencyFormatter.format(bank)}).'),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await provider.tarikTunaiKeLaci(
        nominal: nominal,
        catatan: _catatanController.text.trim(),
      );
      AppFeedback.success();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Berhasil memindahkan ${CurrencyFormatter.format(nominal)} dari Rekening Bank ke Kas Laci Tunai.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFF43F5E)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final bankNow = provider.rekeningBank;
    final laciNow = provider.kasLaciTunai;
    final bankAfter = (bankNow - _nominal).clamp(0, double.infinity).toInt();
    final laciAfter = laciNow + _nominal;
    final isOverBank = _nominal > bankNow;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E1422),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Color(0xFFF59E0B), width: 1.5)),
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
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5)),
                          ),
                          child: const Text(
                            '👑 MULTI-DOMPET PRO',
                            style: TextStyle(color: Color(0xFFFDE68A), fontSize: 9.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tarik Tunai (Bank → Laci)',
                          style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Ringkasan Perpindahan Saldo Dompet
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF060B14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '🏦 REKENING BANK',
                                style: TextStyle(color: Color(0xFF7DD3FC), fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.format(bankNow),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              if (_nominal > 0)
                                Text(
                                  isOverBank ? 'Melebihi saldo bank!' : '→ ${CurrencyFormatter.format(bankAfter)}',
                                  style: TextStyle(
                                    color: isOverBank ? const Color(0xFFFB7185) : Colors.white54,
                                    fontSize: 10.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward_rounded, color: Color(0xFFFBBF24), size: 20),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                '💵 KAS LACI TUNAI',
                                style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  CurrencyFormatter.format(laciNow),
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              if (_nominal > 0 && !isOverBank)
                                Text(
                                  '→ ${CurrencyFormatter.format(laciAfter)}',
                                  style: const TextStyle(
                                    color: Color(0xFF6EE7B7),
                                    fontSize: 10.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pemindahan dana antar dompet pondok tidak mengubah total saldo tabungan santri.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              const Text(
                'NOMINAL TARIK TUNAI (RP)',
                style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800),
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
                  prefixStyle: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                  filled: true,
                  fillColor: const Color(0xFF060A14),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildChip('+50.000', () => _addChip(50000, bankNow)),
                  _buildChip('+100.000', () => _addChip(100000, bankNow)),
                  _buildChip('+250.000', () => _addChip(250000, bankNow)),
                  _buildChip('+500.000', () => _addChip(500000, bankNow)),
                  _buildChip('Semua Bank', () => _setAllBank(bankNow), highlight: true),
                ],
              ),

              const SizedBox(height: 14),
              const Text(
                'CATATAN (OPSIONAL)',
                style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _catatanController,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                decoration: const InputDecoration(
                  hintText: 'Misal: Tarik ATM BSI untuk jajan sore santri',
                  isDense: true,
                ),
              ),

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOverBank ? const Color(0xFFF43F5E) : const Color(0xFFFBBF24),
                    foregroundColor: const Color(0xFF030712),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: (_isSubmitting || isOverBank) ? null : _submit,
                  child: Text(
                    isOverBank ? 'SALDO REKENING TIDAK CUKUP' : '⇄ PINDAHKAN KE KAS LACI TUNAI',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, VoidCallback onTap, {bool highlight = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFF59E0B).withOpacity(0.18) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight ? const Color(0xFFFBBF24).withOpacity(0.5) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: highlight ? const Color(0xFFFDE68A) : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
