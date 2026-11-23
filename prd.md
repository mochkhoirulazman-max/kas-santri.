Product Requirements Document (PRD): Aplikasi Kas Santri

Nama Produk: Kas Santri (Sistem Manajemen Uang Saku & Titipan Santri Harian)

Platform: Mobile App (Android & iOS / Cross-Platform / PWA Offline-First)

Target Pengguna: Pengurus Pondok, Musyrif/Musyrifah, Bendahara Asrama, atau Wali Kamar.

Status Dokumen: Versi 1.0 (Siap Eksekusi Development / AI Coding)

1. Latar Belakang & Konteks Masalah (Problem Statement)

Di lingkungan pondok pesantren, santri tidak diperbolehkan memegang uang tunai dalam jumlah besar untuk menghindari kehilangan, pemborosan, atau pencurian. Seluruh uang bulanan santri dititipkan kepada pengurus (pengelola).

Masalah Utama di Lapangan:

Pengambilan Harian yang Acak (Micro-Withdrawals): Santri memiliki kuota jatah harian (misal: setoran $\text{Rp } 300.000$ untuk $30$ hari = jatah $\text{Rp } 10.000/\text{hari}$). Namun, santri tidak mengambil $\text{Rp } 10.000$ sekaligus, melainkan dicicil secara acak (pagi $\text{Rp } 2.000$, siang $\text{Rp } 5.000$, malam $\text{Rp } 3.000$).

Beban Hitung Manual: Pengurus harus mencatat setiap transaksi kecil dan menghitung sisa kuota harian serta total sisa saldo bulanan secara manual di buku tulis atau Excel.

Antrean Santri: Saat jam istirahat, puluhan santri mengantre bersamaan. Pencatatan manual memakan waktu lama dan rawan salah hitung.

Kasus Khusus (Overlimit & Carry-Over): Sulit melacak santri yang kemarin tidak mengambil uang (apakah jatahnya hangus atau terakumulasi) dan santri yang izin mengambil melebihi batas harian untuk keperluan darurat (beli sabun, obat, kitab).

Solusi:
Aplikasi mobile Kas Santri dengan antarmuka super cepat (3-Tap Transaction) yang secara otomatis menghitung simulasi keluar-masuk uang, memantau kuota jatah harian secara real-time, dan menjaga kecocokan antara catatan aplikasi dengan total uang tunai fisik yang dipegang pengurus.

2. Logika Bisnis & Mesin Perhitungan (Core Financial Engine)

Agar aplikasi berjalan akurat, sistem harus menerapkan rumus perhitungan otomatis berikut:

A. Perhitungan Jatah Harian Dasar

Saat santri menyetorkan uang di awal periode:


$$J_{harian} = \frac{S_{awal}}{D_{hari}}$$


Keterangan:

$J_{harian}$ = Jatah maksimal per hari (contoh: $\text{Rp } 10.000$)

$S_{awal}$ = Total setoran awal (contoh: $\text{Rp } 300.000$)

$D_{hari}$ = Durasi hari dalam satu periode (default: $30$ hari)

B. Perhitungan Pengambilan Harian Bertahap (Multi-Withdrawal)

Dalam satu hari yang sama, santri dapat melakukan $n$ kali pengambilan ($P_1, P_2, \dots, P_n$).


$$T_{hari\_ini} = \sum_{i=1}^{n} P_i$$

$$Sisa_{jatah\_hari\_ini} = J_{harian} - T_{hari\_ini}$$

Contoh Simulasi:

Jatah Harian ($J_{harian}$) = $\text{Rp } 10.000$

Pagi ambil $P_1 = \text{Rp } 2.000 \rightarrow Sisa_{jatah\_hari\_ini} = \text{Rp } 8.000$

Siang ambil $P_2 = \text{Rp } 5.000 \rightarrow Sisa_{jatah\_hari\_ini} = \text{Rp } 3.000$

Malam ambil $P_3 = \text{Rp } 3.000 \rightarrow Sisa_{jatah\_hari\_ini} = \text{Rp } 0$ (Status: Limit Habis)

C. Perhitungan Sisa Saldo Total

$$Saldo_{akhir} = (S_{awal} + S_{susulan}) - \sum T_{seluruh\_hari}$$

D. Aturan Khusus (Edge Cases Logic)

Jika Santri Mengambil Melebihi Jatah Harian ($T_{hari\_ini} > J_{harian}$):

