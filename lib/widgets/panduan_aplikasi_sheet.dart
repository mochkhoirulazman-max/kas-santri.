import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kas_santri_provider.dart';
import '../providers/theme_wallpaper_provider.dart';
import '../screens/onboarding_screen.dart';
import '../services/tutorial_service.dart';
import '../utils/app_feedback.dart';
import 'encrypted_backup_helper.dart';

/// Bottom sheet Panduan Aplikasi & Putar Ulang Tutorial (Spotlight Tour / Slide Onboarding).
class PanduanAplikasiSheet {
  static Future<void> show(BuildContext rootContext) async {
    AppFeedback.tap();
    await showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final bottomPad = MediaQuery.of(sheetCtx).padding.bottom;
        return DraggableScrollableSheet(
          initialChildSize: 0.84,
          minChildSize: 0.55,
          maxChildSize: 0.94,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xF5072536),
                    Color(0xF70A1426),
                    Color(0xF810132A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                ),
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + bottomPad),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Text('📖', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PANDUAN & TUTORIAL INTERAKTIF',
                              style: TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Cara Pakai Cepat Kas-Santri',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close_rounded, color: Colors.white60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tombol Putar Ulang Tutorial Sorotan (6 Langkah)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        AppFeedback.tap();
                        final provider = Provider.of<KasSantriProvider>(
                          rootContext,
                          listen: false,
                        );
                        await TutorialService.instance.resetWalkthrough();
                        if (sheetCtx.mounted) {
                          Navigator.pop(sheetCtx);
                        }
                        if (rootContext.mounted) {
                          Navigator.of(rootContext).popUntil((r) => r.isFirst);
                          provider.triggerSpotlightTour();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: const Color(0xFF030712),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                      label: const Text(
                        '🎯 Mulai Tutorial Sorotan di Beranda (6 Langkah)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tombol Reset & Putar Ulang Semua Tutorial Sorotan di Semua Menu
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        AppFeedback.tap();
                        final provider = Provider.of<KasSantriProvider>(
                          rootContext,
                          listen: false,
                        );
                        await TutorialService.instance.resetAllScreenTours();
                        if (sheetCtx.mounted) {
                          Navigator.pop(sheetCtx);
                        }
                        if (rootContext.mounted) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Semua tutorial sorotan di-reset & mode otomatis aktif kembali.',
                              ),
                              backgroundColor: Color(0xFF0EA5E9),
                            ),
                          );
                          Navigator.of(rootContext).popUntil((r) => r.isFirst);
                          provider.triggerSpotlightTour();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6EE7B7),
                        side: BorderSide(
                          color: const Color(0xFF34D399).withValues(alpha: 0.55),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded, size: 17),
                      label: const Text(
                        '🔄 Reset & Putar Ulang Semua Tutorial Sorotan',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Switch Preferensi Tutorial Otomatis Saat Pertama Buka Menu
                  FutureBuilder<bool>(
                    future: TutorialService.instance.isAutoTourEnabled(),
                    builder: (context, snap) {
                      var autoVal = snap.data ?? true;
                      return StatefulBuilder(
                        builder: (_, setInnerState) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                              ),
                            ),
                            child: SwitchListTile.adaptive(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              activeColor: const Color(0xFF34D399),
                              title: const Text(
                                'Panduan Sorotan Otomatis (Saat Pertama Buka Menu)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text(
                                'Jika dimatikan, ketuk ikon (?) di header menu kapan saja.',
                                style: TextStyle(color: Colors.white60, fontSize: 10),
                              ),
                              value: autoVal,
                              onChanged: (val) async {
                                AppFeedback.tap();
                                setInnerState(() => autoVal = val);
                                await TutorialService.instance.setAutoTourEnabled(val);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // Tombol Buka Slide Pengenalan (5 Slide)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        AppFeedback.tap();
                        Navigator.pop(sheetCtx);
                        if (rootContext.mounted) {
                          Navigator.push(
                            rootContext,
                            MaterialPageRoute(
                              builder: (_) => const OnboardingScreen(isReplayMode: true),
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF67E8F9),
                        side: BorderSide(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.55),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.slideshow_rounded, size: 18),
                      label: const Text(
                        '✨ Buka Slide Pengenalan & Setup Cepat (5 Slide)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'RINGKASAN ALUR KERJA BENDAHARA',
                    style: TextStyle(
                      color: Color(0xFF67E8F9),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _guideCard(
                    emoji: '💸',
                    title: '1. Ambil Uang 3 Detik & Scan QR',
                    body:
                        'Ketuk kartu santri di tab Kas & Ambil (2 kotak atau 1 baris) atau pindai Kartu QR saat antrean padat. Kuota harian terhitung & dibulatkan otomatis.',
                    accent: const Color(0xFF34D399),
                  ),
                  _guideCard(
                    emoji: '🎁',
                    title: '2. Setoran Sambangan vs Top-Up Jajan',
                    body:
                        'Gunakan mode "Sambangan" untuk membagi otomatis Infak Masak, Listrik, Beras (Liter/Rp) & Uang Jajan, atau "Top-Up Jajan" untuk murni menambah saldo saku.',
                    accent: const Color(0xFF38BDF8),
                  ),
                  _guideCard(
                    emoji: '🌾',
                    title: '3. Buku Infak & Serah Terima Yayasan',
                    body:
                        'Pantau lunas/belum infak bulanan per kelompok (Santriyin, Santriyat, Santri Baru), stok beras gudang, serta catat berita acara serah terima ke Dapur/Yayasan.',
                    accent: const Color(0xFFFBBF24),
                  ),
                  _guideCard(
                    emoji: '🧮',
                    title: '4. Multi-Dompet & Cash Opname Malam',
                    body:
                        'Pisahkan uang di Kas Laci Tunai vs Rekening Bank. Gunakan Kalkulator Cash Opname pecahan fisik setiap malam agar kas pondok 100% bebas selisih.',
                    accent: const Color(0xFFA78BFA),
                  ),
                  _guideCard(
                    emoji: '📲',
                    title: '5. Rekap WA Wali & Laporan Resmi PDF/Excel',
                    body:
                        'Kirim mutasi santun 1-klik ke WhatsApp orang tua, bagikan struk gambar rapi, atau cetak laporan PDF berkop logo & Excel multi-sheet untuk rapat yayasan.',
                    accent: const Color(0xFF2DD4BF),
                  ),
                  _guideCard(
                    emoji: '💾',
                    title: '6. Cadangan Aman (.JSON / .KSBAK / Drive)',
                    body:
                        'Simpan cadangan rutin ke file lokal .JSON, file terenkripsi AES-256 (.KSBAK), atau Google Drive serta aktifkan Kunci PIN agar aman saat HP berganti.',
                    accent: const Color(0xFFFB7185),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _guideCard({
    required String emoji,
    required String title,
    required String body,
    required Color accent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(const Color(0xFF081426), accent, 0.18)!,
            const Color(0xFF091120),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.2,
                    height: 1.38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet cepat untuk mengganti Wallpaper & Transparansi Kaca langsung dari Akses Cepat Sistem.
class QuickWallpaperThemeSheet {
  static Future<void> show(BuildContext context) async {
    AppFeedback.tap();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final bottomPad = MediaQuery.of(sheetCtx).padding.bottom;
        return Consumer<ThemeWallpaperProvider>(
          builder: (ctx, themeProv, _) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 22 + bottomPad),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xF5072536),
                    Color(0xF70A1426),
                    Color(0xF815112D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: const Color(0xFFD946EF).withValues(alpha: 0.45),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text('🎨', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WALLPAPER & KACA VIBRANT',
                                style: TextStyle(
                                  color: Color(0xFFF0ABFC),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                'Pilih Suasana Tampilan Aplikasi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: const Icon(Icons.close_rounded, color: Colors.white60),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ThemeWallpaperProvider.presets.map((spec) {
                        final isSelected = !themeProv.hasValidCustomWallpaper &&
                            themeProv.preset == spec.preset;
                        return InkWell(
                          onTap: () {
                            AppFeedback.tap();
                            themeProv.setPreset(spec.preset);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: spec.gradientColors),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? spec.accentColor
                                    : Colors.white24,
                                width: isSelected ? 1.6 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.palette_outlined,
                                  size: 14,
                                  color: spec.accentColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  spec.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 11.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              AppFeedback.tap();
                              final picked = await FilePicker.platform.pickFiles(
                                type: FileType.image,
                              );
                              if (picked != null &&
                                  picked.files.single.path != null) {
                                await themeProv.setCustomWallpaperFromFile(
                                  picked.files.single.path!,
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF67E8F9),
                              side: BorderSide(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                              ),
                            ),
                            icon: const Icon(Icons.photo_library_outlined, size: 16),
                            label: const Text(
                              'Pilih Foto Galeri',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        if (themeProv.hasValidCustomWallpaper) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              AppFeedback.tap();
                              themeProv.clearCustomWallpaper();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFDA4AF),
                              side: BorderSide(
                                color: const Color(0xFFF43F5E).withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text(
                              'Reset Default',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    _miniSlider(
                      ctx,
                      label: 'Transparansi Kaca Kartu',
                      valueText: '${(themeProv.cardOpacity * 100).round()}%',
                      value: themeProv.cardOpacity,
                      min: 0.35,
                      max: 0.95,
                      onChanged: themeProv.setCardOpacity,
                    ),
                    _miniSlider(
                      ctx,
                      label: 'Redup Wallpaper (Kontras Teks)',
                      valueText: '${(themeProv.wallpaperDim * 100).round()}%',
                      value: themeProv.wallpaperDim,
                      min: 0.15,
                      max: 0.85,
                      onChanged: themeProv.setWallpaperDim,
                    ),
                    _miniSlider(
                      ctx,
                      label: 'Efek Blur Latar',
                      valueText: themeProv.wallpaperBlur.toStringAsFixed(1),
                      value: themeProv.wallpaperBlur,
                      min: 0.0,
                      max: 16.0,
                      onChanged: themeProv.setWallpaperBlur,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _miniSlider(
    BuildContext context, {
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              valueText,
              style: const TextStyle(
                color: Color(0xFF67E8F9),
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: const Color(0xFF34D399),
            inactiveColor: Colors.white12,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Sheet cepat untuk Backup & Restore (.JSON gratis, .KSBAK AES-256 PRO, dan Google Drive PRO).
class QuickBackupRestoreSheet {
  static Future<void> show(BuildContext rootContext) async {
    AppFeedback.tap();
    await showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final bottomPad = MediaQuery.of(sheetCtx).padding.bottom;
        final provider = Provider.of<KasSantriProvider>(rootContext);
        final isPro = provider.hasProAccess;

        return Container(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 22 + bottomPad),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xF5062C28),
                Color(0xF70A1528),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: const Color(0xFF34D399).withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('💾', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CADANGAN & PEMULIHAN DATA',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Amankan Data Kas Pondok Anda',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _actionTile(
                emoji: '💾',
                title: 'Simpan Backup ke Memori HP (.JSON)',
                subtitle: 'Simpan langsung ke folder Download / Dokumen HP (Gratis)',
                accent: const Color(0xFF34D399),
                isLockedPro: false,
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await EncryptedBackupHelper.saveLocalBackupToDevice(
                    rootContext,
                    encrypted: false,
                  );
                },
              ),
              _actionTile(
                emoji: '📤',
                title: 'Bagikan File Backup (.JSON)',
                subtitle: 'Kirim cepat ke WhatsApp, Google Drive, atau Telegram (Gratis)',
                accent: const Color(0xFF2DD4BF),
                isLockedPro: false,
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await EncryptedBackupHelper.shareLocalBackupFile(
                    rootContext,
                    encrypted: false,
                  );
                },
              ),
              _actionTile(
                emoji: '🔐',
                title: 'Backup Terenkripsi AES-256 (.KSBAK)',
                subtitle: 'Simpan ke HP atau bagikan dengan kunci password kriptografi',
                accent: const Color(0xFF38BDF8),
                isLockedPro: !isPro,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  EncryptedBackupHelper.backupEncryptedKsbak(rootContext);
                },
              ),
              _actionTile(
                emoji: '⬆️',
                title: 'Pulihkan Data Backup (.JSON / .KSBAK)',
                subtitle: 'Pilih file cadangan dari memori HP (mendukung penuh .KSBAK)',
                accent: const Color(0xFFA78BFA),
                isLockedPro: false,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  EncryptedBackupHelper.restoreBackupAnyFormat(
                    rootContext,
                    provider,
                  );
                },
              ),
              _actionTile(
                emoji: '☁️',
                title: 'Cadangkan ke Cloud Online (AES-256)',
                subtitle: 'Offline-First + Cloud Backup Online terenkripsi antar HP',
                accent: const Color(0xFF38BDF8),
                isLockedPro: false,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  EncryptedBackupHelper.showCloudBackupDialog(
                    rootContext,
                    provider,
                  );
                },
              ),
              _actionTile(
                emoji: '🌐',
                title: 'Pulihkan dari Cloud Online',
                subtitle: 'Unduh cadangan terenkripsi memakai Kode Pondok & Password',
                accent: const Color(0xFFFBBF24),
                isLockedPro: false,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  EncryptedBackupHelper.showCloudRestoreDialog(
                    rootContext,
                    provider,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _actionTile({
    required String emoji,
    required String title,
    required String subtitle,
    required Color accent,
    required bool isLockedPro,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF07111F).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.38)),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isLockedPro)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFBBF24)),
                            ),
                            child: const Text(
                              '🔒 PRO',
                              style: TextStyle(
                                color: Color(0xFFFDE68A),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
