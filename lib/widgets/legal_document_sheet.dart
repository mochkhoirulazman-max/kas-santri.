import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../utils/app_feedback.dart';

class LegalDocumentSheet extends StatelessWidget {
  final String title;
  final String badge;
  final IconData icon;
  final Color accentColor;
  final List<({String heading, String body})> sections;

  const LegalDocumentSheet({
    Key? key,
    required this.title,
    required this.badge,
    required this.icon,
    required this.accentColor,
    required this.sections,
  }) : super(key: key);

  static List<({String heading, String body})> buildTermsSections({
    bool isPlayStoreBuild = kIsPlayStoreBuild,
  }) {
    return [
      (
        heading: '1. Ruang Lingkup & Lisensi Gratis',
        body:
            'Aplikasi Kas-Santri dirancang khusus untuk membantu bendahara, musyrif, dan pengurus pondok pesantren dalam mencatat uang saku, setoran, serta tunggakan santri secara offline-first. Versi Gratis dapat digunakan selamanya tanpa biaya untuk mengelola maksimal 15 santri aktif beserta seluruh fitur inti transaksi cepat, mutasi, tunggakan, PIN keamanan, dan backup JSON lokal.',
      ),
      (
        heading: '2. Paket Kas-Santri PRO (Prabayar & Lifetime)',
        body:
            'Paket Kas-Santri PRO membuka kapasitas santri tanpa batas serta fitur lanjutan (Multi-Dompet Tunai/Bank, Cash Opname Fisik, Scan & Cetak Kartu QR, Ekspor Excel/PDF Berkop Logo, Kirim WA 1-Klik & Struk Gambar PNG bebas watermark, Biometrik, serta Auto-Backup Google Drive).\n\n• Pro Bulanan (1 Bulan): Rp 25.000.\n• Pro Tahun Ajaran (12 Bulan): Rp 179.000.\n• Pro Selamanya (Lifetime): Rp 399.000 sekali bayar untuk satu perangkat/akun pondok.',
      ),
      (
        heading: '3. Uji Coba Gratis 14 Hari',
        body:
            'Setiap perangkat berhak mengaktifkan 1 (satu) kali Uji Coba Gratis Kas-Santri PRO selama 14 hari penuh tanpa kewajiban membayar di muka. Setelah masa 14 hari berakhir, akun otomatis kembali ke Mode Gratis tanpa menghapus data santri maupun riwayat transaksi yang sudah tercatat.',
      ),
      (
        heading: '4. Ketentuan Pembayaran & Aktivasi PRO',
        body: isPlayStoreBuild
            ? 'Seluruh pembelian dan aktivasi paket Kas-Santri PRO diproses secara resmi dan aman melalui sistem Google Play Billing sesuai ketentuan Google Play. Status PRO akan aktif secara otomatis setelah transaksi terverifikasi pada akun Google Play Anda.'
            : 'Pada distribusi Direct APK, pembayaran ditujukan ke DANA/QRIS resmi a.n. ${AppConfig.adminAccountName} (${AppConfig.adminDanaNumber}) dan menghasilkan Kode Aktivasi PRO Ed25519 yang terikat pada ID Perangkat unik. Pada distribusi Google Play Store, seluruh transaksi diproses melalui Google Play Billing sesuai ketentuan Google Play.',
      ),
      (
        heading: '5. Hak Cipta & Tanggung Jawab Data',
        body:
            'Hak cipta aplikasi dan rancangan sistem dimiliki penuh oleh Moch Khoirul Azman (© 2026). Pengurus pondok bertanggung jawab mencadangkan data secara berkala melalui fitur Backup JSON/.KSBAK atau Cloud Google Drive sebelum mengganti atau mereset perangkat.',
      ),
    ];
  }

