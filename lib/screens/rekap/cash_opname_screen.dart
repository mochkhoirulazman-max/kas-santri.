import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/kas_santri_provider.dart';
import '../../utils/app_feedback.dart';
import '../../utils/currency_formatter.dart';
import '../paywall_screen.dart';

class CashOpnameScreen extends StatefulWidget {
  const CashOpnameScreen({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) async {
    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    if (!provider.hasProAccess) {
      AppFeedback.alert();
      await PaywallScreen.show(
        context,
        triggerFeature: 'Kalkulator Cash Opname Pecahan Uang Fisik',
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CashOpnameScreen()),
    );
  }

  @override
  State<CashOpnameScreen> createState() => _CashOpnameScreenState();
}

class _CashOpnameScreenState extends State<CashOpnameScreen> {
  static const List<int> _denominations = [
    100000,
    50000,
    20000,
    10000,
    5000,
    2000,
    1000,
    500,
  ];

  final Map<int, TextEditingController> _qtyControllers = {};
  final TextEditingController _catatanController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final d in _denominations) {
      _qtyControllers[d] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    _catatanController.dispose();
    super.dispose();
  }

  int _qtyFor(int denom) {
    final text = _qtyControllers[denom]?.text.trim() ?? '';
    return int.tryParse(text) ?? 0;
  }

  int get _totalFisik {
    int sum = 0;
    for (final d in _denominations) {
      sum += d * _qtyFor(d);
    }
    return sum;
  }

  Map<int, int> get _rincianMap {
    final map = <int, int>{};
    for (final d in _denominations) {
      final qty = _qtyFor(d);
      if (qty > 0) map[d] = qty;
    }
    return map;
  }

  void _stepQty(int denom, int delta) {
    AppFeedback.tap();
    final next = (_qtyFor(denom) + delta).clamp(0, 999999);
    setState(() {
      _qtyControllers[denom]?.text = next.toString();
    });
  }

  void _resetAll() {
    AppFeedback.tap();
    setState(() {
      for (final d in _denominations) {
        _qtyControllers[d]?.text = '0';
      }
      _catatanController.clear();
    });
  }

  Future<void> _saveOpname() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final provider = Provider.of<KasSantriProvider>(context, listen: false);
    final totalSistem = provider.targetUangFisikDiLaci;
    final totalFisik = _totalFisik;
    final selisih = totalFisik - totalSistem;

    await provider.simpanCashOpname(
      totalSistem: totalSistem,
      totalFisik: totalFisik,
      rincianPecahan: _rincianMap,
      catatan: _catatanController.text.trim(),
    );

