# Product Requirements Document (PRD): Aplikasi Kas-Santri

> [!IMPORTANT]
> **ATURAN WAJIB PEMELIHARAAN PRD (STANDING RULE):**
> Setiap kali ada penambahan fitur baru, perubahan arsitektur/skema database, perubahan aturan bisnis, pembaruan keamanan, atau perubahan konfigurasi build/CI/CD di masa mendatang, agen AI / pengembang **WAJIB** memperbarui dokumen `prd.md` ini pada commit yang sama agar `prd.md` selalu 100% sinkron dengan kondisi aktual kode sumber (*Single Source of Truth*).

- **Nama Produk:** Kas-Santri (Sistem Manajemen Uang Saku, Titipan, Tabungan Terpisah, Tunggakan & Infak Santri Terpadu)
- **Versi Rilis Aktif:** `v4.3.0+43` (`AppConfig.appVersion = '4.3.0'`)
- **Platform:** Mobile App Android (Flutter — Offline-First + Cloud Backup Online) untuk distribusi Direct APK (DANA/QRIS) dan Google Play Store (`.aab`)
- **Target Pengguna:** Pengurus Pondok, Musyrif/Musyrifah, Bendahara Asrama, Bendahara Infak, atau Wali Kamar di seluruh Pondok Pesantren
- **Tema Visual Utama:** *Dark Translucent Aurora Glassmorphism v4.3* (Obsidian Dark `#090D16`, Emerald `#10B981`, Royal Gold `#F59E0B`, dengan 1 Global `AppBackgroundWrapper` + Tata Letak Tombol Kartu 2 Kotak)
- **Pengembang:** Moch Khoirul Azman *(Dibuat: Senin, 23 November 2026 • 09:00 WIB — Kredensial Pengembang Netral tanpa nama pondok tertentu)*
- **Repositori Utama:** https://github.com/mochkhoirulazman-max/kas-santri.git (Workspace: `project antigrafity`)
- **Status Dokumen:** **Versi 4.3 Final Master** (Brankas Tabungan Terpisah Kantong Kas Ke-4 SQLite v5, Backup Hybrid SAF Lokal `.ksbak` & Cloud Backup Online AES-256, Tutorial Sorotan Kontekstual 16 Layar Anti-Mengganggu, Smooth 60–120 FPS, Strict PRO Gating `hasProAccess`, Rekonsiliasi Akuntansi 100%, Modular Repository Architecture, Ed25519 License + Admin Command Center, & Standar CI/CD AGP 9.3.1)

---

## 1. Latar Belakang & Konteks Masalah (Problem Statement)

Di lingkungan pondok pesantren, santri tidak diperbolehkan memegang uang tunai dalam jumlah besar untuk menghindari kehilangan, pemborosan, atau pencurian. Selain mengelola uang jajan harian, bendahara pondok juga mengurus **Infak Bulanan (Masak/Makan, Listrik, dan Beras)** yang sering kali dititipkan sekaligus oleh orang tua saat menjenguk (*sambangan*).

### Masalah Utama di Lapangan
1. **Pengambilan Harian yang Acak (*Micro-Withdrawals*):** Santri mengambil jatah harian secara dicicil acak (pagi Rp 2.000, siang Rp 5.000, malam Rp 3.000), sehingga pencatatan buku kertas rawan salah hitung saat antrean padat.
2. **Pembagian Amplop Sambangan (*Split Payment*) yang Rumit:** Saat wali santri menjenguk dan menitipkan uang total (misal Rp 500.000), bendahara harus memecahnya untuk Infak Masak (Rp 130.000), Infak Listrik (Rp 20.000), Infak Beras (baik berupa fisik 15 Liter maupun uang pengganti Rp 150.000), memotong tunggakan, lalu memasukkan sisanya ke Saldo Uang Jajan.
3. **Pencatatan Buku Infak Kertas Rawan Salah & Sulit Direkap:** Bendahara harus membuka 3 buku terpisah (Santriyin, Santriyat, Santri Baru), menandai santri pulang/pindah dengan stabilo hijau, rawan salah tulis Tgl Habis (+1 bulan), serta kesulitan memisahkan total beras fisik (Liter) vs uang beras (Rupiah).
4. **Campur Aduk Kantong Uang:** Tanpa pemisahan tegas antara Titipan Uang Jajan Santri, Kas Infak Pondok (yang harus disetor ke Dapur/Yayasan), Kas Laci Tunai, dan Saldo Rekening Bank, bendahara rentan mengalami selisih saat tutup kas malam (*Cash Opname*).
5. **Kasus Khusus (*Overlimit*, *Carry-Over* & Tunggakan):** Sulit melacak santri yang mengambil melebihi batas harian, akumulasi jatah sisa kemarin, serta tunggakan/talangan administrasi.

