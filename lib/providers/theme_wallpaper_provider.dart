import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_feedback.dart';

enum WallpaperPreset {
  sunriseBeach,
  obsidianAurora,
  emeraldMist,
  midnightGold,
  deepOceanGlass,
  matteCharcoal,
}

class WallpaperPresetSpec {
  final WallpaperPreset preset;
  final String name;
  final String subtitle;
  final List<Color> gradientColors;
  final Color glowPrimary;
  final Color glowSecondary;
  final Color accentColor;
  final String? bundledAssetPath;

  const WallpaperPresetSpec({
    required this.preset,
    required this.name,
    required this.subtitle,
    required this.gradientColors,
    required this.glowPrimary,
    required this.glowSecondary,
    required this.accentColor,
    this.bundledAssetPath,
  });
}

class ThemeWallpaperProvider extends ChangeNotifier {
  static const String defaultBundledWallpaperAsset =
      'assets/wallpapers/default_wallpaper.jpg';

  static const String _keyPreset = 'ks_v41_wallpaper_preset';
  static const String _keyCustomPath = 'ks_v32_custom_wallpaper_path';
  static const String _keyCardOpacity = 'ks_v32_card_opacity';
  static const String _keyWallpaperDim = 'ks_v32_wallpaper_dim';
  static const String _keyWallpaperBlur = 'ks_v32_wallpaper_blur';
  static const String _keyHapticEnabled = 'ks_v32_haptic_enabled';

  static const List<WallpaperPresetSpec> presets = [
    WallpaperPresetSpec(
      preset: WallpaperPreset.sunriseBeach,
      name: 'Sunrise Pantai Teduh',
      subtitle: 'Pantai matahari terbit bawaan (Default)',
      gradientColors: [Color(0xFF061523), Color(0xFF102A3B), Color(0xFF07131E)],
      glowPrimary: Color(0xFFF59E0B),
      glowSecondary: Color(0xFF10B981),
      accentColor: Color(0xFFFBBF24),
      bundledAssetPath: defaultBundledWallpaperAsset,
    ),
    WallpaperPresetSpec(
      preset: WallpaperPreset.obsidianAurora,
      name: 'Obsidian Aurora',
      subtitle: 'Klasik emerald & cyan malam tenang',
      gradientColors: [Color(0xFF040811), Color(0xFF0A1626), Color(0xFF06111A)],
      glowPrimary: Color(0xFF10B981),
      glowSecondary: Color(0xFF06B6D4),
      accentColor: Color(0xFF34D399),
    ),
    WallpaperPresetSpec(
      preset: WallpaperPreset.emeraldMist,
      name: 'Emerald Mist',
      subtitle: 'Hijau zamrud teduh pesantren',
      gradientColors: [Color(0xFF03100E), Color(0xFF082420), Color(0xFF051318)],
      glowPrimary: Color(0xFF059669),
      glowSecondary: Color(0xFF34D399),
      accentColor: Color(0xFF6EE7B7),
    ),
    WallpaperPresetSpec(
      preset: WallpaperPreset.midnightGold,
      name: 'Midnight Gold',
      subtitle: 'Biru malam elegan aksen emas',
      gradientColors: [Color(0xFF070812), Color(0xFF141129), Color(0xFF0B0E17)],
      glowPrimary: Color(0xFFF59E0B),
      glowSecondary: Color(0xFF8B5CF6),
      accentColor: Color(0xFFFBBF24),
    ),
    WallpaperPresetSpec(
      preset: WallpaperPreset.deepOceanGlass,
      name: 'Deep Ocean Glass',
      subtitle: 'Samudra biru kaca bening modern',
      gradientColors: [Color(0xFF030B16), Color(0xFF0A203A), Color(0xFF061529)],
      glowPrimary: Color(0xFF38BDF8),
      glowSecondary: Color(0xFF6366F1),
      accentColor: Color(0xFF7DD3FC),
    ),
    WallpaperPresetSpec(
      preset: WallpaperPreset.matteCharcoal,
      name: 'Matte Charcoal',
      subtitle: 'Gelap kontras tinggi super ringan',
      gradientColors: [Color(0xFF07090E), Color(0xFF121722), Color(0xFF090C12)],
      glowPrimary: Color(0xFF38BDF8),
      glowSecondary: Color(0xFF10B981),
      accentColor: Color(0xFF67E8F9),
    ),
  ];

