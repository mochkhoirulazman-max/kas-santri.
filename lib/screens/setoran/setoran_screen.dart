import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/infak_santri.dart';
import '../../models/santri.dart';
import '../../models/setoran.dart';
import '../../providers/kas_santri_provider.dart';
import '../../providers/theme_wallpaper_provider.dart';
import '../../utils/app_feedback.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/sambangan_receipt_dialog.dart';
import '../../widgets/searchable_santri_picker.dart';
import 'buku_infak_view.dart';

class SetoranScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  final int activeSubTab;
  final ValueChanged<int>? onSubTabChanged;

  const SetoranScreen({
    Key? key,
    this.onSaved,
    this.activeSubTab = 0,
    this.onSubTabChanged,
  }) : super(key: key);

  @override
  State<SetoranScreen> createState() => _SetoranScreenState();
}

class _SetoranScreenState extends State<SetoranScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String? _selectedSantriId;
  TipeSetoran _tipeSetoran = TipeSetoran.awalBulan;
  bool _potongTunggakan = true;
  String _sumberDompet = 'TUNAI'; // 'TUNAI' atau 'REKENING'

  final TextEditingController _nominalController = TextEditingController(text: '300.000');
  final TextEditingController _durasiController = TextEditingController(text: '30');
  final TextEditingController _catatanController = TextEditingController();

  // Smart Split Sambangan controllers & states
  bool _sambanganDefaultsLoaded = false;
  bool _isMasakChecked = true;
  bool _isMasakBebas = false;
  bool _isListrikChecked = true;
  bool _isListrikBebas = false;
  String _sambanganJenisBeras = InfakSantriModel.berasUangVal;
  late DateTime _tglMasuk;
  late String _tglHabisYmd;
  final TextEditingController _masakController = TextEditingController(text: '130.000');
  final TextEditingController _listrikController = TextEditingController(text: '20.000');
  final TextEditingController _berasLiterController = TextEditingController(text: '15');
  final TextEditingController _berasUangController = TextEditingController(text: '150.000');

  @override
  void initState() {
    super.initState();
    _tglMasuk = DateTime.now().toLocal();
    _tglHabisYmd =
        InfakSantriModel.hitungTglHabis(DateFormatter.toLocalDateString(_tglMasuk));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sambanganDefaultsLoaded) {
      final peng = Provider.of<KasSantriProvider>(context, listen: false).pengaturan;
      _masakController.text =
          CurrencyFormatter.formatWithoutSymbol(peng.defaultInfakMasak);
      _listrikController.text =
          CurrencyFormatter.formatWithoutSymbol(peng.defaultInfakListrik);
      final l = peng.defaultInfakBerasLiter;
      _berasLiterController.text =
          l == l.roundToDouble() ? l.toInt().toString() : l.toString();
      _berasUangController.text =
          CurrencyFormatter.formatWithoutSymbol(peng.defaultInfakBerasUang);
      _sambanganDefaultsLoaded = true;
    }
  }

  @override
  void dispose() {
    _nominalController.dispose();
    _durasiController.dispose();
    _catatanController.dispose();
    _masakController.dispose();
    _listrikController.dispose();
    _berasLiterController.dispose();
    _berasUangController.dispose();
    super.dispose();
  }

  int get _nominal => CurrencyFormatter.parse(_nominalController.text);
  int get _durasi => int.tryParse(_durasiController.text.trim()) ?? 30;

  int get _sambanganMasak => (_isMasakChecked && !_isMasakBebas)
      ? CurrencyFormatter.parse(_masakController.text)
      : 0;
  int get _sambanganListrik => (_isListrikChecked && !_isListrikBebas)
      ? CurrencyFormatter.parse(_listrikController.text)
      : 0;
  int get _sambanganBerasUang =>
      _sambanganJenisBeras == InfakSantriModel.berasUangVal
          ? CurrencyFormatter.parse(_berasUangController.text)
          : 0;
  double get _sambanganBerasLiter =>
      _sambanganJenisBeras == InfakSantriModel.berasFisik
          ? (double.tryParse(
                _berasLiterController.text.trim().replaceAll(',', '.'),
              ) ??
              0.0)
          : 0.0;

  int get _totalPotonganInfakUang =>
      _sambanganMasak + _sambanganListrik + _sambanganBerasUang;

  int _sambanganSisaJajan(Santri? santri) {
    int rem = _nominal - _totalPotonganInfakUang;
    if (rem <= 0) return rem;
    if (_potongTunggakan && santri != null && santri.tunggakan > 0) {
      rem = (rem - santri.tunggakan).clamp(0, rem);
    }
    return rem;
  }

  int _nominalBersih(Santri? santri) {
    if (_tipeSetoran == TipeSetoran.sambanganSplit) {
      final raw = _sambanganSisaJajan(santri);
      return raw < 0 ? 0 : raw;
    }
    int net = _nominal;
    if (_potongTunggakan && santri != null && santri.tunggakan > 0) {
      net = (_nominal - santri.tunggakan).clamp(0, double.infinity).toInt();
    }
    return net;
  }

  int _hitungJatahPresisi(Santri? santri, {int kelipatan = 500}) {
    if (_durasi <= 0) return 0;
    return CurrencyFormatter.hitungJatahHarianBulat(
      _nominalBersih(santri),
      _durasi,
      kelipatan: kelipatan,
    );
  }

  void _setQuick(int nominal, int durasi) {
    AppFeedback.tap();
    setState(() {
      _nominalController.text = CurrencyFormatter.formatWithoutSymbol(nominal);
      _durasiController.text = durasi.toString();
    });
  }

  Future<void> _pickSambanganDate({required bool isMasuk}) async {
    AppFeedback.tap();
    final initial = isMasuk
        ? _tglMasuk
        : DateFormatter.parseLocalDate(_tglHabisYmd);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF10B981),
              onPrimary: Color(0xFF040914),
              surface: Color(0xFF0F172A),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null && mounted) {
      final localPicked = DateTime(picked.year, picked.month, picked.day);
      setState(() {
        if (isMasuk) {
          _tglMasuk = localPicked;
          _tglHabisYmd = InfakSantriModel.hitungTglHabis(
            DateFormatter.toLocalDateString(localPicked),
          );
        } else {
          _tglHabisYmd = DateFormatter.toLocalDateString(localPicked);
        }
      });
    }
  }

  Future<void> _simpan() async {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final santriList = provider.allSantri.where((s) => s.statusAktif).toList();

    final targetId =
        _selectedSantriId ?? (santriList.isNotEmpty ? santriList.first.id : null);
    if (targetId == null) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih santri terlebih dahulu!'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    if (_nominal <= 0) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal setoran harus lebih dari Rp 0!'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    final santri = santriList.firstWhere((s) => s.id == targetId);

    if (_tipeSetoran == TipeSetoran.sambanganSplit) {
      if (_totalPotonganInfakUang > _nominal) {
        AppFeedback.alert();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Total potongan infak melebihi total uang diterima dari wali!',
            ),
            backgroundColor: Color(0xFFE11D48),
          ),
        );
        return;
      }

      try {
        final res = await provider.catatSambanganSmartSplit(
          santriId: targetId,
          totalUangDiterima: _nominal,
          tanggalMasuk: _tglMasuk,
          tglHabisYmd: _tglHabisYmd,
          nominalMasak: _sambanganMasak,
          isMasakBebas: _isMasakBebas,
          nominalListrik: _sambanganListrik,
          isListrikBebas: _isListrikBebas,
          jenisBeras: _sambanganJenisBeras,
          berasLiter: _sambanganBerasLiter,
          berasUang: _sambanganBerasUang,
          durasiHari: _durasi,
          potongTunggakan: _potongTunggakan,
          sumberDompet: _sumberDompet,
          catatan: _catatanController.text.trim(),
        );
        AppFeedback.success();
        if (mounted) {
          await SambanganReceiptDialog.show(
            context,
            santri: santri,
            infak: res.infak,
            totalDiterima: _nominal,
            sisaJajan: res.sisaJajan,
            jatahBaru: res.jatahBaru,
            nominalPotongTunggakan: res.nominalPotongTunggakan,
          );
        }
      } catch (e) {
        AppFeedback.alert();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menyimpan sambangan: $e'),
              backgroundColor: const Color(0xFFE11D48),
            ),
          );
        }
      }
      return;
    }

    final catatan = _catatanController.text.trim().isNotEmpty
        ? _catatanController.text.trim()
        : (_tipeSetoran == TipeSetoran.awalBulan
            ? 'Setoran Bulanan'
            : 'Top-Up Susulan');

    await provider.catatSetoran(
      santriId: targetId,
      nominalSetoran: _nominal,
      durasiHari: _durasi,
      jatahHarianHitung: _hitungJatahPresisi(
        santri,
        kelipatan: provider.pengaturan.pembulatanJatah,
      ),
      tipeSetoran: _tipeSetoran,
      tanggalSetor: DateTime.now(),
      catatan: catatan,
      potongTunggakan: _potongTunggakan,
      metodeBayar: _sumberDompet,
    );

    AppFeedback.success();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Setoran ${santri.namaLengkap} (${CurrencyFormatter.format(_nominal)}) berhasil disimpan!',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = Provider.of<KasSantriProvider>(context);
    final cardOpacity = Provider.of<ThemeWallpaperProvider>(context).cardOpacity;
    final santriList = provider.allSantri.where((s) => s.statusAktif).toList();

    if (_selectedSantriId == null && santriList.isNotEmpty) {
      _selectedSantriId = santriList.first.id;
    }
    final selectedSantri =
        santriList.where((s) => s.id == _selectedSantriId).firstOrNull;
    final kelipatan = provider.pengaturan.pembulatanJatah;
    final netMasuk = _nominalBersih(selectedSantri);
    final jatahBulat = _hitungJatahPresisi(selectedSantri, kelipatan: kelipatan);
    final selisihPembulatan =
        CurrencyFormatter.hitungSelisihPembulatan(netMasuk, _durasi, jatahBulat);
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final isSambangan = _tipeSetoran == TipeSetoran.sambanganSplit;
    final isDeficitSambangan = isSambangan && _totalPotonganInfakUang > _nominal;

    final statusInfakPratinjau = InfakSantriModel.hitungStatusLunas(
      nominalMasak: _sambanganMasak,
      isMasakBebas: _isMasakBebas,
      nominalListrik: _sambanganListrik,
      isListrikBebas: _isListrikBebas,
      jenisBeras: _sambanganJenisBeras,
      berasLiter: _sambanganBerasLiter,
      berasUang: _sambanganBerasUang,
      targetMasak: provider.pengaturan.defaultInfakMasak,
      targetListrik: provider.pengaturan.defaultInfakListrik,
      targetBerasLiter: provider.pengaturan.defaultInfakBerasLiter,
      targetBerasUang: provider.pengaturan.defaultInfakBerasUang,
    );

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Top Sub-Tab Switcher: [ 💸 Setoran & Sambangan ] | [ 🌾 Buku Infak ]
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(cardOpacity),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  _buildSubTabPill(
                    label: '💸 Setoran & Sambangan',
                    selected: widget.activeSubTab == 0,
                    onTap: () => widget.onSubTabChanged?.call(0),
                  ),
                  _buildSubTabPill(
                    label: '🌾 Buku Infak',
                    selected: widget.activeSubTab == 1,
                    onTap: () => widget.onSubTabChanged?.call(1),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: widget.activeSubTab == 1
                ? const BukuInfakView()
                : ListView(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 120 + bottomSafe),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(cardOpacity),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isSambangan
                                            ? 'SMART SPLIT SAMBANGAN v3.0'
                                            : 'PEMASUKAN KAS',
                                        style: TextStyle(
                                          color: isSambangan
                                              ? const Color(0xFFFBBF24)
                                              : const Color(0xFF34D399),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isSambangan
                                            ? 'Sambangan (Infak + Uang Jajan)'
                                            : 'Setoran Bulanan & Top-Up',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isSambangan
                                            ? 'Otomatis pisah Kas Infak Pondok (Masak, Listrik, Beras) & Uang Jajan.'
                                            : 'Otomatis membagi nominal setoran menjadi kuota jatah harian.',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withOpacity(0.3),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    isSambangan ? '🎁' : '📥',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Pilih Santri (Universal Searchable Picker)
                            const Text(
                              'PILIH SANTRI',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SearchableSantriField(
                              selectedSantri: selectedSantri,
                              placeholder: 'Cari & pilih santri...',
                              onTap: () async {
                                final picked = await SearchableSantriPicker.show(
                                  context,
                                  santriList: santriList,
                                  selectedSantriId: _selectedSantriId,
                                  title: 'Pilih Santri Penyetor',
                                );
                                if (picked != null && mounted) {
                                  setState(() => _selectedSantriId = picked);
                                }
                              },
                            ),

                            if (selectedSantri != null && selectedSantri.tunggakan > 0) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF450A1A).withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFFB7185).withOpacity(0.5),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('🚨', style: TextStyle(fontSize: 18)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Tunggakan Aktif: ${CurrencyFormatter.format(selectedSantri.tunggakan)}',
                                                style: const TextStyle(
                                                  color: Color(0xFFFECDD3),
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _potongTunggakan
                                                    ? 'Tunggakan dipotong otomatis. Sisa bersih masuk saldo jajan: ${CurrencyFormatter.format(netMasuk)}.'
                                                    : 'Setoran masuk tanpa memotong tunggakan.',
                                                style: const TextStyle(
                                                  color: Color(0xFFFDA4AF),
                                                  fontSize: 9.5,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'Potong tunggakan dari setoran ini',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Switch(
                                            value: _potongTunggakan,
                                            activeColor: const Color(0xFF34D399),
                                            onChanged: (val) {
                                              AppFeedback.tap();
                                              setState(() => _potongTunggakan = val);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // 3 Jenis Setoran: Awal Bulan | Top-Up Susulan | Sambangan
                            const Text(
                              'JENIS SETORAN',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildTipeChip(
                                  '📅 Awal Bulan',
                                  TipeSetoran.awalBulan,
                                  const Color(0xFF34D399),
                                  defaultNominal: 300000,
                                ),
                                const SizedBox(width: 6),
                                _buildTipeChip(
                                  '➕ Top-Up',
                                  TipeSetoran.susulanTopUp,
                                  const Color(0xFF38BDF8),
                                  defaultNominal: 150000,
                                ),
                                const SizedBox(width: 6),
                                _buildTipeChip(
                                  '🎁 Sambangan',
                                  TipeSetoran.sambanganSplit,
                                  const Color(0xFFFBBF24),
                                  defaultNominal: 500000,
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Sumber Dompet Masuk: Tunai vs Rekening
                            const Text(
                              'DOMPET TUJUAN MASUK',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildDompetChip('💵 Kas Laci Tunai', 'TUNAI', const Color(0xFF34D399)),
                                const SizedBox(width: 8),
                                _buildDompetChip('🏦 Rekening Bank', 'REKENING', const Color(0xFF38BDF8)),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Total Uang Diterima & Durasi (Hr)
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isSambangan
                                            ? 'TOTAL UANG DITERIMA DARI WALI'
                                            : 'NOMINAL SETORAN (RP)',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _nominalController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [RibuanInputFormatter()],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'monospace',
                                        ),
                                        decoration: const InputDecoration(
                                          prefixText: 'Rp ',
                                          isDense: true,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DURASI (HR)',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _durasiController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'monospace',
                                        ),
                                        decoration: const InputDecoration(isDense: true),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Pintasan Cepat Nominal
                            if (isSambangan)
                              Row(
                                children: [
                                  _buildQuickBtn('400rb', 400000, 30),
                                  const SizedBox(width: 6),
                                  _buildQuickBtn('500rb', 500000, 30),
                                  const SizedBox(width: 6),
                                  _buildQuickBtn('600rb', 600000, 30),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  _buildQuickBtn('150rb (5rb/hr)', 150000, 30),
                                  const SizedBox(width: 6),
                                  _buildQuickBtn('300rb (10rb/hr)', 300000, 30),
                                  const SizedBox(width: 6),
                                  _buildQuickBtn('450rb (15rb/hr)', 450000, 30),
                                ],
                              ),

                            if (isSambangan) ...[
                              const SizedBox(height: 14),
                              _buildSambanganSmartSplitPanel(
                                isDeficit: isDeficitSambangan,
                                statusInfakPratinjau: statusInfakPratinjau,
                                netMasuk: netMasuk,
                                jatahBulat: jatahBulat,
                              ),
                            ] else ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF04201A), Color(0xFF071426)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withOpacity(0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'HASIL HITUNG JATAH HARIAN',
                                            style: TextStyle(
                                              color: Color(0xFF34D399),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${CurrencyFormatter.format(jatahBulat)} / hari',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            selisihPembulatan > 0
                                                ? 'Pembulatan ke bawah kelipatan ${CurrencyFormatter.format(kelipatan)} • Sisa ${CurrencyFormatter.format(selisihPembulatan)} tetap utuh di saldo'
                                                : 'Dibulatkan kelipatan ${CurrencyFormatter.format(kelipatan)} agar praktis saat penarikan',
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 9.5,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('🧮', style: TextStyle(fontSize: 26)),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            const Text(
                              'CATATAN (OPSIONAL)',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _catatanController,
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: isSambangan
                                    ? 'Contoh: Sambangan Ibu / Titipan Awal Bulan'
                                    : 'Contoh: Transfer Wali Santri via BSI',
                                isDense: true,
                              ),
                            ),

                            const SizedBox(height: 18),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDeficitSambangan
                                      ? const Color(0xFFE11D48)
                                      : (isSambangan
                                          ? const Color(0xFFFBBF24)
                                          : const Color(0xFF10B981)),
                                  foregroundColor: isDeficitSambangan
                                      ? Colors.white
                                      : const Color(0xFF030712),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  elevation: 6,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: _simpan,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    isSambangan
                                        ? '💾 SIMPAN SAMBANGAN (INFAK + JAJAN)'
                                        : '💾 SIMPAN SETORAN & UPDATE JATAH',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF06B6D4)])
                : null,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF030712) : Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipeChip(
    String label,
    TipeSetoran tipe,
    Color accent, {
    required int defaultNominal,
  }) {
    final isSelected = _tipeSetoran == tipe;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          setState(() {
            _tipeSetoran = tipe;
            if (tipe == TipeSetoran.sambanganSplit && _nominal < 300000) {
              _nominalController.text =
                  CurrencyFormatter.formatWithoutSymbol(defaultNominal);
            }
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? accent.withOpacity(0.18) : const Color(0xFF070B14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? accent : Colors.white12),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? accent : Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSambanganSmartSplitPanel({
    required bool isDeficit,
    required String statusInfakPratinjau,
    required int netMasuk,
    required int jatahBulat,
  }) {
    final tglMasukStr = DateFormatter.toLocalDateString(_tglMasuk);
    final literStr = _sambanganBerasLiter == _sambanganBerasLiter.roundToDouble()
        ? _sambanganBerasLiter.toInt().toString()
        : _sambanganBerasLiter.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF070C17),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDeficit
              ? const Color(0xFFF43F5E)
              : const Color(0xFFFBBF24).withOpacity(0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'POS POTONGAN INFAK BULANAN',
            style: TextStyle(
              color: Color(0xFFFDE68A),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Tanggal Masuk & Habis
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickSambanganDate(isMasuk: true),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TGL MASUK', style: TextStyle(color: Colors.white54, fontSize: 9)),
                        Text(tglMasukStr, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickSambanganDate(isMasuk: false),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF34D399).withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TGL HABIS (+1 BLN)', style: TextStyle(color: Color(0xFF34D399), fontSize: 9)),
                        Text(_tglHabisYmd, style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 11.5, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Masak & Listrik
          _buildInfakToggleField(
            label: 'Infak Masak / Makan',
            checked: _isMasakChecked,
            bebas: _isMasakBebas,
            controller: _masakController,
            onToggleCheck: (v) => setState(() => _isMasakChecked = v),
            onToggleBebas: () => setState(() => _isMasakBebas = !_isMasakBebas),
          ),
          const SizedBox(height: 8),
          _buildInfakToggleField(
            label: 'Infak Listrik',
            checked: _isListrikChecked,
            bebas: _isListrikBebas,
            controller: _listrikController,
            onToggleCheck: (v) => setState(() => _isListrikChecked = v),
            onToggleBebas: () => setState(() => _isListrikBebas = !_isListrikBebas),
          ),
          const SizedBox(height: 10),

          // Beras 4 Mode
          const Text(
            'INFAK BERAS',
            style: TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _berasModeChip('💵 Bayar Uang', InfakSantriModel.berasUangVal, const Color(0xFFFBBF24)),
              _berasModeChip('🌾 Fisik (Liter)', InfakSantriModel.berasFisik, const Color(0xFF34D399)),
              _berasModeChip('⏳ Belum Setor', InfakSantriModel.berasBelum, const Color(0xFFF43F5E)),
              _berasModeChip('✓ Bebas Beras', InfakSantriModel.berasBebas, const Color(0xFF38BDF8)),
            ],
          ),
          if (_sambanganJenisBeras == InfakSantriModel.berasUangVal) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _berasUangController,
              keyboardType: TextInputType.number,
              inputFormatters: [RibuanInputFormatter()],
              style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              decoration: const InputDecoration(isDense: true, prefixText: 'Rp ', labelText: 'Nominal Uang Pengganti Beras'),
              onChanged: (_) => setState(() {}),
            ),
          ] else if (_sambanganJenisBeras == InfakSantriModel.berasFisik) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _berasLiterController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              decoration: const InputDecoration(isDense: true, suffixText: ' Liter', labelText: 'Jumlah Beras Fisik (Uang = Rp 0)'),
              onChanged: (_) => setState(() {}),
            ),
          ],

          const SizedBox(height: 12),

          // Preview Hasil Pembagian Real-Time
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDeficit
                    ? [const Color(0xFF4C0519), const Color(0xFF1F0A14)]
                    : [const Color(0xFF04201A), const Color(0xFF071426)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDeficit
                    ? const Color(0xFFF43F5E)
                    : const Color(0xFF34D399).withOpacity(0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PRATINJAU HASIL SMART SPLIT',
                      style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w900),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Status: $statusInfakPratinjau',
                        style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 9.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _splitRow(
                  'Masuk Kas Infak Pondok:',
                  '${CurrencyFormatter.format(_totalPotonganInfakUang)}${_sambanganBerasLiter > 0 ? ' + $literStr L' : ''}',
                  const Color(0xFFFDE68A),
                ),
                _splitRow(
                  'Sisa Masuk Saldo Jajan:',
                  CurrencyFormatter.format(netMasuk),
                  isDeficit ? const Color(0xFFFDA4AF) : const Color(0xFF34D399),
                  isBold: true,
                ),
                _splitRow(
                  'Jatah Harian Baru:',
                  '${CurrencyFormatter.format(jatahBulat)} / hari',
                  const Color(0xFF67E8F9),
                ),
                if (isDeficit) ...[
                  const SizedBox(height: 6),
                  const Text(
                    '⚠️ Total potongan infak melebihi uang diterima! Kurangi pos infak atau perbesar total uang diterima.',
                    style: TextStyle(color: Color(0xFFFECDD3), fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfakToggleField({
    required String label,
    required bool checked,
    required bool bebas,
    required TextEditingController controller,
    required ValueChanged<bool> onToggleCheck,
    required VoidCallback onToggleBebas,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            activeColor: const Color(0xFF10B981),
            visualDensity: VisualDensity.compact,
            onChanged: (v) {
              AppFeedback.tap();
              onToggleCheck(v ?? false);
            },
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                InkWell(
                  onTap: () {
                    AppFeedback.tap();
                    onToggleBebas();
                  },
                  child: Text(
                    bebas ? '✓ Bebas (Rp 0)' : 'Ketuk untuk Bebas ✓',
                    style: TextStyle(
                      color: bebas ? const Color(0xFF34D399) : Colors.white54,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 112,
            child: TextField(
              controller: controller,
              enabled: checked && !bebas,
              keyboardType: TextInputType.number,
              inputFormatters: [RibuanInputFormatter()],
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                isDense: true,
                prefixText: bebas ? null : 'Rp ',
                hintText: bebas ? 'Bebas' : '0',
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _berasModeChip(String label, String value, Color accent) {
    final selected = _sambanganJenisBeras == value;
    return InkWell(
      onTap: () {
        AppFeedback.tap();
        setState(() => _sambanganJenisBeras = value);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.18) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? accent : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : Colors.white60,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _splitRow(String label, String val, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(
            val,
            style: TextStyle(
              color: color,
              fontSize: isBold ? 13 : 11.5,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDompetChip(String label, String value, Color accent) {
    final isSelected = _sumberDompet == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          AppFeedback.tap();
          setState(() => _sumberDompet = value);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? accent.withOpacity(0.18) : const Color(0xFF070B14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? accent : Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? accent : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickBtn(String label, int nominal, int durasi) {
    return Expanded(
      child: InkWell(
        onTap: () => _setQuick(nominal, durasi),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF070B14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
