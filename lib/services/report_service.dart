import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/santri.dart';
import '../models/transaksi.dart';
import '../models/pengaturan.dart';
import '../models/infak_santri.dart';
import '../models/serah_terima_infak.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../utils/time_category_helper.dart';

class ReportService {
  static final ReportService instance = ReportService._init();
  ReportService._init();

  /// Normalisasi nomor WhatsApp Indonesia (08xxx -> 628xxx, hapus karakter non-digit)
  static String normalizeWaPhone(String? rawPhone) {
    if (rawPhone == null) return '';
    var phone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) return '';
    if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    } else if (phone.startsWith('8')) {
      phone = '62$phone';
    }
    return phone;
  }

  /// Membuka WhatsApp langsung ke nomor wali dengan pesan terisi otomatis
  Future<bool> openWhatsAppDirect({
    required String? rawPhone,
    required String message,
  }) async {
    final phone = normalizeWaPhone(rawPhone);
    if (phone.isEmpty) return false;
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Menghasilkan format pesan teks WhatsApp rapi untuk wali santri
  String generateWhatsAppText({
    required Santri santri,
    required List<TransaksiHarian> mutasiList,
    required PengaturanAplikasi pengaturan,
    bool isProUser = false,
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
    if (!isProUser) {
      buffer.writeln('\n_Dicatat dengan Kas-Santri_');
    }

    return buffer.toString();
  }

  /// Pesan pengingat sopan saat saldo santri kritis (< 3 hari) atau memiliki tunggakan
  String generateCriticalReminderText({
    required Santri santri,
    required String namaPondok,
    required String namaPengurus,
  }) {
    final statusTunggakan = santri.tunggakan > 0
        ? '• 🚨 Tunggakan Talangan: *${CurrencyFormatter.format(santri.tunggakan)}*${santri.catatanTunggakan.isNotEmpty ? ' (${santri.catatanTunggakan})' : ''}\n'
        : '';
    return '''*Assalamu’alaikum Warahmatullahi Wabarakatuh* 🌸

Yth. *Bapak/Ibu Wali Santri* dari ananda *${santri.namaLengkap}* (${santri.kamar}),

Menginformasikan dengan penuh takdzim bahwa saldo titipan uang saku ananda saat ini berada pada status *Kritis (< 3 Hari)*:
• 💰 Sisa Saldo: *${CurrencyFormatter.format(santri.saldoTotal)}*
• 📆 Estimasi Ketahanan: ±*${santri.estimasiHari} hari* (Jatah ${CurrencyFormatter.format(santri.jatahHarian)}/hari)
$statusTunggakan
Mohon kiranya Bapak/Ibu dapat menyiapkan setoran lanjutan agar kebutuhan harian ananda di *$namaPondok* tetap berjalan lancar.

*Jazakumullah Khairan Katsiran*
*Wassalamu’alaikum Warahmatullahi Wabarakatuh* 🙏
— *$namaPengurus ($namaPondok)*''';
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

  /// Format pesan teks WhatsApp Struk Pembagian Setoran Sambangan (Infak + Uang Jajan)
  String generateSambanganReceiptText({
    required Santri santri,
    required InfakSantriModel infak,
    required PengaturanAplikasi pengaturan,
    required int totalDiterima,
    required int sisaJajan,
    required int jatahBaru,
    int nominalPotongTunggakan = 0,
    bool isProUser = false,
  }) {
    final masakLabel = infak.isMasakBebas
        ? '✓ Bebas / Ikut Saudara'
        : CurrencyFormatter.format(infak.nominalMasak);
    final listrikLabel = infak.isListrikBebas
        ? '✓ Bebas / Ikut Saudara'
        : CurrencyFormatter.format(infak.nominalListrik);
    final String berasLabel;
    if (infak.jenisBeras == InfakSantriModel.berasBebas) {
      berasLabel = '✓ Bebas Beras';
    } else if (infak.jenisBeras == InfakSantriModel.berasFisik) {
      final literStr = infak.berasLiter == infak.berasLiter.roundToDouble()
          ? infak.berasLiter.toInt().toString()
          : infak.berasLiter.toString();
      berasLabel = '🌾 Fisik $literStr Liter (Rp 0)';
    } else if (infak.jenisBeras == InfakSantriModel.berasUang) {
      berasLabel = CurrencyFormatter.format(infak.berasUang);
    } else {
      berasLabel = '⏳ Belum Setor Beras';
    }

    final buffer = StringBuffer();
    buffer.writeln('*Assalamu’alaikum Warahmatullahi Wabarakatuh* 🌸\n');
    buffer.writeln('Alhamdulillah, telah kami terima titipan *Setoran Sambangan* dari Wali Santri ananda:');
    buffer.writeln('• Nama: *${santri.namaLengkap}* (${santri.kategoriLabel})');
    if (santri.kamar.trim().isNotEmpty) {
      buffer.writeln('• Kamar / Asrama: *${santri.kamar}*');
    }
    buffer.writeln('• Total Uang Diterima: *${CurrencyFormatter.format(totalDiterima)}* (${infak.sumberDompet})');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🌾 *RINCIAN POS INFAK BULANAN (${infak.periodeBulan}):*');
    buffer.writeln('• Infak Masak / Makan: $masakLabel');
    buffer.writeln('• Infak Listrik: $listrikLabel');
    buffer.writeln('• Infak Beras: $berasLabel');
    buffer.writeln('• Masa Berlaku: *${infak.tglMasuk}* s.d. *${infak.tglHabis}*');
    buffer.writeln('• Status Infak: *${infak.statusLunas}*');
    if (nominalPotongTunggakan > 0) {
      buffer.writeln('• 🚨 Potong Tunggakan: *${CurrencyFormatter.format(nominalPotongTunggakan)}*');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💰 *SISA MASUK UANG JAJAN:*');
    buffer.writeln('• Tambahan Saldo Jajan: *${CurrencyFormatter.format(sisaJajan)}*');
    buffer.writeln('• Jatah Harian Baru: *${CurrencyFormatter.format(jatahBaru)} / hari*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Semoga menjadi amal jariyah yang berkah dan ilmu ananda di *${pengaturan.namaPondok}* bermanfaat. Aamiin.\n');
    buffer.writeln('Bendahara: *${pengaturan.namaPengurus}*');
    if (!isProUser) {
      buffer.writeln('\n_Dicatat dengan Kas-Santri_');
    }
    return buffer.toString();
  }

  /// Format pesan Berita Acara Serah Terima Kas Infak / Beras ke Dapur / Yayasan
  String generateSerahTerimaBeritaAcaraText({
    required SerahTerimaInfakModel item,
    required PengaturanAplikasi pengaturan,
  }) {
    final literStr = item.jumlahBerasLiter == item.jumlahBerasLiter.roundToDouble()
        ? item.jumlahBerasLiter.toInt().toString()
        : item.jumlahBerasLiter.toString();
    final buffer = StringBuffer();
    buffer.writeln('*BERITA ACARA SERAH TERIMA INFAK PONDOK* 🤝\n');
    buffer.writeln('Pondok: *${pengaturan.namaPondok}*');
    buffer.writeln('Tahun Ajaran: ${pengaturan.tahunAjaran}');
    buffer.writeln('Tanggal Serah: *${item.tanggalSerah}*');
    buffer.writeln('Periode Bulan: *${item.periodeBulan}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('• Pos Infak: *${item.posInfak}*');
    buffer.writeln('• Sumber Kantong: *${item.sumberDompet}*');
    if (item.nominalUang > 0) {
      buffer.writeln('• Nominal Diserahkan: *${CurrencyFormatter.format(item.nominalUang)}*');
    }
    if (item.jumlahBerasLiter > 0) {
      buffer.writeln('• Beras Fisik Diserahkan: *$literStr Liter*');
    }
    buffer.writeln('• Diterima Oleh: *${item.penerima}*');
    if (item.catatan != null && item.catatan!.trim().isNotEmpty) {
      buffer.writeln('• Catatan: ${item.catatan}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Diserahkan oleh: *${pengaturan.namaPengurus}*');
    return buffer.toString();
  }

  /// Pesan pengingat jatuh tempo / kewajiban infak bulanan via WhatsApp
  String generateInfakReminderText({
    required Santri santri,
    required PengaturanAplikasi pengaturan,
    required String periodeBulan,
    InfakSantriModel? infak,
  }) {
    final literDefaultStr = pengaturan.defaultInfakBerasLiter ==
            pengaturan.defaultInfakBerasLiter.roundToDouble()
        ? pengaturan.defaultInfakBerasLiter.toInt().toString()
        : pengaturan.defaultInfakBerasLiter.toStringAsFixed(1);

    final buffer = StringBuffer();
    buffer.writeln('*Assalamu’alaikum Warahmatullahi Wabarakatuh* 🌸\n');
    buffer.writeln('Yth. *Bapak/Ibu Wali Santri*');
    buffer.writeln('dari ananda: *${santri.namaLengkap}* (${santri.kategoriLabel})');
    if (santri.kamar.trim().isNotEmpty) {
      buffer.writeln('Kamar / Asrama: *${santri.kamar}*');
    }
    buffer.writeln('');
    buffer.writeln('Dengan hormat menginformasikan jadwal & kewajiban *Infak Bulanan* periode *$periodeBulan* (TA ${pengaturan.tahunAjaran}):');
    if (infak != null && infak.tglHabis.isNotEmpty) {
      buffer.writeln('• Masa Berlaku: *${infak.tglMasuk}* s.d. *${infak.tglHabis}*');
      buffer.writeln('• Status Saat Ini: *${infak.statusLunas}*');
    } else {
      buffer.writeln('• Status Saat Ini: *BELUM TERCATAT*');
    }

    if (infak != null && infak.statusLunas == InfakSantriModel.statusCicilVal) {
      final masakStatus = infak.isMasakBebas
          ? 'Bebas'
          : CurrencyFormatter.format(infak.nominalMasak);
      final listrikStatus = infak.isListrikBebas
          ? 'Bebas'
          : CurrencyFormatter.format(infak.nominalListrik);
      final String berasStatus;
      if (infak.jenisBeras == InfakSantriModel.berasBebas) {
        berasStatus = 'Bebas';
      } else if (infak.jenisBeras == InfakSantriModel.berasFisik) {
        final lStr = infak.berasLiter == infak.berasLiter.roundToDouble()
            ? infak.berasLiter.toInt().toString()
            : infak.berasLiter.toStringAsFixed(1);
        berasStatus = '$lStr Liter';
      } else if (infak.jenisBeras == InfakSantriModel.berasUang) {
        berasStatus = CurrencyFormatter.format(infak.berasUang);
      } else {
        berasStatus = 'Belum';
      }
      buffer.writeln('');
      buffer.writeln('📋 *Tercatat Saat Ini:* Masak $masakStatus | Listrik $listrikStatus | Beras $berasStatus');
      if (infak.catatan != null && infak.catatan!.trim().isNotEmpty) {
        buffer.writeln('📝 Catatan: ${infak.catatan!.trim()}');
      }
    }

    buffer.writeln('');
    buffer.writeln('🌾 *Tarif Standar Infak Bulanan Pondok:*');
    buffer.writeln('• Infak Masak / Makan: *${CurrencyFormatter.format(pengaturan.defaultInfakMasak)}*');
    buffer.writeln('• Infak Listrik: *${CurrencyFormatter.format(pengaturan.defaultInfakListrik)}*');
    buffer.writeln('• Infak Beras: *$literDefaultStr Liter* atau uang pengganti *${CurrencyFormatter.format(pengaturan.defaultInfakBerasUang)}*');
    buffer.writeln('');
    buffer.writeln('Mohon kiranya Bapak/Ibu berkenan menindaklanjuti agar administrasi ananda di *${pengaturan.namaPondok}* berjalan lancar dan berkah. Aamiin.\n');
    buffer.writeln('*Jazakumullah Khairan Katsiran*');
    buffer.writeln('*Wassalamu’alaikum Warahmatullahi Wabarakatuh* 🙏');
    buffer.writeln('— *${pengaturan.namaPengurus} (${pengaturan.namaPondok})*');
    return buffer.toString();
  }
}
