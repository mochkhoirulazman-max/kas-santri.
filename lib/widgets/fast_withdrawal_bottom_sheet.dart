import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/santri_status.dart';
import '../models/transaksi.dart';
import '../providers/kas_santri_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/time_category_helper.dart';
import '../utils/app_feedback.dart';
import 'undo_snackbar.dart';

class FastWithdrawalBottomSheet extends StatefulWidget {
  final SantriStatusHariIni statusSantri;

  const FastWithdrawalBottomSheet({
    Key? key,
    required this.statusSantri,
  }) : super(key: key);

  static void show(BuildContext context, SantriStatusHariIni status) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FastWithdrawalBottomSheet(statusSantri: status),
    );
  }

  @override
  State<FastWithdrawalBottomSheet> createState() => _FastWithdrawalBottomSheetState();
}

class _FastWithdrawalBottomSheetState extends State<FastWithdrawalBottomSheet> {
  final TextEditingController _nominalController = TextEditingController();
  final TextEditingController _customKeperluanController = TextEditingController(text: 'Jajan Harian');
  TimeCategory _selectedWaktu = TimeCategory.malam;
  String _selectedKeperluan = 'Jajan Harian';
  OverlimitHandling _selectedPolicy = OverlimitHandling.potongBesok;

  final List<String> _tagChips = [
    'Jajan Pagi',
    'Jajan Siang',
    'Jajan Sore',
    'Jajan Malam',
    'Sabun/Cuci',
    'Obat',
    'Fotokopi',
    'Kitab',
    'Potong Rambut',
  ];

  @override
  void initState() {
    super.initState();
    // Default select time based on taken periods
    final txList = widget.statusSantri.transaksiHariIni;
    final takenPeriods = txList.map((t) => t.kategoriWaktu).toList();
    if (!takenPeriods.contains(TimeCategory.pagi)) {
      _selectedWaktu = TimeCategory.pagi;
    } else if (!takenPeriods.contains(TimeCategory.siang)) {
      _selectedWaktu = TimeCategory.siang;
    } else if (!takenPeriods.contains(TimeCategory.sore)) {
      _selectedWaktu = TimeCategory.sore;
    } else {
      _selectedWaktu = TimeCategory.malam;
    }

    final sisa = widget.statusSantri.sisaJatahHariIni;
    if (sisa > 0) {
      final initialVal = sisa >= 2000 ? 2000 : sisa;
      _nominalController.text = CurrencyFormatter.formatWithoutSymbol(initialVal);
    }
  }

  @override
  void dispose() {
    _nominalController.dispose();
    _customKeperluanController.dispose();
    super.dispose();
  }

  int get _nominal => CurrencyFormatter.parse(_nominalController.text);
  Santri get _santri => widget.statusSantri.santri;
  int get _sisaJatah => widget.statusSantri.sisaJatahHariIni;
  bool get _isOverlimit => _nominal > _sisaJatah;
  bool get _isSaldoKurang => _nominal > _santri.saldoTotal;

  void _addQuickChip(int amount) {
    AppFeedback.tap();
    setState(() {
      final cur = _nominal;
      _nominalController.text = CurrencyFormatter.formatWithoutSymbol(cur + amount);
    });
  }

