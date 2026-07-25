import 'package:flutter/material.dart';
import '../theme.dart';
import '../util/format.dart';

/// The three milestone times. These are captured values (they don't tick), so
/// they're always safe to show — the anxiety-inducing *live* clock lives
/// separately and is hidden by default.
class TimersBar extends StatelessWidget {
  final int? pangramMs;
  final int? perfectMs;
  final int? completeMs;
  final bool hasPerfect;
  final int pangramTotal;
  final int perfectTotal;

  const TimersBar({
    super.key,
    required this.pangramMs,
    required this.perfectMs,
    required this.completeMs,
    required this.hasPerfect,
    required this.pangramTotal,
    required this.perfectTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tile('🐝', 'Pangram', pangramMs, BeeColors.pangram,
            badge: pangramTotal),
        if (hasPerfect)
          _tile('⭐', 'Perfect', perfectMs, BeeColors.perfect,
              badge: perfectTotal),
        _tile('🏁', 'Complete', completeMs, BeeColors.good),
      ],
    );
  }

  Widget _tile(String icon, String label, int? ms, Color color, {int? badge}) {
    final pending = ms == null;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: BeeColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: pending ? BeeColors.surfaceHi : color.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Text('$icon $label',
                    style: const TextStyle(
                        fontSize: 11, color: BeeColors.muted, height: 1.2)),
                const SizedBox(height: 2),
                Text(
                  formatClock(ms),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: pending ? BeeColors.muted : color,
                  ),
                ),
              ],
            ),
            // Small count badge: how many (perfect) pangrams exist.
            if (badge != null && badge > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F1420),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
