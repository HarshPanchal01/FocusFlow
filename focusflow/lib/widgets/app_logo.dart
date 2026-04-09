import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const AppLogo({
    super.key,
    this.size = 100,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.35),
                  blurRadius: size * 0.15,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background 'F' - Increased opacity and slightly adjusted position
          Padding(
            padding: EdgeInsets.only(right: size * 0.18, bottom: size * 0.12),
            child: Text(
              'F',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75), // Increased from 0.4
                fontSize: size * 0.68,
                fontWeight: FontWeight.w900,
                fontFamily: 'sans-serif',
                height: 1,
                letterSpacing: -2,
              ),
            ),
          ),
          // Foreground 'F'
          Padding(
            padding: EdgeInsets.only(left: size * 0.12, top: size * 0.08),
            child: Text(
              'F',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.65,
                fontWeight: FontWeight.w900,
                fontFamily: 'sans-serif',
                height: 1,
                letterSpacing: -2,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