### Solusi Kas-Santri v4.3 PRO
Aplikasi mobile **Kas-Santri v4.3 PRO** dengan antarmuka super cepat (*3-Tap Transaction* di bawah 5 detik dan Scan QR 1 detik), *Smart Split Setoran Sambangan*, *Buku Infak Bulanan Digital* (Santriyin, Santriyat, Santri Baru), **Brankas Tabungan Terpisah (Kantong Kas Ke-4)** yang diisolasi total agar tidak ikut terpotong jajan harian, **Backup Lokal `.ksbak` Berbasis SAF & Cloud Backup Online Terenkripsi AES-256**, **Tutorial Sorotan Kontekstual pada 16 Layar/Menu** dengan mode anti-mengganggu (`seen_tour_<screenKey>`), rekonsiliasi 4 kantong kas presisi 0 selisih, verifikasi fisik *Cash Opname*, serta ekspor laporan PDF/Excel resmi berkop logo pondok yang berjalan mulus 60–120 FPS (`compute()` isolate).

---

## 2. Logika Bisnis & Mesin Perhitungan (Core Financial Engine)

### A. Perhitungan Jatah Harian Dasar & Pembulatan Tunai Otomatis
Saat santri menyetorkan uang bersih $S_{bersih}$ untuk durasi $D_{hari}$ (default: $30$ hari), dengan opsi pemotongan tunggakan $P_{tunggakan}$:

$$S_{bersih} = S_{awal} - P_{tunggakan}$$

Hasil bagi dibulatkan ke bawah (*floor*) pada kelipatan pecahan tunai $K$ (default $K = \text{Rp } 500$ atau dapat diatur ke $K = \text{Rp } 1.000$ di Pengaturan):

$$J_{harian} = \left\lfloor \frac{S_{bersih}}{D_{hari} \times K} \right\rfloor \times K$$

- Selisih pembulatan tidak hangus dan tetap tersimpan utuh di $Saldo_{akhir}$ santri.
- Pada **Top-Up / Setoran Susulan**, `jatah_harian` santri otomatis diperbarui apabila kalkulator menghasilkan nominal `jatahHarianBaru > 0` (atau dapat dipertahankan manual oleh bendahara).
- Saat menambah **Santri Baru**, saldo awal otomatis dimulai dari `Rp 0` agar seluruh pemasukan uang tercatat rapi melalui modul **Setoran & Sambangan** dan terekam di `mutasi_dompet`.

### B. Perhitungan Pengambilan Harian Bertahap (*Multi-Withdrawal*)
Dalam satu hari yang sama, santri dapat melakukan $n$ kali pengambilan ($P_1, P_2, \dots, P_n$):

$$T_{hari\_ini} = \sum_{i=1}^{n} P_i, \qquad Sisa_{jatah\_hari\_ini} = J_{efektif\_hari\_ini} - T_{hari\_ini}$$

### C. Perhitungan Sisa Saldo Total & Estimasi Ketahanan Hari

$$Saldo_{akhir} = (S_{awal} + S_{susulan} - P_{tunggakan}) - \sum T_{seluruh\_hari}$$

$$\text{Estimasi Hari} = \left\lfloor \frac{Saldo_{akhir}}{J_{harian}} \right\rfloor$$

Jika $\text{Estimasi Hari} < 3$, santri otomatis masuk kategori **Saldo Kritis**.

### D. Aturan Khusus (*Edge Cases Logic*) & Rekonsiliasi Akuntansi v4.2
1. **Pengambilan Melebihi Jatah Harian ($T_{hari\_ini} > J_{efektif\_hari\_ini}$):** Memunculkan *Warning Modal* izin darurat dengan pilihan:
   - **Opsi A (`OverlimitHandling.potongBesok`):** Kelebihan pengambilan hari ini otomatis memotong kuota `jatahHariIni` santri pada hari berikutnya (`computeEffectiveDailyQuotaMap`).
   - **Opsi B (`OverlimitHandling.hitungUlangRataRata`):** Menghitung ulang `jatah_harian` berdasarkan sisa hari periode aktual dari `setoran_bulanan` terakhir santri:
     $$J_{harian\_baru} = \left\lfloor \frac{Saldo_{akhir}}{Sisa_{hari\_periode\_aktual} \times K} \right\rfloor \times K$$
2. **Mode Sisa Jatah Harian (`ModeSisaHarian.ketat` vs `ModeSisaHarian.akumulasi`):**
   - **Mode Ketat (Default):** Sisa kuota hari ini tetap tersimpan di $Saldo_{akhir}$, dan kuota besok kembali ke $J_{harian}$ standar (dikurangi potongan overlimit kemarin jika ada).
   - **Mode Akumulasi:** Sisa kuota kemarin yang tidak diambil ($J_{harian} - T_{kemarin} > 0$) otomatis ditambahkan ke kuota `jatahHariIni` hari berikutnya (dibatasi maksimal `saldoTotal`).
