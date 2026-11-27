import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/kas_santri_provider.dart';
import '../../services/bulk_santri_excel_service.dart';
import '../../utils/app_feedback.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_background_wrapper.dart';
import '../../widgets/guided_spotlight_tour.dart';
import '../paywall_screen.dart';

class ImportSantriExcelScreen extends StatefulWidget {
  const ImportSantriExcelScreen({Key? key}) : super(key: key);

  @override
  State<ImportSantriExcelScreen> createState() =>
      _ImportSantriExcelScreenState();
}

class _ImportSantriExcelScreenState extends State<ImportSantriExcelScreen> {
  final ScreenSpotlightController _spotCtrl = ScreenSpotlightController();
  String _sumberDompet = 'TUNAI';
  bool _isBusy = false;
  BulkExcelParseResult? _parseResult;
  String? _pickedFileName;

  Future<void> _downloadTemplate(KasSantriProvider provider) async {
    AppFeedback.tap();
    setState(() => _isBusy = true);
    try {
      final bytes = await BulkSantriExcelService.instance
          .buildTemplateExcelBytesAsync(
        namaPondok: provider.pengaturan.namaPondok,
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(dir.path, 'template_import_santri_kas_santri.xlsx'),
      );
      await file.writeAsBytes(bytes, flush: true);
      AppFeedback.success();
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Template Import Santri Massal Kas-Santri (.xlsx)',
      );
    } catch (e) {
      AppFeedback.alert();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat template Excel: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _pickAndParseExcel(KasSantriProvider provider) async {
    AppFeedback.tap();
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (res == null || res.files.single.path == null) return;
      if (mounted) setState(() => _isBusy = true);
      final file = File(res.files.single.path!);
      final bytes = await file.readAsBytes();
      final parsed = await BulkSantriExcelService.instance
          .parseAndValidateExcelBytesAsync(
        bytes: bytes,
        existingSantri: provider.allSantri,
        isProUser: provider.isProUser,
      );
      if (!mounted) return;
      setState(() {
        _pickedFileName = p.basename(file.path);
        _parseResult = parsed;
      });
    } catch (e) {
      AppFeedback.alert();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membaca file Excel: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _executeImport(KasSantriProvider provider) async {
    final parsed = _parseResult;
    if (parsed == null || parsed.validRows.isEmpty) return;

    if (parsed.exceedsFreeQuota) {
      AppFeedback.alert();
      await PaywallScreen.show(
        context,
        triggerFeature:
            'Import Massal ${parsed.validRows.length} Santri (Mode Gratis maksimal ${KasSantriProvider.maxFreeSantriQuota} santri aktif)',
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      final count = await provider.importSantriMassal(
        parsed.santriList,
        sumberDompet: _sumberDompet,
      );
      if (mounted) {
        AppFeedback.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alhamdulillah! $count santri berhasil diimpor.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, count);
      }
    } catch (e) {
      AppFeedback.alert();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal impor santri: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    if (!provider.hasProAccess) {
      return AppBackgroundWrapper(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('Import Santri Massal (.xlsx) 🔒')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(22),
                borderColor: const Color(0xFFFBBF24).withValues(alpha: 0.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📥 👑', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 10),
                    const Text(
                      'Import Massal Excel 100–500 Santri (PRO)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Impor ratusan data santri sekaligus dari file .xlsx tersedia pada Kas-Santri PRO atau Uji Coba Gratis 14 Hari.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => PaywallScreen.show(
                        context,
                        triggerFeature: 'Import Santri Massal dari Excel (.xlsx)',
                      ),
                      icon: const Text('👑'),
                      label: const Text('Buka Kas-Santri PRO / Trial 14 Hari'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final parsed = _parseResult;

    return ScreenSpotlightHost(
      screenKey: 'tour_import_excel',
      controller: _spotCtrl,
      steps: const [
        SpotlightStepSpec(
          emoji: '📑',
          title: 'Unduh & Isi Template Excel (.xlsx)',
          description:
              'Unduh dulu template resmi agar nama kolom sesuai sistem. Cocok untuk memasukkan 100–500 santri baru sekaligus tanpa mengetik satu per satu.',
          accent: Color(0xFF34D399),
        ),
        SpotlightStepSpec(
          emoji: '🔍',
          title: 'Pratinjau Validasi Sebelum Impor',
          description:
              'Unggah file .xlsx lalu periksa jumlah baris valid, deteksi duplikat, dan tentukan dompet sumber saldo awal (Tunai / Rekening) sebelum konfirmasi.',
          accent: Color(0xFF38BDF8),
        ),
      ],
      child: AppBackgroundWrapper(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Import Santri Massal (.xlsx)'),
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
                    const Text(
                      'LANGKAH 1 — SIAPKAN TEMPLATE EXCEL',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Cocok untuk pesantren dengan 100–500+ santri agar tidak perlu input satu per satu.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isBusy ? null : () => _downloadTemplate(provider),
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: const Text(
                          'Download Template Excel (.xlsx)',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6EE7B7),
                          side: BorderSide(
                            color: const Color(0xFF34D399).withOpacity(0.55),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                borderRadius: 22,
                padding: const EdgeInsets.all(16),
                borderColor: const Color(0xFF38BDF8).withOpacity(0.45),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LANGKAH 2 — PILIH DOMPET & UNGGAH FILE',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Saldo Awal: Tunai Laci'),
                            selected: _sumberDompet == 'TUNAI',
                            onSelected: (_) =>
                                setState(() => _sumberDompet = 'TUNAI'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Saldo Awal: Rekening'),
                            selected: _sumberDompet == 'REKENING',
                            onSelected: (_) =>
                                setState(() => _sumberDompet = 'REKENING'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isBusy
                            ? null
                            : () => _pickAndParseExcel(provider),
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: Text(
                          _pickedFileName != null
                              ? 'Ganti File ($_pickedFileName)'
                              : 'Pilih File Excel (.xlsx) & Pratinjau',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (parsed != null) ...[
                const SizedBox(height: 12),
                GlassCard(
                  borderRadius: 22,
                  padding: const EdgeInsets.all(16),
                  borderColor: parsed.exceedsFreeQuota
                      ? const Color(0xFFFBBF24).withOpacity(0.65)
                      : const Color(0xFF34D399).withOpacity(0.45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HASIL VALIDASI PRATINJAU',
                        style: TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _statPill(
                            'Siap Impor',
                            '${parsed.validRows.length}',
                            const Color(0xFF34D399),
                          ),
                          const SizedBox(width: 8),
                          _statPill(
                            'Duplikat',
                            '${parsed.duplicateNames.length}',
                            const Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 8),
                          _statPill(
                            'Dilewati',
                            '${parsed.invalidRows.length}',
                            const Color(0xFFF43F5E),
                          ),
                        ],
                      ),
                      if (parsed.exceedsFreeQuota) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.16),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFBBF24).withOpacity(0.55),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('👑', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Mode Gratis tersisa ${parsed.remainingFreeSlots} slot santri, sedangkan file berisi ${parsed.validRows.length} santri valid. Upgrade ke PRO untuk impor tanpa batas!',
                                  style: const TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontSize: 11.5,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (parsed.duplicateNames.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Duplikat otomatis dilewati:\n• ${parsed.duplicateNames.take(5).join('\n• ')}',
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (parsed.invalidRows.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Baris tidak valid:\n• ${parsed.invalidRows.take(5).join('\n• ')}',
                          style: const TextStyle(
                            color: Color(0xFFFDA4AF),
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (parsed.validRows.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Pratinjau Data Santri Valid:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...parsed.validRows.take(15).map((item) {
                          final s = item.santri;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.namaLengkap,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        '${s.kamar} • ${s.kategoriLabel}',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(s.saldoTotal),
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (parsed.validRows.length > 15)
                          Text(
                            '... dan ${parsed.validRows.length - 15} santri lainnya.',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isBusy
                                ? null
                                : () => _executeImport(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: parsed.exceedsFreeQuota
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF10B981),
                              foregroundColor: const Color(0xFF04121A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: Icon(
                              parsed.exceedsFreeQuota
                                  ? Icons.workspace_premium_rounded
                                  : Icons.check_circle_rounded,
                            ),
                            label: Text(
                              parsed.exceedsFreeQuota
                                  ? 'Buka PRO untuk Impor ${parsed.validRows.length} Santri 👑'
                                  : 'Impor ${parsed.validRows.length} Santri Sekarang',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _statPill(String label, String val, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                color: accent,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