Sistem memunculkan peringatan (Warning Modal): "Pengambilan melebihi jatah harian sebesar Rp X. Apakah tetap diizinkan (Darurat/Kasbon Jatah)?"

Jika pengurus menekan "Izinkan", transaksi tetap tercatat, memotong $Saldo_{akhir}$, dan sistem memberikan opsi:

Opsi A (Potong Jatah Besok): Jatah hari berikutnya otomatis berkurang sebesar nominal kelebihan hari ini.

Opsi B (Hitung Ulang Rata-Rata): Jatah harian untuk sisa hari ke depan dihitung ulang secara proporsional:


$$J_{harian\_baru} = \frac{Saldo_{akhir}}{Sisa_{hari\_periode}}$$

Jika Jatah Hari Ini Tidak Habis ($Sisa_{jatah\_hari\_ini} > 0$):

Uang yang tidak diambil otomatis tetap tersimpan di $Saldo_{akhir}$ santri (tidak hilang).

Pengurus dapat mengatur mode di Pengaturan: Mode Ketat (besok jatah tetap $\text{Rp } 10.000$, sisa uang menjadi tabungan akhir bulan) atau Mode Akumulasi (sisa $\text{Rp } 3.000$ hari ini ditambahkan ke kuota besok menjadi $\text{Rp } 13.000$).

3. Spesifikasi Fitur Berdasarkan Fase Pengembangan

Struktur fitur di bawah ini mengikuti peta arsitektur sistem (Fase 1 hingga Fase 5) beserta pelengkap sub-fitur ke-4 pada setiap modul:

FASE 1: Catat Ambil Uang (Fitur Inti & Prioritas Kecepatan UX)

Fokus utama fase ini adalah kecepatan transaksi di bawah $5$ detik per santri saat antrean padat.

Pilih Santri Cepat:

Pencarian instan berbasis ketik nama/panggilan atau filter per Kamar/Asrama.

Menampilkan daftar santri yang paling sering/baru saja bertransaksi di urutan atas.

Input Nominal:

Numpad kustom berukuran besar yang nyaman ditekan satu tangan.

Menampilkan informasi real-time di atas numpad: Sisa Jatah Hari Ini dan Total Saldo.

Pintasan Nominal (Quick Chips):

Tombol sekali tekan untuk pecahan populer: +1.000, +2.000, +3.000, +5.000, +10.000, serta tombol Ambil Sisa Jatah Hari Ini.

Tombol pintasan dapat ditekan berkali-kali (misal: tekan +2.000 dua kali otomatis menjadi $\text{Rp } 4.000$).

Validasi Limit & Catatan Singkat (Sub-fitur ke-4):

Indikator warna otomatis saat mengetik nominal (Hijau = Aman, Kuning = Pas Limit, Merah = Melebihi Jatah Harian).

Tag keterangan opsional sekali klik: Jajan, Beli Sabun/Toiletries, Obat/Sakit, Fotokopi/Sekolah.

FASE 2: Daftar Santri & Monitoring Jatah Harian

Modul pengelolaan data santri dan panel kontrol kuota harian.

A. Modul Daftar Santri

Lihat Semua Santri: Daftar kartu santri yang menampilkan Nama, Kamar, Sisa Saldo Total, dan Progress Bar jatah hari ini.

Cari Santri: Pencarian real-time berdasarkan nama, nama panggilan, atau nomor kamar.

Tambah Santri Baru: Form ringkas (Nama Lengkap, Panggilan, Kamar/Kelas, Nama Wali, No. WhatsApp Wali, Jatah Harian Khusus jika berbeda dari default).

Kelola & Kelompokkan Kamar/Kelas (Sub-fitur ke-4): Fitur edit/nonaktifkan santri serta pengelompokan berdasarkan kamar agar pengurus mudah memfilter saat pembagian uang.

B. Modul Sisa & Jatah Harian

Jatah Harian: Menampilkan kuota standar harian santri (misal $\text{Rp } 10.000/\text{hari}$) beserta rincian sudah diambil berapa kali hari ini (contoh: "Hari ini sudah ambil 2x: Pagi 2rb, Siang 5rb").

Sisa Saldo: Menampilkan total uang santri yang masih tersimpan beserta estimasi cukup untuk berapa hari lagi ($\text{Estimasi Hari} = \lfloor \frac{Saldo_{akhir}}{J_{harian}} \rfloor$).

