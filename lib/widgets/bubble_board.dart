import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'bubble_cell.dart';

class _Spot {
  final String letter;
  final Offset center;
  final double diameter;
  final bool isCenter;
  const _Spot(this.letter, this.center, this.diameter, this.isCenter);
}

/// Lays out the required center bubble with the other letters on a ring around
/// it, sized so nothing overlaps. Every tap in the board is routed to the
/// *nearest* bubble, so there are no dead zones — a tap anywhere registers the
/// closest letter.
class BubbleBoard extends StatefulWidget {
  final String center;
  final List<String> outer;
  final void Function(String letter) onLetter;

  const BubbleBoard({
    super.key,
    required this.center,
    required this.outer,
    required this.onLetter,
  });

  @override
  State<BubbleBoard> createState() => _BubbleBoardState();
}

class _BubbleBoardState extends State<BubbleBoard> {
  List<_Spot> _spots = const [];
  String? _pressed;

  _Spot? _nearest(Offset p) {
    _Spot? best;
    var bestD = double.infinity;
    for (final s in _spots) {
      final dx = s.center.dx - p.dx, dy = s.center.dy - p.dy;
      final dist = dx * dx + dy * dy;
      if (dist < bestD) {
        bestD = dist;
        best = s;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = math.min(constraints.maxWidth, constraints.maxHeight);
        final n = widget.outer.length;
        final cx = s / 2, cy = s / 2;

        final radius = s * 0.36;
        final adjacent = 2 * radius * math.sin(math.pi / n);
        final dOuter = math.min(s * 0.25, adjacent * 0.80);
        final dCenter = math.min(s * 0.28, dOuter * 1.14);

        // Compute spot geometry (also used by the tap router).
        final spots = <_Spot>[
          for (var i = 0; i < n; i++)
            _Spot(
              widget.outer[i],
              Offset(
                cx + radius * math.cos(-math.pi / 2 + 2 * math.pi * i / n),
                cy + radius * math.sin(-math.pi / 2 + 2 * math.pi * i / n),
              ),
              dOuter,
              false,
            ),
          _Spot(widget.center, Offset(cx, cy), dCenter, true),
        ];
        _spots = spots;

        final children = <Widget>[
          for (final spot in spots)
            Positioned(
              left: spot.center.dx - spot.diameter / 2,
              top: spot.center.dy - spot.diameter / 2,
              child: BubbleCell(
                letter: spot.letter,
                isCenter: spot.isCenter,
                diameter: spot.diameter,
                pressed: _pressed == spot.letter,
              ),
            ),
        ];

        return SizedBox(
          width: s,
          height: s,
          // Raw Listener + fire on pointer-DOWN: registers instantly, ignores
          // the gesture arena and drag-slop, so no taps get dropped.
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              final hit = _nearest(e.localPosition);
              if (hit != null) {
                setState(() => _pressed = hit.letter);
                widget.onLetter(hit.letter);
              }
            },
            onPointerUp: (_) => setState(() => _pressed = null),
            onPointerCancel: (_) => setState(() => _pressed = null),
            child: Stack(children: children),
          ),
        );
      },
    );
  }
}
