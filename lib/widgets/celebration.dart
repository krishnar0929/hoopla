import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Full-screen "Congratulations!" with balloons floating up and confetti falling.
/// Shown above every screen, so it keeps playing while the app moves on.
/// Tap anywhere to close it early.
class Celebration {
  static OverlayEntry? _current;

  /// Grab [overlayOf] before any `await` (the screen may be gone afterwards):
  /// `final overlay = Celebration.overlayOf(context);` … `Celebration.show(overlay, ...)`.
  static OverlayState? overlayOf(BuildContext context) => Overlay.maybeOf(context, rootOverlay: true);

  static void show(
    OverlayState? overlay, {
    String title = 'Congratulations!',
    String message = '',
    String emoji = '🎉',
    Duration duration = const Duration(milliseconds: 4200),
  }) {
    if (overlay == null || !overlay.mounted) return;
    _current?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationView(
        title: title,
        message: message,
        emoji: emoji,
        duration: duration,
        onDone: () {
          if (_current == entry) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
    HapticFeedback.heavyImpact();
  }
}

class _CelebrationView extends StatefulWidget {
  const _CelebrationView({required this.title, required this.message, required this.emoji, required this.duration, required this.onDone});
  final String title;
  final String message;
  final String emoji;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_CelebrationView> createState() => _CelebrationViewState();
}

class _CelebrationViewState extends State<_CelebrationView> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this, duration: widget.duration);
  late final List<_Balloon> balloons;
  late final List<_Confetti> confetti;
  bool closing = false;

  static const _balloonColors = [
    Color(0xFFFF6B4A),
    Color(0xFF6C4CF5),
    Color(0xFFFFB020),
    Color(0xFFFF5FA2),
    Color(0xFF2EC4B6),
    Color(0xFF3A86FF),
    Color(0xFFC8F560),
  ];
  static const _confettiColors = [
    Color(0xFFE63946),
    Color(0xFF1D3BAF),
    Color(0xFFFFB020),
    Color(0xFF6C4CF5),
    Color(0xFF2EC4B6),
    Color(0xFFFF5FA2),
  ];

  @override
  void initState() {
    super.initState();
    final r = Random();
    balloons = List.generate(16, (i) {
      return _Balloon(
        x: r.nextDouble(),
        delay: r.nextDouble() * 0.35,
        speed: 0.55 + r.nextDouble() * 0.45,
        size: 0.8 + r.nextDouble() * 0.6,
        sway: 0.02 + r.nextDouble() * 0.03,
        phase: r.nextDouble() * pi * 2,
        color: _balloonColors[i % _balloonColors.length],
      );
    });
    confetti = List.generate(110, (i) {
      return _Confetti(
        x: r.nextDouble(),
        delay: r.nextDouble() * 0.45,
        speed: 0.6 + r.nextDouble() * 0.7,
        spin: (r.nextDouble() - 0.5) * 14,
        drift: (r.nextDouble() - 0.5) * 0.25,
        w: 6 + r.nextDouble() * 6,
        h: 3 + r.nextDouble() * 4,
        color: _confettiColors[i % _confettiColors.length],
      );
    });
    controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _close() {
    if (closing) return;
    closing = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = controller.value;
            // Fade in fast, hold, fade out over the last 15%.
            final fade = t < 0.08 ? t / 0.08 : (t > 0.85 ? (1 - t) / 0.15 : 1.0);
            final pop = Curves.elasticOut.transform((t / 0.3).clamp(0.0, 1.0));
            return Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.black.withValues(alpha: 0.28)),
                  if (!reduceMotion)
                    CustomPaint(painter: _PartyPainter(t: t, balloons: balloons, confetti: confetti)),
                  Center(
                    child: Transform.scale(
                      scale: reduceMotion ? 1 : 0.6 + 0.4 * pop,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                          constraints: const BoxConstraints(maxWidth: 380),
                          decoration: BoxDecoration(
                            color: HC.card,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: const [BoxShadow(color: Color(0x3317142B), blurRadius: 30, offset: Offset(0, 12))],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.emoji, style: const TextStyle(fontSize: 56)),
                              const SizedBox(height: 6),
                              Text(widget.title, textAlign: TextAlign.center, style: display(28)),
                              if (widget.message.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(widget.message, textAlign: TextAlign.center, style: body(15, color: HC.muted)),
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
          },
        ),
      ),
    );
  }
}

class _Balloon {
  _Balloon({required this.x, required this.delay, required this.speed, required this.size, required this.sway, required this.phase, required this.color});
  final double x, delay, speed, size, sway, phase;
  final Color color;
}

class _Confetti {
  _Confetti({
    required this.x,
    required this.delay,
    required this.speed,
    required this.spin,
    required this.drift,
    required this.w,
    required this.h,
    required this.color,
  });
  final double x, delay, speed, spin, drift, w, h;
  final Color color;
}

class _PartyPainter extends CustomPainter {
  _PartyPainter({required this.t, required this.balloons, required this.confetti});
  final double t;
  final List<_Balloon> balloons;
  final List<_Confetti> confetti;

  @override
  void paint(Canvas canvas, Size size) {
    // Confetti falls from above the top edge, spinning and drifting.
    for (final c in confetti) {
      final p = ((t - c.delay) * c.speed * 1.6);
      if (p <= 0) continue;
      final y = -20 + p * (size.height + 40);
      if (y > size.height + 20) continue;
      final x = (c.x + c.drift * p) * size.width + sin(p * 9 + c.spin) * 12;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p * c.spin);
      // Flip on one axis so pieces "flutter".
      canvas.scale(1, cos(p * c.spin * 1.7).abs().clamp(0.2, 1.0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: c.w, height: c.h), const Radius.circular(1.5)),
        Paint()..color = c.color,
      );
      canvas.restore();
    }

    // Balloons rise from below the bottom edge, swaying side to side.
    for (final b in balloons) {
      final p = ((t - b.delay) * b.speed * 1.5);
      if (p <= 0) continue;
      final r = 26.0 * b.size;
      final y = size.height + r * 3 - p * (size.height + r * 6);
      if (y < -r * 4) continue;
      final x = b.x * size.width + sin(p * 6 + b.phase) * size.width * b.sway;
      _balloon(canvas, Offset(x, y), r, b.color, sin(p * 5 + b.phase) * 0.12);
    }
  }

  void _balloon(Canvas canvas, Offset c, double r, Color color, double tilt) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    final body = Rect.fromCenter(center: Offset.zero, width: r * 1.7, height: r * 2.05);

    // String
    final string = Path()
      ..moveTo(0, r * 1.08)
      ..cubicTo(r * 0.3, r * 1.6, -r * 0.3, r * 2.1, r * 0.1, r * 2.8);
    canvas.drawPath(string, Paint()
      ..color = const Color(0x8817142B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    // Knot
    final knot = Path()
      ..moveTo(-r * 0.12, r * 1.14)
      ..lineTo(r * 0.12, r * 1.14)
      ..lineTo(0, r * 0.98)
      ..close();
    canvas.drawPath(knot, Paint()..color = color);

    // Body with a soft gradient and a shine
    canvas.drawOval(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [Color.lerp(color, Colors.white, 0.35)!, color, Color.lerp(color, Colors.black, 0.18)!],
          stops: const [0, 0.55, 1],
        ).createShader(body),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-r * 0.35, -r * 0.45), width: r * 0.35, height: r * 0.6),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PartyPainter old) => old.t != t;
}
