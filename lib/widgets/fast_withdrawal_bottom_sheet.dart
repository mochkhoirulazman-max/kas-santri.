import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/santri.dart';
import '../models/santri_status.dart';
import '../models/transaksi.dart';
import '../providers/kas_santri_provider.dart';
import '../utils/currency_formatter.dart';
import 'numpad_widget.dart';
import 'quick_chips_widget.dart';

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
      backgroundColor: Colors.transparent,
      builder: (ctx) => FastWithdrawalBottomSheet(statusSantri: status),
    );
  }

  @override
  State<FastWithdrawalBottomSheet> createState() =>
      _FastWithdrawalBottomSheetState();
}

class _FastWithdrawalBottomSheetState extends State<FastWithdrawalBottomSheet> {
  String _inputNominalStr = '';
  String? _selectedCategory;
  final TextEditingController _customNoteController = TextEditingController();

  final List<String> _tagChips = [
    'Jajan',
    'Beli Sabun/Toiletries',
    'Obat/Sakit',
    'Fotokopi/Sekolah',
  ];

  int get _nominal => int.tryParse(_inputNominalStr) ?? 0;
  Santri get _santri => widget.statusSantri.santri;
  int get _sisaJatah => widget.statusSantri.sisaJatahHariIni;

  void _onKeyPress(String val) {
    if (_inputNominalStr.length >= 8) return; // Maks 99 juta
    setState(() {
      _inputNominalStr += val;
    });
  }

  void _onBackspace() {
    if (_inputNominalStr.isNotEmpty) {
      setState(() {
        _inputNominalStr =
            _inputNominalStr.substring(0, _inputNominalStr.length - 1);
      });
    }
  }

  void _onClear() {
    setState(() {
      _inputNominalStr = '';
    });
  }

  void _onAddQuickAmount(int amount) {
    setState(() {
      final current = _nominal;
      final result = current + amount;
      _inputNominalStr = result.toString();
    });
  }

  void _onTakeRemainingQuota() {
    setState(() {
      _inputNominalStr = _sisaJatah.toString();
    });
  }

  // Menentukan warna indikator: Hijau (Aman), Kuning (Pas Limit), Merah (Overlimit)
  Color _getIndicatorColor() {
    if (_nominal == 0) return Colors.black87;
    if (_nominal > _sisaJatah) {
      return const Color(0xFFD32F2F); // Merah
    } else if (_nominal == _sisaJatah) {
      return const Color(0xFFF57C00); // Kuning / Amber
    } else {
      return const Color(0xFF2E7D32); // Hijau
    }
  }

  String _getIndicatorStatusText() {
    if (_nominal == 0) return 'Masukkan nominal pengambilan';
    if (_nominal > _sisaJatah) {
      final kelebihan = _nominal - _sisaJatah;
      return '⚠️ Melebihi jatah harian (+${CurrencyFormatter.format(kelebihan)})';
    } else if (_nominal == _sisaJatah) {
      return '✓ Pas dengan sisa limit hari ini';
    } else {
      final sisaSetelah = _sisaJatah - _nominal;
      return '✓ Masih aman (Sisa nanti: ${CurrencyFormatter.format(sisaSetelah)})';
    }
  }

