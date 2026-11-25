import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_wallpaper_provider.dart';

/// Pembungkus latar global aplikasi (mendukung 5 preset aurora & foto galeri + blur/scrim)
class AppBackgroundWrapper extends StatelessWidget {
  final Widget child;

  const AppBackgroundWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<ThemeWallpaperProvider>(context);
    final spec = wp.activeSpec;
    final hasCustom = wp.hasValidCustomWallpaper;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasCustom)
          Image.file(
            File(wp.customWallpaperPath!),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _buildPresetCanvas(spec),
          )
        else
          _buildPresetCanvas(spec),

        if (wp.wallpaperBlur > 0.2)
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

        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withOpacity(wp.wallpaperDim),
          ),
        ),

        child,
      ],
    );
  }

  Widget _buildPresetCanvas(WallpaperPresetSpec spec) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
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
                    spec.glowPrimary.withOpacity(0.32),
                    spec.glowPrimary.withOpacity(0.0),
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
                    spec.glowSecondary.withOpacity(0.28),
                    spec.glowSecondary.withOpacity(0.0),
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

/// Kartu Glassmorphism konsisten yang mengikuti slider opasitas kartu global
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
    this.blurSigma = 12,
    this.opacityMultiplier = 1.0,
    this.baseColor = const Color(0xFF0F172A),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardOpacity = Provider.of<ThemeWallpaperProvider>(context).cardOpacity;
    final effectiveOpacity = (cardOpacity * opacityMultiplier).clamp(0.22, 0.96);

    final BoxDecoration decoration;
    if (gradientColors != null && gradientColors!.length >= 2) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors!
              .map((c) => c.withOpacity((c.opacity * effectiveOpacity).clamp(0.15, 0.95)))
              .toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.14),
          width: 1.1,
        ),
      );
    } else {
      decoration = BoxDecoration(
        color: baseColor.withOpacity(effectiveOpacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.14),
          width: 1.1,
        ),
      );
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: decoration,
            child: child,
          ),
        ),
      ),
    );
  }
}