    if (selisih == 0) {
      AppFeedback.success();
    } else {
      AppFeedback.alert();
    }

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selisih == 0
                ? 'Cash Opname tersimpan: Cocok (Terverifikasi Fisik ✓)'
                : 'Cash Opname tersimpan dengan selisih ${CurrencyFormatter.format(selisih)}.',
          ),
          backgroundColor: selisih == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final kasJajanTunai = provider.kasLaciTunai;
    final kasInfakTunai = provider.kasInfakTunai;
    final tabunganTunai = provider.tabunganTunai;
    final kasSistem = provider.targetUangFisikDiLaci;
    final totalFisik = _totalFisik;
    final selisih = totalFisik - kasSistem;
    final logs = provider.opnameLogs;

    final Color statusColor;
    final Color statusBg;
    final String statusText;
    if (selisih == 0) {
      statusColor = const Color(0xFF34D399);
      statusBg = const Color(0xFF10B981).withOpacity(0.18);
      statusText = 'Cocok (Terverifikasi Fisik ✓)';
    } else if (selisih < 0) {
      statusColor = const Color(0xFFFB7185);
      statusBg = const Color(0xFFF43F5E).withOpacity(0.18);
      statusText = 'Kurang ${CurrencyFormatter.format(selisih.abs())}';
    } else {
      statusColor = const Color(0xFFFBBF24);
      statusBg = const Color(0xFFF59E0B).withOpacity(0.18);
      statusText = 'Lebih +${CurrencyFormatter.format(selisih)}';
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xCC060F1E),
        title: const Row(
          children: [
            Flexible(
              child: Text(
                'Cash Opname Fisik',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 6),
            Text('👑', style: TextStyle(fontSize: 15)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _resetAll,
            icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF7DD3FC)),
            label: const Text('Reset 0', style: TextStyle(color: Color(0xFF7DD3FC), fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 24),
          children: [
            // Panel Perbandingan Real-Time
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF081426)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: statusColor.withOpacity(0.5), width: 1.4),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '💵 TARGET LACI (SISTEM)',
                              style: TextStyle(color: Color(0xFF7DD3FC), fontSize: 9.5, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                CurrencyFormatter.format(kasSistem),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.white12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              '🧮 TOTAL UANG FISIK',
                              style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                CurrencyFormatter.format(totalFisik),
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF060B14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        _opnameBreakdownRow(
                          'Kas Laci Tunai (Titipan Uang Jajan)',
                          CurrencyFormatter.format(kasJajanTunai),
                          Colors.white70,
                        ),
                        const SizedBox(height: 4),
                        _opnameBreakdownRow(
                          'Kas Infak Tunai (Belum Disetor ke Yayasan)',
                          CurrencyFormatter.format(kasInfakTunai),
                          const Color(0xFFFDE68A),
                        ),
                        const SizedBox(height: 4),
                        _opnameBreakdownRow(
                          'Brankas Tabungan Tunai Santri (Kantong 4)',
                          CurrencyFormatter.format(tabunganTunai),
                          const Color(0xFFA7F3D0),
                        ),
                        const Divider(color: Colors.white12, height: 12),
                        _opnameBreakdownRow(
                          'Target Total Uang Fisik Seharusnya di Laci',
                          CurrencyFormatter.format(kasSistem),
                          const Color(0xFF67E8F9),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: statusColor.withOpacity(0.55)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            const Text(
              'HITUNG JUMLAH LEMBAR / KEPING PECAHAN',
              style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.6),
            ),
            const SizedBox(height: 8),

            // 8 Baris Pecahan Uang
            ..._denominations.map((denom) {
              final qty = _qtyFor(denom);
              final subTotal = denom * qty;
              final isCoin = denom <= 1000;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: qty > 0 ? const Color(0xFF34D399).withOpacity(0.45) : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 86,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF060B14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CurrencyFormatter.format(denom),
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            isCoin ? 'Koin / Kertas' : 'Lembar',
                            style: const TextStyle(color: Colors.white38, fontSize: 8.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _stepQty(denom, -1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 30,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.remove, color: Colors.white70, size: 16),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 54,
                      child: TextField(
                        controller: _qtyControllers[denom],
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _stepQty(denom, 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 30,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF34D399).withOpacity(0.5)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.add, color: Color(0xFF34D399), size: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.format(subTotal),
                          style: TextStyle(
                            color: subTotal > 0 ? const Color(0xFF34D399) : Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 10),
            const Text(
              'CATATAN OPNAME / PENJELASAN SELISIH',
              style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _catatanController,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              decoration: const InputDecoration(
                hintText: 'Contoh: Tutup kas malam Senin • uang koin sesuai laci',
                isDense: true,
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: const Color(0xFF030712),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _isSaving ? null : _saveOpname,
                child: const Text(
                  '💾 SIMPAN HASIL CASH OPNAME',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                ),
              ),
            ),

            if (logs.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'RIWAYAT CASH OPNAME TERAKHIR',
                style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.6),
              ),
              const SizedBox(height: 8),
              ...logs.take(5).map((log) {
                final jam = '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}';
                final badgeColor = log.isCocok
                    ? const Color(0xFF34D399)
                    : (log.selisih < 0 ? const Color(0xFFFB7185) : const Color(0xFFFBBF24));
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${log.tanggalLokal} • $jam WIB',
                              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Fisik: ${CurrencyFormatter.format(log.totalFisik)} | Sistem: ${CurrencyFormatter.format(log.totalSistem)}',
                              style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                            ),
                            if (log.catatan != null && log.catatan!.isNotEmpty)
                              Text(
                                log.catatan!,
                                style: const TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: badgeColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          log.isCocok ? 'Cocok ✓' : CurrencyFormatter.format(log.selisih),
                          style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _opnameBreakdownRow(
    String label,
    String val,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isBold ? Colors.white : Colors.white60,
              fontSize: 10.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          val,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
