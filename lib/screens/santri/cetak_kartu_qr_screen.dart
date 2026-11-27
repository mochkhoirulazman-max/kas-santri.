import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/santri.dart';
import '../../providers/kas_santri_provider.dart';
import '../../services/qr_card_pdf_service.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/app_background_wrapper.dart';
import '../../widgets/guided_spotlight_tour.dart';
import '../paywall_screen.dart';

enum _QrPrintScope { semua, perKamar, pilihan }

class CetakKartuQrScreen extends StatefulWidget {
  const CetakKartuQrScreen({Key? key}) : super(key: key);

  @override
  State<CetakKartuQrScreen> createState() => _CetakKartuQrScreenState();
}

class _CetakKartuQrScreenState extends State<CetakKartuQrScreen> {
  final ScreenSpotlightController _spotCtrl = ScreenSpotlightController();
  _QrPrintScope _scope = _QrPrintScope.semua;
  String? _selectedKamar;
  final Set<String> _manualIds = {};
  String _search = '';
  bool _isGenerating = false;

  List<Santri> _resolveSelected(KasSantriProvider provider) {
    final active = provider.santriStatusList.map((s) => s.santri).toList();
    switch (_scope) {
      case _QrPrintScope.semua:
        return active;
      case _QrPrintScope.perKamar:
        final k = _selectedKamar ?? (provider.kamars.isNotEmpty ? provider.kamars.first : null);
        if (k == null) return [];
        return active.where((s) => s.kamar == k).toList();
      case _QrPrintScope.pilihan:
        return active.where((s) => _manualIds.contains(s.id)).toList();
    }
  }

