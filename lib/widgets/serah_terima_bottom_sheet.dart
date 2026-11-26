import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/serah_terima_infak.dart';
import '../providers/kas_santri_provider.dart';
import '../screens/paywall_screen.dart';
import '../services/report_service.dart';
import '../utils/app_feedback.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

class SerahTerimaFormSheet extends StatefulWidget {
  const SerahTerimaFormSheet({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) async {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    if (!provider.hasProAccess) {
      AppFeedback.alert();
      await PaywallScreen.show(
        context,
        triggerFeature: 'Serah Terima Kas Infak & Beras ke Dapur / Yayasan',
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SerahTerimaFormSheet(),
    );
  }

  @override
  State<SerahTerimaFormSheet> createState() => _SerahTerimaFormSheetState();
}

class _SerahTerimaFormSheetState extends State<SerahTerimaFormSheet> {
  final TextEditingController _nominalController = TextEditingController();
  final TextEditingController _literController = TextEditingController();
  final TextEditingController _penerimaController = TextEditingController(
    text: 'Ustadzah Dapur / Bendahara Yayasan',
  );
  final TextEditingController _catatanController = TextEditingController();

  late String _tanggalSerah;
  String _posInfak = 'GABUNGAN'; // GABUNGAN, MASAK, LISTRIK, BERAS_UANG, BERAS_FISIK
  String _sumberDompet = 'TUNAI'; // TUNAI, REKENING, GUDANG_BERAS
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tanggalSerah = DateFormatter.toLocalDateString(DateTime.now());
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    if (provider.kasInfakTunai > 0) {
      _nominalController.text =
          CurrencyFormatter.formatWithoutSymbol(provider.kasInfakTunai);
    }
    if (provider.stokBerasFisikLiter > 0) {
      final l = provider.stokBerasFisikLiter;
      _literController.text =
          l == l.roundToDouble() ? l.toInt().toString() : l.toString();
    }
  }

  @override
  void dispose() {
    _nominalController.dispose();
    _literController.dispose();
    _penerimaController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final penerima = _penerimaController.text.trim();
    if (penerima.isEmpty) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama penerima wajib diisi!'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    final isBerasFisik = _sumberDompet == 'GUDANG_BERAS';
    final nominalUang =
        isBerasFisik ? 0 : CurrencyFormatter.parse(_nominalController.text);
    final liter = isBerasFisik
        ? (double.tryParse(_literController.text.trim().replaceAll(',', '.')) ??
            0.0)
        : 0.0;

    if ((!isBerasFisik && nominalUang <= 0) || (isBerasFisik && liter <= 0)) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi nominal uang atau jumlah liter beras dengan benar.'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final item = SerahTerimaInfakModel(
      id: const Uuid().v4(),
      tanggalSerah: _tanggalSerah,
      periodeBulan: provider.selectedInfakPeriode,
      posInfak: _posInfak,
      sumberDompet: _sumberDompet,
      nominalUang: nominalUang,
      jumlahBerasLiter: liter,
      penerima: penerima,
      catatan: _catatanController.text.trim().isNotEmpty
          ? _catatanController.text.trim()
          : null,
    );

    await provider.catatSerahTerimaInfak(item);
    AppFeedback.success();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serah terima ke Dapur / Yayasan berhasil dicatat!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final isBerasFisik = _sumberDompet == 'GUDANG_BERAS';

    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xF52A1D08), Color(0xF7091D2C), Color(0xF7071324)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: const Border(top: BorderSide(color: Color(0xFFFBBF24), width: 1.5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
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
                  const Text('🤝', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SERAH TERIMA KAS INFAK',
                          style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Setor ke Dapur / Yayasan (${provider.selectedInfakPeriode})',
                          style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900),
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
              const SizedBox(height: 12),

              // Saldo Kantong Infak saat ini
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF060B14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _miniStat('Infak Tunai', CurrencyFormatter.format(provider.kasInfakTunai), const Color(0xFF34D399)),
                    _miniStat('Infak Bank', CurrencyFormatter.format(provider.kasInfakRekening), const Color(0xFF38BDF8)),
                    _miniStat(
                      'Stok Beras',
                      '${provider.stokBerasFisikLiter.toStringAsFixed(provider.stokBerasFisikLiter == provider.stokBerasFisikLiter.roundToDouble() ? 0 : 1)} L',
                      const Color(0xFFFDE68A),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              const Text('SUMBER KANTONG SERAH TERIMA', style: TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _sumberChip('💵 Tunai Laci', 'TUNAI', const Color(0xFF34D399)),
                  const SizedBox(width: 6),
                  _sumberChip('🏦 Rekening', 'REKENING', const Color(0xFF38BDF8)),
                  const SizedBox(width: 6),
                  _sumberChip('🌾 Beras Fisik', 'GUDANG_BERAS', const Color(0xFFFBBF24)),
                ],
              ),
              const SizedBox(height: 12),

              const Text('POS INFAK TERKAIT', style: TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _posInfak,
                dropdownColor: const Color(0xFF090E1A),
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: 'GABUNGAN', child: Text('Gabungan (Masak + Listrik + Beras)')),
                  DropdownMenuItem(value: 'MASAK', child: Text('Infak Masak / Dapur')),
                  DropdownMenuItem(value: 'LISTRIK', child: Text('Infak Listrik')),
                  DropdownMenuItem(value: 'BERAS_UANG', child: Text('Infak Beras (Uang)')),
                  DropdownMenuItem(value: 'BERAS_FISIK', child: Text('Infak Beras Fisik (Liter)')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _posInfak = v);
                },
              ),
              const SizedBox(height: 12),

