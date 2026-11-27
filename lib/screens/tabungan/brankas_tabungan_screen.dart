import 'package:flutter/material.dart';
import '../../widgets/guided_spotlight_tour.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/santri.dart';
import '../../models/transaksi_tabungan.dart';
import '../../providers/kas_santri_provider.dart';
import '../../services/report_service.dart';
import '../../utils/app_feedback.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/app_background_wrapper.dart';
import '../../widgets/searchable_santri_picker.dart';
import '../paywall_screen.dart';

enum _TabunganActionMode { setor, tarik, transfer }

class BrankasTabunganScreen extends StatefulWidget {
  final String? initialSantriId;

  const BrankasTabunganScreen({Key? key, this.initialSantriId})
      : super(key: key);

  @override
  State<BrankasTabunganScreen> createState() => _BrankasTabunganScreenState();
}

class _BrankasTabunganScreenState extends State<BrankasTabunganScreen> {
  final ScreenSpotlightController _spotCtrl = ScreenSpotlightController();
  int _activeTab = 0; // 0 = Saldo Per Santri, 1 = Mutasi Tabungan
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialSantriId != null && widget.initialSantriId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final provider = Provider.of<KasSantriProvider>(context, listen: false);
        final match = provider.allSantri
            .where((s) => s.id == widget.initialSantriId)
            .firstOrNull;
        if (match != null) {
          _showSantriTabunganOptions(match);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSantriTabunganOptions(Santri santri) {
    AppFeedback.tap();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xF5072536), Color(0xF70A1428)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: const Color(0xFF2DD4BF).withValues(alpha: 0.45),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                santri.namaLengkap,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${santri.kamar} • Tabungan: ${CurrencyFormatter.format(santri.saldoTabungan)} • Jajan: ${CurrencyFormatter.format(santri.saldoTotal)}',
                style: const TextStyle(color: Color(0xFF99F6E4), fontSize: 11.5),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openActionModal(
                          _TabunganActionMode.setor,
                          preselectedSantriId: santri.id,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: const Color(0xFF030712),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 17),
                      label: const Text(
                        'Setor',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openActionModal(
                          _TabunganActionMode.tarik,
                          preselectedSantriId: santri.id,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFDA4AF),
                        side: const BorderSide(color: Color(0xFFFB7185)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.payments_outlined, size: 17),
                      label: const Text(
                        'Tarik',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openActionModal(
                          _TabunganActionMode.transfer,
                          preselectedSantriId: santri.id,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF67E8F9),
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text(
                        'Pindah Jajan ↔ Tabungan',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _kirimInfoTabunganWa(santri);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF34D399)),
                      ),
                      child: const Text('💬 WA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF6EE7B7))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _kirimInfoTabunganWa(Santri santri) async {
    AppFeedback.tap();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final namaPondok = provider.pengaturan.namaPondok;
    final msg = StringBuffer()
      ..writeln('*Assalamu’alaikum Warahmatullahi Wabarakatuh* 🌸\n')
      ..writeln('Yth. Wali Santri dari ananda *${santri.namaLengkap}* (${santri.kamar}),')
      ..writeln('Berikut informasi saldo *Brankas Tabungan Terpisah* per ${DateFormatter.formatFullDateTime(DateTime.now())}:')
      ..writeln('• 🏦 Saldo Tabungan Tersimpan: *${CurrencyFormatter.format(santri.saldoTabungan)}*')
      ..writeln('• 💵 Saldo Uang Jajan Aktif: *${CurrencyFormatter.format(santri.saldoTotal)}*\n')
      ..writeln('_Tabungan terpisah aman & tidak terpotong oleh pengambilan jajan harian._')
      ..writeln('\nHormat kami,\n*Bendahara $namaPondok*');

    if (!provider.hasProAccess) {
      await Clipboard.setData(ClipboardData(text: msg.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Info tabungan disalin ke clipboard (Kirim WA 1-klik khusus PRO).',
          ),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      return;
    }

    final ok = await ReportService.instance.openWhatsAppDirect(
      rawPhone: santri.noWaWali,
      message: msg.toString(),
    );
    if (!ok && mounted) {
      await Clipboard.setData(ClipboardData(text: msg.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nomor WA wali belum diisi / WA tidak terpasang. Teks info telah disalin.',
          ),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
    }
  }

  Future<void> _openActionModal(
    _TabunganActionMode mode, {
    String? preselectedSantriId,
  }) async {
    AppFeedback.tap();
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final activeSantri =
        provider.allSantri.where((s) => s.statusAktif).toList();
    if (activeSantri.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada data santri aktif.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    String selectedSantriId =
        preselectedSantriId ?? activeSantri.first.id;
    bool jajanKeTabungan = true; // khusus mode.transfer
    String sumberDompet = 'TUNAI';
    final nominalCtrl = TextEditingController();
    final catatanCtrl = TextEditingController();
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setModalState) {
          final isPro = provider.hasProAccess;
          final currentSantri = activeSantri.firstWhere(
            (s) => s.id == selectedSantriId,
            orElse: () => activeSantri.first,
          );
          final bottomPad = MediaQuery.of(sheetCtx).viewInsets.bottom +
              MediaQuery.of(sheetCtx).padding.bottom;

          final String modalTitle;
          final Color accent;
          switch (mode) {
            case _TabunganActionMode.setor:
              modalTitle = 'Setor ke Brankas Tabungan';
              accent = const Color(0xFF34D399);
              break;
            case _TabunganActionMode.tarik:
              modalTitle = 'Tarik dari Brankas Tabungan';
              accent = const Color(0xFFFB7185);
              break;
            case _TabunganActionMode.transfer:
              modalTitle = 'Pindah Saldo Jajan ↔ Tabungan';
              accent = const Color(0xFF38BDF8);
              break;
          }

          return Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomPad),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xF5072536), Color(0xF80A1428)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: accent.withValues(alpha: 0.50)),
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
                  Text(
                    modalTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pemilih Santri dengan SearchableSantriPicker
                  SearchableSantriField(
                    selectedSantri: currentSantri,
                    placeholder: 'Pilih santri...',
                    onTap: () async {
                      final pickedId = await SearchableSantriPicker.show(
                        sheetCtx,
                        santriList: activeSantri,
                        selectedSantriId: selectedSantriId,
                        title: 'Pilih Santri Penabung',
                      );
                      if (pickedId != null && sheetCtx.mounted) {
                        setModalState(() => selectedSantriId = pickedId);
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // Ringkasan saldo santri terpilih
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF060B14).withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tabungan: ${CurrencyFormatter.format(currentSantri.saldoTabungan)}',
                          style: const TextStyle(
                            color: Color(0xFF6EE7B7),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Jajan: ${CurrencyFormatter.format(currentSantri.saldoTotal)}',
                          style: const TextStyle(
                            color: Color(0xFF67E8F9),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (mode == _TabunganActionMode.transfer) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text(
                              'Jajan → Tabungan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            selected: jajanKeTabungan,
                            selectedColor: const Color(0xFF065F46),
                            onSelected: (_) =>
                                setModalState(() => jajanKeTabungan = true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text(
                              'Tabungan → Jajan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            selected: !jajanKeTabungan,
                            selectedColor: const Color(0xFF0E7490),
                            onSelected: (_) =>
                                setModalState(() => jajanKeTabungan = false),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextField(
                    controller: nominalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [RibuanInputFormatter()],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Nominal (Rp)',
                      prefixText: 'Rp ',
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Chip nominal cepat
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [10000, 20000, 50000, 100000].map((val) {
                      return ActionChip(
                        backgroundColor: const Color(0xFF0A1628),
                        side: BorderSide(color: accent.withValues(alpha: 0.4)),
                        label: Text(
                          '+${CurrencyFormatter.formatWithoutSymbol(val)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: () {
                          AppFeedback.tap();
                          final cur = CurrencyFormatter.parse(nominalCtrl.text);
                          nominalCtrl.text =
                              CurrencyFormatter.formatWithoutSymbol(cur + val);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Sumber / Kantong Dompet',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('💵 Kas Laci Tunai'),
                          selected: sumberDompet == 'TUNAI',
                          selectedColor: const Color(0xFF065F46),
                          onSelected: (_) =>
                              setModalState(() => sumberDompet = 'TUNAI'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(
                            isPro
                                ? '🏦 Rekening Bank'
                                : '🏦 Rekening Bank 👑',
                          ),
                          selected: sumberDompet == 'REKENING',
                          selectedColor: const Color(0xFF1E3A8A),
                          onSelected: (_) {
                            if (!isPro) {
                              PaywallScreen.show(
                                sheetCtx,
                                triggerFeature:
                                    'Multi-Dompet Rekening Bank di Brankas Tabungan',
                              );
                              return;
                            }
                            setModalState(() => sumberDompet = 'REKENING');
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  TextField(
                    controller: catatanCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Catatan (mis. Tabungan Lebaran / Kitab)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: const Color(0xFF030712),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        isSaving ? 'Menyimpan...' : 'Simpan Transaksi Tabungan',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final nominal =
                                  CurrencyFormatter.parse(nominalCtrl.text);
                              if (nominal <= 0) {
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Masukkan nominal lebih dari Rp 0.',
                                    ),
                                    backgroundColor: Color(0xFFF59E0B),
                                  ),
                                );
                                return;
                              }
                              setModalState(() => isSaving = true);
                              try {
                                final note = catatanCtrl.text.trim();
                                switch (mode) {
                                  case _TabunganActionMode.setor:
                                    await provider.setorTabungan(
                                      santriId: selectedSantriId,
                                      nominal: nominal,
                                      sumberDompet: sumberDompet,
                                      catatan: note.isEmpty ? null : note,
                                    );
                                    break;
                                  case _TabunganActionMode.tarik:
                                    await provider.tarikTabungan(
                                      santriId: selectedSantriId,
                                      nominal: nominal,
                                      sumberDompet: sumberDompet,
                                      catatan: note.isEmpty ? null : note,
                                    );
                                    break;
                                  case _TabunganActionMode.transfer:
                                    if (jajanKeTabungan) {
                                      await provider.transferJajanKeTabungan(
                                        santriId: selectedSantriId,
                                        nominal: nominal,
                                        sumberDompet: sumberDompet,
                                        catatan: note.isEmpty ? null : note,
                                      );
                                    } else {
                                      await provider.transferTabunganKeJajan(
                                        santriId: selectedSantriId,
                                        nominal: nominal,
                                        sumberDompet: sumberDompet,
                                        catatan: note.isEmpty ? null : note,
                                      );
                                    }
                                    break;
                                }
                                AppFeedback.success();
                                if (sheetCtx.mounted) {
                                  Navigator.pop(sheetCtx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Transaksi Brankas Tabungan berhasil disimpan!',
                                      ),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } catch (e) {
                                AppFeedback.alert();
                                if (sheetCtx.mounted) {
                                  setModalState(() => isSaving = false);
                                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceFirst(
                                              'Exception: ',
                                              '',
                                            ),
                                      ),
                                      backgroundColor: const Color(0xFFE11D48),
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    nominalCtrl.dispose();
    catatanCtrl.dispose();
  }

  Future<void> _confirmVoidTx(
    KasSantriProvider provider,
    TransaksiTabungan tx,
  ) async {
    AppFeedback.tap();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1422),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF43F5E)),
        ),
        title: const Text(
          'Batalkan Mutasi Tabungan?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'Mutasi "${tx.tipeLabel}" sebesar ${CurrencyFormatter.format(tx.nominal)} untuk ${tx.namaSantri ?? tx.santriId} akan dibatalkan dan saldo terkait dikembalikan otomatis.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tutup', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    try {
      await provider.voidTransaksiTabungan(tx.id);
      AppFeedback.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mutasi tabungan berhasil dibatalkan.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      AppFeedback.alert();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final isPro = provider.hasProAccess;
    final hideBalance = provider.pengaturan.hideBalance;

    final q = _searchQuery.trim().toLowerCase();
    final santriList = provider.allSantri.where((s) {
      if (!s.statusAktif) return false;
      if (q.isEmpty) return true;
      return s.namaLengkap.toLowerCase().contains(q) ||
          s.namaPanggilan.toLowerCase().contains(q) ||
          s.kamar.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        final cmp = b.saldoTabungan.compareTo(a.saldoTabungan);
        if (cmp != 0) return cmp;
        return a.namaLengkap.compareTo(b.namaLengkap);
      });

    final txList = provider.transaksiTabunganList.where((t) {
      if (q.isEmpty) return true;
      return (t.namaSantri ?? '').toLowerCase().contains(q) ||
          (t.kamarSantri ?? '').toLowerCase().contains(q) ||
          (t.catatan ?? '').toLowerCase().contains(q);
    }).toList();

    return ScreenSpotlightHost(
      screenKey: 'tour_tabungan',
      controller: _spotCtrl,
      steps: const [
        SpotlightStepSpec(
          emoji: '🏦',
          title: 'Brankas Tabungan Terpisah (Anti-Tercampur)',
          description:
              'Dana tabungan darurat, pulang/lebaran, atau kitab terpisah 100% dari saldo uang jajan harian sehingga tidak pernah ikut terpotong jajan anak.',
          accent: Color(0xFF34D399),
        ),
        SpotlightStepSpec(
          emoji: '💰',
          title: 'Setor, Tarik & Pindah Buku Instan',
          description:
              'Catat setor/tarik tabungan (Tunai atau Bank), atau transfer sisa uang jajan ke Brankas Tabungan (maupun sebaliknya) dalam satu ketukan.',
          accent: Color(0xFF38BDF8),
        ),
        SpotlightStepSpec(
          emoji: '📜',
          title: 'Saldo Per Santri & Jejak Mutasi Khusus',
          description:
              'Gunakan tab Saldo Santri untuk daftar penabung aktif dan tab Mutasi Tabungan untuk mengecek/membatalkan (Void) mutasi tabungan dengan aman.',
          accent: Color(0xFFFBBF24),
        ),
      ],
      child: AppBackgroundWrapper(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: const Color(0xCC060F1E),
            title: const Text(
              '🏦 Brankas Tabungan Terpisah',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            actions: [
              IconButton(
                tooltip: hideBalance ? 'Tampilkan Saldo' : 'Sembunyikan Saldo',
                icon: Icon(
                  hideBalance
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                ),
                onPressed: () {
                  AppFeedback.tap();
                  provider.toggleHideBalance();
                },
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: SpotlightHelpButton(
                    onTap: _spotCtrl.startTour,
                    size: 32,
                    accent: const Color(0xFF34D399),
                  ),
                ),
              ),
            ],
          ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    // Hero Card Kantong 4
                    GlassCard(
                      borderRadius: 24,
                      padding: const EdgeInsets.all(16),
                      borderColor:
                          const Color(0xFF2DD4BF).withValues(alpha: 0.48),
                      gradientColors: const [
                        Color(0xD6083635),
                        Color(0xDC0B182C),
                        Color(0xD8111834),
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'KANTONG KAS KE-4 • TERPISAH DARI JAJAN',
                                style: TextStyle(
                                  color: Color(0xFF5EEAD4),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${provider.countPenabungAktif} Penabung Aktif',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              hideBalance
                                  ? 'Rp ••••••••'
                                  : CurrencyFormatter.format(
                                      provider.totalBrankasTabungan,
                                    ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF060B14)
                                        .withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '💵 Tunai di Laci',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                      Text(
                                        hideBalance
                                            ? '••••••'
                                            : CurrencyFormatter.format(
                                                provider.tabunganTunai,
                                              ),
                                        style: const TextStyle(
                                          color: Color(0xFF6EE7B7),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: isPro
                                      ? null
                                      : () => PaywallScreen.show(
                                            context,
                                            triggerFeature:
                                                'Rincian Rekening Bank Brankas Tabungan',
                                          ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF060B14)
                                          .withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isPro
                                            ? Colors.white12
                                            : const Color(0xFFFBBF24)
                                                .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isPro
                                              ? '🏦 Rekening Bank'
                                              : '🏦 Rekening Bank 👑',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 9.5,
                                          ),
                                        ),
                                        Text(
                                          !isPro
                                              ? 'Terkunci PRO'
                                              : (hideBalance
                                                  ? '••••••'
                                                  : CurrencyFormatter.format(
                                                      provider.tabunganRekening,
                                                    )),
                                          style: TextStyle(
                                            color: isPro
                                                ? const Color(0xFF67E8F9)
                                                : const Color(0xFFFDE68A),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 3 Tombol Aksi Utama
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _openActionModal(_TabunganActionMode.setor),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: const Color(0xFF030712),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '+ Setor',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _openActionModal(_TabunganActionMode.tarik),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFDA4AF),
                              side: const BorderSide(color: Color(0xFFFB7185)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '💸 Tarik',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: () =>
                                _openActionModal(_TabunganActionMode.transfer),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF67E8F9),
                              side: const BorderSide(color: Color(0xFF38BDF8)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '⇄ Pindah Jajan ↔ Tabungan',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Pencarian + Sub-Tab Switcher
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari santri, kamar, atau catatan tabungan...',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF5EEAD4),
                          size: 19,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor:
                            const Color(0xFF0A1424).withValues(alpha: 0.78),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: _subTabPill(
                            label: '👥 Saldo Per Santri (${santriList.length})',
                            selected: _activeTab == 0,
                            onTap: () => setState(() => _activeTab = 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _subTabPill(
                            label: '📜 Mutasi Tabungan (${txList.length})',
                            selected: _activeTab == 1,
                            onTap: () => setState(() => _activeTab = 1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _activeTab == 0
                    ? _buildSantriSaldoList(santriList, hideBalance)
                    : _buildMutasiList(provider, txList),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _subTabPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        AppFeedback.tap();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0F766E).withValues(alpha: 0.72)
              : const Color(0xFF0A1424).withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF2DD4BF) : Colors.white12,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildSantriSaldoList(List<Santri> list, bool hideBalance) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada data santri yang cocok.',
          style: TextStyle(color: Colors.white60, fontSize: 12.5),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final s = list[idx];
        return RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1424).withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: s.saldoTabungan > 0
                    ? const Color(0xFF2DD4BF).withValues(alpha: 0.42)
                    : Colors.white12,
              ),
            ),
            child: ListTile(
              onTap: () => _showSantriTabunganOptions(s),
              leading: CircleAvatar(
                backgroundColor: s.saldoTabungan > 0
                    ? const Color(0xFF064E3B)
                    : Colors.white10,
                child: Text(
                  s.namaPanggilan.isNotEmpty
                      ? s.namaPanggilan[0].toUpperCase()
                      : 'S',
                  style: TextStyle(
                    color: s.saldoTabungan > 0
                        ? const Color(0xFF5EEAD4)
                        : Colors.white54,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              title: Text(
                s.namaLengkap,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                '${s.kamar} • Jajan: ${hideBalance ? '••••' : CurrencyFormatter.format(s.saldoTotal)}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hideBalance
                        ? '••••••'
                        : CurrencyFormatter.format(s.saldoTabungan),
                    style: TextStyle(
                      color: s.saldoTabungan > 0
                          ? const Color(0xFF5EEAD4)
                          : Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Tabungan',
                    style: TextStyle(color: Colors.white38, fontSize: 9.5),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMutasiList(
    KasSantriProvider provider,
    List<TransaksiTabungan> list,
  ) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada riwayat mutasi tabungan.',
          style: TextStyle(color: Colors.white60, fontSize: 12.5),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final tx = list[idx];
        final isMasuk = tx.isMasuk;
        final santri = provider.allSantri
            .where((s) => s.id == tx.santriId)
            .firstOrNull;
        final color = tx.isVoided
            ? Colors.white38
            : (isMasuk ? const Color(0xFF34D399) : const Color(0xFFFB7185));

        return RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1424).withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: tx.isVoided
                    ? Colors.white12
                    : color.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${tx.namaSantri ?? tx.santriId} • ${tx.tipeLabel}',
                        style: TextStyle(
                          color: tx.isVoided ? Colors.white38 : Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          decoration: tx.isVoided
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    Text(
                      '${isMasuk ? '+' : '-'}${CurrencyFormatter.format(tx.nominal)}',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        decoration: tx.isVoided
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormatter.formatFullDateTime(tx.createdAt)} • ${tx.sumberDompet} • Saldo Tabungan: ${CurrencyFormatter.format(tx.saldoTabunganSetelah)}'
                  '${tx.catatan != null && tx.catatan!.isNotEmpty ? ' • ${tx.catatan}' : ''}',
                  style: const TextStyle(color: Colors.white60, fontSize: 10.8),
                ),
                if (!tx.isVoided) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (santri != null)
                        TextButton.icon(
                          onPressed: () => _kirimInfoTabunganWa(santri),
                          icon: const Icon(
                            Icons.send_to_mobile_rounded,
                            size: 14,
                            color: Color(0xFF6EE7B7),
                          ),
                          label: Text(
                            provider.hasProAccess ? 'Info WA' : 'Info WA 👑',
                            style: const TextStyle(
                              color: Color(0xFF6EE7B7),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: () => _confirmVoidTx(provider, tx),
                        icon: const Icon(
                          Icons.cancel_outlined,
                          size: 14,
                          color: Color(0xFFFB7185),
                        ),
                        label: const Text(
                          'Void / Batal',
                          style: TextStyle(
                            color: Color(0xFFFB7185),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
