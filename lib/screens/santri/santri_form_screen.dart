import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/santri.dart';
import '../../providers/kas_santri_provider.dart';
import '../../utils/currency_formatter.dart';
import '../paywall_screen.dart';

class SantriFormScreen extends StatefulWidget {
  final Santri? santriToEdit;

  const SantriFormScreen({Key? key, this.santriToEdit}) : super(key: key);

  @override
  State<SantriFormScreen> createState() => _SantriFormScreenState();
}

class _SantriFormScreenState extends State<SantriFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _namaLengkapController;
  late TextEditingController _namaPanggilanController;
  late TextEditingController _kamarController;
  late TextEditingController _noWaWaliController;
  late TextEditingController _jatahHarianController;
  late TextEditingController _saldoAwalController;

  bool _statusAktif = true;
  late String _kategoriSantri;
  late String _statusSantri;

  @override
  void initState() {
    super.initState();
    final s = widget.santriToEdit;
    final defaultJatah = Provider.of<KasSantriProvider>(context, listen: false).pengaturan.defaultJatahHarian;

    _namaLengkapController = TextEditingController(text: s?.namaLengkap ?? '');
    _namaPanggilanController = TextEditingController(text: s?.namaPanggilan ?? '');
    _kamarController = TextEditingController(text: s?.kamar ?? '');
    _noWaWaliController = TextEditingController(text: s?.noWaWali ?? '');
    _jatahHarianController = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(s?.jatahHarian ?? defaultJatah),
    );
    _saldoAwalController = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(s?.saldoTotal ?? 0),
    );
    _statusAktif = s?.statusAktif ?? true;
    _kategoriSantri = s?.kategoriSantri ?? Santri.kategoriSantriyin;
    _statusSantri = s?.statusSantri ?? Santri.statusAktifVal;
  }

  @override
  void dispose() {
    _namaLengkapController.dispose();
    _namaPanggilanController.dispose();
    _kamarController.dispose();
    _noWaWaliController.dispose();
    _jatahHarianController.dispose();
    _saldoAwalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final isEdit = widget.santriToEdit != null;
    if (!isEdit && provider.hasReachedFreeSantriLimit) {
      PaywallScreen.show(
        context,
        triggerFeature:
            'Santri Tanpa Batas — Kuota Mode Gratis maksimal ${KasSantriProvider.maxFreeSantriQuota} santri aktif telah tercapai.',
      );
      return;
    }

    final parsedSaldo = CurrencyFormatter.parse(_saldoAwalController.text);
    final parsedJatah = CurrencyFormatter.parse(_jatahHarianController.text);

    final santri = Santri(
      id: isEdit ? widget.santriToEdit!.id : const Uuid().v4(),
      namaLengkap: _namaLengkapController.text.trim(),
      namaPanggilan: _namaPanggilanController.text.trim(),
      kategoriSantri: _kategoriSantri,
      statusSantri: _statusSantri,
      kamar: _kamarController.text.trim(),
      noWaWali: _noWaWaliController.text.trim().isNotEmpty ? _noWaWaliController.text.trim() : null,
      saldoTotal: parsedSaldo,
      setoranAwal: widget.santriToEdit?.setoranAwal ?? parsedSaldo,
      jatahHarian: parsedJatah > 0 ? parsedJatah : 10000,
      tunggakan: widget.santriToEdit?.tunggakan ?? 0,
      catatanTunggakan: widget.santriToEdit?.catatanTunggakan ?? '',
      statusAktif: _statusAktif,
      createdAt: widget.santriToEdit?.createdAt,
    );

    await provider.saveSantri(santri, isEdit: isEdit);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit ? 'Data santri berhasil diperbarui' : 'Santri baru berhasil ditambahkan',
          ),
          backgroundColor: const Color(0xFF00796B),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.santriToEdit != null;
    final provider = Provider.of<KasSantriProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Data Santri' : 'Tambah Santri Baru'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informasi Pribadi & Asrama',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _namaLengkapController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap Santri *',
                        prefixIcon: Icon(Icons.person),
                        hintText: 'Contoh: Ahmad Fauzan Ramadhan',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _namaPanggilanController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Panggilan *',
                        prefixIcon: Icon(Icons.badge_outlined),
                        hintText: 'Contoh: Fauzan (untuk pencarian instan)',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Panggilan wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _kamarController,
                      decoration: InputDecoration(
                        labelText: 'Kamar / Asrama / Kelas *',
                        prefixIcon: const Icon(Icons.meeting_room_outlined),
                        hintText: 'Contoh: Kamar Abu Bakar (01)',
                        suffixIcon: provider.kamars.isNotEmpty
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.arrow_drop_down),
                                onSelected: (k) => _kamarController.text = k,
                                itemBuilder: (ctx) => provider.kamars
                                    .map((k) => PopupMenuItem(value: k, child: Text(k)))
                                    .toList(),
                              )
                            : null,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Kamar wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _kategoriSantri,
                      decoration: const InputDecoration(
                        labelText: 'Kelompok Santri',
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: Santri.kategoriSantriyin, child: Text('Santriyin (Putra)')),
                        DropdownMenuItem(value: Santri.kategoriSantriyat, child: Text('Santriyat (Putri)')),
                        DropdownMenuItem(value: Santri.kategoriSantriBaru, child: Text('Santri Baru')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _kategoriSantri = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _statusSantri,
                      decoration: const InputDecoration(
                        labelText: 'Status Keaktifan',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: Santri.statusAktifVal, child: Text('Aktif di Pondok')),
                        DropdownMenuItem(value: Santri.statusPulangVal, child: Text('Pulang / Izin')),
                        DropdownMenuItem(value: Santri.statusPindahVal, child: Text('Pindah / Boyong')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _statusSantri = val);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kontak Wali & Pengaturan Keuangan',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noWaWaliController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Nomor WhatsApp Orang Tua / Wali',
                        prefixIcon: Icon(Icons.phone),
                        hintText: 'Contoh: 081234567890 (Untuk kirim laporan)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _jatahHarianController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [RibuanInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Jatah Harian Standar (Rp) *',
                        prefixIcon: Icon(Icons.monetization_on_outlined),
                        prefixText: 'Rp ',
                        helperText: 'Batas maksimal uang yang boleh diambil per hari',
                      ),
                      validator: (v) {
                        final num = CurrencyFormatter.parse(v ?? '');
                        if (num <= 0) return 'Jatah harian harus lebih dari 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    if (!isEdit)
                      TextFormField(
                        controller: _saldoAwalController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [RibuanInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Saldo Titipan Awal (Rp)',
                          prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                          prefixText: 'Rp ',
                          helperText: 'Bisa diisi nanti via menu Setoran Bulanan',
                        ),
                      ),
                    if (isEdit) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Status Santri Aktif'),
                        subtitle: const Text('Nonaktifkan jika santri sudah lulus / pindah'),
                        value: _statusAktif,
                        activeColor: const Color(0xFF00796B),
                        onChanged: (val) => setState(() => _statusAktif = val),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                isEdit ? 'Simpan Perubahan' : 'Tambahkan Santri',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