  Future<void> _handleSubmit() async {
    if (_nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal pengambilan harus lebih dari Rp 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_nominal > _santri.saldoTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saldo santri tidak mencukupi! (Saldo: ${CurrencyFormatter.format(_santri.saldoTotal)})',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isOverlimit = _nominal > _sisaJatah;
    final note = _selectedCategory ??
        (_customNoteController.text.trim().isNotEmpty
            ? _customNoteController.text.trim()
            : 'Jajan');

    if (isOverlimit) {
      // Tampilkan Warning Modal Overlimit sesuai PRD
      final kelebihan = _nominal - _sisaJatah;
      final handling = await _showOverlimitDialog(kelebihan);
      if (handling == null) return; // Dibatalkan oleh pengurus

      _saveTransaction(isOverlimit: true, handling: handling, note: note);
    } else {
      _saveTransaction(isOverlimit: false, note: note);
    }
  }

  Future<OverlimitHandling?> _showOverlimitDialog(int kelebihan) {
    return showDialog<OverlimitHandling>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        OverlimitHandling selectedOption = OverlimitHandling.potongBesok;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Peringatan Overlimit',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengambilan melebihi jatah harian sebesar ${CurrencyFormatter.format(kelebihan)}. Apakah tetap diizinkan (Darurat / Kasbon Jatah)?',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pilih Penyesuaian Saldo:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  RadioListTile<OverlimitHandling>(
                    title: const Text('Opsi A: Potong Jatah Besok', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Jatah besok otomatis berkurang sebesar nominal kelebihan hari ini.', style: TextStyle(fontSize: 11)),
                    value: OverlimitHandling.potongBesok,
                    groupValue: selectedOption,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedOption = val);
                    },
                  ),
                  RadioListTile<OverlimitHandling>(
                    title: const Text('Opsi B: Hitung Ulang Rata-Rata', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Jatah harian untuk sisa hari ke depan dihitung ulang proporsional.', style: TextStyle(fontSize: 11)),
                    value: OverlimitHandling.hitungUlangRataRata,
                    groupValue: selectedOption,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedOption = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, null),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx, selectedOption),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                  ),
                  child: const Text('Izinkan Ambil'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveTransaction({
    required bool isOverlimit,
    OverlimitHandling? handling,
    required String note,
  }) async {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);

    Navigator.pop(context); // Tutup bottom sheet segera

    await provider.catatPengambilan(
      santri: _santri,
      nominal: _nominal,
      catatan: note,
      isOverlimit: isOverlimit,
      overlimitHandling: handling,
    );
  }

  @override
  Widget build(BuildContext context) {
    final indicatorColor = _getIndicatorColor();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Info Santri & Real-time Quota Info
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF00796B),
                foregroundColor: Colors.white,
                radius: 20,
                child: Text(
                  _santri.namaPanggilan.isNotEmpty
                      ? _santri.namaPanggilan[0].toUpperCase()
                      : _santri.namaLengkap[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _santri.namaLengkap,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_santri.kamar} • Saldo: ${CurrencyFormatter.format(_santri.saldoTotal)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              // Sisa Jatah Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Sisa Jatah Hari Ini',
                      style: TextStyle(fontSize: 10, color: Colors.teal),
                    ),
                    Text(
                      CurrencyFormatter.format(_sisaJatah),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF004D40),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          // Rincian Pengambilan Sebelumnya Hari Ini
          if (widget.statusSantri.transaksiHariIni.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.statusSantri.ringkasanAmbilHariIni,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ),

          const SizedBox(height: 12),

          // Display Nominal Input Real-time dengan Indikator Warna
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: indicatorColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: indicatorColor.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Rp ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: indicatorColor,
                      ),
                    ),
                    Text(
                      _nominal > 0 ? CurrencyFormatter.formatWithoutSymbol(_nominal) : '0',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: indicatorColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _getIndicatorStatusText(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: indicatorColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Quick Addition Chips (+1k, +2k, +5k, Ambil Sisa Jatah)
          QuickChipsWidget(
            onAddAmount: _onAddQuickAmount,
            onTakeRemainingQuota: _onTakeRemainingQuota,
            sisaJatahHariIni: _sisaJatah,
          ),

          const SizedBox(height: 8),

          // Tag Keterangan Sekali Klik
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tagChips.map((tag) {
                final isSelected = _selectedCategory == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(tag, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? tag : null;
                      });
                    },
                    selectedColor: Colors.teal.shade100,
                    checkmarkColor: const Color(0xFF00796B),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Numpad Kustom Berukuran Besar
          NumpadWidget(
            onKeyPress: _onKeyPress,
            onBackspace: _onBackspace,
            onClear: _onClear,
          ),

          const SizedBox(height: 12),

          // Tombol Simpan Ambil Uang (Tap 3)
          ElevatedButton(
            onPressed: _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Simpan Ambil Uang (${CurrencyFormatter.format(_nominal)})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