Status Hari Ini: Badge visual jelas pada setiap nama santri:

🟢 Utuh (Belum ambil hari ini)

🔵 Sebagian (Sudah ambil sebagian, masih ada sisa jatah hari ini)

🟡 Limit Habis (Jatah hari ini sudah $\text{Rp } 0$)

🔴 Overlimit / Saldo Kritis (Ambil melebihi jatah harian atau total saldo hampir habis)

Penyesuaian Kuota & Izin Darurat (Sub-fitur ke-4): Tombol khusus untuk memberikan izin pengambilan ekstra tanpa merusak catatan reguler.

FASE 3: Setoran Bulanan & Riwayat Transaksi

A. Modul Setoran Bulanan (Pemasukan)

Catat Setoran Baru: Input uang masuk di awal bulan dari orang tua/wali santri.

Hitung Jatah Otomatis: Kalkulator otomatis saat input setoran. Ketika pengurus memasukkan $\text{Rp } 300.000$ dan durasi $30$ hari, sistem langsung menampilkan $\text{Jatah Harian} = \text{Rp } 10.000$ (dapat diubah manual jika diinginkan).

Setoran Susulan (Top-Up Tengah Bulan): Fitur menambah saldo di tengah bulan. Sistem menanyakan apakah setoran susulan ini untuk menambah nominal jatah harian atau memperpanjang jumlah hari.

Pengaturan Periode & Sisa Saldo Bulan Lalu (Sub-fitur ke-4): Mengatur bagaimana sisa saldo bulan lalu ditangani (digabung ke bulan baru atau disimpan sebagai tabungan terpisah).

B. Modul Riwayat Transaksi

Riwayat per Santri: Buku mutasi digital lengkap per individu (Menampilkan Tanggal, Jam Pagi/Siang/Malam, Tipe Masuk/Keluar, Nominal, dan Sisa Saldo setelah transaksi).

Saring Tanggal: Filter transaksi berdasarkan Hari Ini, Kemarin, 7 Hari Terakhir, Bulan Ini, atau rentang tanggal khusus.

Detail Catatan: Melihat jam pasti pengambilan (penting jika santri lupa dan merasa belum mengambil uang siang tadi, pengurus bisa menunjukkan bukti jam pengambilan: "Kamu tadi sudah ambil Rp 5.000 jam 12:45 WIB").

Koreksi / Batalkan Transaksi (Sub-fitur ke-4): Fitur Edit atau Void/Batal jika pengurus salah klik nominal, disertai pengembalian saldo otomatis.

FASE 4: Rekap & Laporan (Audit Fisik & Pelaporan)

Rekap Harian: Total uang tunai yang keluar hari ini dari seluruh santri. Membantu pengurus mencocokkan uang di dompet/laci setiap malam.

Rekap Bulanan: Ringkasan total pemasukan setoran vs total pengeluaran seluruh santri dalam satu bulan.

Total Uang Titipan (Brankas Fisik): Angka indikator paling krusial di beranda yang menunjukkan Total Seluruh Sisa Saldo Santri Aktif. Jika angka di aplikasi tertulis $\text{Rp } 12.450.000$, maka uang tunai fisik/rekening yang dipegang pengurus harus berjumlah persis $\text{Rp } 12.450.000$.

Kirim Laporan ke Wali Santri / Export (Sub-fitur ke-4): Membuat kartu laporan mutasi bulanan santri dalam bentuk gambar/PDF atau pesan teks rapi yang bisa langsung dikirim ke WhatsApp orang tua santri dengan 1 klik.

FASE 5: Keamanan (Masuk & Kunci Aplikasi) & Pengaturan

A. Modul Masuk & Kunci Aplikasi

Masuk Akun: Autentikasi pengurus (mendukung mode lokal maupun sinkronisasi akun email/Google).

Kunci PIN / Biometrik: Sangat penting di lingkungan pondok agar ketika HP pengurus tergeletak di meja, santri tidak bisa membuka aplikasi dan mengubah saldo sendiri.

Keluar Akun: Fitur logout aman dengan peringatan jika ada data lokal yang belum dicadangkan.

B. Modul Pengaturan

Profil Pemilik: Nama Pondok/Asrama, Nama Pengurus/Musyrif, dan kontak yang akan tampil di kop laporan untuk orang tua.

