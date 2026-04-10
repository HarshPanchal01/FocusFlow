import 'dart:math';
import 'package:flutter/material.dart';

/// A celebration animation overlay that shows rising particles
/// when a focus session completes. Automatically dismisses after
/// the animation finishes.
///
/// Usage:
///   CelebrationOverlay.show(context);
class CelebrationOverlay {
  static void show(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _CelebrationWidget(
        onComplete: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _CelebrationWidget extends StatefulWidget {
  final VoidCallback onComplete;
  const _CelebrationWidget({required this.onComplete});

  @override
  State<_CelebrationWidget> createState() => _CelebrationWidgetState();
}

class _CelebrationWidgetState extends State<_CelebrationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();

    // Generate particles
    _particles = List.generate(30, (_) => _Particle(
      x: _random.nextDouble(),
      startY: 0.9 + _random.nextDouble() * 0.2,
      speed: 0.3 + _random.nextDouble() * 0.7,
      size: 4.0 + _random.nextDouble() * 8.0,
      color: [
        const Color(0xFF4CAF50), // green
        const Color(0xFF8BC34A), // light green
        const Color(0xFFFFC107), // amber
        const Color(0xFFFF9800), // orange
        const Color(0xFF2E7D32), // dark green
        const Color(0xFFFFEB3B), // yellow
        Colors.white,
      ][_random.nextInt(7)],
      drift: (_random.nextDouble() - 0.5) * 0.3,
      shape: _random.nextBool() ? _ParticleShape.circle : _ParticleShape.square,
    ));

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return IgnorePointer(
          child: CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ParticlePainter(
              particles: _particles,
              progress: _controller.value,
            ),
          ),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress * p.speed).clamp(0.0, 1.0);
      
      // Rise from bottom, slow down near top
      final curve = Curves.easeOutCubic.transform(t);
      final y = (p.startY - curve * 1.2) * size.height;
      final x = (p.x + p.drift * t) * size.width;

      // Fade out in the last 30%
      final opacity = t > 0.7 ? (1.0 - (t - 0.7) / 0.3) : 1.0;

      // Slight rotation for squares
      final rotation = t * pi * 2 * p.drift;

      final paint = Paint()
        ..color = p.color.withOpacity(opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      if (p.shape == _ParticleShape.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            const Radius.circular(1),
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.progress != progress;
}

class _Particle {
  final double x;        // horizontal position 0-1
  final double startY;   // start near bottom
  final double speed;    // how fast it rises
  final double size;     // pixel size
  final Color color;
  final double drift;    // horizontal movement
  final _ParticleShape shape;

  _Particle({
    required this.x,
    required this.startY,
    required this.speed,
    required this.size,
    required this.color,
    required this.drift,
    required this.shape,
  });
}

enum _ParticleShape { circle, square }
