import 'dart:io';
import 'package:flutter/material.dart';
import '../../widgets/guided_spotlight_tour.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/santri_status.dart';
import '../../models/transaksi.dart';
import '../../providers/kas_santri_provider.dart';
import '../../services/report_service.dart';
import '../../utils/app_feedback.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/time_category_helper.dart';
import '../../widgets/app_background_wrapper.dart';
import '../../widgets/fast_withdrawal_bottom_sheet.dart';
import '../../widgets/quick_edit_santri_bottom_sheet.dart';
import '../../widgets/tunggakan_bottom_sheet.dart';
import '../paywall_screen.dart';
import '../setoran/setoran_screen.dart';
import '../tabungan/brankas_tabungan_screen.dart';

class SantriDetailScreen extends StatefulWidget {
  final String santriId;

  const SantriDetailScreen({Key? key, required this.santriId})
      : super(key: key);

  @override
  State<SantriDetailScreen> createState() => _SantriDetailScreenState();
}

class _SantriDetailScreenState extends State<SantriDetailScreen> {
  final ScreenSpotlightController _spotCtrl = ScreenSpotlightController();
  String _filterPeriode = 'SEMUA'; // 'SEMUA', 'HARI_INI', '7_HARI', 'BULAN_INI'
  List<TransaksiHarian> _mutasiList = [];
  bool _isLoadingMutasi = true;

  @override
  void initState() {
    super.initState();
    _loadMutasi();
  }

  Future<void> _loadMutasi() async {
    if (!mounted) return;
    setState(() => _isLoadingMutasi = true);
    final now = DateTime.now();
    String? start;
    String? end;

    if (_filterPeriode == 'HARI_INI') {
      start = DateFormatter.toLocalDateString(now);
      end = start;
    } else if (_filterPeriode == '7_HARI') {
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      start = DateFormatter.toLocalDateString(sevenDaysAgo);
      end = DateFormatter.toLocalDateString(now);
    } else if (_filterPeriode == 'BULAN_INI') {
      final firstDay = DateTime(now.year, now.month, 1);
      start = DateFormatter.toLocalDateString(firstDay);
      end = DateFormatter.toLocalDateString(now);
    }

    final list = await DatabaseHelper.instance.getBukuMutasiSantri(
      widget.santriId,
      tanggalMulai: start,
      tanggalSelesai: end,
    );

    if (mounted) {
      setState(() {
        _mutasiList = list;
        _isLoadingMutasi = false;
      });
    }
  }