  Future<void> _previewAndPrint(KasSantriProvider provider) async {
    AppFeedback.tap();
    if (!provider.isProUser) {
      await PaywallScreen.show(
        context,
        triggerFeature: 'Cetak Massal Kartu Santri QR Siap Laminating (PDF A4)',
      );
      return;
    }

    final targets = _resolveSelected(provider);
    if (targets.isEmpty) {
      AppFeedback.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 santri untuk dicetak.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final bytes = await QrCardPdfService.instance.buildBulkQrCardsPdfBytes(
        pengaturan: provider.pengaturan,
        santriList: targets,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Kartu_Santri_QR_${provider.pengaturan.namaPondok}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat PDF Kartu QR: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _sharePdf(KasSantriProvider provider) async {
    AppFeedback.tap();
    if (!provider.isProUser) {
      await PaywallScreen.show(
        context,
        triggerFeature: 'Cetak Massal Kartu Santri QR Siap Laminating (PDF A4)',
      );
      return;
    }

    final targets = _resolveSelected(provider);
    if (targets.isEmpty) return;

    setState(() => _isGenerating = true);
    try {
      final bytes = await QrCardPdfService.instance.buildBulkQrCardsPdfBytes(
        pengaturan: provider.pengaturan,
        santriList: targets,
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(
          dir.path,
          'kartu_qr_santri_${DateTime.now().millisecondsSinceEpoch}.pdf',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      AppFeedback.success();
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Kartu QR Santri Siap Cetak A4 (${targets.length} Santri)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan PDF: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    if (!provider.hasProAccess) {
      return AppBackgroundWrapper(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('Cetak Kartu QR Massal (A4)')),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassCard(
                  borderRadius: 26,
                  padding: const EdgeInsets.all(24),
                  borderColor: const Color(0xFFFBBF24).withValues(alpha: 0.55),
                  gradientColors: const [
                    Color(0xDE06382E),
                    Color(0xE00A1628),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🪪', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFBBF24)),
                        ),
                        child: const Text(
                          '🔒 FITUR KHUSUS PRO',
                          style: TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Cetak Kartu QR Santri Massal (A4)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Susun otomatis 8 Kartu ID QR Santri per halaman A4 lengkap dengan garis potong siap laminating untuk Scan Antrean 1 Detik.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => PaywallScreen.show(
                            context,
                            triggerFeature:
                                'Cetak Massal Kartu Santri QR Siap Laminating (PDF A4)',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBBF24),
                            foregroundColor: const Color(0xFF030712),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                          label: const Text(
                            'Coba Gratis 14 Hari / Upgrade PRO',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final activeSantri = provider.santriStatusList.map((s) => s.santri).toList();
    final kamars = provider.kamars;
    final selected = _resolveSelected(provider);
    final pagesEstimate = selected.isEmpty ? 0 : (selected.length / 8).ceil();

    final manualFiltered = activeSantri.where((s) {
      if (_search.trim().isEmpty) return true;
      final q = _search.trim().toLowerCase();
      return s.namaLengkap.toLowerCase().contains(q) ||
          s.kamar.toLowerCase().contains(q);
    }).toList();

    return ScreenSpotlightHost(
      screenKey: 'tour_cetak_qr',
      controller: _spotCtrl,
      steps: const [
        SpotlightStepSpec(
          emoji: '🪪',
          title: 'Pilih Cakupan Santri yang Dicetak',
          description:
              'Anda dapat mencetak QR Card untuk Semua Santri Aktif, Per Kamar tertentu, atau memilih santri secara manual.',
          accent: Color(0xFF34D399),
        ),
        SpotlightStepSpec(
          emoji: '🖨️',
          title: 'PDF A4 Siap Laminating (8 Kartu/Halaman)',
          description:
              'Aplikasi menyusun kartu ID QR dengan logo pondok & garis potong otomatis. Gunakan hasil cetakan untuk Scan QR Antrean 1 Detik di Beranda.',
          accent: Color(0xFF38BDF8),
        ),
      ],
      child: AppBackgroundWrapper(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Cetak Kartu QR Massal (A4)'),
            actions: [
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              GlassCard(
                borderRadius: 22,
                padding: const EdgeInsets.all(16),
                borderColor: const Color(0xFF34D399).withOpacity(0.45),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'TATA LETAK ID CARD A4 (8 KARTU / HALAMAN)',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        if (!provider.isProUser)
                          const Text('👑 PRO', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Mencetak QR unik santri beserta logo pondok, kamar, kategori & garis potong siap laminating untuk Scan Antrean 1 Detik.',
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text('Semua Aktif (${activeSantri.length})'),
                          selected: _scope == _QrPrintScope.semua,
                          onSelected: (_) =>
                              setState(() => _scope = _QrPrintScope.semua),
                        ),
                        ChoiceChip(
                          label: const Text('Per Kamar'),
                          selected: _scope == _QrPrintScope.perKamar,
                          onSelected: (_) => setState(() {
                            _scope = _QrPrintScope.perKamar;
                            _selectedKamar ??=
                                kamars.isNotEmpty ? kamars.first : null;
                          }),
                        ),
                        ChoiceChip(
                          label: Text('Pilih Manual (${_manualIds.length})'),
                          selected: _scope == _QrPrintScope.pilihan,
                          onSelected: (_) =>
                              setState(() => _scope = _QrPrintScope.pilihan),
                        ),
                      ],
                    ),
                    if (_scope == _QrPrintScope.perKamar && kamars.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: kamars.contains(_selectedKamar)
                            ? _selectedKamar
                            : kamars.first,
                        dropdownColor: const Color(0xFF090E1A),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Pilih Kamar / Kelas',
                          isDense: true,
                        ),
                        items: kamars
                            .map(
                              (k) => DropdownMenuItem(value: k, child: Text(k)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedKamar = v),
                      ),
                    ],
                  ],
                ),
              ),
              if (_scope == _QrPrintScope.pilihan) ...[
                const SizedBox(height: 12),
                GlassCard(
                  borderRadius: 22,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      TextField(
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Cari nama santri atau kamar...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _manualIds.addAll(activeSantri.map((s) => s.id));
                              });
                            },
                            child: const Text('Pilih Semua'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _manualIds.clear()),
                            child: const Text('Kosongkan'),
                          ),
                        ],
                      ),
                      ...manualFiltered.map((s) {
                        final checked = _manualIds.contains(s.id);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: checked,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _manualIds.add(s.id);
                              } else {
                                _manualIds.remove(s.id);
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
                            '${s.kamar} • ${s.qrCode}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10.5,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              GlassCard(
                borderRadius: 22,
                padding: const EdgeInsets.all(16),
                borderColor: const Color(0xFFFBBF24).withOpacity(0.45),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kartu Terpilih:',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5),
                        ),
                        Text(
                          '${selected.length} Santri ($pagesEstimate Halaman A4)',
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isGenerating
                                ? null
                                : () => _sharePdf(provider),
                            icon: const Icon(Icons.share_outlined, size: 17),
                            label: const Text('Bagikan PDF'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isGenerating
                                ? null
                                : () => _previewAndPrint(provider),
                            icon: const Icon(Icons.print_rounded, size: 17),
                            label: Text(
                              _isGenerating
                                  ? 'Membuat...'
                                  : (provider.isProUser
                                      ? 'Cetak PDF A4'
                                      : 'Cetak PDF 👑'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
