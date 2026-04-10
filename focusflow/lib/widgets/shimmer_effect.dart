import 'dart:math';
import 'package:flutter/material.dart';

/// A diagonal shine sweep that plays twice — like light catching a polished
/// surface. Used on the Focus Patterns card when ML data updates.
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final bool animate;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.animate = false,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 620),
      vsync: this,
    );
    if (widget.animate) {
      _hasAnimated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runShimmer();
      });
    }
  }

  Future<void> _runShimmer() async {
    if (!mounted) return;
    await _controller.forward(from: 0);
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 130));
    if (!mounted) return;
    await _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(ShimmerEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate && !_hasAnimated) {
      _hasAnimated = true;
      _runShimmer();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (_controller.value == 0 && !_controller.isAnimating) {
                  return const SizedBox.shrink();
                }
                return CustomPaint(
                  painter: _ShinePainter(progress: _controller.value),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ShinePainter extends CustomPainter {
  final double progress;

  _ShinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final bandWidth = size.width * 0.26;
    final skewX = size.height * 0.38; // how diagonal the streak is

    // Sweep from fully off-left to fully off-right
    final centerX = -bandWidth - skewX +
        progress * (size.width + 2 * (bandWidth + skewX));

    // Diagonal parallelogram path
    final path = Path()
      ..moveTo(centerX - bandWidth / 2 + skewX, 0)
      ..lineTo(centerX + bandWidth / 2 + skewX, 0)
      ..lineTo(centerX + bandWidth / 2 - skewX, size.height)
      ..lineTo(centerX - bandWidth / 2 - skewX, size.height)
      ..close();

    // Gradient perpendicular to the streak
    final gradRect = Rect.fromLTWH(
      centerX - bandWidth / 2 - skewX,
      0,
      bandWidth + 2 * skewX,
      size.height,
    );

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.42),
          Colors.white.withValues(alpha: 0.78),
          Colors.white.withValues(alpha: 0.42),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(gradRect);

    canvas.drawPath(path, paint);

    // Sparkle stars at the leading tip of the streak
    final tipX = centerX + skewX;
    final tipY = size.height * 0.2;

    if (tipX > -10 && tipX < size.width + 10) {
      // Fade sparkle in/out around middle of sweep
      final fadeProgress = ((progress - 0.08) / 0.84).clamp(0.0, 1.0);
      final opacity =
          (1.0 - (fadeProgress - 0.5).abs() * 2.4).clamp(0.0, 1.0);

      if (opacity > 0) {
        final mainPaint = Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..style = PaintingStyle.fill;

        final smallPaint = Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.65)
          ..style = PaintingStyle.fill;

        // Main sparkle
        _draw4PointStar(
            canvas, Offset(tipX, tipY), size.height * 0.09, mainPaint);

        // Secondary smaller sparkle offset up-right
        _draw4PointStar(
            canvas,
            Offset(tipX + size.height * 0.13, tipY - size.height * 0.06),
            size.height * 0.045,
            smallPaint);
      }
    }
  }

  void _draw4PointStar(
      Canvas canvas, Offset center, double outerRadius, Paint paint) {
    final innerRadius = outerRadius * 0.2;
    final path = Path();

    for (int i = 0; i < 8; i++) {
      final angle = (i * pi / 4) - pi / 2;
      final r = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ShinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
