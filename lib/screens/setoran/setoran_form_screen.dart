import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/santri.dart';
import '../../models/setoran.dart';
import '../../providers/kas_santri_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/searchable_santri_picker.dart';

class SetoranFormScreen extends StatefulWidget {
  final String? preselectedSantriId;

  const SetoranFormScreen({Key? key, this.preselectedSantriId}) : super(key: key);

  @override
  State<SetoranFormScreen> createState() => _SetoranFormScreenState();
}

class _SetoranFormScreenState extends State<SetoranFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedSantriId;
  TipeSetoran _tipeSetoran = TipeSetoran.awalBulan;
  OpsiSetoranSusulan _opsiSusulan = OpsiSetoranSusulan.tambahJatahHarian;
  PerlakuanSisaSaldoLalu _perlakuanSisa = PerlakuanSisaSaldoLalu.gabungBulanBaru;
  String _sumberDompet = 'TUNAI';

  final TextEditingController _nominalController = TextEditingController();
  final TextEditingController _durasiHariController = TextEditingController(text: '30');
  final TextEditingController _jatahHitungController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();

  DateTime _tanggalSetor = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedSantriId = widget.preselectedSantriId;
    _durasiHariController.addListener(_calculateAutoQuota);
    _nominalController.addListener(_calculateAutoQuota);
  }

  @override
  void dispose() {
    _durasiHariController.dispose();
    _nominalController.dispose();
    _jatahHitungController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  // Hitung otomatis jatah harian dengan pembulatan ke bawah
  void _calculateAutoQuota() {
    final nominal = CurrencyFormatter.parse(_nominalController.text);
    final durasi = int.tryParse(_durasiHariController.text) ?? 30;
    final kelipatan = Provider.of<KasSantriProvider>(context, listen: false).pengaturan.pembulatanJatah;

    if (nominal > 0 && durasi > 0) {
      final jatah = CurrencyFormatter.hitungJatahHarianBulat(nominal, durasi, kelipatan: kelipatan);
      _jatahHitungController.text = CurrencyFormatter.formatWithoutSymbol(jatah);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSantriId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih santri terlebih dahulu')),
      );
      return;
    }

    final nominal = CurrencyFormatter.parse(_nominalController.text);
    final durasi = int.tryParse(_durasiHariController.text) ?? 30;
    final parsedJatah = CurrencyFormatter.parse(_jatahHitungController.text);
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final jatah = parsedJatah > 0
        ? parsedJatah
        : CurrencyFormatter.hitungJatahHarianBulat(
            nominal,
            durasi,
            kelipatan: provider.pengaturan.pembulatanJatah,
          );

    await provider.catatSetoran(
      santriId: _selectedSantriId!,
      nominalSetoran: nominal,
      durasiHari: durasi,
      jatahHarianHitung: jatah,
      tipeSetoran: _tipeSetoran,
      tanggalSetor: _tanggalSetor,
      catatan: _catatanController.text.trim().isNotEmpty ? _catatanController.text.trim() : null,
      perlakuanSisa: _perlakuanSisa,
      opsiSusulan: _tipeSetoran == TipeSetoran.susulanTopUp ? _opsiSusulan : null,
      metodeBayar: _sumberDompet,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setoran uang berhasil dicatat dan saldo santri telah ditambahkan!'),
          backgroundColor: Color(0xFF00796B),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final activeSantris = provider.allSantri.where((s) => s.statusAktif).toList();

    Santri? selectedSantri;
    if (_selectedSantriId != null) {
      selectedSantri = activeSantris.firstWhere(
        (s) => s.id == _selectedSantriId,
        orElse: () => activeSantris.first,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catat Setoran Uang Masuk'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
          children: [
            // Pilih Santri
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih Santri',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                    ),
                    const SizedBox(height: 12),
                    SearchableSantriField(
                      selectedSantri: selectedSantri,
                      placeholder: 'Pilih Nama Santri *',
                      onTap: () async {
                        final picked = await SearchableSantriPicker.show(
                          context,
                          santriList: activeSantris,
                          selectedSantriId: _selectedSantriId,
                          title: 'Pilih Santri',
                        );
                        if (picked != null && mounted) {
                          setState(() => _selectedSantriId = picked);
                        }
                      },
                    ),

                    if (selectedSantri != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Saldo saat ini: ${CurrencyFormatter.format(selectedSantri.saldoTotal)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                            ),
                            Text(
                              'Jatah: ${CurrencyFormatter.format(selectedSantri.jatahHarian)}/hr',
                              style: TextStyle(color: Colors.teal.shade900, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Jenis Setoran & Nominal
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detail Pemasukan Uang',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                    ),
                    const SizedBox(height: 12),

                    // Segmented Button Tipe Setoran
                    SegmentedButton<TipeSetoran>(
                      segments: const [
                        ButtonSegment(
                          value: TipeSetoran.awalBulan,
                          label: Text('Awal Bulan'),
                          icon: Icon(Icons.calendar_month),
                        ),
                        ButtonSegment(
                          value: TipeSetoran.susulanTopUp,
                          label: Text('Top-Up Susulan'),
                          icon: Icon(Icons.add_card),
                        ),
                      ],
                      selected: {_tipeSetoran},
                      onSelectionChanged: (set) {
                        setState(() => _tipeSetoran = set.first);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Sumber Dompet Masuk
                    DropdownButtonFormField<String>(
                      value: _sumberDompet,
                      decoration: const InputDecoration(
                        labelText: 'Dompet Tujuan Masuk *',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'TUNAI', child: Text('💵 Kas Laci Tunai')),
                        DropdownMenuItem(value: 'REKENING', child: Text('🏦 Rekening Bank (Transfer)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _sumberDompet = val);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Input Nominal Setoran
                    TextFormField(
                      controller: _nominalController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [RibuanInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Nominal Setoran (Rp) *',
                        prefixIcon: Icon(Icons.attach_money),
                        prefixText: 'Rp ',
                        hintText: '300.000',
                      ),
                      validator: (v) {
                        final parsed = CurrencyFormatter.parse(v ?? '');
                        if (parsed <= 0) return 'Nominal setoran harus lebih dari 0';
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Durasi Hari & Kalkulator Otomatis Jatah Harian
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _durasiHariController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Durasi (Hari) *',
                              prefixIcon: Icon(Icons.timelapse),
                              suffixText: 'hari',
                            ),
                            validator: (v) {
                              final d = int.tryParse(v ?? '');
                              if (d == null || d <= 0) return 'Isi durasi';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _jatahHitungController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [RibuanInputFormatter()],
                            decoration: const InputDecoration(
                              labelText: 'Jatah / Hari *',
                              prefixText: 'Rp ',
                              helperText: 'Otomatis pembulatan bawah',
                            ),
                            validator: (v) {
                              final j = CurrencyFormatter.parse(v ?? '');
                              if (j <= 0) return 'Jatah tidak valid';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Pilihan Khusus Setoran Susulan (Top-Up)
                    if (_tipeSetoran == TipeSetoran.susulanTopUp) ...[
                      const Text(
                        'Tujuan Setoran Susulan:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      RadioListTile<OpsiSetoranSusulan>(
                        title: const Text('Menambah Kuota Jatah Harian', style: TextStyle(fontSize: 13)),
                        subtitle: const Text('Nominal harian santri bertambah untuk sisa periode', style: TextStyle(fontSize: 11)),
                        value: OpsiSetoranSusulan.tambahJatahHarian,
                        groupValue: _opsiSusulan,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          if (val != null) setState(() => _opsiSusulan = val);
                        },
                      ),
                      RadioListTile<OpsiSetoranSusulan>(
                        title: const Text('Memperpanjang Jumlah Hari', style: TextStyle(fontSize: 13)),
                        subtitle: const Text('Jatah harian tetap, uang cukup untuk durasi lebih lama', style: TextStyle(fontSize: 11)),
                        value: OpsiSetoranSusulan.perpanjangHari,
                        groupValue: _opsiSusulan,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          if (val != null) setState(() => _opsiSusulan = val);
                        },
                      ),
                    ],

                    // Pilihan Penanganan Sisa Bulan Lalu (Awal Bulan)
                    if (_tipeSetoran == TipeSetoran.awalBulan) ...[
                      const Text(
                        'Perlakuan Sisa Saldo Bulan Lalu:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      RadioListTile<PerlakuanSisaSaldoLalu>(
                        title: const Text('Digabung ke Bulan Baru', style: TextStyle(fontSize: 13)),
                        subtitle: const Text('Sisa uang bulan lalu diakumulasikan ke saldo santri', style: TextStyle(fontSize: 11)),
                        value: PerlakuanSisaSaldoLalu.gabungBulanBaru,
                        groupValue: _perlakuanSisa,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          if (val != null) setState(() => _perlakuanSisa = val);
                        },
                      ),
                      RadioListTile<PerlakuanSisaSaldoLalu>(
                        title: const Text('Simpan sebagai Tabungan Terpisah', style: TextStyle(fontSize: 13)),
                        subtitle: const Text('Saldo operasional harian dimulai murni dari setoran baru ini', style: TextStyle(fontSize: 11)),
                        value: PerlakuanSisaSaldoLalu.simpanTabungan,
                        groupValue: _perlakuanSisa,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          if (val != null) setState(() => _perlakuanSisa = val);
                        },
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Catatan & Tanggal
                    TextFormField(
                      controller: _catatanController,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Tambahan (Opsional)',
                        prefixIcon: Icon(Icons.notes),
                        hintText: 'Misal: Titipan via transfer Ibu',
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.date_range, color: Colors.teal),
                      title: const Text('Tanggal Setoran', style: TextStyle(fontSize: 13)),
                      subtitle: Text(DateFormatter.formatDisplayDate(_tanggalSetor), style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _tanggalSetor,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _tanggalSetor = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Simpan Data Setoran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }
}
