import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/santri.dart';
import '../../models/santri_status.dart';
import '../../models/transaksi.dart';
import '../../providers/kas_santri_provider.dart';
import '../../database/database_helper.dart';
import '../../services/report_service.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/time_category_helper.dart';
import '../../widgets/fast_withdrawal_bottom_sheet.dart';
import 'emergency_override_dialog.dart';
import 'santri_form_screen.dart';
import '../setoran/setoran_form_screen.dart';

class SantriDetailScreen extends StatefulWidget {
  final String santriId;

  const SantriDetailScreen({Key? key, required this.santriId}) : super(key: key);

  @override
  State<SantriDetailScreen> createState() => _SantriDetailScreenState();
}

class _SantriDetailScreenState extends State<SantriDetailScreen> {
  String _filterPeriode = 'SEMUA'; // 'SEMUA', 'HARI_INI', '7_HARI', 'BULAN_INI'
  List<TransaksiHarian> _mutasiList = [];
  bool _isLoadingMutasi = true;

  @override
  void initState() {
    super.initState();
    _loadMutasi();
  }

  Future<void> _loadMutasi() async {
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

  void _showTransactionDetail(TransaksiHarian tx) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tx.tipe == TipeTransaksi.setoran ? 'Detail Setoran' : 'Detail Pengambilan',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (tx.isVoided)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('DIBATALKAN', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                ],
              ),
              const Divider(height: 20),
              _buildDetailRow('Nominal', CurrencyFormatter.format(tx.nominal), isBold: true),
              _buildDetailRow('Waktu Transaksi', '${DateFormatter.formatFullDateTime(tx.waktuAmbil)} WIB'),
              _buildDetailRow('Kategori Waktu', '${TimeCategoryHelper.getEmoji(tx.kategoriWaktu)} ${TimeCategoryHelper.getLabel(tx.kategoriWaktu)}'),
              _buildDetailRow('Keterangan', tx.catatan ?? '-'),
              _buildDetailRow('Saldo Setelahnya', CurrencyFormatter.format(tx.saldoSetelahTransaksi)),
              if (tx.isOverlimit)
                _buildDetailRow('Status Limit', 'Overlimit (${tx.overlimitHandling ?? "Normal"})', color: Colors.red),
              const SizedBox(height: 20),