  static List<({String heading, String body})> buildPrivacySections({
    bool isPlayStoreBuild = kIsPlayStoreBuild,
  }) {
    return [
      (
        heading: '1. Penyimpanan Data Lokal (SQLite Offline-First)',
        body:
            'Seluruh data santri, nominal saldo, transaksi harian, tunggakan, mutasi dompet, buku infak, catatan keperluan, nomor WhatsApp wali, serta foto profil santri disimpan 100% secara lokal di dalam basis data SQLite pada perangkat pengurus (dan opsional di ruang tersembunyi drive.appdata akun Google Drive milik pengurus sendiri). Data keuangan santri dan pondok Anda tidak pernah dikirim ke server pengembang.',
      ),
      (
        heading: '2. Penggunaan Izin Kamera & Galeri',
        body:
            'Izin kamera hanya digunakan secara lokal saat pengurus memindai Kode QR Kartu Santri atau mengambil foto profil santri / logo pondok. Tidak ada gambar atau video yang dikirim ke server eksternal mana pun.',
      ),
      (
        heading: '3. Cadangan Privat Google Drive (drive.appdata)',
        body:
            'Jika Anda mengaktifkan fitur PRO Cloud Backup Google Drive, aplikasi hanya meminta akses ke ruang tersembunyi khusus aplikasi (scope drive.appdata) pada akun Google milik pondok/pengurus sendiri. Aplikasi tidak dapat melihat atau membaca file pribadi lain di Google Drive Anda.',
      ),
      (
        heading: '4. Keamanan PIN, Biometrik, Sinkronisasi Waktu & Metadata Lisensi',
        body:
            'PIN keamanan 4–6 digit disimpan dalam bentuk hash kriptografis terenkripsi melalui Android Keystore / EncryptedSharedPreferences. Autentikasi sidik jari ditangani langsung oleh sistem biometrik Android tanpa menyimpan data biometrik mentah di aplikasi.\n\nUntuk menjaga integritas masa aktif lisensi dan informasi versi terbaru aplikasi, aplikasi hanya melakukan sinkronisasi metadata lisensi ringan non-sensitif (ID Perangkat, Nama Pondok, Status Paket Lisensi, dan Versi Aplikasi${isPlayStoreBuild ? '' : ', serta metadata kontak pengurus pada distribusi Direct APK'}) dan pengecekan ringan header standar HTTP Date jaringan untuk sinkronisasi waktu anti-manipulasi jam.',
      ),
      (
        heading: '5. Kontak Dukungan Resmi Pengembang',
        body:
            'Untuk bantuan teknis, konsultasi penggunaan aplikasi, atau pertanyaan privasi data, silakan hubungi:\n• Pengembang: ${AppConfig.adminAccountName}\n• Kontak Dukungan: ${AppConfig.adminDanaNumber}',
      ),
    ];
  }

  static Future<void> showTerms(BuildContext context) async {
    AppFeedback.tap();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LegalDocumentSheet(
        title: 'Syarat & Ketentuan Kas-Santri',
        badge: 'DOKUMEN RESMI OFFLINE',
        icon: Icons.gavel_rounded,
        accentColor: const Color(0xFF38BDF8),
        sections: buildTermsSections(),
      ),
    );
  }

  static Future<void> showPrivacy(BuildContext context) async {
    AppFeedback.tap();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LegalDocumentSheet(
        title: 'Kebijakan Privasi Kas-Santri',
        badge: '100% OFFLINE-FIRST & AMAN',
        icon: Icons.privacy_tip_rounded,
        accentColor: const Color(0xFF34D399),
        sections: buildPrivacySections(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1422),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: accentColor.withOpacity(0.6), width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accentColor.withOpacity(0.45)),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      AppFeedback.tap();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Flexible(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
                itemCount: sections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, idx) {
                  final sec = sections[idx];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF060B14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sec.heading,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sec.body,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset > 0 ? 10 : 16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    AppFeedback.tap();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: const Color(0xFF030712),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Saya Mengerti & Tutup',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
