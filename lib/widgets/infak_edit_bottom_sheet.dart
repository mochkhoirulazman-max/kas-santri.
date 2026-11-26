import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/infak_santri.dart';
import '../models/santri.dart';
import '../providers/kas_santri_provider.dart';
import '../screens/paywall_screen.dart';
import '../utils/app_feedback.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

class InfakEditBottomSheet extends StatefulWidget {
  final Santri santri;
  final String periodeBulan;
  final InfakSantriModel? existingInfak;

  const InfakEditBottomSheet({
    Key? key,
    required this.santri,
    required this.periodeBulan,
    this.existingInfak,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required Santri santri,
    required String periodeBulan,
    InfakSantriModel? existingInfak,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InfakEditBottomSheet(
        santri: santri,
        periodeBulan: periodeBulan,
        existingInfak: existingInfak,
      ),
    );
  }

  @override
  State<InfakEditBottomSheet> createState() => _InfakEditBottomSheetState();
}

class _InfakEditBottomSheetState extends State<InfakEditBottomSheet> {
  late TextEditingController _masakController;
  late TextEditingController _listrikController;
  late TextEditingController _berasLiterController;
  late TextEditingController _berasUangController;
  late TextEditingController _catatanController;

  late bool _isMasakBebas;
  late bool _isListrikBebas;
  late String _jenisBeras;
  late String _sumberDompet;
  late String _tglMasuk;
  late String _tglHabis;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final peng = provider.pengaturan;
    final ex = widget.existingInfak;

    final today = DateFormatter.toLocalDateString(DateTime.now());
    _tglMasuk = ex?.tglMasuk.isNotEmpty == true ? ex!.tglMasuk : today;
    _tglHabis = ex?.tglHabis.isNotEmpty == true
        ? ex!.tglHabis
        : InfakSantriModel.hitungTglHabis(_tglMasuk);

    _isMasakBebas = ex?.isMasakBebas ?? false;
    _isListrikBebas = ex?.isListrikBebas ?? false;
    _jenisBeras = ex?.jenisBeras ?? InfakSantriModel.berasUangVal;
    _sumberDompet = provider.hasProAccess ? (ex?.sumberDompet ?? 'TUNAI') : 'TUNAI';

    final masakVal = ex != null ? ex.nominalMasak : peng.defaultInfakMasak;
    final listrikVal = ex != null ? ex.nominalListrik : peng.defaultInfakListrik;
    final literVal =
        ex != null && ex.berasLiter > 0 ? ex.berasLiter : peng.defaultInfakBerasLiter;
    final berasUangVal =
        ex != null && ex.berasUang > 0 ? ex.berasUang : peng.defaultInfakBerasUang;

