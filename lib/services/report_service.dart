import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/santri.dart';
import '../models/transaksi.dart';
import '../models/pengaturan.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../utils/time_category_helper.dart';

class ReportService {
  static final ReportService instance = ReportService._init();
  ReportService._init();

  /// Menghasilkan format pesan teks WhatsApp rapi untuk wali santri
  String generateWhatsAppText({
    required Santri santri,
    required List<TransaksiHarian> mutasiList,
    required PengaturanAplikasi pengaturan,
  }) {
    final buffer = StringBuffer();
    final todayStr = DateFormatter.toLocalDateString(DateTime.now());

    buffer.writeln('*Assalamu’alaikum Warahmatullahi Wabarakatuh* 🌸\n');
    buffer.writeln('Yth. *Bapak/Ibu Wali Santri*');
    buffer.writeln('dari ananda tercinta: *${santri.namaLengkap}* (${santri.namaPanggilan})');
    buffer.writeln('Kamar / Asrama: *${santri.kamar}*\n');
    buffer.writeln('Semoga Bapak/Ibu senantiasa dalam keadaan sehat wal afiat dan selalu dalam lindungan Allah SWT. Aamiin.\n');
    buffer.writeln('Izin menyampaikan laporan rekapitulasi mutasi buku kas santri per $todayStr:\n');
    buffer.writeln('💰 *STATUS TITIPAN & JATAH SANTRI:*');
    buffer.writeln('• Sisa Saldo Titipan: *${CurrencyFormatter.format(santri.saldoTotal)}*');
    buffer.writeln('• Standar Jatah Harian: *${CurrencyFormatter.format(santri.jatahHarian)} / hari*');
    buffer.writeln('• Estimasi Ketahanan: ±*${santri.estimasiHari} hari* ke depan');
    if (santri.tunggakan > 0) {
      final ket = santri.catatanTunggakan.isNotEmpty ? ' (${santri.catatanTunggakan})' : '';
      buffer.writeln('• 🚨 *Catatan Tunggakan/Talangan:* *${CurrencyFormatter.format(santri.tunggakan)}*$ket');
    } else {
      buffer.writeln('• ✅ *Status Administrasi:* Bersih / Bebas Tunggakan');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📜 *Riwayat Transaksi Terbaru:*');

    final displayList = mutasiList.take(8).toList();
    if (displayList.isEmpty) {
      buffer.writeln('  _Belum ada riwayat transaksi pada periode ini._');
    } else {
      for (var tx in displayList) {
        if (tx.isVoided) continue;
        final icon = tx.tipe == TipeTransaksi.setoran ? '📥 [Setoran]' : '📤 [Ambil]';
        final waktu = DateFormatter.formatFullDateTime(tx.waktuAmbil);
        final nominal = CurrencyFormatter.format(tx.nominal);
        final ket = tx.catatan != null && tx.catatan!.isNotEmpty ? ' (${tx.catatan})' : '';
        buffer.writeln('  • $icon $waktu');
        buffer.writeln('    Nominal: *$nominal*$ket | Sisa: ${CurrencyFormatter.format(tx.saldoSetelahTransaksi)}');
      }
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Demikian laporan buku mutasi ini kami sampaikan dengan amanah demi transparansi keuangan santri di *${pengaturan.namaPondok}*.\n');
    buffer.writeln('*Jazakumullah Khairan Katsiran*');
    buffer.writeln('*Wassalamu’alaikum Warahmatullahi Wabarakatuh* 🙏\n');
    buffer.writeln('Pengurus Kas: *${pengaturan.namaPengurus}*');
    if (pengaturan.kontakPengurus.isNotEmpty) {
      buffer.writeln('Kontak: ${pengaturan.kontakPengurus}');
    }

    return buffer.toString();
  }

  /// Kirim langsung via WhatsApp (jika nomor wali tersedia) atau Share Sheet
  Future<void> sendWhatsAppReport({
    required Santri santri,
    required List<TransaksiHarian> mutasiList,
    required PengaturanAplikasi pengaturan,
  }) async {
    final text = generateWhatsAppText(
      santri: santri,
      mutasiList: mutasiList,
      pengaturan: pengaturan,
    );

    if (santri.noWaWali != null && santri.noWaWali!.trim().isNotEmpty) {
      var phone = santri.noWaWali!.replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.startsWith('0')) {
        phone = '62${phone.substring(1)}';
      }
      final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Jika tidak ada nomor WA atau gagal membuka WA langsung, buka sheet share
    await Share.share(
      text,
      subject: 'Laporan Uang Saku Santri - ${santri.namaLengkap}',
    );
  }

  /// Menghasilkan dokumen PDF Mutasi Santri yang siap cetak / dibagikan
  Future<void> generateAndPrintPdf({
    required Santri santri,
    required List<TransaksiHarian> mutasiList,
    required PengaturanAplikasi pengaturan,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Kop Laporan
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    pengaturan.namaPondok.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal800,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'LAPORAN BUKU MUTASI UANG SAKU SANTRI',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Divider(thickness: 1.5, color: PdfColors.teal800),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Informasi Santri
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Nama Santri: ${santri.namaLengkap}'),
                      pw.Text('Nama Panggilan: ${santri.namaPanggilan}'),
                      pw.Text('Kamar / Asrama: ${santri.kamar}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Sisa Saldo: ${CurrencyFormatter.format(santri.saldoTotal)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900,
                        ),
                      ),
                      pw.Text('Jatah: ${CurrencyFormatter.format(santri.jatahHarian)} / hari'),
                      pw.Text('Estimasi: ±${santri.estimasiHari} hari'),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Tabel Mutasi
            pw.Text(
              'Rincian Transaksi:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Tanggal & Jam', 'Kategori', 'Tipe', 'Keterangan', 'Nominal', 'Saldo Akhir'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
              cellAlignment: pw.Alignment.centerLeft,
              data: mutasiList.map((tx) {
                final waktu = DateFormatter.formatFullDateTime(tx.waktuAmbil);
                final kat = TimeCategoryHelper.getLabel(tx.kategoriWaktu);
                final tipe = tx.tipe == TipeTransaksi.setoran ? 'Setoran' : 'Ambil';
                final ket = tx.catatan ?? '-';
                final nominal = CurrencyFormatter.format(tx.nominal);
                final saldo = CurrencyFormatter.format(tx.saldoSetelahTransaksi);
                final statusVoid = tx.isVoided ? ' (BATAL)' : '';

                return [
                  waktu,
                  kat,
                  '$tipe$statusVoid',
                  ket,
                  nominal,
                  saldo,
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 30),

            // Tanda tangan
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Wali Santri,'),
                    pw.SizedBox(height: 45),
                    pw.Text('( ................................... )'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Dicetak: ${DateFormatter.formatDisplayDate(DateTime.now())}'),
                    pw.Text('Pengurus Kas / Musyrif,'),
                    pw.SizedBox(height: 45),
                    pw.Text(
                      '${pengaturan.namaPengurus}\n( ${pengaturan.namaPondok} )',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Mutasi_${santri.namaPanggilan}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
