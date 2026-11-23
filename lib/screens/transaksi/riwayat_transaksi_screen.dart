import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/transaksi.dart';
import '../../providers/kas_santri_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/time_category_helper.dart';
import '../../utils/app_feedback.dart';

class RiwayatTransaksiScreen extends StatefulWidget {
  const RiwayatTransaksiScreen({Key? key}) : super(key: key);

  @override
  State<RiwayatTransaksiScreen> createState() => _RiwayatTransaksiScreenState();
}

class _RiwayatTransaksiScreenState extends State<RiwayatTransaksiScreen> {
  String _selectedSantriId = 'ALL';
  String _selectedWaktu = 'ALL';
  List<TransaksiHarian> _list = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final results = await DatabaseHelper.instance.getAllTransaksi(
      santriId: _selectedSantriId,
      kategoriWaktu: _selectedWaktu,
    );
    if (mounted) {
      setState(() {
        _list = results;
        _isLoading = false;
      });
    }
  }

  void _confirmVoid(TransaksiHarian tx, String namaSantri) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Transaksi Ini?'),
        content: Text(
          'Transaksi $namaSantri sebesar ${CurrencyFormatter.format(tx.nominal)} akan dibatalkan dan saldo santri akan dikembalikan otomatis.',
          style: const TextStyle(fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            onPressed: () async {
              final provider = Provider.of<KasSantriProvider>(context, listen: false);
              await provider.voidTransaksi(tx.id);
              if (mounted) {
                Navigator.pop(ctx);
                await _fetch();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaksi dibatalkan & saldo dikembalikan.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
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
    final santriList = provider.allSantri.where((s) => s.statusAktif).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await provider.loadAllData();
        await _fetch();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 44, 16, 90),
        children: [
          // Filter Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'BUKU MUTASI DIGITAL',
                          style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Riwayat Keluar & Masuk',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF060B14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '${_list.length} catatan',
                        style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 2 Dropdowns: Filter Santri & Filter Waktu
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSantriId,
                        dropdownColor: const Color(0xFF090E1A),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'ALL', child: Text('Semua Santri')),
                          ...santriList.map((s) => DropdownMenuItem(value: s.id, child: Text(s.namaLengkap, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedSantriId = val);
                            _fetch();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedWaktu,
                        dropdownColor: const Color(0xFF090E1A),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Semua Waktu')),
                          DropdownMenuItem(value: 'PAGI', child: Text('🌅 Pagi')),
                          DropdownMenuItem(value: 'SIANG', child: Text('☀️ Siang')),
                          DropdownMenuItem(value: 'SORE', child: Text('🌤️ Sore')),
                          DropdownMenuItem(value: 'MALAM', child: Text('🌙 Malam')),
                          DropdownMenuItem(value: 'SETORAN', child: Text('📥 Setoran')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedWaktu = val);
                            _fetch();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Transaction Items
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_list.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: const Center(
                child: Text('Belum ada catatan mutasi transaksi.', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            )
          else
            ..._list.map((tx) {
              final santri = santriList.where((s) => s.id == tx.santriId).firstOrNull;
              final namaSantri = santri != null ? santri.namaLengkap : 'Santri';
              final isMasuk = tx.tipe == TipeTransaksi.setoran;
              final katStr = TimeCategoryHelper.getDbString(tx.kategoriWaktu);
              final jamStr = '${tx.waktuAmbil.hour.toString().padLeft(2, '0')}:${tx.waktuAmbil.minute.toString().padLeft(2, '0')}';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Kolom info kiri
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isMasuk
                                  ? const Color(0xFF10B981).withOpacity(0.2)
                                  : const Color(0xFF06B6D4).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isMasuk
                                    ? const Color(0xFF34D399).withOpacity(0.4)
                                    : const Color(0xFF38BDF8).withOpacity(0.4),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(isMasuk ? '📥' : '💸', style: const TextStyle(fontSize: 16)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        namaSantri,
                                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white12),
                                      ),
                                      child: Text(
                                        '$katStr • $jamStr',
                                        style: const TextStyle(color: Colors.white70, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (tx.isOverlimit)
                                      Container(
                                        margin: const EdgeInsets.only(left: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF43F5E).withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFFB7185).withOpacity(0.5)),
                                        ),
                                        child: const Text(
                                          'Overlimit',
                                          style: TextStyle(color: Color(0xFFFDA4AF), fontSize: 8.5, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tx.catatan != null && tx.catatan!.isNotEmpty ? tx.catatan! : (isMasuk ? 'Setoran' : 'Jajan Harian'),
                                  style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Kolom nominal & aksi kanan
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${isMasuk ? '+' : '-'}${CurrencyFormatter.format(tx.nominal)}',
                            style: TextStyle(
                              color: isMasuk ? const Color(0xFF34D399) : const Color(0xFFFCD34D),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        InkWell(
                          onTap: () {
                            AppFeedback.tap();
                            _confirmVoid(tx, namaSantri);
                          },
                          child: const Text(
                            'Void / Batal',
                            style: TextStyle(
                              color: Color(0xFFFB7185),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