3. **Rekonsiliasi Ketat `editTransaksi()`, `voidTransaksi()`, dan `deleteSantri()` (0 Selisih Brankas vs Dompet):**
   - **`editTransaksi()`:** Menolak transaksi yang sudah `isVoided` atau `newNominal <= 0`, otomatis mengonversi kekurangan saldo menjadi `tunggakan` (`TALANGAN_SALDO`) agar `saldo_total` tidak pernah negatif, dan memperbarui/mencatat jurnal penyesuaian di `mutasi_dompet`.
   - **`voidTransaksi(TipeTransaksi.setoran)`:** Memulihkan potongan tunggakan (`nominal_potong_tunggakan`), menandai void pada `setoran_bulanan`, mencatat mutasi penyeimbang `KELUAR` di `mutasi_dompet`, dan apabila sebagian saldo setoran sudah terlanjur dipakai jajan (`saldo_total < nominal_bersih`), otomatis mencatat selisih yang terpakai sebagai `tunggakan` (`TALANGAN_SALDO`) dengan peringatan konfirmasi jelas di UI.
   - **`deleteSantri()` (Opsi Hybrid Aman):** Menyediakan pilihan utama **"Arsipkan sebagai Boyong/Lulus"** jika santri memiliki saldo/riwayat. Jika bendahara tetap memilih **Hapus Permanen** saat `saldo_total > 0`, sistem menampilkan dialog konfirmasi nominal pengembalian saldo lalu otomatis mencatat mutasi penyeimbang `KELUAR` di `mutasi_dompet` (default `TUNAI`) serta `audit_log` agar `totalBrankasFisik == kasLaciTunai + rekeningBank` tetap 100% seimbang.

### E. Logika Smart Split Setoran Sambangan (Infak + Uang Jajan)
Saat wali menitipkan total uang $U_{total}$ (contoh: $\text{Rp } 500.000$) dalam satu kali sambangan/transfer:

$$I_{uang} = I_{masak} + I_{listrik} + I_{beras\_uang}$$

$$S_{jajan} = U_{total} - (I_{uang} + P_{tunggakan})$$

- **Tarif Default Awal Pondok (dapat diubah bebas di Pengaturan):**
  - Infak Masak / Makan Bulanan: `Rp 130.000`
  - Infak Listrik: `Rp 20.000`
  - Infak Beras Fisik: `15 Liter` (jika bawa beras fisik, maka $I_{beras\_uang} = \text{Rp } 0$)
  - Infak Beras Pengganti Uang: `Rp 150.000`
- **Perhitungan Otomatis Tgl Habis (*Rolling Date*):** `tgl_habis` otomatis dihitung $+1$ bulan kalender dari `tgl_masuk` (contoh: `18-11-2026` -> `18-12-2026`).
- **Penentuan Otomatis Status Infak:** `LUNAS`, `CICIL`, atau `BELUM`.

### F. Akuntansi 4 Kantong Kas & Verifikasi Cash Opname Terpadu (v4.3)
1. **Kantong 1 — Brankas Titipan Uang Jajan Santri ($\text{Rp}$):** $\sum Saldo_{akhir,\text{santri}}$ (terpecah menjadi Kas Laci Tunai dan Rekening Bank).
2. **Kantong 2 — Kas Infak Pondok Belum Disetor ($\text{Rp}$):**
   $$\text{Saldo Kas Infak} = \sum I_{uang,\text{masuk}} - \sum \text{Serah Terima ke Dapur/Yayasan}$$
3. **Kantong 3 — Catatan Gudang Beras Fisik ($\text{Liter}$):** Total akumulasi liter beras fisik dikurangi serah terima beras fisik ke dapur.
4. **Kantong 4 — Brankas Tabungan Terpisah ($\text{Rp}$, Baru v4.3):** $\sum Saldo_{tabungan,\text{santri}}$ (simpanan darurat, tabungan pulang/lebaran, kitab/ziarah) yang **100% terisolasi** dari pengambilan jajan harian (`catatPengambilan` tidak pernah menyentuh `saldo_tabungan`), terpecah menjadi **Tabungan Tunai** vs **Tabungan Rekening** serta mendukung transfer 1-ketuk antar jajan <-> tabungan dan Void aman.
5. **Verifikasi Tutup Kas Malam (*Cash Opname* 4 Kantong):**
   $$\text{Target Uang Fisik di Laci} = \text{Kas Laci Tunai (Uang Jajan)} + \text{Kas Infak Tunai Belum Disetor} + \text{Tabungan Tunai Santri}$$
   $$\Delta_{selisih} = \text{Total Uang Fisik di Laci} - \text{Target Uang Fisik di Laci}$$

---

## 3. Spesifikasi Fitur Lengkap & Gerbang Ketat PRO (`hasProAccess`)

