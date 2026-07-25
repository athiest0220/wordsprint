import 'package:flutter/material.dart';

import '../models/game_progress.dart';
import '../models/puzzle.dart';
import '../services/app_repository.dart';
import '../theme.dart';
import '../util/format.dart';
import 'share_card.dart';

/// Shown when a puzzle is completed (or re-opened after completion). Celebrates
/// the three times and compares each to the player's running average.
class ResultsScreen extends StatelessWidget {
  final AppRepository repo;
  final Puzzle puzzle;
  const ResultsScreen({super.key, required this.repo, required this.puzzle});

  @override
  Widget build(BuildContext context) {
    final GameProgress prog = repo.progress.load(puzzle.key);
    final stats = repo.stats.forSize(puzzle.size);

    var score = 0;
    for (final w in prog.foundWords) {
      score += puzzle.scoreFor(w);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${puzzle.title ?? '${puzzle.size} Letters'} — Complete'),
        actions: [
          if (!puzzle.isReroll)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Share result',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ShareResultScreen(
                puzzle: puzzle,
                foundCount: prog.foundWords.length,
                score: score,
                pangramMs: prog.pangramMs,
                perfectMs: prog.perfectMs,
                completeMs: prog.completeMs,
                oopsCount: prog.oopsCount,
                oopsAttempts: prog.foundWords.length + prog.oopsCount,
                elapsedMs: prog.completeMs ?? prog.elapsedMs,
              ),
            )),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            const Center(
              child: Text('🏆', style: TextStyle(fontSize: 56)),
            ),
            const Center(
              child: Text('Queen Bee!',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: BeeColors.accent)),
            ),
            Center(
              child: Text(
                'All ${puzzle.validWords.length} words • '
                '${puzzle.pangrams.length} pangrams',
                style: const TextStyle(color: BeeColors.muted),
              ),
            ),
            Center(
              child: Text(
                _oopsLine(prog),
                style: const TextStyle(color: BeeColors.muted, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            _resultRow('🐝', 'Time to pangram', prog.pangramMs,
                stats.avgPangramMs, stats.pangramBestMs, BeeColors.pangram),
            if (puzzle.hasPerfectPangram)
              _resultRow('⭐', 'Time to perfect pangram', prog.perfectMs,
                  stats.avgPerfectMs, stats.perfectBestMs, BeeColors.perfect),
            _resultRow('🏁', 'Time to complete', prog.completeMs,
                stats.avgCompleteMs, stats.completeBestMs, BeeColors.good),
            const SizedBox(height: 24),
            Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final w in (puzzle.pangrams.toList()..sort()))
                    Chip(
                      label: Text(w),
                      backgroundColor: BeeColors.accent.withValues(alpha: 0.25),
                      side: const BorderSide(color: BeeColors.accent),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: BeeColors.accent,
                foregroundColor: const Color(0xFF0F1420),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Back to puzzles',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  String _oopsLine(GameProgress prog) {
    final attempts = prog.foundWords.length + prog.oopsCount;
    final pct = attempts == 0 ? 0 : (prog.oopsCount / attempts * 100).round();
    return 'Oops rate: ${prog.oopsCount} mistakes ($pct%)';
  }

  Widget _resultRow(String icon, String label, int? ms, int? avgMs,
      int? bestMs, Color color) {
    final beatAvg = ms != null && avgMs != null && ms <= avgMs;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13, color: BeeColors.muted)),
                  const SizedBox(height: 2),
                  Text(
                    formatClock(ms),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('avg ${formatClockShort(avgMs)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: beatAvg ? BeeColors.good : BeeColors.muted)),
                Text('best ${formatClockShort(bestMs)}',
                    style: const TextStyle(
                        fontSize: 12, color: BeeColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
