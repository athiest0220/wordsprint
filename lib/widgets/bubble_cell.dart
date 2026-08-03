import 'package:flutter/material.dart';
import '../theme.dart';

/// A 3D "bubble" — a glossy sphere with a radial highlight, a bright specular
/// dot, and a soft drop shadow. Visual only: taps are handled by [BubbleBoard]
/// (nearest-bubble routing) so there are no dead zones between bubbles.
class BubbleCell extends StatelessWidget {
  final String letter;
  final bool isCenter;
  final double diameter;
  final bool pressed;

  const BubbleCell({
    super.key,
    required this.letter,
    required this.isCenter,
    required this.diameter,
    this.pressed = false,
  });

  @override
  Widget build(BuildContext context) {
    final d = diameter;
    final base = isCenter ? BeeColors.bubbleCenter : BeeColors.bubbleOuter;
    final highlight = Color.lerp(base, Colors.white, 0.55)!;
    final edge = Color.lerp(base, Colors.black, 0.42)!;

    return AnimatedScale(
      scale: pressed ? 0.9 : 1.0,
      duration: const Duration(milliseconds: 70),
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.42),
            radius: 0.95,
            colors: [highlight, base, edge],
            stops: const [0.0, 0.55, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: d * 0.12,
              offset: Offset(0, d * 0.07),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: d * 0.20,
              top: d * 0.14,
              child: Container(
                width: d * 0.30,
                height: d * 0.22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(d),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.55),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Text(
              letter,
              style: TextStyle(
                color: BeeColors.bubbleText,
                fontSize: d * 0.42,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: d * 0.04,
                    offset: Offset(0, d * 0.02),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
