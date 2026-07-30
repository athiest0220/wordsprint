import 'package:flutter/material.dart';

import '../models/stats.dart';
import '../theme.dart';
import '../util/brand.dart';
import '../util/format.dart';
import '../util/share_image.dart';

/// Shows a rendered stats "result card" (with the real logo) and shares it as
/// an image — the stats counterpart to [ShareResultScreen]. Falls back to plain
/// text if the image capture fails.
class StatsShareScreen extends StatefulWidget {
  final String label;
  final SizeStats stats;

  const StatsShareScreen({
    super.key,
    required this.label,
    required this.stats,
  });

  @override
  State<StatsShareScreen> createState() => _StatsShareScreenState();
}

class _StatsShareScreenState extends State<StatsShareScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  String get _caption {
    final s = widget.stats;
    final b = StringBuffer('📖 Word Sprint — ${widget.label}\n');
    b.writeln('Games played ${s.gamesStarted}, completed ${s.gamesCompleted}');
    if (s.pangramCount > 0) {
      b.writeln('🐝 Pangram   avg ${formatClockShort(s.avgPangramMs)}'
          '  best ${formatClockShort(s.pangramBestMs)}');
    }
    if (s.perfectCount > 0) {
      b.writeln('⭐ Perfect   avg ${formatClockShort(s.avgPerfectMs)}'
          '  best ${formatClockShort(s.perfectBestMs)}');
    }
    if (s.completeCount > 0) {
      b.writeln('🏁 Complete  avg ${formatClockShort(s.avgCompleteMs)}'
          '  best ${formatClockShort(s.completeBestMs)}');
    }
    if (s.oopsRate != null) {
      b.writeln('🙈 Oops rate ${(s.oopsRate! * 100).toStringAsFixed(0)}%');
    }
    b.writeln(kWordSprintShareTag);
    return b.toString().trimRight();
  }

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      await shareCapturedCard(
        boundaryKey: _cardKey,
        origin: _shareOrigin(),
        fallbackText: _caption,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share stats')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: _StatsCard(label: widget.label, stats: widget.stats),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: BeeColors.accent,
                  foregroundColor: const Color(0xFF0F1420),
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _busy ? null : _shareImage,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Color(0xFF0F1420)))
                    : const Icon(Icons.ios_share),
                label: Text(_busy ? 'Preparing…' : 'Share image'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The visual stats card that gets captured to an image.
class _StatsCard extends StatelessWidget {
  final String label;
  final SizeStats stats;

  const _StatsCard({required this.label, required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Container(
      width: 360,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C2942), Color(0xFF0E1622)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: BeeColors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset('assets/icon/logo.png', width: 46, height: 46),
              const SizedBox(width: 10),
              const Text('Word Sprint',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Text('$label · career stats',
              style: const TextStyle(fontSize: 15, color: BeeColors.muted)),
          const SizedBox(height: 16),
          Text('${s.gamesCompleted} completed · ${s.gamesStarted} played',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: BeeColors.cellText)),
          const SizedBox(height: 16),
          if (s.pangramCount > 0)
            _row('🐝', 'Pangram', s.avgPangramMs, s.pangramBestMs,
                s.pangramCount),
          if (s.perfectCount > 0)
            _row('⭐', 'Perfect', s.avgPerfectMs, s.perfectBestMs,
                s.perfectCount),
          if (s.completeCount > 0)
            _row('🏁', 'Complete', s.avgCompleteMs, s.completeBestMs,
                s.completeCount),
          if (s.oopsRate != null) ...[
            const SizedBox(height: 8),
            Text('🙈 Oops rate ${(s.oopsRate! * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(color: BeeColors.muted, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          const Text('Race the dictionary ⏱',
              textAlign: TextAlign.center,
              style: TextStyle(color: BeeColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          const Text(kWordSprintShareTag,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: BeeColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _row(String icon, String label, int? avg, int? best, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text('$icon $label',
                style: const TextStyle(
                    fontSize: 14, color: BeeColors.outerCellText)),
          ),
          Expanded(
            flex: 3,
            child: _kv('avg', formatClockShort(avg)),
          ),
          Expanded(
            flex: 3,
            child: _kv('best', formatClockShort(best)),
          ),
          Expanded(
            flex: 2,
            child: Text('×$count',
                textAlign: TextAlign.right,
                style: const TextStyle(color: BeeColors.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('$k ',
            style: const TextStyle(color: BeeColors.muted, fontSize: 11)),
        Text(v,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()])),
      ],
    );
  }
}
