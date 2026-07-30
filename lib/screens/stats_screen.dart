import 'package:flutter/material.dart';

import '../services/app_repository.dart';
import '../models/stats.dart';
import '../theme.dart';
import '../util/format.dart';
import 'stats_share_card.dart';

/// Career averages and bests, per letter-count plus an overall roll-up.
class StatsScreen extends StatefulWidget {
  final AppRepository repo;
  const StatsScreen({super.key, required this.repo});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    final book = widget.repo.stats.book;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Reset stats',
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _card('All sizes', book.overall, highlight: true),
            for (final size in [6, 7, 8, 9, 10, 11])
              _card('$size letters', book.bySize[size]!),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, SizeStats s, {bool highlight = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: highlight ? BeeColors.surfaceHi : BeeColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: BeeColors.accent)),
                const Spacer(),
                Text('${s.gamesCompleted} done / ${s.gamesStarted} played',
                    style: const TextStyle(
                        fontSize: 12, color: BeeColors.muted)),
                if (s.gamesStarted > 0 || s.gamesEnded > 0)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.ios_share, size: 18),
                    tooltip: 'Share $title',
                    onPressed: () => _shareSize(title, s),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _statLine('🐝 Pangram', s.avgPangramMs, s.pangramBestMs,
                s.pangramCount),
            _statLine('⭐ Perfect pangram', s.avgPerfectMs, s.perfectBestMs,
                s.perfectCount),
            _statLine('🏁 Complete', s.avgCompleteMs, s.completeBestMs,
                s.completeCount),
            const Divider(height: 14, color: BeeColors.surfaceHi),
            Row(
              children: [
                const Expanded(
                  flex: 4,
                  child: Text('🙈 Oops rate',
                      style: TextStyle(color: BeeColors.outerCellText)),
                ),
                Expanded(
                  flex: 6,
                  child: Text(
                    s.oopsRate == null
                        ? '—'
                        : '${(s.oopsRate! * 100).toStringAsFixed(0)}%  '
                            '(${s.oopsTotal} in ${s.attemptsTotal} tries)',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: BeeColors.bad),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statLine(String label, int? avg, int? best, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              flex: 4,
              child: Text(label,
                  style: const TextStyle(color: BeeColors.outerCellText))),
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

  void _shareSize(String label, SizeStats s) {
    // Open the rendered stats card, which shares as an image (with the
    // download-URL footer) — the stats counterpart to the result share.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StatsShareScreen(label: label, stats: s),
    ));
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BeeColors.surface,
        title: const Text('Reset all statistics?'),
        content: const Text('This clears every average and best time. '
            'It cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset',
                  style: TextStyle(color: BeeColors.bad))),
        ],
      ),
    );
    if (ok == true) {
      await widget.repo.stats.reset();
      if (mounted) setState(() {});
    }
  }
}
