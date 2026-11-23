import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/kas_santri_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';

class RiwayatTransaksiScreen extends StatefulWidget {
  const RiwayatTransaksiScreen({Key? key}) : super(key: key);

  @override
  State<RiwayatTransaksiScreen> createState() => _RiwayatTransaksiScreenState();
}

class _RiwayatTransaksiScreenState extends State<RiwayatTransaksiScreen> {
  String _filter = 'SEMUA';
  List<Map<String, dynamic>> _list = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    String query = '''
      SELECT t.*, s.nama_lengkap, s.nama_panggilan, s.kamar
      FROM transaksi_harian t
      JOIN santri s ON t.santri_id = s.id
    ''';

    final now = DateTime.now();
    List<dynamic> args = [];

    if (_filter == 'HARI_INI') {
      final today = DateFormatter.toLocalDateString(now);
      query += ' WHERE t.tanggal_lokal = ?';
      args.add(today);
    } else if (_filter == 'KEMARIN') {
      final yesterday = DateFormatter.toLocalDateString(now.subtract(const Duration(days: 1)));
      query += ' WHERE t.tanggal_lokal = ?';
      args.add(yesterday);
    } else if (_filter == '7_HARI') {
      final weekAgo = DateFormatter.toLocalDateString(now.subtract(const Duration(days: 7)));
      final today = DateFormatter.toLocalDateString(now);
      query += ' WHERE t.tanggal_lokal BETWEEN ? AND ?';
      args.addAll([weekAgo, today]);
    } else if (_filter == 'BULAN_INI') {
      final first = DateFormatter.toLocalDateString(DateTime(now.year, now.month, 1));
      final today = DateFormatter.toLocalDateString(now);
      query += ' WHERE t.tanggal_lokal BETWEEN ? AND ?';
      args.addAll([first, today]);
    }

    query += ' ORDER BY t.waktu_ambil DESC';

    final res = await db.rawQuery(query, args);

    if (mounted) {
      setState(() {
        _list = res;
        _isLoading = false;
      });
    }
  }

  void _confirmVoid(Map<String, dynamic> row) {
    final txId = row['id'] as String;
    final nominal = (row['nominal'] as num).toInt();
    final nama = row['nama_lengkap'] as String;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Transaksi Ini?'),
        content: Text(
          'Transaksi $nama sebesar ${CurrencyFormatter.format(nominal)} akan dibatalkan dan saldo santri akan dikembalikan otomatis.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final provider = Provider.of<KasSantriProvider>(context, listen: false);
              await provider.voidTransaksi(txId);
              Navigator.pop(ctx);
              await _fetch();
            },
            child: const Text('Ya, Batalkan Transaksi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Mutasi Kas Seluruh Santri'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('SEMUA', 'Semua'),
                  _chip('HARI_INI', 'Hari Ini'),
                  _chip('KEMARIN', 'Kemarin'),
                  _chip('7_HARI', '7 Hari Terakhir'),
                  _chip('BULAN_INI', 'Bulan Ini'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(
                  child: Text('Tidak ada riwayat mutasi pada filter ini', style: TextStyle(color: Colors.grey)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: _list.length,
                  separatorBuilder: (ctx, idx) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final item = _list[idx];
                    final nominal = (item['nominal'] as num).toInt();
                    final isVoided = (item['is_voided'] as int?) == 1;
                    final isOverlimit = (item['is_overlimit'] as int?) == 1;
                    final tipe = item['tipe'] as String? ?? 'PENGAMBILAN';
                    final isSetoran = tipe == 'SETORAN';
                    final waktu = DateTime.tryParse(item['waktu_ambil'] as String) ?? DateTime.now();

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isVoided
                            ? Colors.grey.shade200
                            : isSetoran
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                        foregroundColor: isVoided
                            ? Colors.grey
                            : isSetoran
                                ? Colors.green
                                : Colors.red,
                        child: Icon(
                          isVoided
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
                          Flexible(
                            child: Text(
                              '${item['nama_lengkap']} (${item['kamar']})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                decoration: isVoided ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${isSetoran ? '+' : '-'}${CurrencyFormatter.format(nominal)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isVoided
                                  ? Colors.grey
                                  : isSetoran
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                              decoration: isVoided ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DateFormatter.formatFullDateTime(waktu)} WIB • ${item['kategori_waktu']}'
                            '${item['catatan'] != null ? ' (${item['catatan']})' : ''}'
                            '${isOverlimit ? " ⚠️ OVERLIMIT" : ""}',
                            style: TextStyle(fontSize: 11, color: isOverlimit ? Colors.orange.shade800 : Colors.grey.shade600),
                          ),
                          Text(
                            'Sisa: ${CurrencyFormatter.format((item['saldo_setelah_transaksi'] as num?)?.toInt() ?? 0)}',
                            style: const TextStyle(fontSize: 11, color: Colors.teal),
                          ),
                        ],
                      ),
                      trailing: isVoided
                          ? const Text('BATAL', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))
                          : IconButton(
                              icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.grey),
                              tooltip: 'Batalkan / Void',
                              onPressed: () => _confirmVoid(item),
                            ),
                    );
                  },
                ),
    );
  }

  Widget _chip(String key, String label) {
    final isSelected = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _filter = key);
            _fetch();
          }
        },
        selectedColor: const Color(0xFF00796B),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