              if (!isBerasFisik)
                TextField(
                  controller: _nominalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RibuanInputFormatter()],
                  style: const TextStyle(color: Color(0xFF34D399), fontSize: 15, fontFamily: 'monospace', fontWeight: FontWeight.w900),
                  decoration: const InputDecoration(isDense: true, prefixText: 'Rp ', labelText: 'Nominal Uang Diserahkan'),
                )
              else
                TextField(
                  controller: _literController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 15, fontFamily: 'monospace', fontWeight: FontWeight.w900),
                  decoration: const InputDecoration(isDense: true, suffixText: ' Liter', labelText: 'Jumlah Beras Fisik Diserahkan'),
                ),

              const SizedBox(height: 10),
              TextField(
                controller: _penerimaController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(isDense: true, labelText: 'Nama Penerima (Dapur / Yayasan)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _catatanController,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                decoration: const InputDecoration(isDense: true, labelText: 'Catatan (Opsional)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBBF24),
                    foregroundColor: const Color(0xFF030712),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    '🤝 SIMPAN SERAH TERIMA KE DAPUR / YAYASAN',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9.5)),
        Text(val, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _sumberChip(String label, String value, Color accent) {
    final selected = _sumberDompet == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          setState(() {
            _sumberDompet = value;
            if (value == 'GUDANG_BERAS') {
              _posInfak = 'BERAS_FISIK';
            }
          });
        },
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.18) : const Color(0xFF060B14),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: selected ? accent : Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: selected ? accent : Colors.white60, fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class SerahTerimaHistorySheet extends StatelessWidget {
  const SerahTerimaHistorySheet({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) async {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    if (!provider.hasProAccess) {
      AppFeedback.alert();
      await PaywallScreen.show(
        context,
        triggerFeature: 'Riwayat & Berita Acara Serah Terima Infak',
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SerahTerimaHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final items = provider.serahTerimaList;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF0E1422),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
        ),
        padding: EdgeInsets.fromLTRB(18, 12, 18, bottomSafe + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('📜', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Riwayat Serah Terima Infak',
                    style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                ),
              ],
            ),
            const Divider(color: Colors.white12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Belum ada catatan serah terima ke Dapur / Yayasan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12.5),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final item = items[idx];
                    final nilaiStr = item.jumlahBerasLiter > 0
                        ? '${item.jumlahBerasLiter.toStringAsFixed(item.jumlahBerasLiter == item.jumlahBerasLiter.roundToDouble() ? 0 : 1)} Liter Beras'
                        : CurrencyFormatter.format(item.nominalUang);
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF060B14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.tanggalSerah} • ${item.posInfak} (${item.sumberDompet})',
                                  style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 10.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                              Text(
                                nilaiStr,
                                style: const TextStyle(color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Penerima: ${item.penerima}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          if (item.catatan != null && item.catatan!.isNotEmpty)
                            Text(item.catatan!, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () async {
                                  AppFeedback.tap();
                                  final ba = ReportService.instance.generateSerahTerimaBeritaAcaraText(
                                    item: item,
                                    pengaturan: provider.pengaturan,
                                  );
                                  await Clipboard.setData(ClipboardData(text: ba));
                                  await Share.share(ba, subject: 'Berita Acara Serah Terima Infak');
                                },
                                icon: const Icon(Icons.share_rounded, size: 15, color: Color(0xFF34D399)),
                                label: const Text('Berita Acara WA', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w800)),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: ctx,
                                    builder: (dCtx) => AlertDialog(
                                      backgroundColor: const Color(0xFF0F172A),
                                      title: const Text('Hapus Catatan Serah Terima?', style: TextStyle(color: Colors.white, fontSize: 15)),
                                      content: Text('Saldo kantong infak akan dikembalikan sebesar $nilaiStr.', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Batal')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
                                          onPressed: () => Navigator.pop(dCtx, true),
                                          child: const Text('Hapus'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await provider.hapusSerahTerimaInfak(item.id);
                                  }
                                },
                                icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFFB7185)),
                                label: const Text('Hapus', style: TextStyle(color: Color(0xFFFB7185), fontSize: 11, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
