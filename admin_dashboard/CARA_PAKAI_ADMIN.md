# Panduan Singkat Admin Command Center Kas-Santri (v3.4)

> **Catatan Keamanan Mutlak:** Folder `admin_dashboard/` hanya untuk **Admin (Anda)** dan tidak pernah didaftarkan di `pubspec.yaml`, sehingga **tidak ikut masuk ke file APK/AAB publik**.

---

## 1. Cara Membuka Dashboard Admin (Mode Offline — Langsung Jalan)
1. Buka file `admin_dashboard/index.html` langsung di browser Chrome/Edge/Safari (baik di Laptop maupun HP).
2. Pilih tab **💾 Mode Offline** dan buat Password Admin Lokal pertama kali (minimal 4 karakter).
3. Anda dapat langsung:
   - Memasukkan **Private Seed Base64** Ed25519 (hasil `dart run tool/generate_keypair.dart --generate-keys`) atau membuat keypair baru.
   - Menghasilkan kode lisensi `KSPRO-...` di tab **🔐 Generator Ed25519**.
   - Mencatat pelanggan pondok, omset DANA/Play Store, follow-up WhatsApp 1-klik, dan ekspor CSV/JSON pembukuan pribadi.

---

## 2. Menghubungkan ke Cloud Supabase (Gratis 5 Menit)
Agar data pelanggan dari seluruh HP bendahara tersinkron otomatis ke Dashboard Admin dan Anda bisa melakukan **Remote Revoke** atau mengirim **Pengumuman Update APK**:

1. **Buat Proyek Gratis di Supabase**:
   - Daftar/masuk ke [supabase.com](https://supabase.com) -> **New Project** -> pilih region terdekat (`Singapore`).
2. **Jalankan Skema SQL**:
   - Buka **SQL Editor** -> **New Query** -> tempel seluruh isi file [`admin_dashboard/supabase_schema.sql`](supabase_schema.sql) -> klik **Run**.
3. **Daftarkan Akun Admin Anda**:
   - Buka **Authentication -> Users -> Add User**, buat akun email & password khusus Admin.
   - Jalankan query di SQL Editor (ganti email sesuai akun yang baru dibuat):
     ```sql
     insert into public.admin_users (user_id, email)
     select id, email from auth.users where email = 'email_admin_anda@gmail.com'
     on conflict (user_id) do nothing;
     ```
4. **Salin URL & Anon Key**:
   - Buka **Project Settings -> API**, salin **Project URL** dan **anon public key**.
   - Buka `admin_dashboard/index.html`, pilih tab **☁️ Supabase Cloud**, tempel URL, Anon Key, Email & Password Admin -> **Login**.

---

## 3. Menghubungkan APK Flutter ke Supabase (Opsional, Aman via GitHub Secrets)
Tambahkan 2 Secrets di repositori GitHub Anda (**Settings -> Secrets and variables -> Actions**):
- `SUPABASE_URL`: `https://xxxxxxxxxxxx.supabase.co`
- `SUPABASE_ANON_KEY`: `eyJhbGci...` (`anon public` key — **JANGAN** pernah memakai `service_role` key).

Workflow `.github/workflows/flutter-apk.yml` otomatis menyuntikkan keduanya lewat `--dart-define` saat build APK/AAB. Jika Secrets tidak diisi, aplikasi tetap berjalan 100% offline-first tanpa error.

---

## 4. Sinkronisasi Kunci Ed25519
1. Jalankan sekali di PC/CI yang terpasang Dart:
   ```bash
   dart run tool/generate_keypair.dart --generate-keys
   ```
   *(Atau klik **✨ Buat Keypair Baru** di tab Generator Ed25519 pada Dashboard Admin).*
2. Tempel **Public Key Base64** ke `LicenseService.defaultPublicKeyBase64` di `lib/services/license_service.dart` sebelum merilis APK.
3. Simpan **Private Seed Base64** hanya di brankas pribadi Anda, dan tempel ke kolom Private Seed setiap kali membuka Dashboard Admin.