    _masakController = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(masakVal),
    );
    _listrikController = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(listrikVal),
    );
    _berasLiterController = TextEditingController(
      text: literVal == literVal.roundToDouble()
          ? literVal.toInt().toString()
          : literVal.toString(),
    );
    _berasUangController = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(berasUangVal),
    );
    _catatanController = TextEditingController(text: ex?.catatan ?? '');
  }

  @override
  void dispose() {
    _masakController.dispose();
    _listrikController.dispose();
    _berasLiterController.dispose();
    _berasUangController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isMasuk}) async {
    AppFeedback.tap();
    final current = DateTime.tryParse(isMasuk ? _tglMasuk : _tglHabis) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      final ymd = DateFormatter.toLocalDateString(picked);
      setState(() {
        if (isMasuk) {
          _tglMasuk = ymd;
          _tglHabis = InfakSantriModel.hitungTglHabis(ymd);
        } else {
          _tglHabis = ymd;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final peng = provider.pengaturan;
    final masak = _isMasakBebas ? 0 : CurrencyFormatter.parse(_masakController.text);
    final listrik =
        _isListrikBebas ? 0 : CurrencyFormatter.parse(_listrikController.text);
    final liter = _jenisBeras == InfakSantriModel.berasFisik
        ? (double.tryParse(
              _berasLiterController.text.trim().replaceAll(',', '.'),
            ) ??
            0.0)
        : 0.0;
    final berasUang = _jenisBeras == InfakSantriModel.berasUangVal
        ? CurrencyFormatter.parse(_berasUangController.text)
        : 0;

    final model = InfakSantriModel(
      id: widget.existingInfak?.id ?? const Uuid().v4(),
      santriId: widget.santri.id,
      periodeBulan: widget.periodeBulan,
      tahunAjaran: peng.tahunAjaran,
      nominalMasak: masak,
      isMasakBebas: _isMasakBebas,
      nominalListrik: listrik,
      isListrikBebas: _isListrikBebas,
      jenisBeras: _jenisBeras,
      berasLiter: liter,
      berasUang: berasUang,
      tglMasuk: _tglMasuk,
      tglHabis: _tglHabis,
      sumberDompet: _sumberDompet,
      setoranId: widget.existingInfak?.setoranId,
      catatan: _catatanController.text.trim().isNotEmpty
          ? _catatanController.text.trim()
          : null,
    );

    await provider.simpanInfakSantri(model);
    AppFeedback.success();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data Infak ${widget.santri.namaLengkap} disimpan!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xF5062D24), Color(0xF70B182C), Color(0xF718132B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: const Border(top: BorderSide(color: Color(0xFF34D399), width: 1.5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + bottomSafe + 22),
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
                children: [
                  const Text('🌾', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catat / Lengkapi Infak (${widget.periodeBulan})',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${widget.santri.namaLengkap} • ${widget.santri.kategoriLabel}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 18),

              // Masak & Listrik
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('INFAK MASAK', style: TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w800)),
                            InkWell(
                              onTap: () {
                                AppFeedback.tap();
                                setState(() => _isMasakBebas = !_isMasakBebas);
                              },
                              child: Text(
                                _isMasakBebas ? '✓ Bebas' : 'Set Bebas',
                                style: TextStyle(
                                  color: _isMasakBebas ? const Color(0xFF34D399) : Colors.white54,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _masakController,
                          enabled: !_isMasakBebas,
                          keyboardType: TextInputType.number,
                          inputFormatters: [RibuanInputFormatter()],
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: _isMasakBebas ? null : 'Rp ',
                            hintText: _isMasakBebas ? 'Bebas ✓' : '130.000',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('INFAK LISTRIK', style: TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w800)),
                            InkWell(
                              onTap: () {
                                AppFeedback.tap();
                                setState(() => _isListrikBebas = !_isListrikBebas);
                              },
                              child: Text(
                                _isListrikBebas ? '✓ Bebas' : 'Set Bebas',
                                style: TextStyle(
                                  color: _isListrikBebas ? const Color(0xFF38BDF8) : Colors.white54,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _listrikController,
                          enabled: !_isListrikBebas,
                          keyboardType: TextInputType.number,
                          inputFormatters: [RibuanInputFormatter()],
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: _isListrikBebas ? null : 'Rp ',
                            hintText: _isListrikBebas ? 'Bebas ✓' : '20.000',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Pilihan Mode Beras
              const Text('MODE INFAK BERAS', style: TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _berasChip('💵 Bayar Uang', InfakSantriModel.berasUangVal, const Color(0xFFFBBF24)),
                  _berasChip('🌾 Fisik (Liter)', InfakSantriModel.berasFisik, const Color(0xFF34D399)),
                  _berasChip('⏳ Belum Setor', InfakSantriModel.berasBelum, const Color(0xFFF43F5E)),
                  _berasChip('✓ Bebas Beras', InfakSantriModel.berasBebas, const Color(0xFF38BDF8)),
                ],
              ),
              if (_jenisBeras == InfakSantriModel.berasUangVal) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _berasUangController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RibuanInputFormatter()],
                  style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 13.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(isDense: true, prefixText: 'Rp ', labelText: 'Nominal Uang Beras'),
                ),
              ] else if (_jenisBeras == InfakSantriModel.berasFisik) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _berasLiterController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 13.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(isDense: true, suffixText: ' Liter', labelText: 'Jumlah Beras Fisik'),
                ),
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isMasuk: true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF060B14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TGL MASUK', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(_tglMasuk, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isMasuk: false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF060B14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF34D399).withOpacity(0.45)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TGL HABIS (+1 BLN)', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(_tglHabis, style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Text('DOMPET MASUK (UANG INFAK)', style: TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _dompetChip('💵 Kas Tunai', 'TUNAI', const Color(0xFF34D399)),
                  const SizedBox(width: 8),
                  _dompetChip('🏦 Rekening Bank', 'REKENING', const Color(0xFF38BDF8)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _catatanController,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Catatan Infak (Opsional)',
                  hintText: 'Contoh: Kurang beras 10 L / Susulan Lunas',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: const Color(0xFF030712),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    '💾 SIMPAN DATA INFAK SANTRI',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _berasChip(String label, String value, Color accent) {
    final selected = _jenisBeras == value;
    return InkWell(
      onTap: () {
        AppFeedback.tap();
        setState(() => _jenisBeras = value);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.2) : const Color(0xFF060B14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? accent : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : Colors.white70,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _dompetChip(String label, String value, Color accent) {
    final isPro = Provider.of<KasSantriProvider>(context).hasProAccess;
    final isLockedRekening = value == 'REKENING' && !isPro;
    final selected = _sumberDompet == value && !isLockedRekening;
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
            color: selected ? accent.withOpacity(0.18) : const Color(0xFF060B14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
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
              color: selected
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
