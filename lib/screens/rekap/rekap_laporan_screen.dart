import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/kas_santri_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';

class RekapLaporanScreen extends StatefulWidget {
  const RekapLaporanScreen({Key? key}) : super(key: key);

  @override
  State<RekapLaporanScreen> createState() => _RekapLaporanScreenState();
}

class _RekapLaporanScreenState extends State<RekapLaporanScreen> {
  int _tabIndex = 0; // 0: Rekap Harian, 1: Rekap Bulanan
  DateTime _selectedDate = DateTime.now();

  // Rekap Harian State
  int _totalKeluarHarian = 0;
  int _jumlahTransaksiHarian = 0;
  Map<String, int> _kategoriHarian = {};
  List<Map<String, dynamic>> _transaksiHarianList = [];

  // Rekap Bulanan State
  int _selectedBulan = DateTime.now().month;
  int _selectedTahun = DateTime.now().year;
  Map<String, int> _rekapBulanan = {'pemasukan': 0, 'pengeluaran': 0, 'net': 0};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dateStr = DateFormatter.toLocalDateString(_selectedDate);

    // Load Rekap Harian
    _totalKeluarHarian = await DatabaseHelper.instance.getTotalPengeluaranHariIni(dateStr);
    _jumlahTransaksiHarian = await DatabaseHelper.instance.getJumlahTransaksiHariIni(dateStr);
    _kategoriHarian = await DatabaseHelper.instance.getRekapKategoriHariIni(dateStr);
    _transaksiHarianList = await DatabaseHelper.instance.getDetailTransaksiTanggal(dateStr);

    // Load Rekap Bulanan
    _rekapBulanan = await DatabaseHelper.instance.getRekapBulanan(_selectedTahun, _selectedBulan);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadAllData();
          await _loadData();
        },
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Segmented Header
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.today),
                  label: Text('Rekap Harian (Audit)'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.calendar_month),
                  label: Text('Rekap Bulanan'),
                ),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (set) {
                setState(() => _tabIndex = set.first);
                _loadData();
              },
            ),

            const SizedBox(height: 14),

            if (_tabIndex == 0) _buildRekapHarianView(provider) else _buildRekapBulananView(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildRekapHarianView(KasSantriProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pemilih Tanggal
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: const Icon(Icons.calendar_today, color: Color(0xFF00796B)),
            title: const Text('Tanggal Audit Fisik', style: TextStyle(fontSize: 12, color: Colors.grey)),
            subtitle: Text(
              DateFormatter.formatDisplayDate(_selectedDate),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            trailing: const Icon(Icons.edit_calendar, size: 20, color: Color(0xFF00796B)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadData();
              }
            },
          ),
        ),

        const SizedBox(height: 12),

        // Kartu Ringkasan Pengeluaran Hari Terpilih
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Uang Keluar Hari Ini', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_jumlahTransaksiHarian Transaksi',
                      style: TextStyle(color: Colors.red.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                CurrencyFormatter.format(_totalKeluarHarian),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD32F2F),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cocokkan jumlah fisik uang tunai di dompet/laci malam ini dengan total pengeluaran ini.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Rekap per Kategori Pengeluaran
        if (_kategoriHarian.isNotEmpty) ...[
          const Text(
            'Rincian Pengeluaran per Kategori:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004D40)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kategoriHarian.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.format(entry.value),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF004D40),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Daftar Transaksi pada Tanggal Terpilih
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mutasi Transaksi Hari Ini:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004D40)),
            ),
            Text(
              '${_transaksiHarianList.length} baris',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (_transaksiHarianList.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('Tidak ada transaksi pada tanggal ini', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transaksiHarianList.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final row = _transaksiHarianList[idx];
                final waktuStr = row['waktu_ambil'] as String;
                final waktu = DateTime.tryParse(waktuStr) ?? DateTime.now();
                final nominal = (row['nominal'] as num).toInt();
                final isVoided = (row['is_voided'] as int?) == 1;
                final isOverlimit = (row['is_overlimit'] as int?) == 1;
                final kat = row['kategori_waktu'] as String? ?? 'PAGI';

                return ListTile(
                  dense: true,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${row['nama_lengkap']} (${row['kamar']})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          decoration: isVoided ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        '-${CurrencyFormatter.format(nominal)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isVoided ? Colors.grey : Colors.red.shade700,
                          fontSize: 13,
                          decoration: isVoided ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${DateFormatter.formatTimeWithWIB(waktu)} • $kat • Catatan: ${row['catatan'] ?? "Jajan"}'
                    '${isOverlimit ? " ⚠️ OVERLIMIT" : ""}',
                    style: TextStyle(fontSize: 11, color: isOverlimit ? Colors.orange.shade800 : Colors.grey.shade600),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildRekapBulananView(KasSantriProvider provider) {
    final pemasukan = _rekapBulanan['pemasukan'] ?? 0;
    final pengeluaran = _rekapBulanan['pengeluaran'] ?? 0;
    final net = _rekapBulanan['net'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bulan & Tahun Selector
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pilih Periode Bulan:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                DropdownButton<int>(
                  value: _selectedBulan,
                  underline: const SizedBox(),
                  items: List.generate(12, (index) {
                    final monthNum = index + 1;
                    final dummyDate = DateTime(2026, monthNum, 1);
                    return DropdownMenuItem(
                      value: monthNum,
                      child: Text(DateFormatter.formatMonthYear(dummyDate)),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedBulan = val);
                      _loadData();
                    }
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Grid 3 Kartu Keuangan Bulanan
        Row(
          children: [
            Expanded(
              child: _buildMonthStatCard(
                title: 'Total Pemasukan',
                amount: pemasukan,
                icon: Icons.arrow_downward,
                color: const Color(0xFF2E7D32),
                bgColor: Colors.green.shade50,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMonthStatCard(
                title: 'Total Pengeluaran',
                amount: pengeluaran,
                icon: Icons.arrow_upward,
                color: const Color(0xFFD32F2F),
                bgColor: Colors.red.shade50,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        _buildMonthStatCard(
          title: 'Net Arus Kas (Pemasukan - Pengeluaran)',
          amount: net,
          icon: Icons.account_balance,
          color: net >= 0 ? const Color(0xFF00796B) : Colors.red.shade800,
          bgColor: net >= 0 ? Colors.teal.shade50 : Colors.red.shade50,
        ),

        const SizedBox(height: 16),

        // Export Laporan Bulanan
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Laporan Santri & Wali',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Kirim laporan mutasi bulanan santri langsung ke WhatsApp orang tua dengan format rapi dan profesional atau cetak dokumen PDF resmi.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  icon: const Icon(Icons.people),
                  label: const Text('Pilih Santri untuk Kirim Laporan'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
                  onPressed: () {
                    // Pindah ke tab Santri
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Buka profil santri di menu "Santri" untuk mengirim laporan WhatsApp atau Cetak PDF'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildMonthStatCard({
    required String title,
    required int amount,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