Atur Jatah Default: Menentukan nilai standar pondok (misal: Default Jatah Harian = $\text{Rp } 10.000$, Default Durasi = $30$ Hari, dan Mode Sisa Jatah Harian = Ketat / Akumulasi).

Cadangkan & Pulihkan Data (Backup/Restore): Ekspor database ke file lokal (.json / .csv / .db) atau Google Drive agar data keuangan santri100% aman meskipun HP pengurus rusak atau berganti perangkat.

4. Alur Pengguna Utama (The "3-Tap" Fast Withdrawal Flow)

Pengalaman pengguna (UX) dirancang khusus untuk kondisi nyata di mana pengurus dikelilingi banyak santri yang meminta uang bersamaan:

Tap 1 (Pilih Santri): Dari halaman utama, pengurus mengetuk kartu nama santri (misal: "Ahmad - Kamar 2"). Bottom sheet transaksi langsung muncul tanpa pindah halaman.

Tap 2 (Pilih Nominal): Pengurus melihat status Ahmad: Sisa Jatah Hari Ini: Rp 8.000 (Sudah ambil pagi Rp 2.000). Ahmad minta $\text{Rp } 5.000$. Pengurus langsung mengetuk tombol pintasan 5.000.

Tap 3 (Simpan): Pengurus mengetuk tombol Simpan Ambil Uang.

Feedback Instan: Muncul notifikasi singkat "Berhasil! Sisa jatah Ahmad hari ini tinggal Rp 3.000" dan layar langsung siap untuk santri berikutnya.

5. Skema Database (Data Model / ERD)

Struktur tabel di bawah ini dirancang agar siap diimplementasikan menggunakan SQLite / Room / WatermelonDB (Offline-First) maupun Supabase / Firebase:

Tabel 1: santri

Nama Kolom

Tipe Data

Keterangan

id

UUID / TEXT

Primary Key

nama_lengkap

TEXT

Nama lengkap santri

nama_panggilan

TEXT

Untuk pencarian cepat

kamar

TEXT

Nama kamar / asrama / kelas

no_wa_wali

TEXT

Nomor WhatsApp orang tua (opsional)

saldo_total

INTEGER

Total sisa uang saat ini (dalam Rupiah)

jatah_harian

INTEGER

Nominal jatah per hari (misal: 10000)

status_aktif

BOOLEAN

true jika santri aktif

created_at

TIMESTAMP

Waktu pembuatan data

Tabel 2: setoran_bulanan (Pemasukan)

Nama Kolom

Tipe Data

Keterangan

id

UUID / TEXT

Primary Key

santri_id

UUID / TEXT

Foreign Key ke santri.id

nominal_setoran

INTEGER

Jumlah uang masuk (misal: 300000)

durasi_hari

INTEGER

Jumlah hari untuk setoran tersebut (misal: 30)

jatah_harian_hitung

INTEGER

Hasil bagi $\frac{\text{nominal}}{\text{durasi}}$

tipe_setoran

ENUM

AWAL_BULAN, SUSULAN_TOPUP

tanggal_setor

DATE

Tanggal uang diterima

catatan

TEXT

Keterangan tambahan (misal: "Titipan via transfer Ibu")

Tabel 3: transaksi_harian (Pengeluaran & Mutasi)

Nama Kolom

Tipe Data

Keterangan

id

UUID / TEXT

Primary Key

santri_id

UUID / TEXT

Foreign Key ke santri.id

nominal

INTEGER

Nominal pengambilan (misal: 2000, 5000, 3000)

waktu_ambil

TIMESTAMP

Tanggal dan jam presisi (untuk lacak pagi/siang/malam)

tanggal_lokal

DATE

Format YYYY-MM-DD untuk query rekap harian cepat

kategori_waktu

ENUM

Otomatis dari jam: PAGI, SIANG, SORE, MALAM

is_overlimit

BOOLEAN

true jika transaksi ini melebihi kuota harian saat itu

catatan

TEXT

Opsional (misal: "Beli obat", "Jajan")

Tabel 4: pengaturan_aplikasi

Nama Kolom

Tipe Data

Keterangan

id

INTEGER

Primary Key (Singleton = 1)

nama_pondok

TEXT

Nama Pondok / Asrama

nama_pengurus

TEXT

Nama pemegang kas

default_jatah_harian

INTEGER

Default 10000

default_durasi_hari

INTEGER

Default 30

mode_sisa_harian

ENUM

