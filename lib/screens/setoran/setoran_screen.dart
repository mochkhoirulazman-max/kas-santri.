import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/kas_santri_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import 'setoran_form_screen.dart';

class SetoranScreen extends StatefulWidget {
  const SetoranScreen({Key? key}) : super(key: key);

  @override
  State<SetoranScreen> createState() => _SetoranScreenState();
}

class _SetoranScreenState extends State<SetoranScreen> {
  List<Map<String, dynamic>> _setoranList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSetoran();
  }

  Future<void> _loadSetoran() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;
    final results = await db.rawQuery('''
      SELECT s.*, st.nama_lengkap, st.nama_panggilan, st.kamar
      FROM setoran_bulanan s
      JOIN santri st ON s.santri_id = st.id
      ORDER BY s.tanggal_setor DESC
    ''');

    if (mounted) {
      setState(() {
        _setoranList = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadAllData();
          await _loadSetoran();
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _setoranList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.input_rounded, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'Belum ada catatan setoran uang masuk',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Catat Setoran Pertama'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SetoranFormScreen()),
                            );
                            _loadSetoran();
                          },
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                    itemCount: _setoranList.length,
                    itemBuilder: (ctx, idx) {
                      final item = _setoranList[idx];
                      final nominal = (item['nominal_setoran'] as num).toInt();
                      final durasi = (item['durasi_hari'] as num).toInt();
                      final jatah = (item['jatah_harian_hitung'] as num).toInt();
                      final isAwal = item['tipe_setoran'] == 'AWAL_BULAN';
                      final tanggalStr = item['tanggal_setor'] as String;
                      final tgl = DateTime.tryParse(tanggalStr) ?? DateTime.now();

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isAwal ? Colors.teal.shade50 : Colors.amber.shade50,
                                    foregroundColor: isAwal ? const Color(0xFF00796B) : Colors.amber.shade900,
                                    child: Icon(isAwal ? Icons.calendar_month : Icons.add_card, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['nama_lengkap'] as String,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Text(
                                          '${item['kamar']} • ${DateFormatter.formatDisplayDate(tgl)}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isAwal ? Colors.teal.shade50 : Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isAwal ? 'Awal Bulan' : 'Top-Up',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isAwal ? const Color(0xFF00796B) : Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Nominal Masuk', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text(
                                        '+${CurrencyFormatter.format(nominal)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Durasi: $durasi Hari', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text(
                                        'Jatah: ${CurrencyFormatter.format(jatah)}/hr',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF004D40),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (item['catatan'] != null && (item['catatan'] as String).isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Catatan: ${item['catatan']}',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Catat Setoran'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SetoranFormScreen()),
          );
          _loadSetoran();
        },
      ),
    );
  }
}
