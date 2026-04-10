import 'package:flutter/material.dart';

/// A text widget that pulses subtly while active,
/// giving the timer a "breathing" feel during focus sessions.
class PulsingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final bool isActive;

  const PulsingText({
    super.key,
    required this.text,
    this.style,
    this.isActive = false,
  });

  @override
  State<PulsingText> createState() => _PulsingTextState();
}

class _PulsingTextState extends State<PulsingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _opacity = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulsingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0; // Reset to full opacity
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Text(widget.text, style: widget.style);
    }

    return FadeTransition(
      opacity: _opacity,
      child: Text(widget.text, style: widget.style),
    );
  }
}