KETAT (Reset tiap hari) atau AKUMULASI (Tambah ke besok)

pin_keamanan

TEXT

Hash PIN 4-6 digit untuk kunci aplikasi

6. Rekomendasi Teknis & Kriteria Non-Fungsional

Arsitektur Offline-First (Wajib):

Di area pondok pesantren atau kamar asrama, sinyal internet sering kali tidak stabil. Aplikasi wajib berfungsi 100% tanpa internet menggunakan database lokal (seperti SQLite, Hive, Isar, atau IndexedDB jika berbasis Web/PWA). Sinkronisasi cloud hanya berjalan di latar belakang saat ada internet.

Kecepatan & Performa:

Perhitungan total pengambilan hari ini ($\sum P_i$) harus menggunakan indexing pada kolom santri_id dan tanggal_lokal sehingga meski sudah ada puluhan ribu baris transaksi selama setahun, aplikasi tetap merespons di bawah $100\text{ ms}$.

Pencegahan Kesalahan Input (Human-Error Guard):

Format angka otomatis menggunakan pemisah ribuan titik (Rp 10.000) saat mengetik agar pengurus tidak salah memasukkan jumlah nol (misal berniat mengetik $\text{Rp } 5.000$ tetapi tertulis $\text{Rp } 50.000$).

Fitur Undo (Batalkan) selama $5$ detik di bagian bawah layar setiap kali selesai menyimpan transaksi pengambilan uang.

---

## 7. PANDUAN BUILD CI/CD & GIT PUSH YANG BENAR & BERHASIL

Untuk memastikan proses build APK di GitHub Actions dan update repository Git selalu berhasil tanpa kegagalan:

### A. Spesifikasi Kompatibilitas Versi (Flutter 3.50.1+)
1. **Android Gradle Plugin (AGP):** `9.3.1` (didefinisikan di `android/settings.gradle` pada plugin `id "com.android.application" version "9.3.1" apply false`).
2. **Gradle Wrapper:** `9.5.0` (didefinisikan di `android/gradle/wrapper/gradle-wrapper.properties` sebagai `distributionUrl=https\://services.gradle.org/distributions/gradle-9.5.0-all.zip`).
3. **Kotlin Version:** `2.4.20` (didefinisikan di `android/settings.gradle` pada plugin `id "org.jetbrains.kotlin.android" version "2.4.20" apply false`).
4. **Java Version:** `Java 17` (`actions/setup-java@v4` with `java-version: '17'`).
5. **SDK Targets:** `compileSdk = 36`, `targetSdk = 36`, `minSdkVersion = 24`.
6. **BuildConfig Configuration:**
   - Gunakan `buildFeatures { buildConfig = true }` di dalam block `android { ... }` pada `android/app/build.gradle`.
   - **JANGAN** gunakan flag usang `android.defaults.buildfeatures.buildconfig=true` di `android/gradle.properties` karena menyebabkan build gagal pada AGP 9+.

### B. Konfigurasi CI/CD GitHub Actions (`.github/workflows/build-apk.yml`)
Workflow GitHub Actions wajib menangani pembentukan wrapper otomatis bila file binari `android/gradlew` belum ada:
```yaml
name: Build APK Release

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Java 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Ensure Android Gradle Wrapper Exists
        run: |
          if [ ! -f "android/gradlew" ]; then
            echo "Generating android wrapper files via flutter create..."
            flutter create --platforms=android .
            rm -f android/settings.gradle.kts android/app/build.gradle.kts
          fi
          chmod +x android/gradlew

      - name: Get Dependencies
        run: flutter pub get

      - name: Build APK Release
        run: flutter build apk --release --no-tree-shake-icons --android-skip-build-dependency-validation

      - name: Upload APK Artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

### C. Prosedur Git Commit & Push yang Benar
1. Gunakan path eksekusi Git: `C:\Users\smkit\AppData\Local\Programs\Git\cmd\git.exe` (atau `git` jika sudah ada di PATH).
2. Perintah commit dan push harus dijalankan dengan hak akses jaringan/bypass sandbox (`BypassSandbox: true`):
   ```bash
   git add -A
   git commit -m "feat: [deskripsi pembaruan]"
   git push origin main
   ```
3. Pantau tab **Actions** di repositori GitHub untuk memastikan workflow `assembleRelease` selesai 100% hijau dan file `app-release.apk` siap diunduh di bagian Artifacts.