  WallpaperPreset _preset = WallpaperPreset.sunriseBeach;
  WallpaperPreset get preset => _preset;

  String? _customWallpaperPath;
  String? get customWallpaperPath => _customWallpaperPath;

  double _cardOpacity = 0.68;
  double get cardOpacity => _cardOpacity;

  double _wallpaperDim = 0.46;
  double get wallpaperDim => _wallpaperDim;

  double _wallpaperBlur = 2.0;
  double get wallpaperBlur => _wallpaperBlur;

  bool _hapticEnabled = true;
  bool get hapticEnabled => _hapticEnabled;

  WallpaperPresetSpec get activeSpec {
    return presets.firstWhere(
      (s) => s.preset == _preset,
      orElse: () => presets.first,
    );
  }

  bool get hasValidCustomWallpaper {
    final path = _customWallpaperPath;
    if (path == null || path.trim().isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final presetName = prefs.getString(_keyPreset);
      if (presetName != null) {
        _preset = WallpaperPreset.values.firstWhere(
          (e) => e.name == presetName,
          orElse: () => WallpaperPreset.sunriseBeach,
        );
      } else {
        _preset = WallpaperPreset.sunriseBeach;
      }
      _customWallpaperPath = prefs.getString(_keyCustomPath);
      _cardOpacity = (prefs.getDouble(_keyCardOpacity) ?? 0.68).clamp(0.35, 0.95);
      _wallpaperDim = (prefs.getDouble(_keyWallpaperDim) ?? 0.46).clamp(0.15, 0.85);
      _wallpaperBlur = (prefs.getDouble(_keyWallpaperBlur) ?? 2.0).clamp(0.0, 20.0);
      _hapticEnabled = prefs.getBool(_keyHapticEnabled) ?? true;
      AppFeedback.hapticEnabled = _hapticEnabled;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setPreset(WallpaperPreset newPreset) async {
    _preset = newPreset;
    _customWallpaperPath = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPreset, newPreset.name);
      await prefs.remove(_keyCustomPath);
    } catch (_) {}
  }

  Future<String> setCustomWallpaperFromFile(String sourcePath) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw Exception('File gambar tidak ditemukan.');
    }
    final appDir = await getApplicationDocumentsDirectory();
    final wallpaperDir = Directory(p.join(appDir.path, 'wallpapers'));
    if (!await wallpaperDir.exists()) {
      await wallpaperDir.create(recursive: true);
    }
    final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final destPath = p.join(
      wallpaperDir.path,
      'bg_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await src.copy(destPath);

    final oldPath = _customWallpaperPath;
    _customWallpaperPath = destPath;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCustomPath, destPath);
    } catch (_) {}

    if (oldPath != null && oldPath != destPath) {
      try {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      } catch (_) {}
    }

    return destPath;
  }

  Future<void> clearCustomWallpaper() async {
    final oldPath = _customWallpaperPath;
    _customWallpaperPath = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCustomPath);
    } catch (_) {}
    if (oldPath != null) {
      try {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> setCardOpacity(double value) async {
    _cardOpacity = value.clamp(0.35, 0.95);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyCardOpacity, _cardOpacity);
    } catch (_) {}
  }

  Future<void> setWallpaperDim(double value) async {
    _wallpaperDim = value.clamp(0.15, 0.85);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyWallpaperDim, _wallpaperDim);
    } catch (_) {}
  }

  Future<void> setWallpaperBlur(double value) async {
    _wallpaperBlur = value.clamp(0.0, 20.0);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyWallpaperBlur, _wallpaperBlur);
    } catch (_) {}
  }

  Future<void> setHapticEnabled(bool enabled) async {
    _hapticEnabled = enabled;
    AppFeedback.hapticEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHapticEnabled, enabled);
    } catch (_) {}
  }
}
