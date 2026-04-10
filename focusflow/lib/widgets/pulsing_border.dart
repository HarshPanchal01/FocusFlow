import 'package:flutter/material.dart';

/// Wraps a child widget with a subtle pulsing glow border.
/// Used on tasks that are overdue or due today to draw attention.
///
/// The border color pulses between full opacity and a lower opacity
/// in a smooth loop, creating an "urgent" visual cue.
class PulsingBorder extends StatefulWidget {
  final Widget child;
  final Color color;
  final double borderRadius;
  final bool active;

  const PulsingBorder({
    super.key,
    required this.child,
    this.color = Colors.red,
    this.borderRadius = 8,
    this.active = true,
  });

  @override
  State<PulsingBorder> createState() => _PulsingBorderState();
}

class _PulsingBorderState extends State<PulsingBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulsingBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_glowAnimation.value * 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: widget.color.withOpacity(_glowAnimation.value),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: widget.child,
          ),
        );
      },
    );
  }
}