              if (!tx.isVoided)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Nominal'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showEditDialog(tx);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.cancel, size: 16),
                        label: const Text('Batalkan / Void'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmVoid(tx);
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(TransaksiHarian tx) {
    final controller = TextEditingController(text: tx.nominal.toString());
    final noteController = TextEditingController(text: tx.catatan ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Koreksi Transaksi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nominal Baru (Rp)', prefixText: 'Rp '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Catatan'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final newNominal = int.tryParse(controller.text) ?? tx.nominal;
              final provider = Provider.of<KasSantriProvider>(context, listen: false);
              await provider.editTransaksi(tx.id, newNominal, noteController.text);
              Navigator.pop(ctx);
              await _loadMutasi();
            },
            child: const Text('Simpan Koreksi'),
          ),
        ],
      ),
    );
  }

  void _confirmVoid(TransaksiHarian tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Transaksi Ini?'),
        content: Text(
          'Transaksi sebesar ${CurrencyFormatter.format(tx.nominal)} akan dibatalkan dan saldo santri akan dikembalikan otomatis.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final provider = Provider.of<KasSantriProvider>(context, listen: false);
              await provider.voidTransaksi(tx.id);
              Navigator.pop(ctx);
              await _loadMutasi();
            },
            child: const Text('Ya, Batalkan Transaksi'),
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
      orElse: () => Santri(id: '', namaLengkap: 'Tidak Ditemukan', namaPanggilan: '', kamar: ''),
    );

    final status = provider.santriStatusList.firstWhere(
      (s) => s.santri.id == widget.santriId,
      orElse: () => SantriStatusHariIni(
        santri: santri,
        totalAmbilHariIni: 0,
        sisaJatahHariIni: santri.jatahHarian,
        jatahHariIni: santri.jatahHarian,
        transaksiHariIni: [],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(santri.namaLengkap),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Data Santri',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SantriFormScreen(santriToEdit: santri),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadAllData();
          await _loadMutasi();
        },
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Card Saldo & Profil Santri
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF00796B),
                          foregroundColor: Colors.white,
                          child: Text(
                            santri.namaPanggilan.isNotEmpty
                                ? santri.namaPanggilan[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                santri.namaLengkap,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text('${santri.kamar} • Panggilan: ${santri.namaPanggilan}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              if (santri.noWaWali != null)
                                Text('WA Wali: ${santri.noWaWali}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Sisa Saldo Total & Estimasi Hari
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sisa Saldo Total', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              CurrencyFormatter.format(santri.saldoTotal),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF004D40),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Estimasi Bertahan', style: TextStyle(fontSize: 10, color: Colors.teal)),
                              Text(
                                '±${santri.estimasiHari} Hari',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Jatah Harian & Status Hari Ini
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Jatah: ${CurrencyFormatter.format(santri.jatahHarian)} / hari',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'Sisa Hari Ini: ${CurrencyFormatter.format(status.sisaJatahHariIni)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: status.progressRatio,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00796B)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            status.ringkasanAmbilHariIni,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Baris Tombol Aksi Cepat
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.flash_on, size: 16),
                    label: const Text('Ambil Cepat'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
                    onPressed: () {
                      FastWithdrawalBottomSheet.show(context, status);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.input_rounded, size: 16),
                    label: const Text('+ Setoran'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SetoranFormScreen(preselectedSantriId: santri.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Sesuaikan Kuota'),
                    onPressed: () {
                      EmergencyOverrideDialog.show(
                        context,
                        santri: santri,
                        onQuotaChanged: (newQuota) {
                          provider.updateJatahKhusus(santri.id, newQuota);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.send_to_mobile, size: 16),
                    label: const Text('Kirim WA'),
                    onPressed: () {
                      ReportService.instance.sendWhatsAppReport(
                        santri: santri,
                        mutasiList: _mutasiList,
                        pengaturan: provider.pengaturan,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF00796B)),
                  tooltip: 'Cetak Dokumen PDF',
                  onPressed: () {
                    ReportService.instance.generateAndPrintPdf(
                      santri: santri,
                      mutasiList: _mutasiList,
                      pengaturan: provider.pengaturan,
                    );
                  },
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                ),
                DropdownButton<String>(
                  value: _filterPeriode,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(value: 'SEMUA', child: Text('Semua Riwayat')),
                    DropdownMenuItem(value: 'HARI_INI', child: Text('Hari Ini')),
                    DropdownMenuItem(value: '7_HARI', child: Text('7 Hari Terakhir')),
                    DropdownMenuItem(value: 'BULAN_INI', child: Text('Bulan Ini')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _filterPeriode = val);
                      _loadMutasi();
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 6),

            // List Mutasi
            if (_isLoadingMutasi)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_mutasiList.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const Text('Belum ada transaksi pada periode ini.', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _mutasiList.length,
                separatorBuilder: (ctx, idx) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final tx = _mutasiList[idx];
                  final isSetoran = tx.tipe == TipeTransaksi.setoran;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    leading: CircleAvatar(
                      backgroundColor: tx.isVoided
                          ? Colors.grey.shade200
                          : isSetoran
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                      foregroundColor: tx.isVoided
                          ? Colors.grey
                          : isSetoran
                              ? Colors.green
                              : Colors.red,
                      child: Icon(
                        tx.isVoided
                            ? Icons.cancel
                            : isSetoran
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                        size: 18,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isSetoran ? 'Setoran Uang' : 'Ambil Uang',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            decoration: tx.isVoided ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        Text(
                          '${isSetoran ? '+' : '-'}${CurrencyFormatter.format(tx.nominal)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: tx.isVoided
                                ? Colors.grey
                                : isSetoran
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                            decoration: tx.isVoided ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormatter.formatFullDateTime(tx.waktuAmbil)} • ${TimeCategoryHelper.getLabel(tx.kategoriWaktu)}'
                          '${tx.catatan != null ? ' (${tx.catatan})' : ''}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        Text(
                          'Sisa Saldo: ${CurrencyFormatter.format(tx.saldoSetelahTransaksi)}',
                          style: const TextStyle(fontSize: 11, color: Colors.teal),
                        ),
                      ],
                    ),
                    onTap: () => _showTransactionDetail(tx),
                  );
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
