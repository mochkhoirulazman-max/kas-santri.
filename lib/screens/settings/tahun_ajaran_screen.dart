import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/santri.dart';
import '../../providers/kas_santri_provider.dart';
import '../../utils/app_feedback.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_background_wrapper.dart';

class TahunAjaranScreen extends StatefulWidget {
  const TahunAjaranScreen({Key? key}) : super(key: key);

  @override
  State<TahunAjaranScreen> createState() => _TahunAjaranScreenState();
}

class _TahunAjaranScreenState extends State<TahunAjaranScreen> {
  int _tabIdx = 0; // 0: Tahun Ajaran, 1: Pindah Kamar, 2: Tutup Buku / Alumni
  late TextEditingController _tahunCtrl;
  final TextEditingController _targetKamarCtrl = TextEditingController();
  String? _filterKamar;
  final Set<String> _selectedIds = {};
  String _archiveStatus = Santri.statusAlumniVal;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final cur = Provider.of<KasSantriProvider>(context, listen: false)
        .pengaturan
        .tahunAjaran;
    _tahunCtrl = TextEditingController(text: cur);
  }

  @override
  void dispose() {
    _tahunCtrl.dispose();
    _targetKamarCtrl.dispose();
    super.dispose();
  }

  String _suggestNextTahunAjaran(String current) {
    final m = RegExp(r'(\d{4})\s*/\s*(\d{4})').firstMatch(current);
    if (m != null) {
      final y1 = int.parse(m.group(1)!) + 1;
      final y2 = int.parse(m.group(2)!) + 1;
      return current.replaceFirst(m.group(0)!, '$y1/$y2');
    }
    final nowYear = DateTime.now().year;
    return '$nowYear/${nowYear + 1}';
  }

  Future<void> _saveNewTahunAjaran(KasSantriProvider provider) async {
    final nextVal = _tahunCtrl.text.trim();
    if (nextVal.isEmpty) return;
    AppFeedback.tap();
    setState(() => _busy = true);
    try {
      await provider.mulaiTahunAjaranBaru(nextVal);
      if (mounted) {
        AppFeedback.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tahun Ajaran diperbarui ke $nextVal!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moveSelectedKamar(KasSantriProvider provider) async {
    final targetKamar = _targetKamarCtrl.text.trim();
    if (_selectedIds.isEmpty || targetKamar.isEmpty) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 santri dan isi nama kamar/kelas tujuan.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }
    AppFeedback.tap();
    setState(() => _busy = true);
    try {
      final moved = await provider.pindahKamarMassal(
        _selectedIds.toList(),
        targetKamar,
      );
      if (mounted) {
        AppFeedback.success();
        setState(() {
          _selectedIds.clear();
          _filterKamar = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$moved santri berhasil dipindahkan ke "$targetKamar".'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archiveSelected(KasSantriProvider provider) async {
    if (_selectedIds.isEmpty) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih santri yang akan diluluskan / diarsipkan.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final statusLabel = _archiveStatus == Santri.statusAlumniVal
        ? 'Alumni / Lulus'
        : 'Pindah';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Arsipkan ${_selectedIds.length} Santri?',
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Status santri terpilih akan diubah menjadi "$statusLabel".\n\n'
          'Saldo akhir dan riwayat mutasi/infak mereka TETAP TERSIMPAN AMAN di arsip audit database, namun tidak lagi memenuhi antrean harian.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Tutup Buku & Arsipkan'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final count = await provider.tutupBukuArsipSantri(
        _selectedIds.toList(),
        statusTujuan: _archiveStatus,
      );
      if (mounted) {
        AppFeedback.success();
        setState(() => _selectedIds.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count santri diarsipkan sebagai $statusLabel.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final activeSantri = provider.santriStatusList.map((e) => e.santri).toList();
    final archivedSantri = provider.allSantri.where((s) => !s.statusAktif).toList();
    final kamars = provider.kamars;

    final filteredActive = activeSantri.where((s) {
      if (_filterKamar == null || _filterKamar!.isEmpty) return true;
      return s.kamar == _filterKamar;
    }).toList();

    return AppBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Tahun Ajaran & Mutasi Kamar')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // Sub-Tab Pill Toggle
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    _segBtn(0, '📅 Tahun Ajaran'),
                    _segBtn(1, '🏠 Pindah Kamar'),
                    _segBtn(2, '🎓 Tutup Buku'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_tabIdx == 0)
                GlassCard(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(18),
                  borderColor: const Color(0xFF34D399).withOpacity(0.45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PERIODE TAHUN AJARAN AKTIF',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Saat ini: ${provider.pengaturan.tahunAjaran}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Mengganti Tahun Ajaran otomatis memisahkan label pencatatan Buku Infak, PDF Resmi, dan Laporan Yayasan periode baru tanpa menghapus riwayat lama.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _tahunCtrl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Tahun Ajaran Baru',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              AppFeedback.tap();
                              _tahunCtrl.text = _suggestNextTahunAjaran(
                                provider.pengaturan.tahunAjaran,
                              );
                            },
                            icon: const Icon(Icons.auto_awesome, size: 15),
                            label: const Text('Naik +1 Tahun'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _saveNewTahunAjaran(provider),
                              child: const Text('Terapkan Tahun Ajaran'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              if (_tabIdx == 1 || _tabIdx == 2) ...[
                GlassCard(
                  borderRadius: 22,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_tabIdx == 1) ...[
                        const Text(
                          'PINDAH KAMAR / NAIK KELAS MASSAL',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _targetKamarCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Nama Kamar / Kelas Tujuan (cth: Kelas 2 MTs)',
                            isDense: true,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'TUTUP BUKU TAHUN AJARAN (LULUSKAN / ARSIPKAN)',
                          style: TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Alumni / Lulus'),
                                selected:
                                    _archiveStatus == Santri.statusAlumniVal,
                                onSelected: (_) => setState(
                                  () => _archiveStatus = Santri.statusAlumniVal,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Pindah Pondok'),
                                selected:
                                    _archiveStatus == Santri.statusPindahVal,
                                onSelected: (_) => setState(
                                  () => _archiveStatus = Santri.statusPindahVal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        value: (_filterKamar == null ||
                                kamars.contains(_filterKamar))
                            ? _filterKamar
                            : null,
                        dropdownColor: const Color(0xFF090E1A),
                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                        decoration: const InputDecoration(
                          labelText: 'Filter Kamar Asal',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Semua Kamar Aktif'),
                          ),
                          ...kamars.map(
                            (k) => DropdownMenuItem<String?>(
                              value: k,
                              child: Text(k),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _filterKamar = v),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Terpilih: ${_selectedIds.length} santri',
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedIds
                                    .addAll(filteredActive.map((s) => s.id));
                              });
                            },
                            child: const Text('Pilih Semua'),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedIds.clear()),
                            child: const Text('Batal Pilih'),
                          ),
                        ],
                      ),
                      ...filteredActive.map((s) {
                        final checked = _selectedIds.contains(s.id);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: checked,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedIds.add(s.id);
                              } else {
                                _selectedIds.remove(s.id);
                              }
                            });
                          },
                          title: Text(
                            s.namaLengkap,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${s.kamar} • Saldo ${CurrencyFormatter.format(s.saldoTotal)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10.5,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _tabIdx == 1
                                  ? _moveSelectedKamar(provider)
                                  : _archiveSelected(provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _tabIdx == 1
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFFF59E0B),
                            foregroundColor: const Color(0xFF04121A),
                          ),
                          icon: Icon(
                            _tabIdx == 1
                                ? Icons.drive_file_move_rounded
                                : Icons.inventory_2_outlined,
                          ),
                          label: Text(
                            _tabIdx == 1
                                ? 'Pindahkan ${_selectedIds.length} Santri Sekarang'
                                : 'Arsipkan ${_selectedIds.length} Santri (Tutup Buku)',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_tabIdx == 2 && archivedSantri.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ARSIP ALUMNI / PINDAH (${archivedSantri.length} SANTRI)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...archivedSantri.take(20).map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${s.namaLengkap} (${s.kamar})',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      s.statusSantriLabel,
                                      style: const TextStyle(
                                        color: Color(0xFFFDE68A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _segBtn(int index, String label) {
    final active = _tabIdx == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          setState(() {
            _tabIdx = index;
            _selectedIds.clear();
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF10B981).withOpacity(0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: active
                ? Border.all(color: const Color(0xFF34D399).withOpacity(0.55))
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF6EE7B7) : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