  void _pasSisa() {
    AppFeedback.tap();
    setState(() {
      final val = _sisaJatah > 0 ? _sisaJatah : 0;
      _nominalController.text = val > 0 ? CurrencyFormatter.formatWithoutSymbol(val) : '0';
    });
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'KS';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _submit() async {
    if (_nominal <= 0) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nominal pengambilan lebih dari Rp 0!'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    final String finalCatatan = _customKeperluanController.text.trim().isNotEmpty
        ? _customKeperluanController.text.trim()
        : _selectedKeperluan;

    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    await provider.catatPengambilan(
      santri: _santri,
      nominal: _nominal,
      catatan: finalCatatan,
      isOverlimit: _isOverlimit || _isSaldoKurang,
      overlimitHandling: _isOverlimit ? _selectedPolicy : null,
      waktuCategory: _selectedWaktu,
    );

    if (_isSaldoKurang) {
      AppFeedback.alert();
    } else {
      AppFeedback.success();
    }

    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final kekurangan = _nominal - _santri.saldoTotal;
      final isKurang = _isSaldoKurang;
      final nominalTransaksi = _nominal;
      final namaSantri = _santri.namaLengkap;
      final bottomMargin = MediaQuery.of(context).padding.bottom + 84;
      final message = isKurang
          ? 'Dicatat! Tunggakan +${CurrencyFormatter.format(kekurangan < 0 ? 0 : kekurangan)} ($namaSantri)'
          : 'Ambil ${CurrencyFormatter.format(nominalTransaksi)} ($namaSantri)';

      Navigator.pop(context);
      UndoToastHelper.showPostWithdrawal(
        messenger: messenger,
        provider: provider,
        message: message,
        bottomMargin: bottomMargin,
        isWarning: isKurang,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sisaSetelah = _sisaJatah - _nominal;
    final remainingRatio = widget.statusSantri.jatahHariIni > 0
        ? (sisaSetelah / widget.statusSantri.jatahHariIni).clamp(0.0, 1.0)
        : 0.0;

    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xF5062B24), Color(0xF7091426), Color(0xF70B182E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: const Color(0xFF34D399).withValues(alpha: 0.50), width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          top: 12,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
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

              // Header Modal: Avatar, Nama, Kamar & Close
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.35),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: _santri.fotoPath != null && File(_santri.fotoPath!).existsSync()
                          ? Image.file(
                              File(_santri.fotoPath!),
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            )
                          : Text(
                              _getInitials(_santri.namaLengkap),
                              style: const TextStyle(
                                color: Color(0xFF34D399),
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _santri.kamar,
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _santri.namaLengkap,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

              const SizedBox(height: 14),

              // Panel Live Simulasi Sisa Jatah Hari Ini (terpisah rapi & tidak menempel)
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SISA JATAH HARI INI',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.format(_sisaJatah < 0 ? 0 : _sisaJatah),
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              if (_nominal > 0) ...[
                                const SizedBox(height: 3),
                                Text(
                                  '→ Sisa ${CurrencyFormatter.format(sisaSetelah < 0 ? 0 : sisaSetelah)}',
                                  style: TextStyle(
                                    color: _isOverlimit ? const Color(0xFFFB7185) : const Color(0xFF7DD3FC),
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 44,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: Colors.white12,
                        ),
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'TOTAL SALDO',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  CurrencyFormatter.format(_santri.saldoTotal),
                                  style: const TextStyle(
                                    color: Color(0xFFE2E8F0),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: remainingRatio,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              colors: _isOverlimit
                                  ? [const Color(0xFFF43F5E), const Color(0xFFE11D48)]
                                  : [const Color(0xFF10B981), const Color(0xFF06B6D4)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.statusSantri.transaksiHariIni.isNotEmpty
                              ? 'Hari ini: ${widget.statusSantri.transaksiHariIni.length}x ambil'
                              : 'Hari ini: Belum ada pengambilan',
                          style: const TextStyle(color: Color(0xFF7DD3FC), fontSize: 10.5),
                        ),
                        Text(
                          'Kuota: ${CurrencyFormatter.format(_santri.jatahHarian)}/hr',
                          style: const TextStyle(color: Colors.white54, fontSize: 10.5, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            // Sesi Waktu Pengambilan (Pagi, Siang, Sore, Malam)
            const Text(
              'SESI WAKTU PENGAMBILAN',
              style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildWaktuBtn('🌅 Pagi', TimeCategory.pagi),
                const SizedBox(width: 6),
                _buildWaktuBtn('☀️ Siang', TimeCategory.siang),
                const SizedBox(width: 6),
                _buildWaktuBtn('🌤️ Sore', TimeCategory.sore),
                const SizedBox(width: 6),
                _buildWaktuBtn('🌙 Malam', TimeCategory.malam),
              ],
            ),

            const SizedBox(height: 14),

            // Nominal Ambil & Reset
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'NOMINAL AMBIL (RP)',
                  style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
                InkWell(
                  onTap: () => setState(() => _nominalController.text = '0'),
                  child: const Text(
                    'Reset Rp 0',
                    style: TextStyle(color: Color(0xFFFB7185), fontSize: 11, fontWeight: FontWeight.bold),
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
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
                filled: true,
                fillColor: const Color(0xFF060A14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Colors.white24, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: _isOverlimit ? const Color(0xFFF43F5E) : const Color(0xFF34D399),
                    width: 2,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 8),

            // Quick Chips Akumulatif
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildQuickChip('+1.000', 1000),
                _buildQuickChip('+2.000', 2000),
                _buildQuickChip('+3.000', 3000),
                _buildQuickChip('+5.000', 5000),
                _buildQuickChip('+10.000', 10000),
                InkWell(
                  onTap: _pasSisa,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                    ),
                    child: const Text(
                      'Pas Sisa',
                      style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Tag Keperluan & Tulis Manual
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'TAG KEPERLUAN',
                  style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
                Text(
                  'Bisa pilih atau tulis manual ✍️',
                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tagChips.map((tag) {
                final isSelected = _selectedKeperluan == tag;
                return InkWell(
                  onTap: () {
                    AppFeedback.tap();
                    setState(() {
                      _selectedKeperluan = tag;
                      _customKeperluanController.text = tag;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? const Color(0xFF34D399) : Colors.white12),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF04121A) : Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 8),

            // Form Tulis Manual Catatan Keperluan
            TextField(
              controller: _customKeperluanController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Tulis keperluan manual (contoh: Beli Kitab, Laundry, Cukur)...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                prefixIcon: const Icon(Icons.edit_note, color: Color(0xFF38BDF8), size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: const Color(0xFF060B14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                ),
              ),
              onChanged: (val) {
                setState(() => _selectedKeperluan = val.trim());
              },
            ),

            // Box Peringatan Overlimit (Melebihi Jatah Harian tapi Masih Ada Saldo)
            if (_isOverlimit && !_isSaldoKurang) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A1A).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFFB7185), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Melebihi Sisa Jatah Hari Ini!',
                          style: TextStyle(color: Color(0xFFFECDD3), fontSize: 11.5, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Input nominal ${CurrencyFormatter.format(_nominal)} melampaui sisa kuota hari ini sebesar ${CurrencyFormatter.format(_nominal - _sisaJatah)}. Sisa saldo bulanan santri masih mencukupi.',
                      style: const TextStyle(color: Color(0xFFFDA4AF), fontSize: 10.5),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<OverlimitHandling>(
                      value: _selectedPolicy,
                      dropdownColor: const Color(0xFF1F122B),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFF43F5E)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: OverlimitHandling.potongBesok,
                          child: Text('Izinkan (Darurat) & Potong Total Saldo', style: TextStyle(fontSize: 11, color: Colors.white)),
                        ),
                        DropdownMenuItem(
                          value: OverlimitHandling.hitungUlangRataRata,
                          child: Text('Izinkan & Hitung Ulang Rata-Rata Jatah Harian', style: TextStyle(fontSize: 11, color: Colors.white)),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPolicy = val);
                      },
                    ),
                  ],
                ),
              ),
            ],

            // Box Peringatan Saldo Bulanan Habis / Kurang (Otomatis Jadi Tunggakan Pondok)
            if (_isSaldoKurang) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4C0519).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFB7185), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF43F5E).withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline, color: Color(0xFFFB7185), size: 18),
                        SizedBox(width: 6),
                        Text(
                          '🚨 Saldo Santri Kurang / Habis!',
                          style: TextStyle(color: Color(0xFFFECDD3), fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sisa saldo bulanan santri hanya ${CurrencyFormatter.format(_santri.saldoTotal)}. Pengambilan sebesar ${CurrencyFormatter.format(_nominal)} akan menghabiskan saldo menjadi Rp 0 dan kekurangannya (${CurrencyFormatter.format(_nominal - _santri.saldoTotal)}) otomatis ditalangi dari fisik brankas pondok serta dicatat sebagai TUNGGAKAN santri.',
                      style: const TextStyle(color: Color(0xFFFDA4AF), fontSize: 10.5, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Tombol Simpan Pengambilan Uang
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSaldoKurang
                      ? const Color(0xFFE11D48)
                      : (_isOverlimit ? const Color(0xFFF43F5E) : const Color(0xFF10B981)),
                  foregroundColor: const Color(0xFF030712),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 6,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shadowColor: (_isSaldoKurang
                          ? const Color(0xFFE11D48)
                          : (_isOverlimit ? const Color(0xFFF43F5E) : const Color(0xFF10B981)))
                      .withOpacity(0.4),
                ),
                onPressed: _submit,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _isSaldoKurang
                        ? '🚨 TALANGI DARI BRANKAS & CATAT TUNGGAKAN'
                        : (_isOverlimit ? '⚠️ IZINKAN AMBIL MELEBIHI JATAH' : '✅ SIMPAN PENGAMBILAN UANG'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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

  Widget _buildWaktuBtn(String label, TimeCategory cat) {
    final isSelected = _selectedWaktu == cat;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          setState(() => _selectedWaktu = cat);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFF060B14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF34D399) : Colors.white12,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF34D399) : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, int amount) {
    return InkWell(
      onTap: () => _addQuickChip(amount),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