### A. Gerbang Terpusat `SubscriptionService.hasProAccess`
Seluruh pengecekan fitur premium wajib melalui satu getter terpusat:
```dart
bool get hasProAccess => isProActive || isTrialActive;
```
- Tombol simulasi debug PRO (`toggleDebugPro`) **DILARANG** tampil atau aktif pada *release build* (`if (!kDebugMode) return;`).
- Pada mode **Gratis (Free)** saat Uji Coba 14 Hari belum diaktifkan atau sudah berakhir, **10 kelompok fitur PRO** berikut wajib terkunci rapat (menampilkan badge `🔒 PRO` / `👑` dan mengarahkan ke `PaywallScreen`):
  1. **Tambah Santri ke-16 ke atas** (maksimal 15 santri aktif di mode Gratis, termasuk saat Import Excel maupun pengaktifan kembali santri arsip).
  2. **Multi-Dompet (Rincian Kas Laci Tunai vs Rekening Bank, Tombol Tarik Bank ke Laci, & Chip Input `🏦 Rekening Bank`)** di `SafeVaultCard`, `SetoranScreen`, `InfakEditBottomSheet`, dan `TunggakanBottomSheet`.
  3. **Kalkulator Cash Opname Pecahan Fisik.**
  4. **Scan QR Kartu Santri & Cetak Massal / Satuan Kartu QR PDF** (termasuk di `QuickEditSantriBottomSheet` dan `SantriDetailScreen`).
  5. **Ekspor Excel (`.xlsx`) & PDF Resmi** (di Riwayat Mutasi, Rekap WA, Buku Infak, dan Buku Mutasi Individu `SantriDetailScreen`).
  6. **Kirim WA 1-Klik, Bagikan Struk Gambar PNG bebas watermark, Filter Saldo Kritis (`< 3 Hari`), & Filter Jatuh Tempo Infak (`<= 3 Hari`).**
  7. **Upload Logo Kustom Pondok, Kunci Aplikasi PIN & Biometrik, serta Backup Cloud Google Drive & Backup Terenkripsi `.KSBAK` (AES-256-GCM).**
  8. **Dashboard Analitik Eksekutif Yayasan (`ExecutiveDashboardScreen`).**
  9. **Pusat Antrean Pengingat WA Cerdas (`SmartWaReminderScreen`).**
  10. **Manajemen Tahun Ajaran & Pindah Kamar Massal (`TahunAjaranScreen`) serta Log Audit Keamanan SHA-256 (`AuditLogScreen`).**

### B. Rincian Modul Utama (Fase 1 s.d. Fase 10)
- **Beranda & Pencairan Cepat 3-Tap (`HomeFastWithdrawalScreen`):**
  - Header pondok netral multi-pondok (default `'Nama Pondok'`), jam lokal real-time, ikon Mahkota PRO (`👑`) dengan animasi terisolasi `RepaintBoundary` (otomatis berhenti saat status PRO aktif untuk menghemat GPU).
  - `SafeVaultCard` dengan tombol privasi saldo, rincian Multi-Dompet, pintasan `🌾 Buku Infak`, `Scan QR`, pencarian instan, filter status/kamar, serta grid 2-kolom / 1-baris kartu santri (`SantriCard` dengan `ResizeImage` 180px tanpa `existsSync()` di `build()`).
  - Toast Undo 5 detik (`UndoToastOverlay`) yang dikendalikan oleh `ValueNotifier<UndoState?>` terisolasi sehingga countdown 1 detik **tidak pernah** memicu `notifyListeners()` global pada 4 tab `PageView`.
- **Buku Mutasi Lengkap Individu (`SantriDetailScreen` — Reconnected v4.2):**
  - Dapat dibuka langsung dari tombol **"📄 Lihat Buku Mutasi Lengkap"** di dalam `QuickEditSantriBottomSheet` maupun `RekapLaporanScreen`.
  - Menampilkan profil & metrik lengkap santri, aksi cepat (Ambil Uang, Setoran/Sambangan, Kelola Tunggakan, Edit Profil, Cetak Kartu QR PRO, Cetak PDF Mutasi PRO, dan Arsip/Hapus Santri Hybrid), serta tab riwayat transaksi & setoran lengkap dengan Void berperingatan rekonsiliasi.
- **Setoran Bulanan, Smart Split Sambangan & Buku Infak (`SetoranScreen` & `BukuInfakView`):**
  - 2 sub-tab terpadu: `💸 Input Setoran` (Top-Up Uang Jajan & Smart Split Sambangan) dan `🌾 Buku Infak` (monitoring infak bulanan Santriyin/Santriyat/Santri Baru, edit cicilan infak dengan audit log `EDIT_INFAK_MANUAL`, Serah Terima ke Dapur/Yayasan, dan ekspor PDF/Excel 4-Sheet).
- **Brankas Tabungan Terpisah (`BrankasTabunganScreen` — Baru v4.3):**
  - Dapat diakses langsung dari `SafeVaultCard` di Beranda, tab `Sistem` (Akses Cepat Pengurus), maupun `SantriDetailScreen`.
  - Menyediakan Setor Tabungan, Tarik Tabungan, Pindah Buku Jajan <-> Tabungan, filter penabung aktif, sembunyikan saldo, serta riwayat mutasi tabungan khusus dengan fitur Void aman (`voidTransaksiTabungan`).