  void _showTransactionDetail(TransaksiHarian tx, Santri santri) {
    AppFeedback.tap();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xF5072638), Color(0xF70A162B), Color(0xF713112B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(
              top: BorderSide(color: Color(0xFF38BDF8), width: 1.4),
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
                    Text(
                      tx.tipe == TipeTransaksi.setoran
                          ? 'Detail Setoran'
                          : 'Detail Pengambilan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (tx.isVoided)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4C0519),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFB7185)),
                        ),
                        child: const Text(
                          'VOID / DIBATALKAN',
                          style: TextStyle(
                            color: Color(0xFFFDA4AF),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 22),
                _buildDetailRow(
                  'Nominal',
                  CurrencyFormatter.format(tx.nominal),
                  isBold: true,
                  color: tx.tipe == TipeTransaksi.setoran
                      ? const Color(0xFF34D399)
                      : const Color(0xFFFB7185),
                ),
                _buildDetailRow(
                  'Waktu Transaksi',
                  '${DateFormatter.formatFullDateTime(tx.waktuAmbil)} WIB',
                ),
                _buildDetailRow(
                  'Kategori Waktu',
                  '${TimeCategoryHelper.getEmoji(tx.kategoriWaktu)} ${TimeCategoryHelper.getLabel(tx.kategoriWaktu)}',
                ),
                _buildDetailRow('Dompet', tx.sumberDompet),
                _buildDetailRow('Keterangan', tx.catatan ?? '-'),
                _buildDetailRow(
                  'Saldo Setelahnya',
                  CurrencyFormatter.format(tx.saldoSetelahTransaksi),
                ),
                if (tx.isOverlimit)
                  _buildDetailRow(
                    'Status Limit',
                    'Overlimit (${tx.overlimitHandling == OverlimitHandling.potongBesok ? "Potong Besok" : tx.overlimitHandling == OverlimitHandling.hitungUlangRataRata ? "Hitung Ulang Rata-Rata" : "Normal"})',
                    color: const Color(0xFFFBBF24),
                  ),
                const SizedBox(height: 18),
                if (!tx.isVoided)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Nominal'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF67E8F9),
                            side: const BorderSide(color: Color(0xFF38BDF8)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showEditDialog(tx);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Batalkan / Void'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE11D48),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmVoid(tx, santri);
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12.5),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                color: color ?? Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(TransaksiHarian tx) {
    final controller = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(tx.nominal),
    );
    final noteController = TextEditingController(text: tx.catatan ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1422),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
        ),
        title: const Text(
          'Koreksi Transaksi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [RibuanInputFormatter()],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                labelText: 'Nominal Baru (Rp)',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Catatan'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: const Color(0xFF030712),
            ),
            onPressed: () async {
              final parsed = CurrencyFormatter.parse(controller.text);
              final newNominal = parsed > 0 ? parsed : tx.nominal;
              final provider = Provider.of<KasSantriProvider>(
                context,
                listen: false,
              );
              await provider.editTransaksi(
                tx.id,
                newNominal,
                noteController.text,
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              await _loadMutasi();
            },
            child: const Text(
              'Simpan Koreksi',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmVoid(TransaksiHarian tx, Santri santri) {
    final isSetoran = tx.tipe == TipeTransaksi.setoran;
    final isSaldoSetoranTerpakai = isSetoran && santri.saldoTotal < tx.nominal;
    final estimasiTalangan =
        isSaldoSetoranTerpakai ? (tx.nominal - santri.saldoTotal) : 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1422),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFF43F5E), width: 1.2),
        ),
        title: Text(
          isSetoran ? 'Batalkan Setoran Ini?' : 'Batalkan Transaksi Ini?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          isSaldoSetoranTerpakai
              ? 'Setoran sebesar ${CurrencyFormatter.format(tx.nominal)} akan dibatalkan.\n\n'
                  '⚠️ Perhatian: Saldo ${santri.namaPanggilan} saat ini tinggal ${CurrencyFormatter.format(santri.saldoTotal)} karena sebagian uang setoran sudah terpakai jajan. Selisih yang sudah terpakai (hingga ${CurrencyFormatter.format(estimasiTalangan)}) akan otomatis tercatat sebagai Tunggakan / Talangan Kas Pondok agar Brankas & Multi-Dompet tetap 100% seimbang.'
              : 'Transaksi sebesar ${CurrencyFormatter.format(tx.nominal)} akan dibatalkan dan saldo santri serta mutasi dompet akan disesuaikan otomatis.',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final provider = Provider.of<KasSantriProvider>(
                context,
                listen: false,
              );
              await provider.voidTransaksi(tx.id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              await _loadMutasi();
            },
            child: const Text(
              'Ya, Batalkan Transaksi',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  void _showAdjustQuotaDialog(KasSantriProvider provider, Santri santri) {
    AppFeedback.tap();
    final ctrl = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(santri.jatahHarian),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1422),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF34D399), width: 1.2),
        ),
        title: const Text(
          'Sesuaikan Jatah Harian',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atur kuota jatah harian khusus untuk ${santri.namaLengkap}:',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [RibuanInputFormatter()],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
              decoration: const InputDecoration(
                labelText: 'Jatah Harian Baru (Rp)',
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: const Color(0xFF030712),
            ),
            onPressed: () async {
              final newJatah = CurrencyFormatter.parse(ctrl.text);
              if (newJatah <= 0) return;
              await provider.updateJatahKhusus(santri.id, newJatah);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text(
              'Simpan Kuota',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final santri = provider.allSantri.firstWhere(
      (s) => s.id == widget.santriId,
      orElse: () => Santri(
        id: '',
        namaLengkap: 'Tidak Ditemukan',
        namaPanggilan: '',
        kamar: '',
      ),
    );

    final status = provider.santriStatusList.firstWhere(
      (s) => s.santri.id == widget.santriId,
      orElse: () => SantriStatusHariIni(
        santri: santri,
        totalAmbilHariIni: 0,
        sisaJatahHariIni: santri.jatahHarian,
        jatahHariIni: santri.jatahHarian,
        transaksiHariIni: const [],
      ),
    );

    final hasFoto =
        santri.fotoPath != null && santri.fotoPath!.trim().isNotEmpty;

    return ScreenSpotlightHost(
      screenKey: 'tour_santri_detail',
      controller: _spotCtrl,
      steps: const [
        SpotlightStepSpec(
          emoji: '🪪',
          title: 'Profil, Saldo Jajan & Brankas Tabungan',
          description:
              'Menampilkan sisa saldo uang jajan harian, posisi 🏦 Brankas Tabungan Terpisah (yang tidak ikut terpotong jajan), jatah harian, dan status infak.',
          accent: Color(0xFF34D399),
        ),
        SpotlightStepSpec(
          emoji: '✏️',
          title: 'Ubah Data Santri, Jatah & Potong Besok',
          description:
              'Ketuk ikon pensil di kanan atas untuk mengedit data profil, foto, kamar, atau jatah harian santri. Aksi cepat Setor, Jajan, & Tabungan juga tersedia.',
          accent: Color(0xFF38BDF8),
        ),
        SpotlightStepSpec(
          emoji: '📜',
          title: 'Riwayat Mutasi Lengkap per Santri',
          description:
              'Gulir ke bawah untuk menelusuri seluruh histori pemasukan, pengambilan harian, dan catatan infak khusus santri ini.',
          accent: Color(0xFFFBBF24),
        ),
      ],
      child: AppBackgroundWrapper(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(
              santri.namaLengkap,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF67E8F9)),
                tooltip: 'Edit Data & Foto Santri',
                onPressed: santri.id.isEmpty
                    ? null
                    : () async {
                        AppFeedback.tap();
                        await QuickEditSantriBottomSheet.show(context, santri);
                        await _loadMutasi();
                      },
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFFB7185),
                ),
                tooltip: 'Arsipkan / Hapus Santri',
                onPressed: santri.id.isEmpty
                    ? null
                    : () {
                        AppFeedback.tap();
                        _confirmDelete(context, santri);
                      },
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
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
          child: RefreshIndicator(
            color: const Color(0xFF34D399),
            backgroundColor: const Color(0xFF0E1422),
            onRefresh: () async {
              await provider.loadAllData();
              await _loadMutasi();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
              children: [
                // Kartu Profil & Ringkasan Saldo (Dark Translucent Aurora Glassmorphism)
                GlassCard(
                  borderRadius: 26,
                  padding: const EdgeInsets.all(18),
                  borderColor: const Color(0xFF34D399).withValues(alpha: 0.45),
                  gradientColors: const [
                    Color(0xD608352D),
                    Color(0xDC0B182C),
                    Color(0xD8141530),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF34D399),
                                width: 1.8,
                              ),
                              color: const Color(0xFF062028),
                            ),
                            child: ClipOval(
                              child: hasFoto
                                  ? Image(
                                      image: ResizeImage(
                                        FileImage(File(santri.fotoPath!)),
                                        width: 180,
                                      ),
                                      width: 54,
                                      height: 54,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(
                                          santri.namaPanggilan.isNotEmpty
                                              ? santri.namaPanggilan[0]
                                                  .toUpperCase()
                                              : 'S',
                                          style: const TextStyle(
                                            color: Color(0xFF34D399),
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        santri.namaPanggilan.isNotEmpty
                                            ? santri.namaPanggilan[0]
                                                .toUpperCase()
                                            : 'S',
                                        style: const TextStyle(
                                          color: Color(0xFF34D399),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  santri.namaLengkap,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${santri.kamar} • Panggilan: ${santri.namaPanggilan} • ${santri.statusSantriLabel}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                  ),
                                ),
                                if (santri.noWaWali != null &&
                                    santri.noWaWali!.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'WA Wali: ${santri.noWaWali}',
                                      style: const TextStyle(
                                        color: Color(0xFF67E8F9),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SISA SALDO TOTAL',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.format(santri.saldoTotal),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF34D399),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF064E3B)
                                  .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF34D399)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Estimasi Bertahan',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFA7F3D0),
                                  ),
                                ),
                                Text(
                                  '±${santri.estimasiHari} Hari',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF060B14)
                              .withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Jatah: ${CurrencyFormatter.format(santri.jatahHarian)} / hari',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Sisa Hari Ini: ${CurrencyFormatter.format(status.sisaJatahHariIni)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF67E8F9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: status.progressRatio,
                                minHeight: 7,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF34D399),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              status.ringkasanAmbilHariIni,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (santri.tunggakan > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4C0519)
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFB7185)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('🚨', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tunggakan: ${CurrencyFormatter.format(santri.tunggakan)}',
                                      style: const TextStyle(
                                        color: Color(0xFFFDA4AF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (santri.catatanTunggakan.isNotEmpty)
                                      Text(
                                        santri.catatanTunggakan,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF062C2B).withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF2DD4BF).withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('🏦', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Brankas Tabungan Terpisah',
                                    style: TextStyle(
                                      color: Color(0xFF99F6E4),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(santri.saldoTabungan),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: santri.id.isEmpty
                                  ? null
                                  : () async {
                                      AppFeedback.tap();
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BrankasTabunganScreen(
                                            initialSantriId: santri.id,
                                          ),
                                        ),
                                      );
                                      await _loadMutasi();
                                    },
                              child: const Text(
                                'Kelola →',
                                style: TextStyle(
                                  color: Color(0xFF5EEAD4),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Baris Tombol Aksi Cepat
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.flash_on_rounded, size: 16),
                        label: const Text(
                          'Ambil Cepat',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: const Color(0xFF030712),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          AppFeedback.tap();
                          await FastWithdrawalBottomSheet.show(context, status);
                          await _loadMutasi();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.input_rounded, size: 16),
                        label: const Text(
                          '+ Setoran',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF67E8F9),
                          side: const BorderSide(color: Color(0xFF38BDF8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          AppFeedback.tap();
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                backgroundColor: Colors.transparent,
                                appBar: AppBar(
                                  title: Text(
                                    'Input Setoran — ${santri.namaPanggilan}',
                                  ),
                                ),
                                body: AppBackgroundWrapper(
                                  child: SetoranScreen(
                                    preselectedSantriId: santri.id,
                                  ),
                                ),
                              ),
                            ),
                          );
                          await _loadMutasi();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        AppFeedback.tap();
                        await TunggakanBottomSheet.show(context, santri);
                        await _loadMutasi();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: santri.tunggakan > 0
                              ? const Color(0xFF4C0519)
                              : const Color(0xFF0E1422),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: santri.tunggakan > 0
                                ? const Color(0xFFFB7185)
                                : Colors.white24,
                          ),
                        ),
                        child: const Text('🚨', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text(
                          'Sesuaikan Kuota',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () =>
                            _showAdjustQuotaDialog(provider, santri),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.send_to_mobile_rounded,
                          size: 16,
                        ),
                        label: Text(
                          provider.hasProAccess ? 'Kirim WA' : 'Kirim WA 👑',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6EE7B7),
                          side: const BorderSide(color: Color(0xFF34D399)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          AppFeedback.tap();
                          if (!provider.hasProAccess) {
                            PaywallScreen.show(
                              context,
                              triggerFeature:
                                  'Kirim Laporan WhatsApp 1-Klik & Tanpa Watermark',
                            );
                            return;
                          }
                          ReportService.instance.sendWhatsAppReport(
                            santri: santri,
                            mutasiList: _mutasiList,
                            pengaturan: provider.pengaturan,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        AppFeedback.tap();
                        if (!provider.hasProAccess) {
                          PaywallScreen.show(
                            context,
                            triggerFeature: 'Cetak Dokumen PDF Mutasi Santri',
                          );
                          return;
                        }
                        ReportService.instance.generateAndPrintPdf(
                          santri: santri,
                          mutasiList: _mutasiList,
                          pengaturan: provider.pengaturan,
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1B4B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: provider.hasProAccess
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFFFBBF24),
                          ),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Color(0xFF67E8F9),
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Header Buku Mutasi Digital & Filter Tanggal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Buku Mutasi Digital',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1422),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButton<String>(
                        value: _filterPeriode,
                        dropdownColor: const Color(0xFF0E1422),
                        underline: const SizedBox(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF67E8F9),
                          fontWeight: FontWeight.w800,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'SEMUA',
                            child: Text('Semua Riwayat'),
                          ),
                          DropdownMenuItem(
                            value: 'HARI_INI',
                            child: Text('Hari Ini'),
                          ),
                          DropdownMenuItem(
                            value: '7_HARI',
                            child: Text('7 Hari Terakhir'),
                          ),
                          DropdownMenuItem(
                            value: 'BULAN_INI',
                            child: Text('Bulan Ini'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _filterPeriode = val);
                            _loadMutasi();
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // List Mutasi
                if (_isLoadingMutasi)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        color: Color(0xFF34D399),
                      ),
                    ),
                  )
                else if (_mutasiList.isEmpty)
                  GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(24),
                    child: const Center(
                      child: Text(
                        'Belum ada transaksi pada periode ini.',
                        style: TextStyle(color: Colors.white60, fontSize: 12.5),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _mutasiList.length,
                    itemBuilder: (ctx, idx) {
                      final tx = _mutasiList[idx];
                      final isSetoran = tx.tipe == TipeTransaksi.setoran;

                      return RepaintBoundary(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1424)
                                .withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: tx.isVoided
                                  ? Colors.white12
                                  : isSetoran
                                      ? const Color(0xFF34D399)
                                          .withValues(alpha: 0.35)
                                      : const Color(0xFFFB7185)
                                          .withValues(alpha: 0.30),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tx.isVoided
                                    ? Colors.white10
                                    : isSetoran
                                        ? const Color(0xFF064E3B)
                                        : const Color(0xFF4C0519),
                              ),
                              child: Icon(
                                tx.isVoided
                                    ? Icons.cancel_outlined
                                    : isSetoran
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                color: tx.isVoided
                                    ? Colors.white38
                                    : isSetoran
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFFFB7185),
                                size: 18,
                              ),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isSetoran ? 'Setoran Uang' : 'Ambil Uang',
                                  style: TextStyle(
                                    color: tx.isVoided
                                        ? Colors.white38
                                        : Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    decoration: tx.isVoided
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                Text(
                                  '${isSetoran ? '+' : '-'}${CurrencyFormatter.format(tx.nominal)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    color: tx.isVoided
                                        ? Colors.white38
                                        : isSetoran
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFFFB7185),
                                    decoration: tx.isVoided
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  '${DateFormatter.formatFullDateTime(tx.waktuAmbil)} • ${TimeCategoryHelper.getLabel(tx.kategoriWaktu)}'
                                  '${tx.catatan != null && tx.catatan!.isNotEmpty ? ' (${tx.catatan})' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white60,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sisa Saldo: ${CurrencyFormatter.format(tx.saldoSetelahTransaksi)} • Dompet: ${tx.sumberDompet}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF67E8F9),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _showTransactionDetail(tx, santri),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  void _confirmDelete(BuildContext context, Santri santri) {
    bool confirmedCheck = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFF43F5E), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4C0519),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🗑️', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hapus ${santri.namaLengkap}?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tindakan ini akan menghapus santri ${santri.namaLengkap} (${santri.kamar}) secara permanen beserta seluruh riwayat mutasinya.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                if (santri.saldoTotal > 0 || santri.tunggakan > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF451A03).withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.65),
                      ),
                    ),
                    child: Text(
                      santri.saldoTotal > 0
                          ? '⚠️ Santri ini masih memiliki saldo titipan sebesar ${CurrencyFormatter.format(santri.saldoTotal)}.\n'
                              'Jika dihapus permanen, saldo tersebut dianggap dikembalikan tunai kepada santri/wali dan otomatis dicatat KELUAR pada Kas Laci Tunai (mutasi_dompet) serta Jejak Audit.'
                          : '⚠️ Santri ini masih memiliki catatan tunggakan sebesar ${CurrencyFormatter.format(santri.tunggakan)}. Sebaiknya arsipkan sebagai Boyong/Lulus agar riwayat tetap tersimpan.',
                      style: const TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 11,
                        height: 1.38,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6EE7B7),
                      side: const BorderSide(color: Color(0xFF34D399)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final provider = Provider.of<KasSantriProvider>(
                        context,
                        listen: false,
                      );
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                      AppFeedback.tap();
                      await provider.tutupBukuArsipSantri(
                        [santri.id],
                        statusTujuan: Santri.statusAlumniVal,
                      );
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            '${santri.namaLengkap} diarsipkan sebagai Boyong/Lulus.',
                          ),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    },
                    icon: const Icon(Icons.archive_outlined, size: 16),
                    label: const Text(
                      '📦 Arsipkan sebagai Boyong / Lulus (Aman)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () {
                    AppFeedback.tap();
                    setDialogState(() => confirmedCheck = !confirmedCheck);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4C0519).withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: confirmedCheck
                            ? const Color(0xFFFB7185)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: confirmedCheck,
                          activeColor: const Color(0xFFE11D48),
                          onChanged: (v) {
                            AppFeedback.tap();
                            setDialogState(() => confirmedCheck = v ?? false);
                          },
                        ),
                        Expanded(
                          child: Text(
                            santri.saldoTotal > 0
                                ? 'Saya paham saldo ${CurrencyFormatter.format(santri.saldoTotal)} dianggap dikembalikan & ingin menghapus permanen.'
                                : 'Saya paham & yakin ingin menghapus data santri ini permanen.',
                            style: const TextStyle(
                              color: Color(0xFFFECDD3),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                AppFeedback.tap();
                Navigator.pop(ctx);
              },
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    confirmedCheck ? const Color(0xFFE11D48) : Colors.white12,
                foregroundColor:
                    confirmedCheck ? Colors.white : Colors.white38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: !confirmedCheck
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final provider = Provider.of<KasSantriProvider>(
                        context,
                        listen: false,
                      );
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                      AppFeedback.tap();
                      await provider.deleteSantri(santri.id);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Santri ${santri.namaLengkap} berhasil dihapus dari daftar.',
                          ),
                          backgroundColor: const Color(0xFFE11D48),
                        ),
                      );
                    },
              child: const Text(
                'Ya, Hapus Permanen',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
