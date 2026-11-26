import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpotlightStepSpec {
  final GlobalKey targetKey;
  final int tabIndex;
  final String emoji;
  final String title;
  final String description;
  final Color accent;

  const SpotlightStepSpec({
    required this.targetKey,
    required this.tabIndex,
    required this.emoji,
    required this.title,
    required this.description,
    required this.accent,
  });
}

/// Overlay interaktif Guided Spotlight Tour (6 Langkah) murni CustomPainter
/// tanpa BackdropFilter agar 100% mulus 60-120 FPS di semua perangkat Android.
class GuidedSpotlightOverlay extends StatefulWidget {
  final List<SpotlightStepSpec> steps;
  final int currentStep;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onSkip;

  const GuidedSpotlightOverlay({
    Key? key,
    required this.steps,
    required this.currentStep,
    required this.onNext,
    required this.onPrev,
    required this.onSkip,
  }) : super(key: key);

  @override
  State<GuidedSpotlightOverlay> createState() => _GuidedSpotlightOverlayState();
}

class _GuidedSpotlightOverlayState extends State<GuidedSpotlightOverlay> {
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant GuidedSpotlightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep) {
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
    final targetCtx = spec.targetKey.currentContext;
    final overlayBox = context.findRenderObject() as RenderBox?;
    final targetBox = targetCtx?.findRenderObject() as RenderBox?;

    if (overlayBox != null &&
        targetBox != null &&
        overlayBox.hasSize &&
        targetBox.hasSize &&
        targetBox.attached) {
      final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
      final rect = topLeft & targetBox.size;
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
      cardTop = math.min(spot.bottom + 16, screenH - 270 - safeBottom);
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
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: spec.accent.withValues(alpha: 0.22),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: spec.accent.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: spec.accent.withValues(alpha: 0.55),
                              ),
                            ),
                            child: Text(
                              'Langkah ${widget.currentStep + 1} / $total',
                              style: TextStyle(
                                color: spec.accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: widget.onSkip,
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                'Lewati Tutorial ✕',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: spec.accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: spec.accent.withValues(alpha: 0.50),
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
                            child: Text(
                              spec.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        spec.description,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 12.2,
                          height: 1.42,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Row(
                            children: List.generate(total, (idx) {
                              final active = idx == widget.currentStep;
                              return Container(
                                margin: const EdgeInsets.only(right: 5),
                                width: active ? 18 : 6,
                                height: 6,
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