- **Backup Lokal Terenkripsi SAF & Cloud Backup Online (`EncryptedBackupHelper` & `CloudBackupService` — Diperbaiki & Diperluas v4.3):**
  - Simpan file `.ksbak` (AES-256-GCM + PBKDF2 60.000 iterasi) langsung ke folder pilihan Android melalui Storage Access Framework (`FilePicker.platform.saveFile`), dilengkapi fallback `Downloads` / `ApplicationDocumentsDirectory` dan Share Sheet + dialog loading yang selalu tertutup aman (`finally`). Pemulihan `.ksbak` memakai `FileType.any` + validasi ekstensi agar kompatibel di Android 11–16 tanpa error MIME.
  - Cloud Backup Online tanpa login Google OAuth (`app_cloud_backups` via Supabase RPC) dengan enkripsi **AES-256 di sisi perangkat** sebelum diunggah.
- **Onboarding Multi-Pondok & Tutorial Sorotan Kontekstual 16 Layar (`ScreenSpotlightHost` + `SpotlightHelpButton` — Baru v4.3):**
  - Saat instalasi pertama, menyapa pengguna dengan slide onboarding dan form Setup Cepat Identitas Pondok.
  - Seluruh **16 halaman & menu fitur** (`tour_home`, `tour_setoran`, `tour_buku_infak`, `tour_mutasi`, `tour_rekap`, `tour_sistem`, `tour_tabungan`, `tour_settings`, `tour_opname`, `tour_santri_detail`, `tour_executive`, `tour_wa_reminder`, `tour_cetak_qr`, `tour_import_excel`, `tour_tahun_ajaran`, `tour_audit_log`) kini dibungkus `ScreenSpotlightHost` murni `CustomPainter` (`OverlayEntry` di rootOverlay tanpa `BackdropFilter`).
  - **Anti-Mengganggu:** Otomatis muncul maksimal 1x saat layar dibuka pertama kali (`seen_tour_<screenKey>`), memiliki kontrol 1-ketuk **"🔕 Matikan tutorial otomatis di semua menu"**, switch kontrol di `Pengaturan` & `PanduanAplikasiSheet`, tombol **"🔄 Reset & Putar Ulang Semua Tutorial Sorotan"**, serta ikon bantuan kaca neon **`?` (`SpotlightHelpButton`)** di header/AppBar setiap menu.

---

## 4. Arsitektur Modular v4.3 (Facade & Repository Pattern)

Untuk menjaga *maintainability* jangka panjang dan mencegah *God Classes* tanpa merusak pemanggil yang sudah ada (*Zero Regression*), lapisan data, backup, dan ekspor dipecah secara modular dengan pola **Facade + Repository**:

1. **Lapisan Database SQLite (`lib/database/`):**
   - `lib/database/database_helper.dart` (**Public Facade** — mempertahankan 100% tanda tangan metode `DatabaseHelper.instance`).
   - `lib/database/schema_migrator.dart`: DDL pembuatan 11 tabel, indeks performa, migrasi aman v1->v5 (`saldo_tabungan` + `transaksi_tabungan`), `PRAGMA foreign_keys = ON`, dan backfill QR/hash.
   - `lib/database/repositories/santri_repository.dart`: CRUD santri, filter, pindah kamar massal, tutup buku tahun ajaran, dan penghapusan santri hybrid berpenyeimbang `mutasi_dompet` + cleanup mutasi tabungan.
   - `lib/database/repositories/ledger_repository.dart`: Mesin transaksi `catatPengambilan`, `catatSetoranBaru`, `catatSambanganSmartSplit`, `editTransaksi`, `voidTransaksi`, manajemen tunggakan, batch query `getAllTransaksiPengambilanHariIniMap`, agregasi SQL `getSaldoDompet`, tarik tunai bank ke laci, dan `cash_opname_logs`.
   - `lib/database/repositories/infak_repository.dart`: CRUD `infak_santri`, `serah_terima_infak`, dan agregasi SQL `getSaldoKantongInfak`.
   - `lib/database/repositories/tabungan_repository.dart` (**Baru v4.3**): Transaksi atomik Brankas Tabungan Terpisah (`setorTabungan`, `tarikTabungan`, `transferJajanKeTabungan`, `transferTabunganKeJajan`, `voidTransaksiTabungan`, `getTransaksiTabungan`, dan agregasi SQL `getSaldoBrankasTabungan`).
   - `lib/database/repositories/backup_audit_repository.dart`: Pengaturan aplikasi, akun bendahara, rantai hash `audit_log`, `dumpBackupJson` (11 tabel), `restoreFromJson` (mendukung kompatibilitas mundur backup lama tanpa `transaksi_tabungan` + anti-elevasi `is_pro`/`has_used_trial`), dan `seedDemoData`.
