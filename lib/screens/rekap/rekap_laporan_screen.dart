import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/santri.dart';
import '../../models/santri_status.dart';
import '../../providers/kas_santri_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/time_category_helper.dart';

class RekapLaporanScreen extends StatefulWidget {
  const RekapLaporanScreen({Key? key}) : super(key: key);

  @override
  State<RekapLaporanScreen> createState() => _RekapLaporanScreenState();
}

class _RekapLaporanScreenState extends State<RekapLaporanScreen> {
  String? _selectedSantriId;

  String _generateWaText(SantriStatusHariIni status, String namaPondok) {
    final santri = status.santri;
    final todayStr = DateFormatter.toLocalDateString(DateTime.now());
    final txList = status.transaksiHariIni;

    final rincianList = txList.isNotEmpty
        ? txList.map((t) {
            final kat = TimeCategoryHelper.getDbString(t.kategoriWaktu);
            final jam = '${t.waktuAmbil.hour.toString().padLeft(2, '0')}:${t.waktuAmbil.minute.toString().padLeft(2, '0')}';
            final nom = CurrencyFormatter.format(t.nominal);
            final note = t.catatan ?? 'Jajan Harian';
            return '- $kat ($jam): $nom [$note]';
          }).join('\n')
        : '- Belum ada pengambilan uang hari ini';

    final infoTunggakan = santri.tunggakan > 0
        ? '🚨 *Tunggakan:* ${CurrencyFormatter.format(santri.tunggakan)} (${santri.catatanTunggakan.isNotEmpty ? santri.catatanTunggakan : 'Aktif'})'
        : '✅ *Status Tunggakan:* Lunas / Tidak Ada Tunggakan';

    return '''*LAPORAN KAS & UANG SAKU SANTRI*
*$namaPondok*
----------------------------------------
👦 *Nama Santri:* ${santri.namaLengkap} (${santri.kamar})
📅 *Tanggal:* $todayStr

📊 *RINGKASAN HARI INI:*
• Kuota Jatah Harian: ${CurrencyFormatter.format(santri.jatahHarian)}
• Terpakai Hari Ini: ${CurrencyFormatter.format(status.totalAmbilHariIni)}
• Sisa Jatah Hari Ini: ${CurrencyFormatter.format(status.sisaJatahHariIni < 0 ? 0 : status.sisaJatahHariIni)}

📝 *RINCIAN PENGAMBILAN HARI INI:*
$rincianList

🏦 *Total Sisa Saldo Titipan:* ${CurrencyFormatter.format(santri.saldoTotal)}
$infoTunggakan
----------------------------------------
_Sistem Aplikasi Kas Santri — By Moch Khoirul Azman_''';
  }

  void _copyWaText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Laporan WhatsApp berhasil disalin ke papan klip!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<KasSantriProvider>(context);
    final statusList = provider.santriStatusList;

    if (_selectedSantriId == null && statusList.isNotEmpty) {
      _selectedSantriId = statusList.first.santri.id;
    }

    final selectedStatus = statusList.where((s) => s.santri.id == _selectedSantriId).firstOrNull ??
        (statusList.isNotEmpty ? statusList.first : null);

    final waPreviewText = selectedStatus != null
        ? _generateWaText(selectedStatus, provider.pengaturan.namaPondok)
        : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 90),
      children: [
        // 1. Audit Kas Harian Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
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
                        'AUDIT KAS HARIAN',
                        style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Rekap Pengeluaran Sesi Waktu',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                    ),
                    child: const Text('Cocok ✓', style: TextStyle(color: Color(0xFF34D399), fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 3 Kolom Rekap Audit
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF060B14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          const Text('🌅 Pagi & Siang', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(provider.rekapPagiSiang),
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF060B14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          const Text('🌙 Sore & Malam', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(provider.rekapSoreMalam),
                            style: const TextStyle(color: Color(0xFFD946EF), fontSize: 11.5, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF060B14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Text('🏦 Sisa Brankas', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(provider.totalBrankasFisik),
                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 11.5, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Transparansi Wali Santri & Generator Laporan WA
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRANSPARANSI WALI SANTRI',
                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              const SizedBox(height: 2),
              const Text(
                'Kirim Laporan Mutasi ke WhatsApp',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
              ),

              const SizedBox(height: 12),

              // Dropdown Santri
              DropdownButtonFormField<String>(
                value: _selectedSantriId,
                dropdownColor: const Color(0xFF090E1A),
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                decoration: const InputDecoration(isDense: true),
                items: statusList.map((s) {
                  return DropdownMenuItem<String>(
                    value: s.santri.id,
                    child: Text(
                      '${s.santri.namaLengkap} (${s.santri.kamar}) — Saldo: ${CurrencyFormatter.format(s.santri.saldoTotal)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSantriId = val);
                },
              ),

              const SizedBox(height: 12),

              // Preview Text Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF060B14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: SelectableText(
                  waPreviewText,
                  style: const TextStyle(
                    color: Color(0xFF67E8F9),
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    height: 1.45,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Tombol Salin Laporan WA
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: const Color(0xFF030712),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 6,
                    shadowColor: const Color(0xFF10B981).withOpacity(0.4),
                  ),
                  onPressed: () => _copyWaText(waPreviewText),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.copy, size: 16),
                      SizedBox(width: 6),
                      Text('📋 SALIN TEKS LAPORAN WHATSAPP', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
