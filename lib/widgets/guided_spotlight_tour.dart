import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/tutorial_service.dart';

class SpotlightStepSpec {
  final GlobalKey? targetKey;
  final int tabIndex;
  final String emoji;
  final String title;
  final String description;
  final Color accent;

  const SpotlightStepSpec({
    this.targetKey,
    this.tabIndex = 0,
    required this.emoji,
    required this.title,
    required this.description,
    required this.accent,
  });
}

/// Controller untuk memicu ulang Tutorial Sorotan dari tombol bantuan (?) di header/AppBar.
class ScreenSpotlightController {
  VoidCallback? _onStart;

  void startTour() => _onStart?.call();

  void _attach(VoidCallback onStart) {
    _onStart = onStart;
  }

  void _detach(VoidCallback onStart) {
    if (_onStart == onStart) {
      _onStart = null;
    }
  }
}

/// Tombol bantuan kaca neon (?) berukuran ringkas dan tidak mencolok
/// untuk memutar ulang tutorial sorotan kapan saja sesuai kebutuhan bendahara.
class SpotlightHelpButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color accent;
  final double size;
  final String tooltip;

  const SpotlightHelpButton({
    Key? key,
    required this.onTap,
    this.accent = const Color(0xFF38BDF8),
    this.size = 34,
    this.tooltip = 'Panduan Menu Ini',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: accent.withValues(alpha: 0.42),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.help_outline_rounded,
            size: size * 0.52,
            color: accent,
          ),
        ),
      ),
    );
  }
}

/// Pembungkus non-intrusif untuk memasang Tutorial Sorotan Kontekstual pada setiap halaman/tab.
/// - Otomatis tampil maksimal 1x per `screenKey` (kecuali dimatikan oleh user).
/// - Menggunakan `OverlayEntry` di rootOverlay agar mencakup AppBar maupun Floating Bottom Bar.
class ScreenSpotlightHost extends StatefulWidget {
  final String screenKey;
  final List<SpotlightStepSpec> steps;
  final ScreenSpotlightController? controller;
  final bool isActive;
  final bool autoStart;
  final Widget child;

  const ScreenSpotlightHost({
    Key? key,
    required this.screenKey,
    required this.steps,
    this.controller,
    this.isActive = true,
    this.autoStart = true,
    required this.child,
  }) : super(key: key);

  @override
  State<ScreenSpotlightHost> createState() => _ScreenSpotlightHostState();
}

