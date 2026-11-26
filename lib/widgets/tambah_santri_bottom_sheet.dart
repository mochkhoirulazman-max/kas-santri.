import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/santri.dart';
import '../providers/kas_santri_provider.dart';
import '../screens/paywall_screen.dart';
import '../screens/santri/import_santri_excel_screen.dart';
import '../utils/app_feedback.dart';
import '../utils/currency_formatter.dart';

class TambahSantriBottomSheet extends StatefulWidget {
  final ValueChanged<String>? onOpenSetoran;

  const TambahSantriBottomSheet({
    Key? key,
    this.onOpenSetoran,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    ValueChanged<String>? onOpenSetoran,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TambahSantriBottomSheet(
        onOpenSetoran: onOpenSetoran,
      ),
    );
  }

  @override
  State<TambahSantriBottomSheet> createState() =>
      _TambahSantriBottomSheetState();
}

class _TambahSantriBottomSheetState extends State<TambahSantriBottomSheet> {
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _panggilanController = TextEditingController();
  final TextEditingController _kamarController =
      TextEditingController(text: 'Kamar 1');
  final TextEditingController _noWaController = TextEditingController();
  late final TextEditingController _jatahController;
  final TextEditingController _tunggakanController =
      TextEditingController(text: '0');

  String _kategoriSantri = Santri.kategoriSantriyin;
  String _statusSantri = Santri.statusAktifVal;

  @override
  void initState() {
    super.initState();
    final defaultJatah = Provider.of<KasSantriProvider>(context, listen: false)
        .pengaturan
        .defaultJatahHarian;
    _jatahController = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(
        defaultJatah > 0 ? defaultJatah : 10000,
      ),
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _panggilanController.dispose();
    _kamarController.dispose();
    _noWaController.dispose();
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

    final panggilanInput = _panggilanController.text.trim();
    final panggilan = panggilanInput.isNotEmpty
        ? panggilanInput
        : nama.split(RegExp(r'\s+')).first;
    final kamar = _kamarController.text.trim().isNotEmpty
        ? _kamarController.text.trim()
        : 'Kamar 1';
    final noWa = _noWaController.text.trim();
    final jatah = CurrencyFormatter.parse(_jatahController.text);
    final tunggakan = CurrencyFormatter.parse(_tunggakanController.text);

    final santri = Santri(
      id: const Uuid().v4(),
      namaLengkap: nama,
      namaPanggilan: panggilan,
      kategoriSantri: _kategoriSantri,
      statusSantri: _statusSantri,
      kamar: kamar,
      noWaWali: noWa.isNotEmpty ? noWa : null,
      saldoTotal: 0,
      setoranAwal: 0,
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

    await provider.tambahSantriBaru(santri);
    AppFeedback.success();

    if (!mounted) return;
    final openSetoranCb = widget.onOpenSetoran;
    final parentNav = Navigator.of(context);
    parentNav.pop();

    if (openSetoranCb != null) {
      await showDialog<void>(
        context: parentNav.context,
        builder: (dlgCtx) => AlertDialog(
          backgroundColor: const Color(0xFF0A192C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: const Color(0xFF34D399).withValues(alpha: 0.45),
            ),
          ),
          title: const Row(
            children: [
              Text('🎉', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Santri Berhasil Disimpan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Data $nama ($kamar) terdaftar dengan saldo awal Rp 0.\n\nIngin langsung mencatat setoran atau sambangan pertama untuk santri ini?',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text(
                'Nanti Saja',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: const Color(0xFF030712),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.pop(dlgCtx);
                openSetoranCb(santri.id);
              },
              icon: const Text('📥', style: TextStyle(fontSize: 13)),
              label: const Text(
                'Langsung Input Setoran?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(parentNav.context).showSnackBar(
        SnackBar(
          content: Text('Santri $nama berhasil ditambahkan (Saldo awal Rp 0).'),
          backgroundColor: const Color(0xFF10B981),
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
            colors: [
              Color(0xF5063128),
              Color(0xF70A182D),
              Color(0xF713122B),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(
              color: const Color(0xFF34D399).withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.20),
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
                  const Expanded(
                    child: Text(
                      '👦 TAMBAH SANTRI BARU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Builder(
                    builder: (btnCtx) {
                      final isPro = Provider.of<KasSantriProvider>(btnCtx).hasProAccess;
                      return TextButton.icon(
                        onPressed: () {
                          AppFeedback.tap();
                          final nav = Navigator.of(context);
                          nav.pop();
                          if (!isPro) {
                            PaywallScreen.show(
                              nav.context,
                              triggerFeature: 'Import Santri Massal dari Excel (.xlsx)',
                            );
                            return;
                          }
                          nav.push(
                            MaterialPageRoute(
                              builder: (_) => const ImportSantriExcelScreen(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.upload_file_rounded,
                          size: 15,
                          color: Color(0xFF34D399),
                        ),
                        label: Text(
                          isPro ? 'Import Excel' : 'Import Excel 👑',
                          style: const TextStyle(
                            color: Color(0xFF6EE7B7),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                  ),
                ],
              ),

              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 4, bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.35),
                  ),
                ),
                child: const Text(
                  '💡 Saldo awal otomatis Rp 0 agar tidak dobel pencatatan. Setoran uang saku / sambangan dicatat melalui tab Setoran.',
                  style: TextStyle(
                    color: Color(0xFFA7F3D0),
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ),

              const Text(
                'NAMA LENGKAP SANTRI *',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _namaController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Contoh: Muhammad Farhan',
                  isDense: true,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NAMA PANGGILAN',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _panggilanController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Contoh: Farhan',
                            isDense: true,
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
                        const Text(
                          'KAMAR / KELAS *',
                          style: TextStyle(
                            color: Color(0xFF67E8F9),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _kamarController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Kamar 1 / Kelas 7A',
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const Text(
                'NO. WHATSAPP WALI (OPSIONAL)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _noWaController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Contoh: 081234567890 (untuk laporan WA)',
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    size: 17,
                    color: Color(0xFF38BDF8),
                  ),
                  isDense: true,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'JATAH HARIAN DEFAULT (RP/HR)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _jatahController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [RibuanInputFormatter()],
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 13,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            prefixText: 'Rp ',
                            hintText: '10.000',
                            isDense: true,
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
                        const Text(
                          'TUNGGAKAN AWAL (OPSIONAL)',
                          style: TextStyle(
                            color: Color(0xFFFDA4AF),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _tunggakanController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [RibuanInputFormatter()],
                          style: const TextStyle(
                            color: Color(0xFFFB7185),
                            fontSize: 13,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            prefixText: 'Rp ',
                            hintText: '0',
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              const Text(
                'KELOMPOK SANTRI (BUKU INFAK)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
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

              const Text(
                'STATUS KEAKTIFAN SANTRI',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
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

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: const Color(0xFF030712),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 6,
                    shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                  onPressed: _submit,
                  child: const Text(
                    'SIMPAN DATA SANTRI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
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
            color: isSelected
                ? accent.withValues(alpha: 0.22)
                : const Color(0xFF060B16).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: isSelected ? accent : Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? accent : Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
