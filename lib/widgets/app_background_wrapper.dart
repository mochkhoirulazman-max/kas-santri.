import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_wallpaper_provider.dart';

/// Pembungkus latar global aplikasi 60–120 FPS:
/// - Blur dijalankan HANYA 1 kali di layer global terisolasi `RepaintBoundary`.
/// - Gambar dimuat hemat RAM memakai `ResizeImage(..., width: 1080)`.
/// - Dilapisi dark vignette lembut agar kontras teks di atas foto matahari terbit selalu tajam.
class AppBackgroundWrapper extends StatelessWidget {
  final Widget child;

  const AppBackgroundWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<ThemeWallpaperProvider>(context);
    final spec = wp.activeSpec;
    final hasCustom = wp.hasValidCustomWallpaper;
    final topScrim = (wp.wallpaperDim + 0.14).clamp(0.28, 0.90);
    final midScrim = (wp.wallpaperDim * 0.86).clamp(0.18, 0.82);
    final botScrim = (wp.wallpaperDim + 0.22).clamp(0.38, 0.94);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasCustom)
                Image(
                  image: ResizeImage(
                    FileImage(File(wp.customWallpaperPath!)),
                    width: 1080,
                  ),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => _buildPresetCanvas(spec),
                )
              else if (spec.bundledAssetPath != null)
                Image(
                  image: ResizeImage(
                    AssetImage(spec.bundledAssetPath!),
                    width: 1080,
                  ),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => _buildPresetCanvas(spec),
                )
              else
                _buildPresetCanvas(spec),

              if (wp.wallpaperBlur > 0.25)
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: wp.wallpaperBlur,
                        sigmaY: wp.wallpaperBlur,
                      ),
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  ),
                ),

              // Dark vignette scrim 3-lapis agar teks putih & neon selalu kontras tajam
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF030712).withValues(alpha: topScrim),
                        const Color(0xFF040A18).withValues(alpha: midScrim),
                        const Color(0xFF020610).withValues(alpha: botScrim),
                      ],
                      stops: const [0.0, 0.48, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildPresetCanvas(WallpaperPresetSpec spec) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: spec.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    spec.glowPrimary.withValues(alpha: 0.34),
                    spec.glowPrimary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    spec.glowSecondary.withValues(alpha: 0.30),
                    spec.glowSecondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu Vibrant Translucent Glass (TANPA BackdropFilter di dalam list agar 60–120 FPS mulus).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final List<Color>? gradientColors;
  final double blurSigma;
  final double opacityMultiplier;
  final Color baseColor;

  const GlassCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderRadius = 24,
    this.borderColor,
    this.gradientColors,
    this.blurSigma = 0,
    this.opacityMultiplier = 1.0,
    this.baseColor = const Color(0xFF0A192F),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardOpacity = Provider.of<ThemeWallpaperProvider>(context).cardOpacity;
    final effectiveOpacity = (cardOpacity * opacityMultiplier).clamp(0.28, 0.94);
    final accent = borderColor ?? const Color(0xFF38BDF8);

    final List<Color> resolvedGradient;
    if (gradientColors != null && gradientColors!.length >= 2) {
      resolvedGradient = gradientColors!
          .map(
            (c) => c.withValues(
              alpha: (c.a * effectiveOpacity).clamp(0.18, 0.94),
            ),
          )
          .toList();
    } else {
      resolvedGradient = [
        Color.lerp(const Color(0xFF082032), accent, 0.24)!
            .withValues(alpha: (effectiveOpacity * 0.92).clamp(0.28, 0.90)),
        Color.lerp(baseColor, const Color(0xFF091326), 0.55)!
            .withValues(alpha: (effectiveOpacity * 0.98).clamp(0.34, 0.94)),
        Color.lerp(const Color(0xFF050B18), accent, 0.10)!
            .withValues(alpha: (effectiveOpacity * 1.02).clamp(0.38, 0.95)),
      ];
    }

    final resolvedBorder = borderColor != null
        ? borderColor!.withValues(alpha: (borderColor!.a * 0.95).clamp(0.32, 0.65))
        : const Color(0xFF38BDF8).withValues(alpha: 0.34);

    return RepaintBoundary(
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: resolvedGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: resolvedBorder, width: 1.15),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Logo Netral Resmi Kas-Santri (Multi-Pondok) dengan dukungan logo kustom PRO.
class KasSantriLogoMark extends StatelessWidget {
  final String? customLogoPath;
  final double size;
  final double borderRadius;
  final bool circular;

  const KasSantriLogoMark({
    Key? key,
    this.customLogoPath,
    this.size = 44,
    this.borderRadius = 14,
    this.circular = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasCustom = customLogoPath != null &&
        customLogoPath!.trim().isNotEmpty &&
        File(customLogoPath!).existsSync();

    final Widget inner = hasCustom
        ? Image(
            image: ResizeImage(
              FileImage(File(customLogoPath!)),
              width: 256,
            ),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildNeutralEmblem(),
          )
        : _buildNeutralEmblem();

    if (circular) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(child: inner),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: inner,
      ),
    );
  }

  Widget _buildNeutralEmblem() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF0E7490), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.mosque_rounded,
          color: const Color(0xFF6EE7B7),
          size: size * 0.54,
        ),
      ),
    );
  }
}