2. **Lapisan Ekspor & Backup Hybrid (`lib/services/` & `lib/widgets/`):**
   - `lib/services/yayasan_export_service.dart` (**Public Facade** & model data laporan).
   - `lib/services/exports/yayasan_excel_exporter.dart`: Pembuatan workbook Excel Yayasan 3-Sheet & Buku Infak 4-Sheet di dalam background isolate `compute()`.
   - `lib/services/exports/yayasan_pdf_exporter.dart`: Generator dokumen PDF Resmi Yayasan & Buku Infak berkop logo pondok.
   - `lib/services/cloud_backup_service.dart` & `lib/widgets/encrypted_backup_helper.dart`: Enkripsi `.ksbak` berbasis isolate + SAF lokal + Cloud Backup Online AES-256 via Supabase RPC.

---

## 5. Skema Database SQLite Offline-First (11 Tabel — Versi Skema 5)

Koneksi SQLite wajib mengaktifkan `PRAGMA foreign_keys = ON;` pada callback `onConfigure` dan menjalankan migrasi skema secara deterministik pada `onUpgrade`.

| No | Nama Tabel | Fungsi Utama & Kolom Kunci |
|---:|---|---|
| 1 | `santri` | Profil & saldo santri (`id`, `qr_code`, `nama_lengkap`, `nama_panggilan`, `kategori_santri`, `status_santri`, `kamar`, `foto_path`, `nama_wali`, `no_wa_wali`, `saldo_total`, **`saldo_tabungan` [v5]**, `jatah_harian`, `tunggakan`, `status_aktif`, `created_at`, `updated_at`). |
| 2 | `setoran_bulanan` | Riwayat setoran & Smart Split (`id`, `santri_id`, `nominal_setoran`, `nominal_potong_tunggakan`, `nominal_bersih`, `durasi_hari`, `jatah_harian_hasil`, `tipe_setoran`, `sumber_dompet`, `catatan`, `tanggal_setor`). |
| 3 | `transaksi_harian` | Mutasi keluar/masuk harian (`id`, `santri_id`, `nominal`, `saldo_sebelum`, `saldo_sesudah`, `tipe`, `waktu_ambil` **[kolom urutan utama]**, `tanggal_lokal`, `kategori_waktu`, `tag_keperluan`, `catatan`, `operator_nama`, `is_overlimit`, `overlimit_handling`, `is_void`, `alasan_void`, `sumber_dompet`). |
| 4 | `tunggakan_log` | Riwayat tambah/bayar/potong/talangan tunggakan (`id`, `santri_id`, `nominal`, `tipe`, `sumber_dompet`, `catatan`, `tanggal`). |
| 5 | `mutasi_dompet` | Buku besar Kas Laci Tunai vs Rekening Bank (`id`, `jenis_dompet`, `tipe`, `nominal`, `kategori`, `referensi_id`, `catatan`, `tanggal`). |
| 6 | `cash_opname_logs` | Riwayat audit pecahan uang fisik laci (`id`, `tanggal_lokal`, `waktu_simpan`, `total_fisik`, `saldo_sistem_tunai`, `selisih`, `rincian_pecahan_json`, `catatan`, `operator_nama`). |
| 7 | `pengaturan_aplikasi` | Konfigurasi singleton (`id = 1`, `nama_pondok` default `'Nama Pondok'`, `tahun_ajaran`, `nama_pengurus`, `no_wa_pengurus`, `logo_path`, `jatah_harian_default`, `durasi_default_hari`, `kelipatan_pembulatan`, `mode_sisa_harian`, `mode_sisa_bulan_lalu`, `tarif_infak_*`, `pin_hash`, `is_pin_enabled`, `is_biometric_enabled`, `is_pro`, `pro_plan`, `has_used_trial`, `trial_start_date`, `last_backup_date`). |
| 8 | `infak_santri` | Buku Infak bulanan per santri (`id`, `santri_id`, `periode_bulan`, `tahun_ajaran`, `nominal_masak`, `is_masak_bebas`, `nominal_listrik`, `is_listrik_bebas`, `jenis_beras`, `beras_liter`, `beras_uang`, `tgl_masuk`, `tgl_habis`, `status_lunas`, `sumber_dompet`, `setoran_id`, `catatan`, `updated_at`). |
| 9 | `serah_terima_infak` | Berita acara penyerahan uang infak/beras ke Dapur/Yayasan (`id`, `tanggal_serah`, `periode_bulan`, `pos_infak`, `sumber_dompet`, `nominal_uang`, `jumlah_beras_liter`, `penerima`, `catatan`, `created_at`). |
| 10 | `audit_log` | Jejak audit keamanan *append-only* berantai SHA-256 (`id`, `timestamp`, `actor`, `action`, `target_id`, `summary`, `prev_hash`, `entry_hash`). |
| 11 | `transaksi_tabungan` | Buku besar Brankas Tabungan Terpisah v5 (`id`, `santri_id`, `tipe` [`SETOR`/`TARIK`/`TRANSFER_DARI_JAJAN`/`TRANSFER_KE_JAJAN`], `nominal`, `sumber_dompet`, `saldo_tabungan_setelah`, `tanggal_lokal`, `catatan`, `is_void`, `created_at`). |