class _ScreenSpotlightHostState extends State<ScreenSpotlightHost> {
  OverlayEntry? _overlayEntry;
  int _currentStep = 0;
  bool _hasCheckedAutoThisSession = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(startTour);
    if (widget.isActive) {
      _scheduleAutoTourCheck();
    }
  }

  @override
  void didUpdateWidget(covariant ScreenSpotlightHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(startTour);
      widget.controller?._attach(startTour);
    }
    if (!oldWidget.isActive && widget.isActive) {
      _scheduleAutoTourCheck();
    } else if (oldWidget.isActive && !widget.isActive && _overlayEntry != null) {
      _removeOverlay();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(startTour);
    _removeOverlay();
    super.dispose();
  }

  void _scheduleAutoTourCheck() {
    if (_hasCheckedAutoThisSession || !widget.autoStart || widget.steps.isEmpty) {
      return;
    }
    Future.delayed(const Duration(milliseconds: 380), () async {
      if (!mounted || !widget.isActive) return;
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
      if (!isCurrentRoute) return;

      _hasCheckedAutoThisSession = true;
      final autoEnabled = await TutorialService.instance.isAutoTourEnabled();
      if (!mounted || !widget.isActive || !autoEnabled) return;

      final seen = await TutorialService.instance.hasSeenScreenTour(widget.screenKey);
      if (!mounted || !widget.isActive || seen) return;
      final stillCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      if (!stillCurrent) return;

      startTour();
    });
  }

  void startTour() {
    if (!mounted || widget.steps.isEmpty) return;
    _removeOverlay();
    _currentStep = 0;
    _overlayEntry = OverlayEntry(
      builder: (_) => GuidedSpotlightOverlay(
        steps: widget.steps,
        currentStep: _currentStep,
        onNext: _nextStep,
        onPrev: _prevStep,
        onSkip: _finishTour,
        onDisableAllAutoTours: _disableAllAutoTours,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _nextStep() {
    if (_currentStep + 1 >= widget.steps.length) {
      _finishTour();
      return;
    }
    _currentStep++;
    _overlayEntry?.markNeedsBuild();
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _currentStep--;
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _finishTour() {
    _removeOverlay();
    unawaited(TutorialService.instance.markScreenTourSeen(widget.screenKey));
  }

  void _disableAllAutoTours() {
    _removeOverlay();
    unawaited(TutorialService.instance.markScreenTourSeen(widget.screenKey));
    unawaited(TutorialService.instance.setAutoTourEnabled(false));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tutorial otomatis dimatikan. Ketuk ikon (?) kapan saja jika butuh panduan.',
        ),
        backgroundColor: Color(0xFF0EA5E9),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Overlay interaktif Guided Spotlight Tour murni CustomPainter
/// tanpa BackdropFilter agar 100% mulus 60-120 FPS di semua perangkat Android.
class GuidedSpotlightOverlay extends StatefulWidget {
  final List<SpotlightStepSpec> steps;
  final int currentStep;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onSkip;
  final VoidCallback? onDisableAllAutoTours;

  const GuidedSpotlightOverlay({
    Key? key,
    required this.steps,
    required this.currentStep,
    required this.onNext,
    required this.onPrev,
    required this.onSkip,
    this.onDisableAllAutoTours,
  }) : super(key: key);

  @override
  State<GuidedSpotlightOverlay> createState() => _GuidedSpotlightOverlayState();
}

class _GuidedSpotlightOverlayState extends State<GuidedSpotlightOverlay> {
  Rect? _targetRect;
  bool _didScrollStep = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant GuidedSpotlightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep ||
        oldWidget.steps != widget.steps) {
      _didScrollStep = false;
      _scheduleMeasure();
    }
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureTarget(retryIfNull: true);
    });
  }

  void _measureTarget({required bool retryIfNull}) {
    if (!mounted || widget.currentStep >= widget.steps.length) return;
    final spec = widget.steps[widget.currentStep];
    final targetKey = spec.targetKey;
    if (targetKey == null) {
      setState(() => _targetRect = null);
      return;
    }

    final targetCtx = targetKey.currentContext;
    final overlayBox = context.findRenderObject() as RenderBox?;
    final targetBox = targetCtx?.findRenderObject() as RenderBox?;

    if (overlayBox != null &&
        targetCtx != null &&
        targetCtx.mounted &&
        targetBox != null &&
        overlayBox.hasSize &&
        targetBox.hasSize &&
        targetBox.attached) {
      final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
      final rect = topLeft & targetBox.size;
      final viewH = overlayBox.size.height;

      // Pastikan elemen target berada di area pandang sebelum mengukur kotak sorotan
      if (!_didScrollStep && (rect.top < 64 || rect.bottom > viewH - 80)) {
        _didScrollStep = true;
        Scrollable.ensureVisible(
          targetCtx,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: 0.35,
        );
        Future.delayed(const Duration(milliseconds: 240), () {
          if (mounted) _measureTarget(retryIfNull: false);
        });
        return;
      }

      setState(() => _targetRect = rect);
    } else {
      setState(() => _targetRect = null);
      if (retryIfNull) {
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted) _measureTarget(retryIfNull: false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentStep < 0 || widget.currentStep >= widget.steps.length) {
      return const SizedBox.shrink();
    }

    final spec = widget.steps[widget.currentStep];
    final total = widget.steps.length;
    final isLast = widget.currentStep == total - 1;
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final safeTop = mq.padding.top + 12;
    final safeBottom = mq.padding.bottom + 16;

    final spot = _targetRect;
    final bool placeBelow = spot == null || spot.center.dy < screenH * 0.52;

    double? cardTop;
    double? cardBottom;
    if (spot == null) {
      cardTop = screenH * 0.28;
    } else if (placeBelow) {
      cardTop = math.min(spot.bottom + 16, screenH - 290 - safeBottom);
      cardTop = math.max(cardTop, safeTop);
    } else {
      final fromBottom = (screenH - spot.top) + 16;
      cardBottom = math.max(fromBottom, safeBottom);
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Scrim gelap dengan lubang sorotan (Tap di area luar lanjut ke step berikutnya)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onNext,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SpotlightHolePainter(
                    targetRect: spot,
                    accentColor: spec.accent,
                  ),
                ),
              ),
            ),
          ),

          // Kartu balon penjelasan Vibrant Glass
          Positioned(
            left: 16,
            right: 16,
            top: cardTop,
            bottom: cardBottom,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: screenH - safeTop - safeBottom - 24,
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.lerp(const Color(0xFF071B2C), spec.accent, 0.22)!
                            .withValues(alpha: 0.96),
                        const Color(0xF6091120),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: spec.accent.withValues(alpha: 0.65),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: spec.accent.withValues(alpha: 0.24),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: spec.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: spec.accent.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              'LANGKAH ${widget.currentStep + 1} / $total',
                              style: TextStyle(
                                color: spec.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: widget.onSkip,
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                'Lewati ✕',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: spec.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: spec.accent.withValues(alpha: 0.45),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              spec.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  spec.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  spec.description,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.2,
                                    height: 1.48,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          // Dot progress
                          Row(
                            children: List.generate(total, (i) {
                              final active = i == widget.currentStep;
                              return Container(
                                width: active ? 16 : 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: active ? spec.accent : Colors.white24,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              );
                            }),
                          ),
                          const Spacer(),
                          if (widget.currentStep > 0) ...[
                            TextButton(
                              onPressed: widget.onPrev,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                '← Kembali',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          ElevatedButton(
                            onPressed: widget.onNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: spec.accent,
                              foregroundColor: const Color(0xFF030712),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              isLast ? 'Selesai ✓' : 'Lanjut →',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.onDisableAllAutoTours != null) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: InkWell(
                            onTap: widget.onDisableAllAutoTours,
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Text(
                                '🔕 Matikan tutorial otomatis di semua menu',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white30,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightHolePainter extends CustomPainter {
  final Rect? targetRect;
  final Color accentColor;

  const _SpotlightHolePainter({
    required this.targetRect,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = Path()..addRect(Offset.zero & size);
    final scrimPaint = Paint()
      ..color = const Color(0xD6030712)
      ..style = PaintingStyle.fill;

    if (targetRect == null) {
      canvas.drawPath(fullPath, scrimPaint);
      return;
    }

    final padded = targetRect!.inflate(6);
    final rrect = RRect.fromRectAndRadius(padded, const Radius.circular(20));
    final holePath = Path()..addRRect(rrect);
    final cutout = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(cutout, scrimPaint);

    // Glow halo + neon border around the highlighted element
    final haloPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRRect(rrect.inflate(2), haloPaint);

    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightHolePainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.accentColor != accentColor;
  }
}