**Indeks Performa Wajib:**
- `idx_transaksi_santri_tanggal ON transaksi_harian (santri_id, tanggal_lokal)`
- `idx_transaksi_waktu ON transaksi_harian (waktu_ambil DESC)`
- `idx_infak_periode_santri ON infak_santri (periode_bulan, santri_id)`
- `idx_serah_terima_periode ON serah_terima_infak (periode_bulan, tanggal_serah DESC)`
- `idx_audit_log_ts ON audit_log (timestamp DESC)`
- `idx_mutasi_dompet_jenis_tipe ON mutasi_dompet (jenis_dompet, tipe)`
- `idx_mutasi_dompet_ref ON mutasi_dompet (referensi_id)`
- `idx_tx_tabungan_santri ON transaksi_tabungan (santri_id, tanggal_lokal, is_void)`

---

## 6. Keamanan, Lisensi Ed25519, Kepatuhan Play Store & Admin Command Center

1. **Lisensi Offline Asimetris Ed25519 (`LicenseService`):**
   - Kode aktivasi berformat `KSPRO-<PAYLOAD_B32>-<SIGNATURE_B32>` diverifikasi secara offline menggunakan kunci publik Ed25519.
   - Kunci publik produksi dapat disuntikkan saat kompilasi melalui `--dart-define=KAS_SANTRI_ED25519_PUBKEY=<BASE64_32_BYTE_PUBKEY>` (dengan fallback aman untuk unit test CI).
   - Generator lisensi HTML warisan berbasis SHA-256 **telah dihapus permanen** dan digantikan sepenuhnya oleh **Admin Command Center (`admin_dashboard/index.html`)** berbasis Ed25519 yang dilengkapi proteksi *Subresource Integrity* (SRI `sha384-...`) dan *Content Security Policy* (CSP).
2. **Proteksi Anti-Tamper Backup & Jam Perangkat:**
   - `restoreFromJson()` memblokir manipulasi status `is_pro`, `pro_plan`, `has_used_trial`, dan `trial_start_date` dari file `.json` luar, diikuti pemanggilan `syncSubscriptionEntitlement()` ke `SubscriptionService`.
   - Enkripsi/dekripsi `.ksbak` (PBKDF2-HMAC-SHA256 60.000 iterasi + AES-256-GCM) berjalan di background isolate `compute()`.
3. **Kepatuhan Penuh Google Play Store (`PLAY_STORE_BUILD=true`):**
   - Menyembunyikan seluruh UI/teks pembayaran DANA & aktivasi kode luar baik di `PaywallScreen` maupun di dalam `LegalDocumentSheet.showTerms`.
   - `CustomerSyncService` menonaktifkan pengiriman *Personal Identifiers* (`nama_bendahara` dan `no_wa` dikosongkan) pada build Google Play Store agar 100% patuh terhadap deklarasi *Google Play Data Safety*, serta disinkronkan penuh dengan `docs/privacy.html`.
   - Seluruh aset gambar bawaan (`assets/wallpapers/default_wallpaper.jpg`) 100% bebas watermark pihak ketiga.

4. **Cloud Backup Online Terenkripsi (`app_cloud_backups` & `CloudBackupService` — v4.3):**
   - Mendukung pencadangan otomatis/manual tanpa login Google OAuth melalui Supabase RPC (`upload_cloud_backup_snapshot`, `download_cloud_backup_snapshot`, `get_cloud_backup_metadata`) dengan enkripsi AES-256 pada sisi klien sebelum diunggah.

---

## 7. Riwayat Evolusi Versi (v3.0 s.d. v4.3)

- **v3.0:** Modul Buku Infak Bulanan (Santriyin/Santriyat/Santri Baru), Smart Split Setoran Sambangan, Serah Terima Infak ke Dapur/Yayasan, dan Akuntansi 3 Kantong Kas.
- **v3.2:** Engine Wallpaper & Translucent Aurora Glassmorphism (`AppBackgroundWrapper`), Navigasi Geser `PageView` 5 Tab, Sistem Login & Profil Bendahara, `SearchableSantriPicker`, dan Ekspor Excel/PDF Siap Cetak.
- **v3.3:** Hardening Keamanan Ed25519, Anti-Clock Tampering (`SecurityGuardService`), Backup Terenkripsi `.ksbak` (AES-256-GCM), Mode Privasi Layar (`FLAG_SECURE`), R8 Full Mode ProGuard Rules, dan Hash-Chained `audit_log`.
- **v3.4:** Admin Command Center (`admin_dashboard/`) terisolasi dengan Supabase RLS & generator lisensi Ed25519.
- **v4.0:** Import Santri Massal Excel (`.xlsx`), Cetak Massal Kartu Santri QR PDF A4, Manajemen Tahun Ajaran & Pindah Kamar Massal, Dashboard Analitik Eksekutif Yayasan, dan Pusat Antrean Pengingat WA Cerdas.
- **v4.1:** Optimasi 60 FPS (penghapusan `BackdropFilter` dari item list/grid), Default Pondok Netral (`'Nama Pondok'`), `InteractiveWalkthroughOverlay` 5 langkah, Saldo Awal Santri Baru `Rp 0`, dan Gerbang Terpusat `SubscriptionService.hasProAccess`.
- **v4.2:** Eliminasi query `N+1` di `loadAllData()` (-99% query SQLite), agregasi SQL `SUM(CASE WHEN ...)` pada `getSaldoDompet()` & `getSaldoKantongInfak()`, rekonsiliasi akuntansi 100% pada `editTransaksi`/`voidTransaksi(setoran)`/`deleteSantri`, isolasi `UndoStateNotifier` + background isolate `compute()` untuk Excel & `.ksbak`, kepatuhan Data Safety Play Store & wallpaper bebas watermark, penghubungan kembali `SantriDetailScreen` + penghapusan 5 layar warisan v1.0, modularisasi *Repository Pattern*, dan optimasi pipeline CI/CD 2-Job.
- **v4.3 (Saat Ini):** Brankas Tabungan Terpisah (Kantong Kas Ke-4, SQLite v5 & `TabunganRepository` + Cash Opname 4 kantong), Perbaikan nyata Backup Lokal `.ksbak` berbasis SAF & Cloud Backup Online terenkripsi AES-256 (`app_cloud_backups`), Kredensial Pengembang Netral tanpa nama pondok, serta Tutorial Sorotan Kontekstual (`ScreenSpotlightHost` + `SpotlightHelpButton`) pada seluruh 16 halaman & menu fitur.

---

## 8. Panduan Build CI/CD, Kompatibilitas Versi & Git Push (WAJIB DIPATUHI)

### A. Spesifikasi Kompatibilitas Versi (DILARANG DIUBAH SEMBARANGAN)
- **Android Gradle Plugin (AGP):** `9.3.1` (`android/settings.gradle`)
- **Gradle Wrapper:** `9.5.0` (`android/gradle/wrapper/gradle-wrapper.properties`)
- **Kotlin Version:** `2.4.20` (`android/settings.gradle`)
- **Java Target:** `Java 17` di `android/app/build.gradle` (dijalankan di atas runner JDK 21 Temurin pada GitHub Actions untuk kompatibilitas AGP 9.3.1 / Gradle 9.5.0)
- **SDK Targets:** `compileSdk = 36`, `targetSdk = 36`, `minSdkVersion = 24`
- **AndroidManifest Storage Permissions:** `READ_EXTERNAL_STORAGE` dibatasi `android:maxSdkVersion="32"` dan `WRITE_EXTERNAL_STORAGE` dibatasi `android:maxSdkVersion="29"`
- **BuildConfig:** Wajib `buildFeatures { buildConfig = true }` di `android/app/build.gradle`; **DILARANG** memakai flag usang `android.defaults.buildfeatures.buildconfig=true` di `android/gradle.properties`

### B. Arsitektur 2-Job GitHub Actions (`.github/workflows/flutter-apk.yml`)
1. **Job 1 — `quality-gate` (`1. Quality Gate (Format, Analyze & Unit Tests)`):**
   - Menjalankan `flutter pub get`, verifikasi `dart format --output=none --set-exit-if-changed lib test`, analisis statis ketat `flutter analyze --no-fatal-infos --fatal-warnings`, dan seluruh suite pengujian `flutter test --coverage` dalam 1 runner VM terpadu.
2. **Job 2 — `build-release-apk` (`2. Build Signed Release APK & AAB`, `needs: [quality-gate]`):**
   - Menyuntikkan secrets opsional `REVENUECAT_ANDROID_API_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, dan `KAS_SANTRI_ED25519_PUBKEY` via `--dart-define`.
   - Memberikan peringatan eksplisit pada `$GITHUB_STEP_SUMMARY` apabila secret keystore release (`KEYSTORE_BASE64`) belum dikonfigurasi.
   - **Build APK Release (Direct DANA/QRIS):**
     ```bash
     flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols --android-skip-build-dependency-validation --dart-define=PLAY_STORE_BUILD=false "${EXTRA_DEFINES[@]}"
     ```
   - **Build AAB Release (Google Play Store Billing):**
     ```bash
     flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols --android-skip-build-dependency-validation --dart-define=PLAY_STORE_BUILD=true "${EXTRA_DEFINES[@]}"
     ```

### C. Prosedur Git Commit & Push
- Path Git lokal: `C:\Users\smkit\AppData\Local\Programs\Git\cmd\git.exe` (jalankan dengan `BypassSandbox: true` saat melakukan operasi jaringan `git push origin main`).
- Pastikan seluruh 11 tabel SQLite tercakup dalam Backup & Restore `.JSON`, `.KSBAK`, dan Cloud Backup Online (`app_cloud_backups`).
